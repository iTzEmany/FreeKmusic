import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/activity_log_repository.dart';
import '../../data/repositories/credits_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../recognition/track_identity.dart';
import '../tags/tag_writer.dart';
import 'track_editor.dart';

/// What a recognition changes in a track's title and artist: the same road as
/// a hand edit (`TrackEditor.save`, the file when a hand edit would write it),
/// with the old values in the Registro and the decision kept in `rec.prop`.
class TrackCorrections {
  TrackCorrections(
    this._db,
    this._editor,
    this._credits, {
    Future<TagWriteReason?> Function(String path)? fileBlock,
    int Function()? now,
  }) : _fileBlock = fileBlock ?? ((_) async => null),
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final TrackEditor _editor;
  final CreditsRepository _credits;

  /// Why the file cannot be rewritten (null = it can), as the edit dialog asks.
  final Future<TagWriteReason?> Function(String path) _fileBlock;
  final int Function() _now;

  /// Puts the identity of [rec] in [track]. [byUser] marks the track as edited
  /// (an accepted proposal); otherwise it is an automatic correction. A track
  /// the user edited is never touched (invariant 1). True if something changed.
  Future<bool> apply(Track track, Recognition rec, {required bool byUser}) async {
    final id = rec.identity;
    final t = await TrackRepository(_db).getById(track.id);
    if (id == null || t == null || t.userEdited) return false;
    final artist = id.artist.isEmpty ? t.artist : id.artist;
    final changed = id.title != t.title || artist != t.artist;
    if (changed) {
      final ids = await _editor.fileIds(t); // what the file has, to put back
      await _write(t, id.title, artist, markEdited: byUser, isrc: id.isrc, mbid: id.mbid);
      await ActivityLogRepository(_db).add(
        at: _now(),
        kind: 'correction',
        name: id.title,
        detail: jsonEncode({
          'trackId': t.id,
          'old': {'title': t.title, 'artist': t.artist, 'isrc': ?ids?.isrc, 'mbid': ?ids?.mbid},
          'new': {'title': id.title, 'artist': artist},
          'src': rec.src?.name,
        }),
      );
    }
    await _setProp(t.id, rec, byUser ? 'accepted' : 'auto', was: changed ? {'title': t.title, 'artist': t.artist ?? ''} : rec.was);
    return changed;
  }

  /// The proposal of [trackId] is refused and does not come back.
  Future<void> discard(int trackId) => _setProp(trackId, null, 'discarded');

  /// Puts back what the Registro [row] (kind `correction`) says was there; the
  /// proposal is then discarded. Returns false for a row it cannot read.
  Future<bool> revert(ActivityLogRow row) async {
    try {
      final j = jsonDecode(row.detail ?? '') as Map;
      final id = j['trackId'] as int;
      final old = j['old'] as Map;
      final t = await TrackRepository(_db).getById(id);
      if (t == null) return false;
      // Missing keys (older rows) leave the file's ids alone.
      await _write(t, old['title'] as String, old['artist'] as String?,
          markEdited: false, isrc: old['isrc'] as String?, mbid: old['mbid'] as String?);
      await _setProp(id, null, 'discarded');
      return true;
    } on Object catch (e, st) {
      AppLog.w('correction ${row.id} not readable', e, st);
      return false;
    }
  }

  /// Accepts every open proposal, one by one; returns how many changed.
  Future<int> acceptAll() async {
    var n = 0;
    for (final p in await _credits.watchProposals().first) {
      if (await apply(p.track, p.rec, byUser: true)) n++;
    }
    return n;
  }

  Future<void> _write(Track t, String title, String? artist, {required bool markEdited, String? isrc, String? mbid}) async {
    final edit = TrackEdit(
      title: title,
      artist: artist,
      album: t.album,
      albumArtist: t.albumArtist,
      year: t.year,
      trackNumber: t.trackNumber,
      genre: t.genre,
      isrc: isrc,
      mbid: mbid,
    );
    await _editor.save(t, edit, markEdited: markEdited);
    if (await _fileBlock(t.path) == null) {
      await _editor.writeToFiles([t], (_) => edit.toChanges());
    }
  }

  Future<TrackEnrichData?> _enrichRow(int trackId) =>
      (_db.select(_db.trackEnrich)..where((e) => e.trackId.equals(trackId))).getSingleOrNull();

  /// Writes the decision in `rec` of the track (the stored one, or [from] when none).
  Future<void> _setProp(int trackId, Recognition? from, String prop, {Map<String, String>? was}) async {
    final row = await _enrichRow(trackId);
    final r = decodeRec(row?.details, trackId) ?? from;
    if (r == null) return;
    final rec = r.copyWith(prop: prop, was: was ?? r.was);
    final companion = TrackEnrichCompanion(trackId: Value(trackId), details: Value(mergeDetails(row?.details, rec: rec)));
    await _db.into(_db.trackEnrich).insert(companion, onConflict: DoUpdate((_) => companion));
  }
}

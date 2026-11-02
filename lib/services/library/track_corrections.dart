import 'dart:convert';

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
    String? Function()? playingPath,
  }) : _playingPath = playingPath ?? (() => null),
       _fileBlock = fileBlock ?? ((_) async => null),
       _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppDatabase _db;
  final TrackEditor _editor;
  final CreditsRepository _credits;

  /// Why the file cannot be rewritten (null = it can), as the edit dialog asks.
  final Future<TagWriteReason?> Function(String path) _fileBlock;
  final int Function() _now;

  /// The file playing now: an automatic correction leaves it alone (DB only).
  final String? Function() _playingPath;

  /// Puts the identity of [rec] in [track]. [byUser] marks the track as edited
  /// (an accepted proposal); otherwise it is an automatic correction (no file
  /// backup, and the file playing now is left alone). A track the user edited
  /// is never touched (invariant 1). The DB part (row, Registro, decision) is
  /// one transaction; the file comes after. True if something changed.
  Future<bool> apply(Track track, Recognition rec, {required bool byUser}) async {
    final id = rec.identity;
    final first = await TrackRepository(_db).getById(track.id);
    if (id == null || id.title.trim().isEmpty || first == null || first.userEdited) return false;
    final toFile = _fileWanted(first, byUser: byUser);
    // What the file has, to put back; read before the transaction (file I/O).
    final ids = toFile && changedBy(first, id) ? await _editor.fileIds(first) : null;
    TrackEdit? edit;
    Track? t;
    await _db.transaction(() async {
      t = await TrackRepository(_db).getById(track.id);
      final cur = t;
      if (cur == null || cur.userEdited) return;
      final artist = id.artist.isEmpty ? cur.artist : id.artist;
      final changed = id.title != cur.title || artist != cur.artist;
      if (changed) {
        edit = await _save(cur, id.title, artist, markEdited: byUser, isrc: id.isrc, mbid: id.mbid);
        await ActivityLogRepository(_db).add(
          at: _now(),
          kind: 'correction',
          name: id.title,
          detail: jsonEncode({
            'trackId': cur.id,
            'old': {'title': cur.title, 'artist': cur.artist, 'isrc': ?ids?.isrc, 'mbid': ?ids?.mbid},
            'new': {'title': id.title, 'artist': artist},
            'src': rec.src?.name,
          }),
        );
      }
      await _credits.setRecDecision(cur.id, byUser ? 'accepted' : 'auto',
          was: changed ? {'title': cur.title, 'artist': cur.artist ?? ''} : rec.was, from: rec);
    });
    final e = edit;
    if (e == null) return false;
    if (toFile) await _toFile(t!, e, backup: byUser);
    return true;
  }

  bool changedBy(Track t, TrackIdentity id) => id.title != t.title || (id.artist.isNotEmpty && id.artist != t.artist);

  /// The proposal of [trackId] is refused and does not come back.
  Future<void> discard(int trackId) => _credits.setRecDecision(trackId, 'discarded');

  /// Puts back what the Registro [row] (kind `correction`) says was there; the
  /// proposal is then discarded. Returns false for a row it cannot read, or
  /// when the track no longer holds the corrected title and artist (edited since).
  Future<bool> revert(ActivityLogRow row) async {
    try {
      final j = jsonDecode(row.detail ?? '') as Map;
      final id = j['trackId'] as int;
      final old = j['old'] as Map;
      final now = j['new'] as Map;
      TrackEdit? edit;
      Track? t;
      await _db.transaction(() async {
        t = await TrackRepository(_db).getById(id);
        final cur = t;
        if (cur == null || cur.title != now['title'] || cur.artist != now['artist']) return;
        // Missing keys (older rows) leave the file's ids alone.
        edit = await _save(cur, old['title'] as String, old['artist'] as String?,
            markEdited: false, isrc: old['isrc'] as String?, mbid: old['mbid'] as String?);
        await _credits.setRecDecision(id, 'discarded');
      });
      final e = edit;
      if (e == null) return false;
      await _toFile(t!, e);
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

  /// Whether the file of [t] is to be rewritten: a hand decision always, an automatic one not on the playing file.
  bool _fileWanted(Track t, {required bool byUser}) {
    if (!_editor.writesFiles) return false;
    if (!byUser && _playingPath() == t.path) {
      AppLog.i('correction of ${t.path}: file left alone, it is playing');
      return false;
    }
    return true;
  }

  /// The DB part of an edit.
  Future<TrackEdit> _save(Track t, String title, String? artist, {required bool markEdited, String? isrc, String? mbid}) async {
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
    return edit;
  }

  Future<void> _toFile(Track t, TrackEdit edit, {bool backup = true}) async {
    if (await _fileBlock(t.path) == null) {
      await _editor.writeToFiles([t], (_) => edit.toChanges(), backup: backup);
    }
  }
}

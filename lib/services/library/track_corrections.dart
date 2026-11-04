import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/activity_log_repository.dart';
import '../../data/repositories/credits_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../recognition/track_identity.dart';
import '../tags/tag_writer.dart';
import 'track_file_sync.dart' show TagFileOutcome;
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
    final job = await _prepare(track, rec, byUser: byUser);
    if (job == null) return false;
    final done = await _db.transaction(() => _applyDb(job, byUser: byUser));
    if (done == null) return false;
    if (job.toFile) await _toFile(done.track, done.edit, backup: byUser);
    return true;
  }

  /// What [apply] reads before its transaction (file I/O stays out of it);
  /// null when the track is not to be touched.
  Future<_Job?> _prepare(Track track, Recognition rec, {required bool byUser}) async {
    final id = rec.identity;
    final first = await TrackRepository(_db).getById(track.id);
    if (id == null || id.title.trim().isEmpty || first == null || first.userEdited) return null;
    final toFile = _fileWanted(first, byUser: byUser);
    // What the file has, to put back.
    final ids = toFile && changedBy(first, id) ? await _editor.fileIds(first) : null;
    return (trackId: track.id, rec: rec, toFile: toFile, ids: ids);
  }

  /// The DB part of [apply], to run inside a transaction; null when the row
  /// did not change (the decision is stored all the same).
  Future<({Track track, TrackEdit edit, int logId})?> _applyDb(_Job job, {required bool byUser}) async {
    final rec = job.rec;
    final id = rec.identity!;
    final cur = await TrackRepository(_db).getById(job.trackId);
    if (cur == null || cur.userEdited) return null;
    // Seconds may have passed since the list was read: a proposal refused or renewed meanwhile is not accepted.
    if (byUser) {
      final stored = decodeRec((await _credits.enrichOf(job.trackId))?.details, job.trackId);
      final now = stored?.identity;
      if (stored != null && (stored.prop != 'open' || now?.title != id.title || now?.artist != id.artist)) return null;
    }
    final artist = id.artist.isEmpty ? cur.artist : id.artist;
    final changed = id.title != cur.title || artist != cur.artist;
    TrackEdit? edit;
    int? logId;
    if (changed) {
      edit = await _save(cur, id.title, artist, markEdited: byUser, isrc: id.isrc, mbid: id.mbid);
      logId = await ActivityLogRepository(_db).add(
        at: _now(),
        kind: 'correction',
        name: id.title,
        detail: jsonEncode({
          'trackId': cur.id,
          'old': {'title': cur.title, 'artist': cur.artist, 'isrc': ?job.ids?.isrc, 'mbid': ?job.ids?.mbid},
          'new': {'title': id.title, 'artist': artist},
          'src': rec.src?.name,
        }),
      );
    }
    await _credits.setRecDecision(cur.id, byUser ? 'accepted' : 'auto',
        was: changed ? {'title': cur.title, 'artist': cur.artist ?? ''} : rec.was, from: rec);
    return edit == null ? null : (track: cur, edit: edit, logId: logId!);
  }

  bool changedBy(Track t, TrackIdentity id) => id.title != t.title || (id.artist.isNotEmpty && id.artist != t.artist);

  /// The proposal of [trackId] is refused and does not come back.
  Future<void> discard(int trackId) => _credits.setRecDecision(trackId, 'discarded');

  /// Puts back what the Registro [row] (kind `correction`) says was there; the
  /// proposal is then discarded, or with [reopen] (the «Annulla» of «Accetta
  /// tutte») put back among the open ones. Returns false for a row it cannot
  /// read, or when the track no longer holds the corrected title and artist (edited since).
  Future<bool> revert(ActivityLogRow row, {bool reopen = false}) async {
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
        if (reopen) {
          // Accepting marked the track as edited, which hides its proposal.
          await (_db.update(_db.tracks)..where((r) => r.id.equals(id))).write(const TracksCompanion(userEdited: Value(false)));
        }
        await _credits.setRecDecision(id, reopen ? 'open' : 'discarded');
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

  /// Accepts every open proposal in ONE transaction (one change of the list, D-361);
  /// the tags go into the files afterwards, one by one, in [AcceptedAll.files].
  Future<AcceptedAll> acceptAll() async {
    final jobs = <_Job>[];
    for (final p in await _credits.watchProposals().first) {
      final job = await _prepare(p.track, p.rec, byUser: true);
      if (job != null) jobs.add(job);
    }
    final done = await _db.transaction(() async => [
      for (final j in jobs)
        if (await _applyDb(j, byUser: true) case final d?) (job: j, done: d),
    ]);
    final ids = [for (final d in done) d.done.logId];
    final log = await (_db.select(_db.activityLogRows)..where((r) => r.id.isIn(ids))).get();
    final toFile = [for (final d in done) if (d.job.toFile) d.done];
    return AcceptedAll(log, _writeFiles([for (final d in toFile) (track: d.track, edit: d.edit)]));
  }

  /// The file part of [acceptAll]. Never throws: a file that stays untouched goes
  /// in the Registro as a failed `correction` row (no `old`/`new`), the DB stands.
  Future<void> _writeFiles(List<({Track track, TrackEdit edit})> jobs) async {
    for (final j in jobs) {
      try {
        final out = await _toFile(j.track, j.edit);
        final why = out.mainReason;
        if (why != null) await _fileFailed(j, why.name);
      } on Object catch (e, st) {
        AppLog.w('tags of ${j.track.path} not written', e, st);
        try {
          await _fileFailed(j, TagWriteReason.ioError.name);
        } on Object catch (e2, st2) {
          AppLog.w('file error of ${j.track.path} not logged', e2, st2);
        }
      }
    }
  }

  Future<void> _fileFailed(({Track track, TrackEdit edit}) j, String why) => ActivityLogRepository(_db).add(
    at: _now(),
    kind: 'correction',
    name: j.edit.title,
    failed: true,
    detail: jsonEncode({'trackId': j.track.id, 'file': why}),
  );

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

  Future<TagFileOutcome> _toFile(Track t, TrackEdit edit, {bool backup = true}) async {
    final why = await _fileBlock(t.path);
    if (why != null) return TagFileOutcome(attempted: 1, failures: {t.id: why});
    return _editor.writeToFiles([t], (_) => edit.toChanges(), backup: backup);
  }
}

typedef _Job = ({int trackId, Recognition rec, bool toFile, ({String? isrc, String? mbid})? ids});

/// What [TrackCorrections.acceptAll] did: the Registro rows of the corrections
/// (to put them back with `revert`) and the file writes, which may still run.
class AcceptedAll {
  const AcceptedAll(this.log, this.files);

  final List<ActivityLogRow> log;

  /// Completes when every file has been tried; never throws.
  final Future<void> files;

  int get count => log.length;
}

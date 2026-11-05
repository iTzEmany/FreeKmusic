import 'dart:convert';

import '../../core/app_log.dart';
import '../../core/clock.dart';
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
    String? Function()? playingPath,
  }) : _playingPath = playingPath ?? (() => null),
       _fileBlock = fileBlock ?? ((_) async => null);

  final AppDatabase _db;
  final TrackEditor _editor;
  final CreditsRepository _credits;

  /// Why the file cannot be rewritten (null = it can), as the edit dialog asks.
  final Future<TagWriteReason?> Function(String path) _fileBlock;

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
    // A file left as it was is told in the Registro when the user asked for it; an automatic one only in the log (a big library would fill the Registro).
    if (job.toFile) await _writeFile(done.track, done.edit, backup: byUser, report: byUser);
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
    final artist = id.artistOver(cur.artist);
    final changed = id.title != cur.title || artist != cur.artist;
    TrackEdit? edit;
    int? logId;
    if (changed) {
      edit = await _save(cur, id.title, artist, markEdited: byUser, isrc: id.isrc, mbid: id.mbid);
      logId = await ActivityLogRepository(_db).add(
        at: nowMs(),
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

  bool changedBy(Track t, TrackIdentity id) => id.title != t.title || id.artistOver(t.artist) != t.artist;

  /// The proposal of [trackId] is refused and does not come back.
  Future<void> discard(int trackId) => _credits.setRecDecision(trackId, 'discarded');

  /// Puts back what the Registro [row] (kind `correction`) says was there; the
  /// proposal is then discarded, or with [reopen] (the «Annulla» of «Accetta
  /// tutte») put back among the open ones. Returns false for a row it cannot
  /// read, or when the track no longer holds the corrected title and artist (edited since).
  Future<bool> revert(ActivityLogRow row, {bool reopen = false}) async {
    try {
      final c = _readCorrection(row);
      final back = c == null ? null : await _db.transaction(() => _revertDb(c, reopen: reopen));
      if (back == null) return false;
      await _writeFile(back.track, back.edit); // the DB is back; a file left as it was is told in the Registro
      return true;
    } on Object catch (e, st) {
      AppLog.w('correction ${row.id} not reverted', e, st);
      return false;
    }
  }

  /// The «Annulla» of [acceptAll]: every correction back and its proposal open again
  /// in ONE transaction (one change of the list, D-372); the files follow in
  /// [RevertedAll.files], after the new tags have gone into them.
  Future<RevertedAll> revertAll(AcceptedAll done) async {
    var back = <({int logId, _Back back})>[];
    try {
      back = await _db.transaction(() async => [
        for (final row in done.log.reversed)
          if (_readCorrection(row) case final c?)
            if (await _revertDb(c, reopen: true) case final b?) (logId: row.id, back: b),
      ]);
    } on Object catch (e, st) {
      AppLog.w('accept all not reverted', e, st);
    }
    // A file that accepting did not write (option off, playing) is not written now either.
    final files = [for (final b in back) if (done.filed.contains(b.logId)) b.back];
    return RevertedAll(back.length, done.files.then((_) => _writeFiles(files)));
  }

  _Correction? _readCorrection(ActivityLogRow row) {
    try {
      final j = jsonDecode(row.detail ?? '') as Map;
      return (id: j['trackId'] as int, old: j['old'] as Map, now: j['new'] as Map);
    } on Object catch (e, st) {
      AppLog.w('correction ${row.id} not readable', e, st);
      return null;
    }
  }

  /// The DB part of a revert, to run inside a transaction; null when the track was edited since.
  Future<_Back?> _revertDb(_Correction c, {required bool reopen}) async {
    final cur = await TrackRepository(_db).getById(c.id);
    if (cur == null || cur.title != c.now['title'] || cur.artist != c.now['artist']) return null;
    // Missing keys (older rows) leave the file's ids alone.
    final edit = await _save(cur, c.old['title'] as String, c.old['artist'] as String?,
        markEdited: false, isrc: c.old['isrc'] as String?, mbid: c.old['mbid'] as String?);
    // Accepting marked the track as edited, which hides its proposal.
    if (reopen) await TrackRepository(_db).setUserEdited(c.id, false);
    await _credits.setRecDecision(c.id, reopen ? 'open' : 'discarded');
    return (track: cur, edit: edit);
  }

  /// Accepts every open proposal in ONE transaction (one change of the list, D-361);
  /// the tags go into the files afterwards, one by one, in [AcceptedAll.files].
  /// The Registro rows are read back [logChunk] ids at a time (SQLite caps the variables of a query).
  Future<AcceptedAll> acceptAll({int logChunk = 500}) async {
    final jobs = <_Job>[];
    for (final p in await _credits.watchProposals().first) {
      final job = await _prepare(p.track, p.rec, byUser: true);
      if (job != null) jobs.add(job);
    }
    final done = await _db.transaction(() async => [
      for (final j in jobs)
        if (await _applyDb(j, byUser: true) case final d?) (job: j, done: d),
    ]);
    final log = await ActivityLogRepository(_db).byIds([for (final d in done) d.done.logId], chunk: logChunk);
    final toFile = [for (final d in done) if (d.job.toFile) d.done];
    return AcceptedAll(log, _writeFiles([for (final d in toFile) (track: d.track, edit: d.edit)]),
        filed: {for (final d in toFile) d.logId});
  }

  /// The file part of [acceptAll].
  Future<void> _writeFiles(List<_Back> jobs) async {
    for (final j in jobs) {
      await _writeFile(j.track, j.edit);
    }
  }

  /// Writes [edit] into the file of [t]. Never throws: a file that stays untouched goes
  /// in the Registro as a failed `correction` row (no `old`/`new`) when [report], the DB stands.
  Future<void> _writeFile(Track t, TrackEdit edit, {bool backup = true, bool report = true}) async {
    try {
      final why = (await _toFile(t, edit, backup: backup)).mainReason;
      if (why != null) {
        AppLog.w('tags of ${t.path} not written: ${why.name}');
        if (report) await _fileFailed(t, edit, why.name);
      }
    } on Object catch (e, st) {
      AppLog.w('tags of ${t.path} not written', e, st);
      try {
        if (report) await _fileFailed(t, edit, TagWriteReason.ioError.name);
      } on Object catch (e2, st2) {
        AppLog.w('file error of ${t.path} not logged', e2, st2);
      }
    }
  }

  Future<void> _fileFailed(Track t, TrackEdit edit, String why) => ActivityLogRepository(_db).add(
    at: nowMs(),
    kind: 'correction',
    name: edit.title,
    failed: true,
    detail: jsonEncode({'trackId': t.id, 'file': why}),
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
    if (!_editor.writesFiles) return TagFileOutcome.none; // option off: nothing to block or to tell
    final why = await _fileBlock(t.path);
    if (why != null) return TagFileOutcome(attempted: 1, failures: {t.id: why});
    return _editor.writeToFiles([t], (_) => edit.toChanges(), backup: backup);
  }
}

typedef _Back = ({Track track, TrackEdit edit});
typedef _Correction = ({int id, Map old, Map now});
typedef _Job = ({int trackId, Recognition rec, bool toFile, ({String? isrc, String? mbid})? ids});

/// What [TrackCorrections.acceptAll] did: the Registro rows of the corrections
/// (to put them back with `revert`) and the file writes, which may still run.
class AcceptedAll {
  const AcceptedAll(this.log, this.files, {this.filed = const {}});

  final List<ActivityLogRow> log;

  /// The ids of the [log] rows whose file was to be written.
  final Set<int> filed;

  /// Completes when every file has been tried; never throws.
  final Future<void> files;

  int get count => log.length;
}

/// What [TrackCorrections.revertAll] did: how many corrections went back and the file writes, which may still run.
class RevertedAll {
  const RevertedAll(this.count, this.files);

  final int count;

  /// Completes when every file has been tried; never throws.
  final Future<void> files;
}

import '../../data/repositories/track_kinds.dart';
import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../tags/safe_tag_writer.dart';
import '../tags/tag_backups.dart';
import '../tags/tag_writer.dart';

/// How writing the tags of some tracks into their files went.
class TagFileOutcome {
  const TagFileOutcome({this.attempted = 0, this.failures = const {}});

  /// Nothing was tried (option off, or the user declined).
  static const none = TagFileOutcome();

  final int attempted;

  /// Track id -> why its file was left untouched.
  final Map<int, TagWriteReason> failures;

  bool get hasFailures => failures.isNotEmpty;

  /// The most frequent reason, to show one.
  TagWriteReason? get mainReason {
    if (failures.isEmpty) return null;
    final counts = <TagWriteReason, int>{};
    for (final r in failures.values) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
}

/// Writes tags into the files of library tracks through [SafeTagWriter] and
/// keeps `sizeBytes`/`mtimeMs` in step, so a rescan does not see the file as
/// changed. A failure never throws: the library edit stands.
class TrackFileSync {
  TrackFileSync(this._db, this._writer);

  final AppDatabase _db;
  final Future<SafeTagWriter> Function() _writer;

  /// False only when the writer is known not to handle [path]'s format.
  Future<bool> canWrite(String path) async {
    try {
      return (await _writer()).writer.supports(SafeTagWriter.formatOf(path));
    } on Object catch (e, st) {
      AppLog.e('tag writer unavailable', e, st);
      return false;
    }
  }

  Future<TagFileOutcome> write(
    List<Track> tracks,
    TagChanges Function(Track) changes, {
    bool backup = true,
  }) async {
    // A saved stream row has no file: its tags live in the database only.
    tracks = [for (final t in tracks) if (t.kind != kStreamKind) t];
    if (tracks.isEmpty) return TagFileOutcome.none;
    final failures = <int, TagWriteReason>{};
    final SafeTagWriter writer;
    try {
      writer = await _writer();
    } on Object catch (e, st) {
      AppLog.e('tag writer unavailable', e, st);
      return TagFileOutcome(
        attempted: tracks.length,
        failures: {for (final t in tracks) t.id: TagWriteReason.unsupported},
      );
    }
    for (final t in tracks) {
      final c = changes(t);
      if (c.isEmpty) continue;
      try {
        final stamp = await writer.write(t.path, c, backup: backup);
        await stampTrack(_db, t.path, stamp);
      } on TagWriteException catch (e) {
        failures[t.id] = e.reason;
      } on Object catch (e, st) {
        AppLog.e('tag write failed: ${t.path}', e, st);
        failures[t.id] = TagWriteReason.ioError;
      }
    }
    return TagFileOutcome(attempted: tracks.length, failures: failures);
  }
}

/// Records the new size and date of a file we replaced.
Future<void> stampTrack(AppDatabase db, String path, FileStamp s) =>
    (db.update(db.tracks)..where((t) => t.path.equals(path))).write(
      TracksCompanion(
        sizeBytes: Value(s.sizeBytes),
        mtimeMs: Value(s.mtimeMs),
        sha256: const Value(null), // the bytes changed
      ),
    );

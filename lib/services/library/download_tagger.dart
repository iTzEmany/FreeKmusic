import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../tags/tag_reader.dart';
import '../tags/tag_writer.dart';
import 'pending_tags.dart';
import 'track_file_sync.dart';

/// Writes a library track's tags (and cover) into the file Codecore itself
/// downloaded or received. Only files inside the download folder, one at a
/// time, never the file that is playing (it waits for the next song). The ISRC
/// is never written: [TagChanges] has no field for it. Never throws.
class DownloadTagger {
  DownloadTagger({
    required this.trackById,
    required this.trackByPath,
    required this.sync,
    required this.reader,
    required this.downloadRoot,
    required this.enabled,
    required this.coverOf,
    required this.playingPath,
    required this.playingChanges,
    this.onFailed,
    this.pending,
  });

  final Future<Track?> Function(int id) trackById;
  final Future<Track?> Function(String path) trackByPath;
  final TrackFileSync sync;
  final TagReader reader;
  final Future<String?> Function() downloadRoot;
  final bool Function() enabled;
  final Future<TagCover?> Function(Track) coverOf;
  final String? Function() playingPath;
  final Stream<String?> playingChanges;

  /// Told when the file was left without its tags (the Registro shows it).
  final Future<void> Function(Track, TagWriteReason)? onFailed;

  /// Files still to tag, persisted across app restarts.
  final PendingTags? pending;

  Future<void> _queue = Future.value();
  // Paths waiting (queued or deferred): one write per file however often asked.
  final _waiting = <String>{};
  final _deferred = <String, int>{};
  StreamSubscription<String?>? _sub;
  bool _disposed = false;
  bool _resumed = false;

  /// Remembers that track [id] still has to be tagged (until [tag] ends).
  Future<void> markPending(int id) async {
    try {
      final t = await trackById(id);
      if (t != null && enabled()) await pending?.add(t.path);
    } on Object catch (e, st) {
      AppLog.w('tagger: cannot mark $id pending', e, st);
    }
  }

  /// App start: tags the files a previous run left pending. Once per process
  /// (the widget that asks can be built again); files already waiting are live work.
  Future<void> resumePending() async {
    if (_resumed) return;
    _resumed = true;
    try {
      for (final path in await pending?.paths() ?? const <String>[]) {
        if (_waiting.contains(path)) continue;
        final t = await File(path).exists() ? await trackByPath(path) : null;
        if (t == null || !enabled()) {
          await pending!.remove(path);
        } else {
          unawaited(tag(t.id));
        }
      }
    } on Object catch (e, st) {
      AppLog.w('tagger: resume failed', e, st);
    }
  }

  /// Queues the write for track [id]; completes when it was written, refused
  /// or put off until the song changes.
  Future<void> tag(int id) async {
    if (_disposed || !enabled()) return;
    final Track? t;
    try {
      t = await trackById(id);
    } on Object catch (e, st) {
      AppLog.w('tagger: cannot load track $id', e, st);
      return;
    }
    if (t == null || !_waiting.add(t.path)) return;
    final run = _queue.then((_) => _run(t!));
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    await run;
  }

  Future<void> _run(Track t) async {
    try {
      if (!enabled() || !await _insideDownloads(t.path)) return;
      if (playingPath() == t.path) {
        _deferred[t.path] = t.id;
        _sub ??= playingChanges.listen(_playingChanged);
        return;
      }
      await _write(t);
    } on Object catch (e, st) {
      AppLog.w('tagger: ${t.path} not written', e, st);
    } finally {
      if (!_deferred.containsKey(t.path)) {
        _waiting.remove(t.path);
        await pending?.remove(t.path);
      }
    }
  }

  // On desktop the download folder is the first library folder, so callers
  // must pass downloaded/received tracks only.
  Future<bool> _insideDownloads(String path) async {
    final root = await downloadRoot();
    return root != null && p.isWithin(p.normalize(root), p.normalize(path));
  }

  void _playingChanged(String? now) {
    for (final path in _deferred.keys.toList()) {
      if (path == now) continue;
      final id = _deferred.remove(path)!;
      _waiting.remove(path);
      unawaited(tag(id));
    }
    if (_deferred.isEmpty) {
      unawaited(_sub?.cancel());
      _sub = null;
    }
  }

  Future<void> _write(Track fresh) async {
    final t = await trackById(fresh.id) ?? fresh;
    if (!await sync.canWrite(t.path)) return;
    final info = await reader.read(t.path);
    // lofty appends a picture: add one only to a file that has none.
    final hasCover = info.coverBytes?.isNotEmpty ?? false;
    // Never a hand-picked picture in the file (invariant 7).
    final cover = hasCover || t.coverSource > 0 ? null : await coverOf(t);
    String? text(String? s) => (s == null || s.trim().isEmpty) ? null : s;
    final c = TagChanges(
      title: text(t.title),
      artist: text(t.artist),
      album: text(t.album),
      albumArtist: text(t.albumArtist),
      year: t.year,
      genre: text(t.genre),
      trackNumber: t.trackNumber,
      discNumber: t.discNumber,
      cover: cover,
    );
    // Already as wanted: do not rewrite the file.
    if (c.cover == null &&
        (c.title == null || c.title == info.title) &&
        (c.artist == null || c.artist == info.artist) &&
        (c.album == null || c.album == info.album) &&
        (c.albumArtist == null || c.albumArtist == info.albumArtist) &&
        (c.year == null || c.year == info.year) &&
        (c.genre == null || c.genre == info.genre) &&
        (c.trackNumber == null || c.trackNumber == info.trackNumber) &&
        (c.discNumber == null || c.discNumber == info.discNumber)) {
      return;
    }
    final out = await sync.write([t], (_) => c, backup: false);
    if (out.hasFailures) {
      final why = out.mainReason ?? TagWriteReason.ioError;
      AppLog.w('tagger: ${t.path} left as it is (${why.name})');
      await onFailed?.call(t, why);
    }
  }

  void dispose() {
    _disposed = true;
    unawaited(_sub?.cancel());
  }
}

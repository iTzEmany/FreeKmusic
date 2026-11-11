import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/uuid.dart';
import 'tag_backups.dart';
import 'tag_reader.dart';
import 'tag_writer.dart';

/// The only way tags reach a file: write on a copy, read the copy back,
/// compare, save the original in [backups], then swap the copy in with a
/// rename. Any failure leaves the original untouched.
class SafeTagWriter {
  SafeTagWriter({
    required this.writer,
    required this.reader,
    required this.workDir,
    required this.backups,
    this.rename,
    this.install,
  });

  final TagWriter writer;
  final TagReader reader;
  final Directory workDir;
  final TagBackupStore backups;

  /// Replaceable in tests to force the cross-partition path.
  final Future<void> Function(String from, String to)? rename;

  /// Replaces [installFile] where a rename cannot (Android MediaStore files).
  final Future<void> Function(String from, String to)? install;

  Future<void> _queue = Future.value();

  static String formatOf(String path) =>
      p.extension(path).replaceFirst('.', '').toLowerCase();

  /// null when [path] can be written, otherwise why not. Opens the file for
  /// appending (changes nothing) to detect read-only media.
  Future<TagWriteReason?> check(String path) async {
    if (!writer.supports(formatOf(path))) return TagWriteReason.unsupported;
    final f = File(path);
    if (!await f.exists()) return TagWriteReason.notFound;
    try {
      final h = await f.open(mode: FileMode.append);
      await h.close();
    } on FileSystemException {
      return TagWriteReason.readOnly;
    }
    return null;
  }

  /// Writes [changes] into [path]; resolves to the file's new size and date.
  /// One write at a time, so two edits never race on the same file.
  /// [backup] false for files Codecore just created: nothing of the user's
  /// to keep, and it must not evict their manual-edit backups.
  Future<FileStamp> write(String path, TagChanges changes, {bool backup = true}) {
    final run = _queue.then((_) => _write(path, changes, backup));
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<FileStamp> _write(String path, TagChanges changes, bool backup) async {
    final why = await check(path);
    if (why != null) throw TagWriteException(why);
    final tmp = File(p.join(
      workDir.path,
      '${newUuid()}.${formatOf(path)}',
    ));
    try {
      await workDir.create(recursive: true);
      final before = await reader.read(path);
      await File(path).copy(tmp.path);
      await writer.write(tmp.path, changes);
      final after = await reader.read(tmp.path);
      final problem = tagMismatch(before, after, changes, format: formatOf(path));
      if (problem != null) {
        throw TagWriteException(TagWriteReason.verifyFailed, problem);
      }
      if (backup) await backups.add(path);
      await (install ?? (a, b) => installFile(a, b, rename: rename))(tmp.path, path);
      return await stampOf(path);
    } on TagWriteException catch (e) {
      AppLog.w('tag write refused for $path: ${e.reason.name} ${e.detail ?? ''}');
      rethrow;
    } on FileSystemException catch (e, st) {
      AppLog.e('tag write I/O error: $path', e, st);
      throw TagWriteException(TagWriteReason.ioError, e.message);
    } finally {
      try {
        if (await tmp.exists()) await tmp.delete();
      } on FileSystemException catch (e, st) {
        AppLog.w('cannot remove work copy ${tmp.path}', e, st);
      }
    }
  }
}

/// What differs between the tags read from the copy and what we wrote (and
/// what must not have changed), or null when all is as expected.
///
/// The reader is not a perfect mirror of the file, so it is forgiving where
/// it is known to be: for MP3 it reports TPE2 (album artist) as the artist,
/// so a written artist or album artist may come back as either; and FLAC
/// years (`YEAR` comment) are not read at all. The files themselves were
/// checked with ffprobe (see the real-file test).
String? tagMismatch(
  TagInfo before,
  TagInfo after,
  TagChanges c, {
  String format = '',
}) {
  String? bad(String name, Object? want, Object? got) =>
      want == got ? null : '$name: "$got" instead of "$want"';
  final artists = {after.artist, after.albumArtist};
  // A multi-artist string may be read back whole while the album artist
  // written is its first name: accept any single name inside it too.
  final names = <String?>{
    for (final a in artists.nonNulls) ...[a, ...a.split(RegExp(r'\s*[,;&]\s*'))],
  };
  // Only the album artist (the first artist) may be a part of the string read back.
  String? inArtists(String name, String? want, Set<String?> pool) =>
      want == null || pool.contains(want.trim())
      ? null
      : '$name: "$want" not found in ${artists.nonNulls.toList()}';
  final yearUnreadable = format == 'flac' && after.year == null;
  final checks = <String?>[
    if (c.title != null) bad('title', c.title!.trim(), after.title),
    inArtists('artist', c.artist, artists),
    inArtists('albumArtist', c.albumArtist, names),
    if (c.album != null) bad('album', c.album!.trim(), after.album),
    if (c.year != null && !yearUnreadable) bad('year', c.year, after.year),
    if (c.trackNumber != null) bad('track', c.trackNumber, after.trackNumber),
    if (c.genre != null &&
        (after.genre == null || !c.genre!.contains(after.genre!)))
      'genre: "${after.genre}" instead of "${c.genre}"',
    // The audio and the cover must come out as they went in.
    if (c.discNumber != null) bad('disc', c.discNumber, after.discNumber),
    if (c.cover != null)
      (after.coverBytes?.isNotEmpty ?? false) ? null : 'cover: missing after write'
    else
      bad('cover', before.coverBytes?.length, after.coverBytes?.length),
    if (before.durationMs != null &&
        after.durationMs != null &&
        (before.durationMs! - after.durationMs!).abs() > 100)
      'duration changed',
    if (c.title == null) bad('title', before.title, after.title),
    if (c.album == null) bad('album', before.album, after.album),
    if (c.artist == null && c.albumArtist == null)
      bad('artist', before.artist, after.artist),
  ];
  return checks.nonNulls.firstOrNull;
}

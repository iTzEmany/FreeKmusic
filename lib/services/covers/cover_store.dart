import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import 'cover_thumbnails.dart';

/// The files of one cover: the original and its small copy for lists and
/// grids (absent while not made yet, or when the original is small already).
typedef CoverFiles = ({String? original, String? thumb});

class CoverStore {
  CoverStore(this.dir, {this.thumbnails});

  final Directory dir;

  /// Makes the thumbnail when a cover is saved; null (tests) = no thumbnails.
  final ThumbnailEncoder? thumbnails;

  static final _changes = StreamController<({String key, CoverFiles files})>.broadcast();

  /// Every cover written or replaced, by any store: the UI's index of the
  /// covers folder follows it instead of looking at the disk.
  static Stream<({String key, CoverFiles files})> get changes => _changes.stream;

  /// Originals smaller than this decode fast enough: no thumbnail.
  static const thumbMinBytes = 64 * 1024;

  static String thumbName(String coverKey) => '${coverKey}_t.png';

  /// File names [thumbName] makes (for measuring the thumbnails on their own).
  static const thumbNamePattern = r'_t\.png$';

  Future<void> _thumbs = Future.value();

  /// Completes when the thumbnails asked for so far are made.
  Future<void> get thumbnailsDone => _thumbs;

  static const maxBytes = 4 * 1024 * 1024;
  static const _folderNames = {'cover', 'folder', 'front', 'album'};
  static const _folderExts = {'.jpg', '.jpeg', '.png'};

  static String coverKeyFor(String albumKey) =>
      sha1.convert(utf8.encode(albumKey)).toString();

  /// Writes the image once per album and returns its `coverKey`.
  Future<String?> saveFromBytes(String albumKey, List<int> bytes, String? mime,
      {bool overwrite = false}) async {
    if (bytes.isEmpty) return null;
    if (bytes.length > maxBytes) {
      AppLog.w('cover too large (${bytes.length} B) for $albumKey, skipped');
      return null;
    }
    final key = coverKeyFor(albumKey);
    final existing = fileFor(key);
    if (existing != null) {
      if (!overwrite) return key;
      await existing.delete();
      final oldThumb = File(p.join(dir.path, thumbName(key)));
      if (await oldThumb.exists()) await oldThumb.delete();
    }
    final ext = (mime ?? '').toLowerCase().contains('png') ? 'png' : 'jpg';
    try {
      await dir.create(recursive: true);
      final tmp = File(p.join(dir.path, '$key.$ext.tmp'));
      await tmp.writeAsBytes(bytes, flush: true);
      final original = p.join(dir.path, '$key.$ext');
      await tmp.rename(original);
      _changes.add((key: key, files: (original: original, thumb: null)));
      // Made after the save returns, one at a time: a scan of hundreds of
      // albums does not wait for them. Only the key waits in line; the
      // picture is read again when its turn comes.
      if (thumbnails != null && bytes.length >= thumbMinBytes) {
        _thumbs = _thumbs.then((_) => ensureThumb(key));
      }
      return key;
    } on Object catch (e, st) {
      AppLog.e('cover save failed for $albumKey', e, st);
      return null;
    }
  }

  Future<String?> _writeThumb(String key, Uint8List cover) async {
    final make = thumbnails;
    if (make == null) return null;
    final png = await make(cover);
    if (png == null) return null;
    final path = p.join(dir.path, thumbName(key));
    final tmp = File('$path.tmp');
    await tmp.writeAsBytes(png, flush: true);
    await tmp.rename(path);
    return path;
  }

  /// Makes the missing thumbnail of [key]; true when one was written. Safe to
  /// repeat and to stop halfway: it only does what is missing.
  Future<bool> ensureThumb(String key) async {
    if (thumbnails == null) return false;
    if (await File(p.join(dir.path, thumbName(key))).exists()) return false;
    final original = fileFor(key);
    if (original == null || await original.length() < thumbMinBytes) return false;
    try {
      final thumb = await _writeThumb(key, await original.readAsBytes());
      if (thumb == null) return false;
      _changes.add((key: key, files: (original: original.path, thumb: thumb)));
      return true;
    } on Object catch (e, st) {
      AppLog.w('thumbnail of $key not written', e, st);
      return false;
    }
  }

  /// The thumbnails of the covers saved before there were any, one at a time
  /// with a pause in between; returns how many were made. Run again after an
  /// interruption, it carries on where it stopped.
  Future<int> fillMissingThumbnails({Duration pause = const Duration(milliseconds: 30)}) async {
    if (thumbnails == null || !await dir.exists()) return 0;
    final keys = <String>{};
    await for (final e in dir.list(followLinks: false)) {
      final name = p.basename(e.path);
      final stem = p.basenameWithoutExtension(name);
      if (e is File && !stem.endsWith('_t') && (name.endsWith('.jpg') || name.endsWith('.png'))) {
        keys.add(stem);
      }
    }
    var made = 0;
    for (final key in keys) {
      if (await ensureThumb(key)) {
        made++;
        await Future<void>.delayed(pause);
      }
    }
    if (made > 0) AppLog.i('cover thumbnails made: $made');
    return made;
  }

  /// The covers in the folder, read once (one listing, not one check per
  /// album); [changes] keeps it up to date afterwards.
  Map<String, CoverFiles> listAll() {
    final originals = <String, String>{}, thumbs = <String, String>{};
    try {
      if (!dir.existsSync()) return const {};
      for (final e in dir.listSync(followLinks: false)) {
        if (e is! File) continue;
        final name = p.basename(e.path);
        if (name.endsWith('.tmp')) continue;
        final stem = p.basenameWithoutExtension(name);
        if (stem.endsWith('_t') && name.endsWith('.png')) {
          thumbs[stem.substring(0, stem.length - 2)] = e.path;
        } else if (name.endsWith('.jpg') || name.endsWith('.png')) {
          originals.putIfAbsent(stem, () => e.path);
        }
      }
    } on FileSystemException catch (e, st) {
      AppLog.w('covers folder unreadable: ${dir.path}', e, st);
    }
    return {
      for (final k in originals.keys) k: (original: originals[k], thumb: thumbs[k]),
    };
  }

  Future<String?> findFolderCover(String directory) async {
    try {
      await for (final e in Directory(directory).list(followLinks: false)) {
        if (e is! File) continue;
        final ext = p.extension(e.path).toLowerCase();
        final name = p.basenameWithoutExtension(e.path).toLowerCase();
        if (_folderExts.contains(ext) && _folderNames.contains(name)) {
          return e.path;
        }
      }
    } on Object catch (e, st) {
      AppLog.w('folder cover search failed: $directory', e, st);
    }
    return null;
  }

  File? fileFor(String coverKey) {
    for (final ext in const ['jpg', 'png']) {
      final f = File(p.join(dir.path, '$coverKey.$ext'));
      if (f.existsSync()) return f;
    }
    return null;
  }
}

extension TrackOwnCover on Track {
  /// A cover of its own: not the one every «unknown|dir» file once shared.
  bool get hasOwnCover =>
      hasCover &&
      !(albumKey.startsWith('unknown|') && coverKey == CoverStore.coverKeyFor(albumKey));
}

import 'dart:convert' show utf8;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/text_utils.dart' show sanitizeFileName;
import '../services/jam/jam_models.dart';
import '../services/jam/jam_online_adder.dart' show jamYtResult;
import 'database_providers.dart';
import 'jam_providers.dart';
import 'library_add_providers.dart';
import 'library_providers.dart';
import 'settings_providers.dart';
import 'youtube_providers.dart' show downloadIndexProvider, resolveDownloadFolder;

/// Longest file name (stem + suffix + extension) we write, in UTF-8 bytes: 255 is the usual limit of a name,
/// and `.part` plus a ` (n)` must still fit. Long CJK or emoji titles would otherwise give ENAMETOOLONG.
const _maxNameBytes = 200;

/// `Title.ext`, or `Title (n).ext` for [n] > 1, never over [_maxNameBytes] bytes and never cutting a character.
String jamFileName(String title, String ext, [int n = 1]) {
  final e = '.${sanitizeFileName(ext)}';
  final suffix = n > 1 ? ' ($n)' : '';
  final room = _maxNameBytes - utf8.encode(suffix).length - utf8.encode(e).length;
  final stem = StringBuffer();
  var used = 0;
  for (final r in sanitizeFileName(title).runes) {
    final c = String.fromCharCode(r);
    used += utf8.encode(c).length;
    if (used > room) break;
    stem.write(c);
  }
  return '$stem$suffix$e';
}

/// «Aggiungi alla libreria» for a Jam item of the host (D-690). Reads the Jam; it sends nothing.
class JamSaver {
  JamSaver(this._ref);
  final Ref _ref;

  /// The `item.id`s saved (or being saved) in this Jam: the saver is rebuilt when the Jam ends.
  final _saved = <int>{};

  File? _cached(JamItem i) => _ref.read(jamProvider.notifier).cache?.cached(i);

  /// Only the host's songs (D-690, a guest's file is not ours to copy), not twice, not already in the library;
  /// an online one can always be saved, a local one only while its file is in the cache.
  bool canSave(JamItem i, String ownId) {
    if (i.ownerDeviceId == ownId || i.ownerDeviceId != _ref.read(jamProvider).jam?.hostDeviceId) return false;
    if (_saved.contains(i.id)) return false;
    if (i.selfFetchable) {
      final r = jamYtResult(i);
      return !_ref.read(inLibraryOfProvider)(r.id, r.source);
    }
    return _cached(i) != null;
  }

  /// True when the song is in the library now.
  Future<bool> save(JamItem i) async {
    if (!_saved.add(i.id)) return false;
    var ok = false;
    try {
      return ok = await _save(i);
    } finally {
      if (!ok) _saved.remove(i.id);
    }
  }

  Future<bool> _save(JamItem i) async {
    if (i.selfFetchable) {
      final r = jamYtResult(i);
      // A saved row or a file already there counts as done (`saveStreamNow` is null then).
      return await _ref.read(libraryAdderProvider).saveStreamNow(r) != null ||
          (_ref.read(savedStreamKeysProvider).value?.contains(r.indexKey) ?? false) ||
          (await _ref.read(downloadIndexProvider.future)).contains(r.id, source: r.source);
    }
    final src = _cached(i);
    if (src == null) return false;
    File? part;
    try {
      final base = await resolveDownloadFolder(
        _ref.read(folderRepositoryProvider),
        location: _ref.read(settingsProvider).downloadLocation,
      );
      if (base == null) return false;
      var out = File(p.join(base.$1.path, jamFileName(i.title, i.ext)));
      for (var n = 2; out.existsSync(); n++) {
        out = File(p.join(base.$1.path, jamFileName(i.title, i.ext, n)));
      }
      await base.$1.create(recursive: true);
      // Copy beside the final name and rename, so the scanner never sees half a file.
      part = File('${out.path}.part');
      await src.copy(part.path);
      await part.rename(out.path);
      await _ref.read(libraryScannerProvider).scanFiles(base.$2, [out.path]).drain<void>();
      return true;
    } on FileSystemException catch (e, st) {
      AppLog.w('jam save: copy of ${i.title} failed', e, st);
      try {
        if (part != null && part.existsSync()) part.deleteSync();
      } on FileSystemException catch (e2, st2) {
        AppLog.w('jam save: could not remove the .part of ${i.title}', e2, st2);
      }
      return false;
    }
  }
}

final jamSaverProvider = Provider<JamSaver>((ref) {
  ref.watch(jamProvider.select((s) => s.jam?.hostDeviceId)); // a new Jam starts with nothing saved
  return JamSaver(ref);
});

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

/// «Aggiungi alla libreria» for a Jam item that is not ours (D-690). Reads the Jam; it sends nothing.
class JamSaver {
  JamSaver(this._ref);
  final Ref _ref;

  File? _cached(JamItem i) => _ref.read(jamProvider.notifier).cache?.cached(i);

  /// An online track can always be saved; a local one of the host only while its file is in the cache.
  bool canSave(JamItem i, String ownId) =>
      i.ownerDeviceId != ownId && (i.selfFetchable || _cached(i) != null);

  /// True when the song is in the library now.
  Future<bool> save(JamItem i) async {
    if (i.selfFetchable) {
      final r = jamYtResult(i);
      // A saved row or a file already there counts as done (`saveStreamNow` is null then).
      return await _ref.read(libraryAdderProvider).saveStreamNow(r) != null ||
          (_ref.read(savedStreamKeysProvider).value?.contains(r.indexKey) ?? false) ||
          (await _ref.read(downloadIndexProvider.future)).contains(r.id, source: r.source);
    }
    final src = _cached(i);
    if (src == null) return false;
    try {
      final base = await resolveDownloadFolder(
        _ref.read(folderRepositoryProvider),
        location: _ref.read(settingsProvider).downloadLocation,
      );
      if (base == null) return false;
      var out = File(p.join(base.$1.path, '${sanitizeFileName(i.title)}.${i.ext}'));
      for (var n = 2; out.existsSync(); n++) {
        out = File(p.join(base.$1.path, '${sanitizeFileName(i.title)} ($n).${i.ext}'));
      }
      await base.$1.create(recursive: true);
      await src.copy(out.path);
      await _ref.read(libraryScannerProvider).scanFiles(base.$2, [out.path]).drain<void>();
      return true;
    } on FileSystemException catch (e, st) {
      AppLog.w('jam save: copy of ${i.title} failed', e, st);
      return false;
    }
  }
}

final jamSaverProvider = Provider<JamSaver>(JamSaver.new);

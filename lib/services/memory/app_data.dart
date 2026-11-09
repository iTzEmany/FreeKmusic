import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../covers/cover_store.dart';
import '../theme/background_image.dart';
import 'dir_size.dart';

/// What the app keeps besides the music, as listed in «Dati dell'app».
enum AppDataKind {
  covers,
  database,
  imageMemory,
  jamCache,
  searchCache,
  catalogCache,
  suggestions,
  blurCopies,
  tagBackups,
  log,
  podcasts,
  radio,
}

/// Kinds that are made again by themselves when needed: the only ones
/// «Svuota cache» may touch. Covers, the database and the tag backups are
/// the user's data and are never in this set.
const clearableKinds = {
  AppDataKind.imageMemory,
  AppDataKind.jamCache,
  AppDataKind.searchCache,
  AppDataKind.catalogCache,
  AppDataKind.suggestions,
  AppDataKind.blurCopies,
  AppDataKind.radio,
};

class AppDataItem {
  const AppDataItem(this.kind, this.bytes, {this.detailBytes});

  final AppDataKind kind;
  final int bytes;

  /// Covers: the part taken by the thumbnails.
  final int? detailBytes;
}

/// Where each kind of app data lives. Resolved once by the provider.
class AppDataPaths {
  const AppDataPaths({
    required this.covers,
    required this.database,
    required this.jam,
    required this.theme,
    required this.tagBackups,
    required this.searchCache,
    required this.catalogCache,
    required this.log,
    this.suggestionFiles = const [],
    this.radio,
  });

  final Directory covers, jam, theme, tagBackups;

  /// `<appSupport>/radio`: the lists of stations (never the saved ones).
  final Directory? radio;
  final File database, searchCache, catalogCache, log;

  /// `suggestions.json` and `seed_ids.json` (Shuffle+), `daylist.json`.
  final List<File> suggestionFiles;

  /// SQLite keeps its journal beside the database file.
  List<String> get databaseFiles => [
    database.path,
    '${database.path}-wal',
    '${database.path}-shm',
  ];

  /// The log and its one rotated copy.
  List<String> get logFiles => [log.path, '${log.path}.1'];
}

Future<int> _filesSize(List<String> paths) async {
  var total = 0;
  for (final f in paths) {
    total += await fileSize(f);
  }
  return total;
}

/// Measures every kind (folders in background isolates). [imageMemoryBytes]
/// is the Flutter image cache: it lives in RAM, not on disk.
Future<List<AppDataItem>> measureAppData(
  AppDataPaths paths, {
  required int podcastBytes,
  int? imageMemoryBytes,
}) async {
  final thumbs = directorySize(
    paths.covers.path,
    namePattern: CoverStore.thumbNamePattern,
  );
  final covers = directorySize(paths.covers.path);
  final tags = directorySize(paths.tagBackups.path);
  final jam = directorySize(paths.jam.path);
  final blur = directorySize(paths.theme.path, namePattern: blurredCopyPattern);
  return [
    AppDataItem(AppDataKind.covers, await covers, detailBytes: await thumbs),
    AppDataItem(AppDataKind.database, await _filesSize(paths.databaseFiles)),
    AppDataItem(
      AppDataKind.imageMemory,
      imageMemoryBytes ?? PaintingBinding.instance.imageCache.currentSizeBytes,
    ),
    AppDataItem(AppDataKind.jamCache, await jam),
    AppDataItem(
      AppDataKind.searchCache,
      await fileSize(paths.searchCache.path),
    ),
    AppDataItem(
      AppDataKind.catalogCache,
      await fileSize(paths.catalogCache.path),
    ),
    AppDataItem(
      AppDataKind.suggestions,
      await _filesSize([for (final f in paths.suggestionFiles) f.path]),
    ),
    AppDataItem(AppDataKind.blurCopies, await blur),
    AppDataItem(AppDataKind.tagBackups, await tags),
    AppDataItem(AppDataKind.log, await _filesSize(paths.logFiles)),
    AppDataItem(AppDataKind.podcasts, podcastBytes),
    if (paths.radio != null)
      AppDataItem(AppDataKind.radio, await directorySize(paths.radio!.path)),
  ];
}

class CacheClearResult {
  const CacheClearResult({required this.freedBytes, required this.jamSkipped});

  final int freedBytes;

  /// The Jam cache was left alone because a Jam is playing from it.
  final bool jamSkipped;
}

/// «Svuota cache»: empties the [clearableKinds] and nothing else. The
/// search and catalog caches and the image cache are owned by other objects, so their own
/// clear methods are passed in.
class CacheCleaner {
  CacheCleaner({
    required this.jamDir,
    required this.themeDir,
    required this.searchCacheFile,
    required this.clearSearchCache,
    required this.catalogCacheFile,
    required this.clearCatalogCache,
    required this.clearImageMemory,
    required this.imageMemoryBytes,
    required this.jamActive,
    this.pickerTempDir,
    this.suggestionFiles = const [],
    this.clearSuggestions,
    this.radioDir,
    this.clearRadioMemory,
  });

  final Directory jamDir, themeDir;
  final File searchCacheFile, catalogCacheFile;
  final Future<void> Function() clearSearchCache, clearCatalogCache;
  final void Function() clearImageMemory;
  final int Function() imageMemoryBytes;
  final bool Function() jamActive;

  /// Shuffle+ files and the call that empties them (log and seed index).
  final List<File> suggestionFiles;
  final Future<void> Function()? clearSuggestions;

  /// The cached lists of radio stations and the searches kept in memory. The
  /// stations the user saved live in the database and are not touched.
  final Directory? radioDir;
  final void Function()? clearRadioMemory;

  /// Where the file picker copies the files it hands over (backups, CSVs…):
  /// `<cache dir>/file_picker`. Only copies, safe to delete.
  final Directory? pickerTempDir;

  Future<CacheClearResult> clear() async {
    var freed = 0;
    final skipJam = jamActive();
    if (!skipJam) {
      freed += await directorySize(jamDir.path);
      await _deleteTree(jamDir);
    }
    freed += await directorySize(
      themeDir.path,
      namePattern: blurredCopyPattern,
    );
    await deleteBlurredCopies(themeDir);
    final searchBefore = await fileSize(searchCacheFile.path);
    await clearSearchCache();
    freed += math.max(0, searchBefore - await fileSize(searchCacheFile.path));
    final catalogBefore = await fileSize(catalogCacheFile.path);
    await clearCatalogCache();
    freed += math.max(0, catalogBefore - await fileSize(catalogCacheFile.path));
    final clearSuggestions = this.clearSuggestions;
    if (clearSuggestions != null) {
      final before = await _filesSize([
        for (final f in suggestionFiles) f.path,
      ]);
      await clearSuggestions();
      final after = await _filesSize([for (final f in suggestionFiles) f.path]);
      freed += math.max(0, before - after);
    }
    final radio = radioDir;
    if (radio != null) {
      freed += await directorySize(radio.path);
      await _deleteTree(radio);
    }
    clearRadioMemory?.call();
    final picker = pickerTempDir;
    if (picker != null) {
      freed += await directorySize(picker.path);
      await _deleteTree(picker);
    }
    freed += imageMemoryBytes();
    clearImageMemory();
    return CacheClearResult(freedBytes: freed, jamSkipped: skipJam);
  }

  Future<void> _deleteTree(Directory dir) async {
    if (!await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
    } on FileSystemException catch (e, st) {
      AppLog.w('cache folder ${p.basename(dir.path)} not emptied', e, st);
    }
  }
}

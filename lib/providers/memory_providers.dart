import 'dart:io';

import 'package:flutter/painting.dart' show PaintingBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/app_log.dart';
import '../core/paths.dart';
import '../data/db/app_database.dart';
import '../data/repositories/memory_queries.dart';
import '../services/daylist/daylist_store.dart';
import '../services/memory/app_data.dart';
import '../services/memory/disk_space.dart';
import 'database_providers.dart';
import 'daylist_providers.dart' show daylistFileProvider, daylistProvider;
import 'import_providers.dart' show searchCacheProvider;
import 'ytm_catalog_providers.dart' show catalogCacheProvider;
import 'jam_providers.dart';
import 'library_providers.dart';
import 'radio_providers.dart' show radioCatalogProvider;
import 'shuffle_plus_providers.dart' show seedIndexProvider, suggestionLogProvider;

final memoryQueriesProvider = Provider<MemoryQueries>(
  (ref) => MemoryQueries(ref.watch(databaseProvider)),
);

/// The library totals follow the database.
final memoryTotalsProvider = StreamProvider.autoDispose<SizeTotals>(
  (ref) => ref.watch(memoryQueriesProvider).watchTotals(),
);

/// Per playlist, format, folder…; read again on a refresh (the page
/// invalidates it when its tab is opened and on pull-to-refresh).
final memoryBreakdownProvider = FutureProvider.autoDispose<MemoryBreakdown>(
  (ref) => ref.watch(memoryQueriesProvider).breakdown(),
);

/// Size of the lyrics, curiosities and credits kept; read when the page opens.
final enrichmentBytesProvider = FutureProvider.autoDispose<EnrichmentBytes>(
  (ref) => ref.watch(memoryQueriesProvider).enrichmentBytes(),
);

/// Never-played music, for the list page.
final neverPlayedTracksProvider = StreamProvider.autoDispose<List<Track>>(
  (ref) => ref.watch(memoryQueriesProvider).watchNeverPlayed(),
);

final appDataPathsProvider = FutureProvider<AppDataPaths>((ref) async {
  final support = await appSupportDir();
  return AppDataPaths(
    covers: ref.watch(coversDirProvider),
    database: await databaseFile(),
    jam: await ref.watch(jamCacheDirProvider.future),
    theme: await themeDir(),
    tagBackups: Directory(p.join(support, 'tag_backups')),
    searchCache: File(p.join(support, 'search_cache.json')),
    catalogCache: File(p.join(support, 'catalog_cache.json')),
    log: File(p.join(support, 'codecore.log')),
    radio: Directory(p.join(support, 'radio')),
    suggestionFiles: [
      File(p.join(support, 'suggestions.json')),
      File(p.join(support, 'seed_ids.json')),
      File(p.join(support, 'daylist.json')),
    ],
  );
});

final appDataUsageProvider = FutureProvider.autoDispose<List<AppDataItem>>((
  ref,
) async {
  final paths = await ref.watch(appDataPathsProvider.future);
  final breakdown = await ref.watch(memoryBreakdownProvider.future);
  return measureAppData(paths, podcastBytes: breakdown.podcastBytes);
});

/// Free space of the volume that holds the most music (the biggest folder);
/// the app folder when no folder is known. Null = not available here.
final musicDiskSpaceProvider = FutureProvider.autoDispose<DiskSpace?>((
  ref,
) async {
  final breakdown = await ref.watch(memoryBreakdownProvider.future);
  final folder = breakdown.folders.where((f) => f.path != null).firstOrNull;
  return diskSpaceOf(folder?.path ?? await appSupportDir());
});

/// The file picker's copy folder inside the cache dir; null where there is
/// no temp dir to ask.
Future<Directory?> pickerTempDirectory() async {
  try {
    return Directory(
      p.join((await getTemporaryDirectory()).path, 'file_picker'),
    );
  } on Object catch (e, st) {
    AppLog.w('temp dir unavailable', e, st);
    return null;
  }
}

class MemoryActions {
  MemoryActions(this._ref);

  final Ref _ref;

  /// «Svuota cache»; the Jam cache is left alone while a Jam plays from it.
  Future<CacheClearResult> clearCaches() async {
    final paths = await _ref.read(appDataPathsProvider.future);
    final cleaner = CacheCleaner(
      jamDir: paths.jam,
      themeDir: paths.theme,
      searchCacheFile: paths.searchCache,
      clearSearchCache: _ref.read(searchCacheProvider).clear,
      catalogCacheFile: paths.catalogCache,
      clearCatalogCache: _ref.read(catalogCacheProvider).clear,
      clearImageMemory: () => PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages(),
      imageMemoryBytes: () =>
          PaintingBinding.instance.imageCache.currentSizeBytes,
      suggestionFiles: paths.suggestionFiles,
      clearSuggestions: () async {
        await _ref.read(suggestionLogProvider).clear();
        await _ref.read(seedIndexProvider).clear();
        // The daylist is made again (from the library; the radio only if it may be asked).
        await DaylistStore(_ref.read(daylistFileProvider)).clear();
        _ref.invalidate(daylistProvider);
      },
      radioDir: paths.radio,
      clearRadioMemory: () => _ref.read(radioCatalogProvider).value?.clearMemory(),
      pickerTempDir: await pickerTempDirectory(),
      jamActive: () {
        final phase = _ref.read(jamProvider).phase;
        return phase == JamPhase.requesting || phase == JamPhase.active;
      },
    );
    return cleaner.clear();
  }
}

final memoryActionsProvider = Provider<MemoryActions>(MemoryActions.new);

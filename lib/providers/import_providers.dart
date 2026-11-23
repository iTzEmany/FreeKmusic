import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/paths.dart';
import '../data/repositories/import_repository.dart';
import '../core/constants.dart';
import '../data/db/app_database.dart';
import '../data/repositories/track_kinds.dart' show kStreamKind;
import '../services/import/import_chain.dart';
import '../services/import/playlist_import_service.dart';
import '../services/import/track_matcher.dart' show MatchThresholds;
import '../services/library/track_editor.dart';
import '../services/online/cached_youtube_service.dart';
import '../services/online/download_queue.dart';
import '../services/online/search_cache.dart';
import 'database_providers.dart';
import 'library_add_providers.dart';
import 'library_providers.dart';
import 'online_providers.dart';
import 'settings_providers.dart';
import 'stream_providers.dart' show streamEnrichRowProvider;
import 'youtube_providers.dart';

/// Single import engine. Created at app start by the shell, which also turns
/// "running" imports left by the last session into "paused".
/// Disk cache of search answers; only the CSV import reads it.
final searchCacheProvider = Provider<SearchCache>((ref) {
  final cache = SearchCache(
      file: () async => File(p.join(await appSupportDir(), 'search_cache.json')));
  ref.onDispose(() => unawaited(cache.flush()));
  return cache;
});

final cachedYoutubeProvider = Provider<CachedYoutubeService>((ref) =>
    CachedYoutubeService(
        ref.watch(youtubeServiceProvider), ref.watch(searchCacheProvider)));

/// Number of cached searches, for the settings.
final searchCacheCountProvider = FutureProvider.autoDispose<int>(
    (ref) => ref.watch(searchCacheProvider).count());

/// A local track by id: the length check in «Rivedi», the Jam covers.
final importedTrackProvider = StreamProvider.autoDispose.family<Track?, int>(
    (ref, id) => ref.watch(trackRepositoryProvider).watchById(id));

final playlistImportServiceProvider = Provider<PlaylistImportService>((ref) {
  final cached = ref.watch(cachedYoutubeProvider);
  final downloads = ref.read(downloadsProvider.notifier);
  final tracks = ref.watch(trackRepositoryProvider);
  final service = PlaylistImportService(
    imports: ref.watch(importRepositoryProvider),
    playlists: ref.watch(playlistRepositoryProvider),
    loadLibrary: tracks.liteEntries,
    youtube: cached,
    forgetSearches: (queries) => unawaited(cached.forget(queries)),
    thresholds: () {
      final s = ref.read(settingsProvider);
      return MatchThresholds(
              sure: s.importSureThreshold, review: s.importReviewThreshold)
          .clamped();
    },
    // D-665: an import saves in streaming whatever the global mode; files only with «scarica anche».
    saveNow: ref.read(libraryAdderProvider).saveStreamNow,
    streaming: () => true,
    enqueue: (r, tag) => downloads.add(r, tag: tag),
    cancelDownloads: downloads.cancelWhere,
    settled: downloads.settled,
    trackIdForPath: tracks.idForPath,
    trackDurationMs: (id) async => (await tracks.getById(id))?.durationMs,
    fetchCover: (trackId, row) async {
      final t = await tracks.getById(trackId);
      if (t == null) return;
      await ref
          .read(coverFetcherProvider)
          .coverForAlbum(t, row.album!, row.primaryArtist, isrc: row.isrc);
    },
    // A saved stream row has no file to tag: it is enriched like a played one.
    enrichLater: (id) async {
      final row = await tracks.getById(id);
      if (row?.kind == kStreamKind) {
        unawaited(ref.read(streamEnrichRowProvider)(id));
      } else {
        afterDownload(ref, id);
      }
    },
    pathForVideo: (v) async =>
        (await ref.read(downloadIndexProvider.future)).pathFor(v.id, source: v.source),
    applyTags: (trackId, row) async {
      final t = await tracks.getById(trackId);
      if (t == null) return;
      // The CSV tags are cleaner than the video title; grouping albums by the
      // first artist keeps a Spotify album in one piece.
      await ref.read(trackEditorProvider).save(
            t,
            TrackEdit(
              title: row.title,
              artist: row.artistLine,
              album: row.album,
              albumArtist: row.primaryArtist,
              year: t.year ?? row.year,
              trackNumber: row.trackNumber ?? t.trackNumber,
              genre: t.genre,
            ),
          );
    },
    youtubeEnabled: kEnableYoutube,
  );
  ref.onDispose(service.dispose);
  return service;
});

final importEventsProvider = StreamProvider<ImportEvent>(
  (ref) => ref.watch(playlistImportServiceProvider).events,
);

/// Imports still running or paused (Activity Center, playlist banner).
final unfinishedImportsProvider = StreamProvider<List<PlaylistImport>>(
  (ref) => ref.watch(importRepositoryProvider).watchUnfinished(),
);

/// Latest import attached to a playlist, in any state.
final playlistImportProvider =
    StreamProvider.family<PlaylistImport?, int>((ref, playlistId) =>
        ref.watch(importRepositoryProvider).watchForPlaylist(playlistId));

final importItemsProvider =
    StreamProvider.family<List<PlaylistImportItem>, int>((ref, importId) =>
        ref.watch(importRepositoryProvider).watchItems(importId));

/// Rows per state of one import: all the counters need. The notification
/// keeps them watched for the whole import, in the background too.
final importCountsProvider =
    StreamProvider.family<Map<ImportItemStatus, int>, int>((ref, importId) =>
        ref.watch(importRepositoryProvider).watchCounts(importId));

Map<ImportItemStatus, int> countImportItems(Iterable<PlaylistImportItem> items) {
  final out = <ImportItemStatus, int>{};
  for (final i in items) {
    out[i.state] = (out[i.state] ?? 0) + 1;
  }
  return out;
}

/// What the Activity centre and the playlist banner show for one import.
class ImportProgress {
  const ImportProgress({
    required this.id,
    required this.playlistId,
    required this.name,
    required this.total,
    required this.done,
    this.saved = 0,
    required this.review,
    required this.missing,
    required this.paused,
    this.planned = 0,
    this.eta,
    this.blockIds = const [],
  });

  factory ImportProgress.from(
    PlaylistImport imp,
    List<PlaylistImportItem> items, {
    Duration? Function(int rowsLeft)? etaFor,
  }) =>
      ImportProgress.chain([imp], (_) => items,
          etaFor: etaFor == null ? null : (_, left) => etaFor(left));

  /// One import as the user sees it: all its blocks counted together. [id] is
  /// the block that runs, or else the first one waiting: pause, resume and
  /// cancel start from it and act on the whole chain.
  factory ImportProgress.chain(
    List<PlaylistImport> blocks,
    List<PlaylistImportItem> Function(int importId) itemsOf, {
    Duration? Function(int importId, int rowsLeft)? etaFor,
  }) =>
      ImportProgress.counted(blocks, (id) => countImportItems(itemsOf(id)),
          etaFor: etaFor);

  /// [ImportProgress.chain] from the rows per state of each block.
  factory ImportProgress.counted(
    List<PlaylistImport> blocks,
    Map<ImportItemStatus, int> Function(int importId) countsOf, {
    Duration? Function(int importId, int rowsLeft)? etaFor,
  }) {
    var total = 0, done = 0, saved = 0, review = 0, missing = 0, planned = 0;
    for (final b in blocks) {
      for (final MapEntry(key: state, value: n) in countsOf(b.id).entries) {
        switch (state) {
          // Rows a sync took out of the source are no longer part of the import.
          case ImportItemStatus.removed:
            continue;
          case ImportItemStatus.pending:
          case ImportItemStatus.queued:
            break;
          case ImportItemStatus.review:
            review += n;
            done += n;
          case ImportItemStatus.notFound:
          case ImportItemStatus.failed:
            missing += n;
            done += n;
          case ImportItemStatus.planned:
            planned += n;
            done += n;
          case ImportItemStatus.downloaded:
          case ImportItemStatus.linked:
            saved += n;
            done += n;
          case ImportItemStatus.skipped:
            done += n;
        }
        total += n;
      }
    }
    final running = blocks.where((b) => b.state == ImportStatus.running).firstOrNull;
    final waiting = blocks.where((b) => b.state == ImportStatus.paused).firstOrNull;
    final current = running ?? waiting ?? blocks.last;
    return ImportProgress(
      id: current.id,
      playlistId: current.playlistId,
      name: importLabel(current.sourceName),
      total: total,
      done: done,
      saved: saved,
      review: review,
      missing: missing,
      paused: running == null && waiting != null,
      planned: planned,
      eta: running == null ? null : etaFor?.call(running.id, total - done),
      blockIds: [for (final b in blocks) b.id],
    );
  }

  final int id, playlistId, total, done, review, missing, planned;

  /// Songs now in the playlist: downloaded or already in the library.
  final int saved;
  final String name;
  final bool paused;

  /// Time left at the current pace; null while unknown or paused.
  final Duration? eta;

  /// The imports this one is made of (several when imported «a blocchi»).
  final List<int> blockIds;

  double? get fraction => total == 0 ? null : done / total;
}

/// Imports still to finish, with counters (Activity centre).
final importProgressProvider = Provider<List<ImportProgress>>((ref) {
  final unfinished = ref.watch(unfinishedImportsProvider).value ?? const [];
  return [
    for (final group in groupImportChains(unfinished))
      ImportProgress.counted(
        _wholeChain(ref, group.first),
        (id) => ref.watch(importCountsProvider(id)).value ?? const {},
        etaFor: (id, left) => ref.read(playlistImportServiceProvider).etaFor(id, left),
      ),
  ];
});

/// Every import of a playlist, any state (the finished blocks of a chain too).
final playlistImportsProvider = StreamProvider.family<List<PlaylistImport>, int>(
    (ref, playlistId) => ref.watch(importRepositoryProvider).watchAllForPlaylist(playlistId));

/// All the blocks of the chain [one] belongs to, finished ones included.
List<PlaylistImport> _wholeChain(Ref ref, PlaylistImport one) {
  final all = ref.watch(playlistImportsProvider(one.playlistId)).value ?? [one];
  return groupImportChains(all).firstWhere((c) => c.any((i) => i.id == one.id), orElse: () => [one]);
}

/// Counters of the latest import of a playlist (null = none).
final playlistImportProgressProvider =
    Provider.family<ImportProgress?, int>((ref, playlistId) {
      final imp = ref.watch(playlistImportProvider(playlistId)).value;
      if (imp == null || imp.state == ImportStatus.cancelled) return null;
      return ImportProgress.counted(
        _wholeChain(ref, imp),
        (id) => ref.watch(importCountsProvider(id)).value ?? const {},
        etaFor: (id, left) => ref.read(playlistImportServiceProvider).etaFor(id, left),
      );
    });

/// What the import engine waits for before it tries again (null = nothing).
final importWaitProvider = StreamProvider<ImportWait?>((ref) async* {
  final service = ref.watch(playlistImportServiceProvider);
  yield service.currentWait;
  yield* service.waits;
});

/// The rows the import engine is searching or enriching right now.
final importStepsProvider = StreamProvider<ImportSteps>((ref) async* {
  final service = ref.watch(playlistImportServiceProvider);
  yield service.currentSteps;
  yield* service.steps;
});

final importByIdProvider = StreamProvider.family<PlaylistImport?, int>(
    (ref, importId) => ref.watch(importRepositoryProvider).watch(importId));

/// Every row of the import [importId] belongs to (all its blocks), in the
/// order of the file; null while loading.
final importChainItemsProvider = Provider.family<List<PlaylistImportItem>?, int>((ref, importId) {
  final imp = ref.watch(importByIdProvider(importId)).value;
  if (imp == null) return null;
  return [
    for (final b in _wholeChain(ref, imp)) ...?ref.watch(importItemsProvider(b.id)).value,
  ];
});

/// The counters of the whole import [importId] belongs to.
final importChainProgressProvider = Provider.family<ImportProgress?, int>((ref, importId) {
  final imp = ref.watch(importByIdProvider(importId)).value;
  if (imp == null) return null;
  return ImportProgress.counted(
    _wholeChain(ref, imp),
    (id) => ref.watch(importCountsProvider(id)).value ?? const {},
    etaFor: (id, left) => ref.read(playlistImportServiceProvider).etaFor(id, left),
  );
});

/// The downloads of import rows, by `(importId, rowIndex)`.
final importDownloadsProvider = Provider<Map<(int, int), DownloadItem>>((ref) => {
      for (final d in ref.watch(downloadsProvider)) ?parseImportTag(d.tag): d,
    });

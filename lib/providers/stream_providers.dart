import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart';
import '../data/repositories/track_repository.dart';
import '../services/online/synthetic_track.dart';
import '../services/online/enrichment_service.dart';
import '../services/online/youtube_service.dart' show YtResult;
import '../services/stream/stream_cache.dart';
import '../services/stream/stream_key.dart' show displayArtist;
import '../services/stream/stream_preparer.dart';
import '../services/stream/stream_promoter.dart';
import 'database_providers.dart';
import 'library_providers.dart';
import 'settings_providers.dart';
import 'online_providers.dart';
import 'player_providers.dart' show audioHandlerProvider;
import 'shuffle_plus_providers.dart' show networkProbeProvider;
import 'youtube_providers.dart';

/// Opened once in main (45.4); the limit follows the settings from 45.6.
final streamCacheProvider = Provider<StreamCache>((ref) =>
    throw StateError('streamCacheProvider must be overridden with an opened cache'));

/// Bytes the cache holds now; invalidate after anything that changes it.
final streamCacheUsedProvider = FutureProvider.autoDispose<int>((ref) async {
  final cache = ref.watch(streamCacheProvider);
  return cache.measure();
});

/// «Svuota»: empties the cache but for the [keep] keys (current track and
/// queue: the player still resolves them); then drops the shadow rows with no
/// plays that are left (rows with plays stay, D-81).
Future<void> clearStreamCache(StreamCache cache, TrackRepository tracks, {Set<String> keep = const {}}) async {
  await cache.clear(keep: keep);
  await tracks.deleteUnplayedStreamRows(keepKeys: keep);
}

/// [clearStreamCache] with the app's cache and tracks, for the settings tile.
final clearStreamCacheProvider = Provider<Future<void> Function(Set<String> keep)>((ref) =>
    (keep) => clearStreamCache(ref.read(streamCacheProvider), ref.read(trackRepositoryProvider), keep: keep));

void _applyLimit(StreamCache cache, int mb, void Function() done) {
  cache.limitBytes = mb * 1024 * 1024;
  // async I/O, never on the UI thread
  cache.evict().then((_) => done()).catchError((Object e, StackTrace st) => AppLog.w('stream cache: evict failed', e, st));
}

final streamPreparerProvider = Provider<StreamPreparer>((ref) {
  final cache = ref.watch(streamCacheProvider);
  void used() => ref.invalidate(streamCacheUsedProvider);
  _applyLimit(cache, ref.read(settingsProvider).streamCacheMb, used);
  ref.listen(settingsProvider.select((s) => s.streamCacheMb), (_, mb) => _applyLimit(cache, mb, used));
  final enrichment = ref.watch(enrichmentServiceProvider);
  final tracks = ref.watch(trackRepositoryProvider);
  final preparer = StreamPreparer(
    cache: ref.watch(streamCacheProvider),
    tracks: tracks,
    youtube: ref.watch(youtubeServiceProvider),
    isMetered: () async => (await ref.read(networkProbeProvider).current()).metered,
    enrich: (r, rowId) async {
      final proposal = await enrichment.propose(_syntheticTrack(r));
      if (proposal.limited) return; // a refusal is not «nothing found»: try again later
      // Tags go to the database only, never into the cached file.
      final row = await tracks.getById(await rowId);
      if (row == null) return;
      await enrichment.apply(
        EnrichmentProposal(
          track: row,
          meta: proposal.meta,
          lyrics: proposal.lyrics,
          curiosity: proposal.curiosity,
          disc: proposal.disc,
          isrc: proposal.isrc,
          source: proposal.source,
        ),
        EnrichField.values.toSet(),
      );
      // A shadow row had no id when `propose` ran, so its credits are saved here.
      await enrichment.saveCredits(row.id, proposal.credits);
    },
  );
  ref.onDispose(preparer.dispose);
  return preparer;
});

/// What `propose` reads (title, artist, album, length) before the row exists.
Track _syntheticTrack(YtResult r) => syntheticTrack(
      title: r.title,
      artist: displayArtist(r),
      album: r.album,
      durationMs: r.duration?.inMilliseconds ?? 0,
      kind: 2,
    );

/// «Scarica» on a cached track moves the file instead of downloading it (46.3).
final streamPromoterProvider = Provider<StreamPromoter>((ref) => StreamPromoter(
      cache: ref.watch(streamCacheProvider),
      tracks: ref.watch(trackRepositoryProvider),
      covers: ref.watch(coverStoreProvider),
      downloadFolder: () => resolveDownloadFolder(ref.read(folderRepositoryProvider)),
      index: () => ref.read(downloadIndexProvider.future),
      scan: (folder, path) async {
        await for (final _ in ref.read(libraryScannerProvider).scanFiles(folder, [path])) {}
      },
      tag: ref.read(downloadTaggerProvider).tag,
      onShadowMerged: (shadow, keep) => ref.read(audioHandlerProvider).replaceQueueId(shadow, keep),
    ));

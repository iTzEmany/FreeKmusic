import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/repositories/track_repository.dart';
import '../data/repositories/track_kinds.dart';
import '../services/audio/online_entries.dart' show isOnlineId;
import '../services/online/enrich_parts.dart' show EnrichStatus;
import '../services/online/synthetic_track.dart';
import '../services/stream/stream_enrich_trigger.dart';
import '../services/online/enrichment_service.dart';
import '../services/stream/stream_cache.dart';
import '../services/stream/stream_preparer.dart';
import '../services/stream/stream_promoter.dart';
import 'database_providers.dart';
import 'library_providers.dart';
import 'settings_providers.dart';
import 'online_providers.dart';
import 'player_providers.dart' show audioHandlerProvider, currentTrackProvider, onlineEntriesProvider, positionProvider;
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
  final preparer = StreamPreparer(
    cache: ref.watch(streamCacheProvider),
    tracks: ref.watch(trackRepositoryProvider),
    youtube: ref.watch(youtubeServiceProvider),
    isMetered: () async => (await ref.read(networkProbeProvider).current()).metered,
  );
  ref.onDispose(preparer.dispose);
  return preparer;
});

/// Enriches a shadow row (tags, lyrics, cover) once it has played 5 s (D-345).
Future<void> enrichStreamRow(EnrichmentService enrichment, TrackRepository tracks, int rowId) async {
  final row = await tracks.getById(rowId);
  if (row == null || row.kind != kStreamKind || row.enrichStatus != EnrichStatus.untried.code) return;
  final proposal = await enrichment.propose(syntheticTrack(
    title: row.title,
    artist: row.artist,
    album: row.album,
    durationMs: row.durationMs,
    kind: kStreamKind,
  ));
  if (proposal.limited) return; // a refusal is not «nothing found»: next listen retries
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
  await enrichment.saveCredits(row.id, proposal.credits);
}

/// Feeds the position to the trigger; kept alive by the app widget.
final streamEnrichTriggerProvider = Provider<StreamEnrichTrigger>((ref) {
  final trigger = StreamEnrichTrigger(
      (id) => enrichStreamRow(ref.read(enrichmentServiceProvider), ref.read(trackRepositoryProvider), id));
  ref.listen(positionProvider, (_, pos) {
    final t = ref.read(currentTrackProvider).value;
    final row = t == null
        ? null
        : isOnlineId(t.id)
            ? ref.read(onlineEntriesProvider)?.entryOf(t.id)?.trackId
            : t.kind == kStreamKind
                ? t.id
                : null;
    trigger.tick(t?.id, row, pos.value ?? Duration.zero);
  });
  return trigger;
});

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

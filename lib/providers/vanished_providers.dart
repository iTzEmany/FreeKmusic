import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../data/repositories/activity_log_repository.dart';
import '../services/import/track_matcher.dart' show MatchThresholds;
import '../services/online/collection_matcher.dart';
import '../services/online/external_collection.dart';
import '../services/online/vanished_tracks.dart';
import '../services/online/youtube_service.dart';
import '../services/stream/stream_key.dart' show keyOfStreamPath;
import 'database_providers.dart';
import 'player_providers.dart' show audioHandlerProvider;
import 'settings_providers.dart' show settingsProvider;
import 'smart_search_providers.dart' show linkMatchLimiterProvider, sourceCooldownProvider;
import 'youtube_providers.dart' show downloadIndexProvider, youtubeServiceProvider;

/// Replaces the saved streams that YouTube dropped (R-242); `main` calls `handle` when the player reports one.
final vanishedTracksProvider = Provider<VanishedTracks>((ref) {
  final tracks = ref.watch(trackRepositoryProvider);
  final log = ActivityLogRepository(ref.watch(databaseProvider));
  return VanishedTracks(
    tracks: tracks,
    onShadowMerged: (gone, keep) => ref.read(audioHandlerProvider).replaceQueueId(gone, keep),
    hasFile: (key) async => await (await ref.read(downloadIndexProvider.future)).existingPathForKey(key) != null,
    search: (row) async {
      // One matcher per search: the library is not consulted, every YouTube Music call is budgeted.
      final matcher = CollectionMatcher(
        youtube: ref.read(youtubeServiceProvider),
        cooldown: ref.read(sourceCooldownProvider),
        limiter: ref.read(linkMatchLimiterProvider),
        library: () => null,
        trackById: tracks.getById,
        thresholds: () {
          final s = ref.read(settingsProvider);
          return MatchThresholds(sure: s.importSureThreshold, review: s.importReviewThreshold).clamped();
        },
      );
      final one = ExternalTrack(title: row.title, artists: row.artists, key: '0', durationMs: row.durationMs);
      final (_, m) = await matcher.match([one]).first;
      if (m is TrackReadyOnline) return m.result;
      if (m is TrackNotFound && m.transient) throw const YtException(YtErrorKind.network);
      return null;
    },
    log: (row, to) => log.add(
      at: nowMs(),
      kind: 'vanished',
      name: row.title,
      failed: to == null,
      detail: jsonEncode({'trackId': row.id, 'from': keyOfStreamPath(row.path), 'to': to?.indexKey}),
    ),
  );
});

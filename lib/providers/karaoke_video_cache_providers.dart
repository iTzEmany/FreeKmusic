import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../services/karaoke_video/karaoke_video_cache.dart';
import '../services/karaoke_video/karaoke_video_source.dart';
import '../services/online/android_yt_dlp_service.dart';
import '../services/online/yt_dlp_process_service.dart';
import 'database_providers.dart' show trackRepositoryProvider;
import 'player_providers.dart';
import 'queue_tracks.dart';
import 'settings_providers.dart';
import 'shuffle_plus_providers.dart' show networkProbeProvider;
import 'stream_providers.dart' show streamCacheProvider;
import 'youtube_providers.dart' show ytDlpServiceProvider;

/// Where the video address comes from: the platform's yt-dlp service (Android: NewPipe, then yt-dlp).
final karaokeVideoSourceProvider = Provider<KaraokeVideoSource>((ref) {
  final yt = ref.watch(ytDlpServiceProvider);
  return KaraokeVideoSource(
    (id) => yt is AndroidYtDlpService ? yt.videoUrl(id) : (yt as YtDlpProcessService).videoUrl(id),
  );
});

/// The cache of karaoke videos (D-649): its 15-minute expiry runs from the start, on every platform,
/// and the karaoke videos of the manual queue are prefetched (D-651).
final karaokeVideoCacheProvider = Provider<KaraokeVideoCache>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  final cache = KaraokeVideoCache(
    cache: ref.watch(streamCacheProvider),
    source: ref.watch(karaokeVideoSourceProvider),
    canPrefetch: () async =>
        !(await ref.read(networkProbeProvider).current()).metered ||
        ref.read(settingsProvider).prefetchOnMobile,
  )..startExpiry();

  var disposed = false, running = false, again = false;
  Future<void> step() async {
    final tracks = await manualQueueTracks(
      handler,
      ref.read(trackRepositoryProvider),
      ref.read(onlineEntriesProvider),
    );
    if (!disposed) cache.prefetchQueue(tracks);
  }

  // One pass at a time, like karaokeAutoProvider: a change meanwhile makes it run again.
  Future<void> sync() async {
    if (running) {
      again = true;
      return;
    }
    running = true;
    try {
      do {
        again = false;
        await step();
      } while (again && !disposed);
    } on Object catch (e, st) {
      AppLog.w('karaoke video: queue prefetch failed', e, st);
    } finally {
      running = false;
    }
  }

  final sub = handler.queueChanges.listen((_) => unawaited(sync()));
  ref.onDispose(() {
    disposed = true;
    unawaited(sub.cancel());
    cache.dispose();
  });
  unawaited(sync());
  return cache;
});

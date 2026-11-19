import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/karaoke_video/karaoke_video_controller.dart';
import 'karaoke_video_cache_providers.dart';
import 'player_providers.dart';

export '../services/karaoke_video/karaoke_video_controller.dart' show KaraokeVideoState, KaraokeVideoStatus;

/// The video of the current karaoke track (none for any other). The app root reads it once, so the
/// audio handler's gate is always plugged in.
final karaokeVideoProvider = NotifierProvider<KaraokeVideoNotifier, KaraokeVideoState>(KaraokeVideoNotifier.new);

class KaraokeVideoNotifier extends Notifier<KaraokeVideoState> {
  @override
  KaraokeVideoState build() {
    final handler = ref.watch(audioHandlerProvider);
    final cache = ref.read(karaokeVideoCacheProvider);
    final c = KaraokeVideoController(
      source: ref.read(karaokeVideoSourceProvider),
      cached: cache.cached,
      download: cache.download,
      release: cache.release,
      tracks: handler.currentTrackStream,
      positions: handler.positionStream,
      playing: handler.playbackState.map((s) => s.playing).distinct(),
      audioPlaying: () => handler.isPlaying,
      onState: (s) => state = s,
    );
    handler.videoGate = c;
    final life = AppLifecycleListener(onStateChange: c.onLifecycle);
    ref.onDispose(() {
      handler.videoGate = null;
      life.dispose();
      c.dispose();
    });
    return const KaraokeVideoState(KaraokeVideoStatus.none);
  }
}

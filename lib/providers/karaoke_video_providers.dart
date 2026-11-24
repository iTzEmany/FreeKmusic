import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/jam/jam_models.dart' show JamState;
import '../services/karaoke_video/karaoke_video.dart';
import '../services/karaoke_video/karaoke_video_controller.dart';
import 'jam_providers.dart';
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
      videoIds: handler.currentTrackStream.map((t) => t == null ? null : karaokeVideoIdOfTrack(t)),
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

/// How a video player is made; tests plug a fake one.
final karaokeVideoPortFactoryProvider = Provider<KaraokeVideoPort Function()>((ref) => MediaKitVideoPort.new);

/// The video of the Jam's current item, aligned to the Jam position (D-710). `ref.listen`, not `watch`:
/// a rebuild per Jam state would recreate the controller and reload the video.
final jamKaraokeVideoProvider = NotifierProvider.autoDispose<JamKaraokeVideoNotifier, KaraokeVideoState>(
  JamKaraokeVideoNotifier.new,
);

class JamKaraokeVideoNotifier extends Notifier<KaraokeVideoState> {
  @override
  KaraokeVideoState build() {
    final cache = ref.read(karaokeVideoCacheProvider);
    final ids = StreamController<String?>(), playing = StreamController<bool>();
    // The first position at once: a guest joining mid-song must not start the video at 0.
    Stream<Duration> positions() async* {
      while (true) {
        final jam = ref.read(jamProvider).jam;
        if (jam != null) yield Duration(milliseconds: jam.positionAtTime(ref.read(jamProvider.notifier).jamNowMs()));
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }

    final c = KaraokeVideoController(
      source: ref.read(karaokeVideoSourceProvider),
      cached: cache.cached,
      download: cache.download,
      release: cache.release,
      videoIds: ids.stream.distinct(),
      positions: positions(),
      playing: playing.stream.distinct(),
      audioPlaying: () => ref.read(jamProvider).jam?.playing ?? false,
      onState: (s) => state = s,
      createPort: ref.read(karaokeVideoPortFactoryProvider),
    );
    void push(JamState? jam) {
      final item = jam?.current;
      ids.add(item == null ? null : jamKaraokeVideoId(item));
      playing.add(jam?.playing ?? false);
    }

    ref.listen(jamProvider.select((u) => u.jam), (_, jam) => push(jam));
    push(ref.read(jamProvider).jam);
    final life = AppLifecycleListener(onStateChange: c.onLifecycle);
    ref.onDispose(() {
      life.dispose();
      c.dispose();
      unawaited(ids.close());
      unawaited(playing.close());
    });
    return const KaraokeVideoState(KaraokeVideoStatus.none);
  }
}

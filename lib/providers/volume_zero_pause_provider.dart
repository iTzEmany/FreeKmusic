import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';
import 'system_volume_provider.dart';
import 'player_providers.dart';
import 'settings_providers.dart';

/// The volume the user sets, 0..1: the system media volume on Android, the
/// app slider (not the handler, so the sleep-timer fade and the preview never
/// count) on desktop.
final volumeZeroInputProvider = Provider<Stream<double>>((ref) {
  if (isAndroid) return ref.watch(systemVolumeProvider).changes;
  final c = StreamController<double>.broadcast();
  ref.listen(volumeProvider, (_, v) => c.add(v));
  ref.onDispose(c.close);
  return c.stream;
});

/// With «pause on zero volume» on, a volume at zero pauses local playback and
/// raising it resumes, only when this feature did the pause (D-504..D-507).
/// State: true while it holds a pause of its own.
class VolumeZeroPauseController extends Notifier<bool> {
  @override
  bool build() {
    final h = ref.read(audioHandlerProvider);
    var on = ref.read(settingsProvider).pauseOnZeroVolume;
    void sysVolume(bool start) {
      if (!isAndroid) return;
      final sv = ref.read(systemVolumeProvider);
      (start ? sv.start() : sv.stop()).ignore();
    }

    if (on) sysVolume(true);
    ref.listen(settingsProvider.select((s) => s.pauseOnZeroVolume), (_, v) {
      on = v;
      if (!v) state = false;
      sysVolume(v);
    });
    final subs = <StreamSubscription<Object?>>[
      ref.read(volumeZeroInputProvider).listen((v) {
        if (!on || h.hasRemote) return;
        if (v <= 0) {
          if (h.isPlaying) {
            state = true;
            h.pause();
          }
        } else if (state) {
          state = false;
          h.play();
        }
      }),
      // Any other play or another track is the user's: the pause is theirs now.
      h.playbackState.map((p) => p.playing).distinct().listen((p) {
        if (p) state = false;
      }),
      h.mediaItem.map((m) => m?.id).distinct().listen((_) => state = false),
    ];
    ref.onDispose(() {
      for (final s in subs) {
        s.cancel();
      }
      if (on) sysVolume(false);
    });
    return false;
  }
}

final volumeZeroPauseProvider =
    NotifierProvider<VolumeZeroPauseController, bool>(
      VolumeZeroPauseController.new,
    );

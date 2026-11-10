import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/platform.dart';
import 'equalizer_providers.dart';
import 'system_volume_provider.dart';
import 'player_providers.dart';
import 'settings_providers.dart';
import 'sleep_timer_provider.dart';

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
    final sv = ref.read(systemVolumeProvider);
    var on = ref.read(settingsProvider).pauseOnZeroVolume;
    void sysVolume(bool start) {
      if (!isAndroid) return;
      (start ? sv.start() : sv.stop()).ignore();
    }

    if (on) sysVolume(true);
    ref.listen(settingsProvider.select((s) => s.pauseOnZeroVolume), (_, v) {
      on = v;
      if (!v) state = false;
      sysVolume(v);
    });
    // A new output (headphones out, Bluetooth gone) must not resume on the
    // speaker; the end of a sleep timer is a pause of its own too.
    ref.listen(outputRouteProvider, (_, _) => state = false);
    ref.listen(sleepTimerProvider.select((s) => s.active), (was, now) {
      if (was == true && !now) state = false;
    });
    final subs = <StreamSubscription<Object?>>[
      ref.read(volumeZeroInputProvider).listen((v) {
        if (!on || h.hasRemote || v.isNaN) return;
        if (v <= 0) {
          if (h.wantsPlay) {
            state = true;
            h.pause().catchError((Object e, StackTrace st) {
              AppLog.w('pause at zero volume failed', e, st);
              state = false;
            });
          }
        } else if (state) {
          state = false;
          // A failed resume leaves the pause as the user's: no flag to retry.
          h.play().catchError((Object e, StackTrace st) {
            AppLog.w('resume after zero volume failed', e, st);
          });
        }
      }),
      // Any other play or another track is the user's: the pause is theirs now.
      h.playbackState.map((p) => p.playing).distinct().listen((p) {
        // A late «playing» from our own resume, after a new zero, is not theirs.
        if (p && h.wantsPlay) state = false;
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

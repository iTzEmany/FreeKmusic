import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/track_kinds.dart';
import '../services/audio/equalizer.dart';
import '../services/karaoke/karaoke_controller.dart';
import 'player_providers.dart';
import 'settings_providers.dart';

/// The main player's voice filter; null where there is none (macOS, iOS, Windows).
final voiceFilterProvider = Provider<VoiceFilter?>(
  (ref) => ref.watch(audioHandlerProvider).voiceFilter,
);

/// The saved karaoke state: on/off and the voice level (0 = lowest, 1 = untouched).
class KaraokeState {
  const KaraokeState(this.on, this.level);

  final bool on;
  final double level;
}

final karaokeProvider = Provider<KaraokeState>((ref) {
  final s = ref.watch(settingsProvider.select((s) => (s.karaokeOn, s.karaokeLevel)));
  return KaraokeState(s.$1, s.$2);
});

void setKaraokeOn(WidgetRef ref, bool on) =>
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(karaokeOn: on));

void setKaraokeLevel(WidgetRef ref, double level) => ref
    .read(settingsProvider.notifier)
    .update((s) => s.copyWith(karaokeLevel: level.clamp(0.0, 1.0)));

/// True while an episode or a radio plays: the filter is off there.
final karaokeBypassProvider = Provider<bool>((ref) {
  final t = ref.watch(currentTrackProvider).value;
  if (t == null) return false;
  final radio = ref.watch(onlineEntriesProvider)?.isRadioId(t.id) == true;
  return radio || t.kind == kEpisodeKind || ref.watch(audioHandlerProvider).isRadio;
});

/// Keeps the voice filter in line with the saved state and the current item.
/// Watched once, from the app root.
final karaokeApplierProvider = Provider<void>((ref) {
  final filter = ref.watch(voiceFilterProvider);
  if (filter == null) return;
  final controller = KaraokeController(filter);
  void apply() {
    final k = ref.read(karaokeProvider);
    unawaited(
      controller.apply(
        on: k.on,
        level: k.level,
        bypass: ref.read(karaokeBypassProvider),
      ),
    );
  }

  ref.listen(karaokeProvider, (_, _) => apply());
  ref.listen(karaokeBypassProvider, (_, _) => apply());
  apply();
});

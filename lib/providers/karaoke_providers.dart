import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/track_kinds.dart';
import '../services/audio/equalizer.dart';
import '../services/jam/jam_models.dart';
import '../services/karaoke/karaoke_controller.dart';
import 'jam_providers.dart';
import 'player_providers.dart';
import 'share_hub.dart';
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

/// The Jam's karaoke as this device sees it (D-587); null while there is no Jam.
class JamKaraoke {
  const JamKaraoke({
    required this.level,
    required this.guestsAllowed,
    required this.isHost,
    required this.remote,
    required this.playsHere,
    required this.hostName,
  });

  /// Voice level 0..1 for every output; null = off.
  final double? level;
  final bool guestsAllowed, isHost, remote, playsHere;
  final String hostName;

  bool get on => level != null;

  /// The host always; a guest only when the host allowed it.
  bool get canCommand => isHost || guestsAllowed;

  /// A remote guest that plays the audio can opt out («Ignora per me»).
  bool get canIgnore => remote && !isHost && playsHere;
}

final jamKaraokeProvider = Provider<JamKaraoke?>((ref) {
  final s = ref.watch(jamProvider);
  final jam = s.jam;
  if (!s.active || jam == null) return null;
  final host = jam.participants.where((p) => p.id == jam.hostDeviceId).firstOrNull;
  return JamKaraoke(
    level: jam.karaoke,
    guestsAllowed: jam.karaokeGuests,
    isHost: s.isHost,
    remote: s.remote,
    playsHere: jam.outputs.contains(ref.read(shareHubProvider.notifier).deviceId),
    hostName: host?.name.isNotEmpty == true ? host!.name : s.peerName,
  );
});

/// Whether the microphone shows: in a Jam always, except for a host whose device
/// cannot filter in a local Jam (it is the only one that plays).
final karaokeButtonVisibleProvider = Provider<bool>((ref) {
  final hasFilter = ref.watch(voiceFilterProvider) != null;
  final jam = ref.watch(jamKaraokeProvider);
  return jam == null ? hasFilter : jam.remote || !jam.isHost || hasFilter;
});

/// The Jam command for [level] (null = off); the sheet throttles the drags.
Future<JamError?> sendJamKaraoke(WidgetRef ref, double? level) =>
    ref.read(jamProvider.notifier).send(JamCommand.karaoke(level));

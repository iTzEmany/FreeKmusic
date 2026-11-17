import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart';
import '../services/stream/stream_key.dart';
import '../services/audio/equalizer.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import '../services/karaoke/karaoke_controller.dart';
import '../services/karaoke/separation_service.dart';
import 'stream_providers.dart' show streamCacheProvider;

import 'dart:io' show Directory, File, FileSystemEntityType;

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
  final s = ref.watch(
    settingsProvider.select((s) => (s.karaokeOn, s.karaokeLevel)),
  );
  return KaraokeState(s.$1, s.$2);
});

void setKaraokeOn(WidgetRef ref, bool on) => ref
    .read(settingsProvider.notifier)
    .update((s) => s.copyWith(karaokeOn: on));

void setKaraokeLevel(WidgetRef ref, double level) => ref
    .read(settingsProvider.notifier)
    .update((s) => s.copyWith(karaokeLevel: level.clamp(0.0, 1.0)));

/// True while an episode or a radio plays: the filter is off there.
final karaokeBypassProvider = Provider<bool>((ref) {
  final t = ref.watch(currentTrackProvider).value;
  if (t == null) return false;
  final radio = ref.watch(onlineEntriesProvider)?.isRadioId(t.id) == true;
  return radio ||
      t.kind == kEpisodeKind ||
      ref.watch(audioHandlerProvider).isRadio;
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
        // With the backing track playing the filter would cut the singer twice.
        bypass: ref.read(karaokeBypassProvider) ||
            ref.read(karaokeBaseProvider).value?.active == true,
      ),
    );
  }

  ref.listen(karaokeProvider, (_, _) => apply());
  ref.listen(karaokeBypassProvider, (_, _) => apply());
  ref.listen(karaokeBaseProvider, (_, _) => apply());
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

  /// [remote]: the Jam has remote guests (this device included, see [JamUiState.remoteJam]).
  final bool guestsAllowed, isHost, remote, playsHere;
  final String hostName;

  bool get on => level != null;

  /// The host always; a guest only when the host allowed it.
  bool get canCommand => isHost || guestsAllowed;

  /// A device that plays in a remote Jam without being its host can opt out
  /// («Ignora per me»). A remote guest never plays (R-157), so it never can.
  bool get canIgnore => remote && !isHost && playsHere;
}

final jamKaraokeProvider = Provider<JamKaraoke?>((ref) {
  final s = ref.watch(jamProvider);
  final jam = s.jam;
  if (!s.active || jam == null) return null;
  final host = jam.participants
      .where((p) => p.id == jam.hostDeviceId)
      .firstOrNull;
  return JamKaraoke(
    level: jam.karaoke,
    guestsAllowed: jam.karaokeGuests,
    isHost: s.isHost,
    remote: s.remoteJam,
    playsHere: jam.outputs.contains(
      ref.read(shareHubProvider.notifier).deviceId,
    ),
    hostName: host?.name.isNotEmpty == true ? host!.name : s.peerName,
  );
});

/// Whether the microphone shows: in a Jam always, except for a host whose device
/// cannot filter in a Jam without remote guests (its own output is the only one).
final karaokeButtonVisibleProvider = Provider<bool>((ref) {
  final hasFilter = ref.watch(voiceFilterProvider) != null;
  final jam = ref.watch(jamKaraokeProvider);
  return jam == null ? hasFilter : jam.remote || !jam.isHost || hasFilter;
});

/// The «Alta qualità» backing-track maker; null where there is no engine (not Android).
final separationServiceProvider = Provider<SeparationService?>((ref) {
  if (!isAndroid) return null;
  final service = SeparationService(
    cache: ref.watch(streamCacheProvider),
    separator: ChannelSeparator(),
    modelsRoot: () async => Directory(await appSupportDir()),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Base (true, default) or Original (false) once the backing track exists (D-622).
class KaraokeUseBase extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool v) => state = v;
}

final karaokeUseBaseProvider = NotifierProvider<KaraokeUseBase, bool>(KaraokeUseBase.new);

/// What «Alta qualità» works on for the current track: the cache [key] of its backing track and the
/// file to separate ([input], null while a streamed track is not in the cache yet).
class KaraokeTarget {
  const KaraokeTarget(this.key, this.input);

  final String key;
  final String? input;
}

Future<String?> _karaokeKey(Track t, String? streamKey) async {
  if (streamKey != null) return karaokeKeyOfStream(streamKey);
  if (t.kind == kEpisodeKind) return null;
  final st = await File(t.path).stat();
  if (st.type == FileSystemEntityType.notFound) return null;
  return karaokeKeyOfLocal(t.id, st.modified.millisecondsSinceEpoch);
}

final karaokeTargetProvider = FutureProvider<KaraokeTarget?>((ref) async {
  final t = ref.watch(currentTrackProvider).value;
  if (t == null || ref.watch(karaokeBypassProvider)) return null;
  final entry = ref.watch(onlineEntriesProvider)?.entryOf(t.id);
  final streamKey = entry?.result.indexKey ?? keyOfStreamPath(t.path);
  final key = await _karaokeKey(t, streamKey);
  if (key == null) return null;
  if (streamKey == null) return KaraokeTarget(key, t.path);
  final preparer = ref.read(audioHandlerProvider).preparer;
  if (preparer == null) return KaraokeTarget(key, null);
  // The file may land after this runs: the preparer's phases tell.
  preparer.phases.addListener(ref.invalidateSelf);
  ref.onDispose(() => preparer.phases.removeListener(ref.invalidateSelf));
  final file = await preparer.cachedFile(streamKey, entry?.result ?? streamResultOfRow(streamKey, t));
  return KaraokeTarget(key, file?.path);
});

/// The separation state of the current target (idle where there is no engine).
final separationStateProvider = Provider<SeparationState>((ref) {
  final service = ref.watch(separationServiceProvider);
  final key = ref.watch(karaokeTargetProvider.select((t) => t.value?.key));
  if (service == null || key == null) return SeparationState.idle;
  service.addListener(ref.invalidateSelf);
  ref.onDispose(() => service.removeListener(ref.invalidateSelf));
  return service.stateOf(key);
});

/// The backing track of the current track: [path] when it exists, [active] when it is what plays.
class KaraokeBase {
  const KaraokeBase(this.key, this.path, this.active);

  final String key;
  final String? path;
  final bool active;
}

bool _baseWanted(Ref ref) =>
    ref.read(karaokeProvider).on &&
    ref.read(karaokeUseBaseProvider) &&
    ref.read(jamKaraokeProvider) == null;

final karaokeBaseProvider = FutureProvider<KaraokeBase?>((ref) async {
  final key = ref.watch(karaokeTargetProvider.select((t) => t.value?.key));
  final cache = ref.read(streamCacheProvider);
  if (key == null || ref.watch(separationServiceProvider) == null) return null;
  ref.watch(separationStateProvider.select((s) => s.phase));
  ref.watch(karaokeProvider.select((k) => k.on));
  ref.watch(karaokeUseBaseProvider);
  ref.watch(jamKaraokeProvider.select((j) => j != null));
  final path = (await cache.fileFor(key))?.path;
  return KaraokeBase(key, path, path != null && _baseWanted(ref));
});

/// Plugs the backing track into the player: the handler's hook, the reload at the same position
/// when the track becomes ready or the choice changes, Base chosen when it becomes ready.
/// Watched once, from the app root.
final karaokeBaseApplierProvider = Provider<void>((ref) {
  final service = ref.watch(separationServiceProvider);
  if (service == null) return;
  final handler = ref.watch(audioHandlerProvider);
  handler.karaokeSource = (t, streamKey) async {
    if (!_baseWanted(ref) || t.kind == kEpisodeKind) return null;
    final key = await _karaokeKey(t, streamKey);
    return key == null ? null : (await ref.read(streamCacheProvider).fileFor(key))?.path;
  };
  ref.onDispose(() => handler.karaokeSource = null);
  ref.listen(separationStateProvider.select((s) => s.phase), (p, n) {
    if (n == SeparationPhase.ready && p != SeparationPhase.ready) {
      ref.read(karaokeUseBaseProvider.notifier).set(true);
    }
  });
  ref.listen(karaokeBaseProvider, (prev, next) {
    final b = next.value;
    final before = prev?.value;
    // Same track only: a track change loads by itself and asks the hook.
    if (b == null || before == null || before.key != b.key) return;
    final want = b.active ? b.path : null;
    if (want != handler.karaokePath) unawaited(handler.reloadCurrent());
  });
});

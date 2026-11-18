import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart';
import '../services/stream/stream_key.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import '../services/karaoke/separation_service.dart';
import 'shuffle_plus_providers.dart' show networkProbeProvider;
import 'stream_providers.dart' show streamCacheProvider;

import 'dart:io' show Directory, File, FileSystemEntityType;

import 'jam_providers.dart';
import 'player_providers.dart';
import 'settings_providers.dart';

/// The saved karaoke state: on/off and the voice level (the «Voce» slider, fase 130).
class KaraokeState {
  const KaraokeState(this.on, this.level);

  final bool on;
  final double level;
}

final karaokeProvider = Provider<KaraokeState>((ref) {
  final s = ref.watch(
    settingsProvider.select(
      (s) => (s.karaokeOn && s.showKaraoke, s.karaokeLevel),
    ),
  );
  return KaraokeState(s.$1, s.$2);
});

void setKaraokeOn(WidgetRef ref, bool on) => ref
    .read(settingsProvider.notifier)
    .update((s) => s.copyWith(karaokeOn: on));

/// True while an episode or a radio plays: there is no backing track.
final karaokeBypassProvider = Provider<bool>((ref) {
  final t = ref.watch(currentTrackProvider).value;
  if (t == null) return false;
  final radio = ref.watch(onlineEntriesProvider)?.isRadioId(t.id) == true;
  return radio ||
      t.kind == kEpisodeKind ||
      ref.watch(audioHandlerProvider).isRadio;
});

/// Whether the microphone shows: only where the separation engine exists (Android), never in a Jam (D-623).
final karaokeButtonVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(separationServiceProvider) != null &&
      ref.watch(settingsProvider.select((s) => s.showKaraoke)) &&
      !ref.watch(jamProvider.select((s) => s.active)),
);

/// The «Alta qualità» backing-track maker; null where there is no engine (not Android).
final separationServiceProvider = Provider<SeparationService?>((ref) {
  if (!isAndroid) return null;
  final service = SeparationService(
    cache: ref.watch(streamCacheProvider),
    separator: ChannelSeparator(),
    modelsRoot: () async => Directory(await appSupportDir()),
  )..startExpiry();
  ref.onDispose(service.dispose);
  return service;
});

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
  // No engine (desktop): nothing is watched or read.
  if (ref.watch(separationServiceProvider) == null) return null;
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
  final file = await preparer.cachedFile(
    streamKey,
    entry?.result ?? streamResultOfRow(streamKey, t),
  );
  return KaraokeTarget(key, file?.path);
});

/// The separation state of the current target (idle where there is no engine).
final separationStateProvider = Provider<SeparationState>((ref) {
  final service = ref.watch(separationServiceProvider);
  if (service == null) return SeparationState.idle;
  final key = ref.watch(karaokeTargetProvider.select((t) => t.value?.key));
  if (key == null) return SeparationState.idle;
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
    ref.read(karaokeProvider).on && !ref.read(jamProvider).active;

/// True while a mix is being made (the slider row shows a small progress).
final karaokeMixingProvider = Provider<bool>((ref) {
  final service = ref.watch(separationServiceProvider);
  if (service == null) return false;
  service.addListener(ref.invalidateSelf);
  ref.onDispose(() => service.removeListener(ref.invalidateSelf));
  return service.mixing;
});

/// What starting «Alta qualità» costs in data on a metered network (D-627); null when nothing or not metered.
final karaokeDataCostProvider =
    FutureProvider.autoDispose<({bool model, bool track})?>((ref) async {
      final service = ref.watch(separationServiceProvider);
      final target = ref.watch(karaokeTargetProvider).value;
      if (service == null || target == null) return null;
      if (!(await ref.read(networkProbeProvider).current()).metered) {
        return null;
      }
      final cost = (
        model: await service.modelsMissing(),
        track: target.input == null,
      );
      return cost.model || cost.track ? cost : null;
    });

/// Makes the file for the saved voice level and tells the handler (same position); nothing when
/// a newer call or another track came meanwhile.
final karaokeApplyProvider = Provider<Future<void> Function()>((ref) {
  var gen = 0;
  return () async {
    final service = ref.read(separationServiceProvider);
    final key = ref.read(karaokeTargetProvider).value?.key;
    if (service == null || key == null) return;
    final mine = ++gen;
    final path = _baseWanted(ref)
        ? await service.mixFor(key, ref.read(karaokeProvider).level)
        : null;
    if (mine != gen || key != ref.read(karaokeTargetProvider).value?.key) {
      return;
    }
    await ref.read(audioHandlerProvider).karaokeChanged(path);
  };
});

final karaokeBaseProvider = FutureProvider<KaraokeBase?>((ref) async {
  if (ref.watch(separationServiceProvider) == null) return null;
  final key = ref.watch(karaokeTargetProvider.select((t) => t.value?.key));
  final cache = ref.read(streamCacheProvider);
  if (key == null) return null;
  ref.watch(separationStateProvider.select((s) => s.phase));
  ref.watch(karaokeProvider.select((k) => k.on));
  ref.watch(jamProvider.select((s) => s.active));
  final path = (await cache.fileFor(karaokeFileKey('base', key)))?.path;
  return KaraokeBase(key, path, path != null && _baseWanted(ref));
});

/// The «Voce N %» of the lyrics pill: only while the base or a mix is really playing (not while
/// separating, after a failure, or at 100 %).
final karaokePillPercentProvider = Provider<int?>((ref) {
  if (!ref.watch(karaokeButtonVisibleProvider)) return null;
  final active = ref.watch(
    karaokeBaseProvider.select((b) => b.value?.active == true),
  );
  final level = ref.watch(karaokeProvider.select((k) => k.level));
  return active && level < 0.995 ? (level * 100).round() : null;
});

/// Plugs the backing track into the player: the handler's hook (the mix of the saved level, null at
/// 100 %), the pins of the files in use, the reload at the same position when the stems become ready
/// or karaoke goes on/off. Watched once, from the app root.
final karaokeBaseApplierProvider = Provider<void>((ref) {
  final service = ref.watch(separationServiceProvider);
  if (service == null) return;
  final handler = ref.watch(audioHandlerProvider);
  final cache = ref.read(streamCacheProvider);
  final keysOfPath = <String, List<String>>{};
  final pinned = <String>{};
  handler.karaokeSource = (t, streamKey) async {
    if (!_baseWanted(ref) || t.kind == kEpisodeKind) return null;
    final key = await _karaokeKey(t, streamKey);
    if (key == null) return null;
    final level = ref.read(karaokeProvider).level;
    final path = await service.mixFor(key, level);
    if (path == null) return null;
    keysOfPath[path] = [
      karaokeFileKey('base', key),
      karaokeFileKey('voice', key),
      karaokeFileKey('mix', '$key:${(level * 20).round() * 5}'),
    ];
    return path;
  };
  // Files that play or wait in the gapless window must not expire or be swept out of the cache;
  // with a mix, its base and voice stay too (the slider needs them).
  handler.onKaraokeInUse = (paths) {
    final keys = {for (final p in paths) ...?keysOfPath[p]};
    for (final k in pinned.difference(keys)) {
      cache.unpin(k);
      unawaited(cache.touch(k)); // playing was a use: the 15 minutes start now
    }
    for (final k in keys.difference(pinned)) {
      cache.pin(k);
    }
    pinned
      ..clear()
      ..addAll(keys);
  };
  ref.onDispose(() {
    handler.karaokeSource = null;
    handler.onKaraokeInUse = null;
    pinned.forEach(cache.unpin);
  });
  ref.listen(karaokeBaseProvider, (prev, next) {
    final b = next.value;
    final before = prev?.value;
    // Same track only: a track change loads by itself and asks the hook.
    if (b == null || before == null || before.key != b.key) return;
    if (before.path == b.path && before.active == b.active) return;
    unawaited(ref.read(karaokeApplyProvider)());
  });
});

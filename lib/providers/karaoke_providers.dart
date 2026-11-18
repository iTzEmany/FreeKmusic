import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart';
import 'queue_tracks.dart';
import '../services/stream/stream_key.dart';
import '../core/app_log.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import '../services/karaoke/separation_service.dart';
import 'shuffle_plus_providers.dart' show networkProbeProvider;
import 'stream_providers.dart' show streamCacheProvider;

import 'dart:io' show Directory, File, FileSystemEntityType;

import 'database_providers.dart' show trackRepositoryProvider;
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
      // The models land while the job runs: look again at every state change.
      service.addListener(ref.invalidateSelf);
      ref.onDispose(() => service.removeListener(ref.invalidateSelf));
      if (!(await ref.read(networkProbeProvider).current()).metered) {
        return null;
      }
      final cost = (
        model: await service.modelsMissing(),
        track: target.input == null,
      );
      return cost.model || cost.track ? cost : null;
    });

/// Which cache keys and which level step each karaoke file handed to the player stands for.
final _karaokePathsProvider =
    Provider<Map<String, ({List<String> keys, int step})>>((ref) => {});

void _recordPath(Ref ref, String path, String key, double level) {
  final step = (level * 20).round();
  ref.read(_karaokePathsProvider)[path] = (
    keys: [
      karaokeFileKey('base', key),
      karaokeFileKey('voice', key),
      karaokeFileKey('mix', '$key:${step * 5}'),
    ],
    step: step,
  );
}

/// The level steps of the karaoke files that play or wait in the player now (empty: the original plays).
class KaraokeInUse extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  // ignore: use_setters_to_change_properties
  void set(Set<int> v) => state = v;
}

final karaokeInUseProvider = NotifierProvider<KaraokeInUse, Set<int>>(
  KaraokeInUse.new,
);

/// Makes the file for the saved voice level and tells the handler (same position). A newer call,
/// another track or a failed mix change nothing: what plays keeps playing.
final karaokeApplyProvider = Provider<Future<void> Function()>((ref) {
  var gen = 0;
  return () async {
    final service = ref.read(separationServiceProvider);
    final key = ref.read(karaokeTargetProvider).value?.key;
    if (service == null || key == null) return;
    final mine = ++gen;
    final level = ref.read(karaokeProvider).level;
    var path = null as String?;
    if (_baseWanted(ref)) {
      final r = await service.mixFor(key, level);
      if (mine != gen || key != ref.read(karaokeTargetProvider).value?.key) {
        return;
      }
      if (r.status == MixStatus.stale || r.status == MixStatus.failed) return;
      path = r.path;
      if (path != null) _recordPath(ref, path, key, level);
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
  // Files the expiry deleted: the slider must not outlive them.
  final stems = ref.read(separationServiceProvider)!.stemsVersion;
  stems.addListener(ref.invalidateSelf);
  ref.onDispose(() => stems.removeListener(ref.invalidateSelf));
  ref.watch(karaokeProvider.select((k) => k.on));
  ref.watch(jamProvider.select((s) => s.active));
  final path = (await cache.fileFor(karaokeFileKey('base', key)))?.path;
  return KaraokeBase(key, path, path != null && _baseWanted(ref));
});

/// The «Voce N %» of the lyrics pill: only while the base or a mix of this very level plays (not
/// while separating or mixing, after a failure, or at 100 %).
final karaokePillPercentProvider = Provider<int?>((ref) {
  if (!ref.watch(karaokeButtonVisibleProvider)) return null;
  final active = ref.watch(
    karaokeBaseProvider.select((b) => b.value?.active == true),
  );
  final level = ref.watch(karaokeProvider.select((k) => k.level));
  final playing = ref.watch(karaokeInUseProvider);
  return active && level < 0.995 && playing.contains((level * 20).round())
      ? (level * 100).round()
      : null;
});

/// Plugs the backing track into the player: the handler's hook (the mix of the saved level, null at
/// 100 %), the pins of the files in use, the reload at the same position when the stems become ready
/// or karaoke goes on/off. Watched once, from the app root.
final karaokeBaseApplierProvider = Provider<void>((ref) {
  final service = ref.watch(separationServiceProvider);
  if (service == null) return;
  final handler = ref.watch(audioHandlerProvider);
  final cache = ref.read(streamCacheProvider);
  final paths = ref.read(_karaokePathsProvider);
  final pinned = <String>{};
  handler.karaokeSource = (t, streamKey) async {
    if (!_baseWanted(ref) || t.kind == kEpisodeKind) return null;
    final key = await _karaokeKey(t, streamKey);
    if (key == null) return null;
    final level = ref.read(karaokeProvider).level;
    final path = (await service.mixFor(
      key,
      level,
    )).path; // a failure: the original plays
    if (path != null) _recordPath(ref, path, key, level);
    return path;
  };
  // Files that play or wait in the gapless window must not expire or be swept out of the cache;
  // with a mix, its base and voice stay too (the slider needs them).
  handler.onKaraokeInUse = (inUse) {
    ref.read(karaokeInUseProvider.notifier).set({
      for (final p in inUse) ?paths[p]?.step,
    });
    final keys = {for (final p in inUse) ...?paths[p]?.keys};
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

/// Keys of the tracks whose data cost the user confirmed with «Avvia» (metered network, D-629).
class KaraokeConfirmed extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void add(String key) => state = {...state, key};
}

final karaokeConfirmedProvider =
    NotifierProvider<KaraokeConfirmed, Set<String>>(KaraokeConfirmed.new);

/// Starts the separation by itself (D-629): the current track when karaoke is on (unless a metered
/// network needs the user's «Avvia»), then the tracks queued by hand, one at a time, in queue order,
/// and keeps their stems pinned while they stay queued. A failed track is never retried here.
/// Watched once, from the app root.
final karaokeAutoProvider = Provider<void>((ref) {
  final service = ref.watch(separationServiceProvider);
  if (service == null) return;
  final handler = ref.watch(audioHandlerProvider);
  final cache = ref.read(streamCacheProvider);
  final pinned = <String>{};
  var running = false, again = false, disposed = false;
  late final Future<void> Function() pump;

  Future<KaraokeTarget?> queuedTarget(Track t) async {
    final online = ref.read(onlineEntriesProvider);
    if (t.kind == kEpisodeKind || online?.isRadioId(t.id) == true) return null;
    final entry = online?.entryOf(t.id);
    final streamKey = entry?.result.indexKey ?? keyOfStreamPath(t.path);
    final key = await _karaokeKey(t, streamKey);
    if (key == null) return null;
    if (streamKey == null) return KaraokeTarget(key, t.path);
    // Prefetch never forces a stream download: only a file already in the cache counts.
    final file = await handler.preparer?.cachedFile(
      streamKey,
      entry?.result ?? streamResultOfRow(streamKey, t),
    );
    return file == null ? null : KaraokeTarget(key, file.path);
  }

  Future<List<KaraokeTarget>> manualQueue() async {
    final from = handler.currentIndex + 1;
    final ids = handler.queueIds;
    if (from <= 0 || handler.userAhead == 0 || from >= ids.length) return [];
    final tracks = await queueTracks(
      ids.sublist(from, (from + handler.userAhead).clamp(from, ids.length)),
      ref.read(trackRepositoryProvider),
      ref.read(onlineEntriesProvider),
    );
    return [for (final t in tracks) ?await queuedTarget(t)];
  }

  void syncPins(Set<String> keys) {
    for (final k in pinned.difference(keys)) {
      cache.unpin(k);
      unawaited(cache.touch(k)); // leaving the queue: the 15 minutes start now
    }
    for (final k in keys.difference(pinned)) {
      cache.pin(k);
    }
    pinned
      ..clear()
      ..addAll(keys);
  }

  void start(KaraokeTarget t) => unawaited(
    service.request(t.key, t.input!).whenComplete(() {
      if (!disposed) unawaited(pump());
    }),
  );

  Future<void> step() async {
    if (!_baseWanted(ref)) {
      // Off: nothing new starts; a running native job is left to finish.
      syncPins(const {});
      return;
    }
    final queued = await manualQueue();
    syncPins({
      for (final t in queued) ...[
        karaokeFileKey('base', t.key),
        karaokeFileKey('voice', t.key),
      ],
    });
    final cur = ref.read(karaokeTargetProvider).value;
    if (cur != null) {
      final phase = service.stateOf(cur.key).phase;
      if (phase == SeparationPhase.idle) {
        // No file yet: the target changes when it lands.
        if (cur.input == null) return;
        final cost = await ref.read(karaokeDataCostProvider.future);
        if (cost != null &&
            !ref.read(karaokeConfirmedProvider).contains(cur.key)) {
          return;
        }
        if (cur.key == ref.read(karaokeTargetProvider).value?.key) start(cur);
        return;
      }
      // Running, or failed: no auto retry.
      if (phase != SeparationPhase.ready) return;
    }
    if (service.busy) return;
    final metered = (await ref.read(networkProbeProvider).current()).metered;
    if (metered && await service.modelsMissing()) return;
    for (final t in queued) {
      if (service.stateOf(t.key).phase == SeparationPhase.idle) {
        start(t);
        return;
      }
    }
  }

  pump = () async {
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
      AppLog.w('karaoke: auto separation failed', e, st);
    } finally {
      running = false;
    }
  };

  // Progress ticks while a job runs are skipped: its end pumps again (see [start]).
  void pumpListener() {
    if (!service.busy) unawaited(pump());
  }

  service.addListener(pumpListener);
  final queueSub = handler.queueChanges.listen((_) => unawaited(pump()));
  ref.listen(karaokeProvider.select((k) => k.on), (_, _) => unawaited(pump()));
  ref.listen(karaokeTargetProvider, (_, _) => unawaited(pump()));
  ref.listen(karaokeConfirmedProvider, (_, _) => unawaited(pump()));
  ref.listen(jamProvider.select((s) => s.active), (_, _) => unawaited(pump()));
  ref.onDispose(() {
    disposed = true;
    service.removeListener(pumpListener);
    unawaited(queueSub.cancel());
    pinned.forEach(cache.unpin);
  });
  unawaited(pump());
});

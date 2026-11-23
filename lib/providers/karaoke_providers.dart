import 'dart:async';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart';
import 'queue_tracks.dart';
import '../services/audio/online_entries.dart' show OnlineEntries, isOnlineId;
import '../services/stream/stream_key.dart';
import '../core/app_log.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import '../data/repositories/track_repository.dart' show TrackRepository;
import '../services/karaoke/separation_service.dart';
import '../services/online/enrich_parts.dart' show isInstrumentalTitle;
import '../services/karaoke_video/karaoke_video.dart';
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

/// An instrumental track: LRCLIB said so, or its title does (D-684). No lyrics search, no karaoke.
/// An online entry (negative id) reads the flag of its shadow row, if it has one.
Future<bool> isInstrumentalTrack(
  TrackRepository Function() repo,
  Track t, {
  OnlineEntries? online,
}) async {
  if (isInstrumentalTitle(t.title)) return true;
  final id = isOnlineId(t.id) ? online?.entryOf(t.id)?.trackId : t.id;
  return id != null && await repo().isInstrumental(id) == true;
}

/// Sets or clears the instrumental flag of [t]; an online entry without a shadow row has none to set.
Future<void> setInstrumentalFlag(WidgetRef ref, Track t, bool value) async {
  final id = isOnlineId(t.id) ? ref.read(onlineEntriesProvider)?.entryOf(t.id)?.trackId : t.id;
  if (id != null) await ref.read(trackRepositoryProvider).setInstrumental(id, value);
  ref.invalidate(instrumentalProvider(t));
}

final instrumentalProvider = FutureProvider.autoDispose.family<bool, Track>(
  (ref, t) => isInstrumentalTrack(
    () => ref.read(trackRepositoryProvider),
    t,
    online: ref.read(onlineEntriesProvider),
  ),
);

/// True while an episode or a radio plays: there is no backing track.
final karaokeBypassProvider = Provider<bool>((ref) {
  final t = ref.watch(currentTrackProvider).value;
  if (t == null) return false;
  if (isKaraokeVideo(t)) return true; // D-639: its audio is already the backing track
  final radio = ref.watch(onlineEntriesProvider)?.isRadioId(t.id) == true;
  return radio ||
      t.kind == kEpisodeKind ||
      ref.watch(audioHandlerProvider).isRadio;
});

/// Whether the microphone shows: only where the separation engine exists (Android), never in a Jam (D-623),
/// never on a karaoke video (it is its own backing track).
final karaokeButtonVisibleProvider = Provider<bool>(
  (ref) =>
      ref.watch(separationServiceProvider) != null &&
      ref.watch(settingsProvider.select((s) => s.showKaraoke)) &&
      !ref.watch(jamProvider.select((s) => s.active)) &&
      !ref.watch(currentTrackProvider.select((t) => t.value != null && isKaraokeVideo(t.value!))),
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
  if (t == null || isInstrumentalTitle(t.title) || ref.watch(karaokeBypassProvider)) {
    return null;
  }
  if (await isInstrumentalTrack(() => ref.read(trackRepositoryProvider), t, online: ref.read(onlineEntriesProvider))) {
    return null;
  }
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

  // A new set with the same steps is no change (it would restart the reminder).
  void set(Set<int> v) {
    if (!setEquals(state, v)) state = v;
  }
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
    if (!_baseWanted(ref) || t.kind == kEpisodeKind || isKaraokeVideo(t)) return null;
    if (await isInstrumentalTrack(() => ref.read(trackRepositoryProvider), t, online: ref.read(onlineEntriesProvider))) {
      return null;
    }
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
  // D-664: a restored, stopped track is not separated until something plays.
  var played = handler.playbackState.value.playing;
  late final Future<void> Function() pump;

  Future<KaraokeTarget?> queuedTarget(Track t) async {
    final online = ref.read(onlineEntriesProvider);
    if (t.kind == kEpisodeKind || isKaraokeVideo(t) || online?.isRadioId(t.id) == true) return null;
    if (await isInstrumentalTrack(() => ref.read(trackRepositoryProvider), t, online: online)) return null;
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
    final tracks = await manualQueueTracks(
      handler,
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

  // `request` takes a moment to mark its key as active: a second call for the same key meanwhile
  // would cancel the first.
  final requested = <String>{};
  void start(KaraokeTarget t) {
    if (!requested.add(t.key)) return;
    unawaited(
      service.request(t.key, t.input!).whenComplete(() {
        requested.remove(t.key);
        if (!disposed) unawaited(pump());
      }),
    );
  }

  Future<void> step() async {
    final target = ref.read(karaokeTargetProvider);
    // Not known yet: the listener pumps again when it is (else a prefetch could go first).
    if (target.isLoading) return;
    final cur = target.value;
    if (!_baseWanted(ref)) {
      // Off: nothing new starts; a prefetch is cancelled, the current track's job finishes.
      syncPins(const {});
      if (service.busy && service.activeKey != cur?.key) await service.cancel();
      return;
    }
    // An explicit «Avvia» on a metered network counts as a gesture: no wait for play.
    if (!played && !ref.read(karaokeConfirmedProvider).contains(cur?.key)) return;
    final queued = await manualQueue();
    if (disposed) return;
    // The current track's stems stay too: at 100 % no player file holds them and the expiry would
    // take them out, then the pump would separate the track again.
    syncPins({
      for (final t in [?cur, ...queued]) ...[
        karaokeFileKey('base', t.key),
        karaokeFileKey('voice', t.key),
      ],
    });
    if (cur != null) {
      final phase = service.stateOf(cur.key).phase;
      if (phase == SeparationPhase.idle) {
        // No file yet: the target changes when it lands.
        if (cur.input == null) return;
        final cost = await ref.read(karaokeDataCostProvider.future);
        if (disposed) return;
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
    // The models come back only with an explicit start: «Elimina» (models page) must stick.
    if (disposed || await service.modelsMissing()) return;
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
  StreamSubscription<void>? playSub;
  if (!played) {
    playSub = handler.playbackState.where((s) => s.playing).listen((_) {
      played = true;
      unawaited(playSub?.cancel());
      unawaited(pump());
    });
  }
  ref.listen(karaokeProvider.select((k) => k.on), (_, _) => unawaited(pump()));
  ref.listen(karaokeTargetProvider, (_, _) => unawaited(pump()));
  ref.listen(karaokeConfirmedProvider, (_, _) => unawaited(pump()));
  ref.listen(jamProvider.select((s) => s.active), (_, _) => unawaited(pump()));
  ref.onDispose(() {
    disposed = true;
    service.removeListener(pumpListener);
    unawaited(queueSub.cancel());
    unawaited(playSub?.cancel());
    pinned.forEach(cache.unpin);
  });
  unawaited(pump());
});

/// How long karaoke may stay on unused before the reminder (D-685).
const kKaraokeIdleReminder = Duration(minutes: 20);

/// Bumps (count + 1) each time karaoke has been on for 20 minutes in a row with no karaoke file in
/// use (D-685): the UI listens, shows «Spegni» and needs no acknowledgement. One bump per idle
/// period; the timer restarts when use resumes or karaoke goes off. Listened to by AppShell.
final karaokeReminderProvider = NotifierProvider<KaraokeReminder, int>(
  KaraokeReminder.new,
);

class KaraokeReminder extends Notifier<int> {
  Timer? _timer;

  @override
  int build() {
    ref.onDispose(() => _timer?.cancel());
    void check() {
      _timer?.cancel();
      final idle =
          ref.read(karaokeProvider).on && ref.read(karaokeInUseProvider).isEmpty;
      if (idle) _timer = Timer(kKaraokeIdleReminder, () => state++);
    }

    ref.listen(karaokeProvider.select((k) => k.on), (_, _) => check());
    ref.listen(karaokeInUseProvider.select((s) => s.isEmpty), (_, _) => check());
    check();
    return 0;
  }
}

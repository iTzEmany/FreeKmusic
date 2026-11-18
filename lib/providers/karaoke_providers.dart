import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart';
import '../services/stream/stream_key.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import '../services/karaoke/separation_service.dart';
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
    settingsProvider.select((s) => (s.karaokeOn, s.karaokeLevel)),
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
  (ref) => ref.watch(separationServiceProvider) != null && !ref.watch(jamProvider.select((s) => s.active)),
);

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
  final file = await preparer.cachedFile(streamKey, entry?.result ?? streamResultOfRow(streamKey, t));
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
    ref.read(karaokeProvider).on &&
    ref.read(karaokeUseBaseProvider) &&
    !ref.read(jamProvider).active;

final karaokeBaseProvider = FutureProvider<KaraokeBase?>((ref) async {
  if (ref.watch(separationServiceProvider) == null) return null;
  final key = ref.watch(karaokeTargetProvider.select((t) => t.value?.key));
  final cache = ref.read(streamCacheProvider);
  if (key == null) return null;
  ref.watch(separationStateProvider.select((s) => s.phase));
  ref.watch(karaokeProvider.select((k) => k.on));
  ref.watch(karaokeUseBaseProvider);
  ref.watch(jamProvider.select((s) => s.active));
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
  final cache = ref.read(streamCacheProvider);
  final keyOfPath = <String, String>{};
  final pinned = <String>{};
  handler.karaokeSource = (t, streamKey) async {
    if (!_baseWanted(ref) || t.kind == kEpisodeKind) return null;
    final key = await _karaokeKey(t, streamKey);
    final path = key == null ? null : (await cache.fileFor(key))?.path;
    if (path == null) return null;
    keyOfPath[path] = key!;
    unawaited(cache.touch(key));
    return path;
  };
  // A base that plays or waits in the gapless window must not be swept out of the cache.
  handler.onKaraokeInUse = (paths) {
    final keys = {for (final p in paths) ?keyOfPath[p]};
    for (final k in pinned.difference(keys)) {
      cache.unpin(k);
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
    if (before.path == b.path && before.active == b.active) return;
    unawaited(handler.karaokeChanged(b.active ? b.path : null));
  });
});

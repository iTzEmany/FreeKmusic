import 'dart:async';
import 'dart:math';

import '../core/app_log.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/platform.dart';
import '../data/db/app_database.dart';
import '../services/audio/codecore_audio_handler.dart';
import '../services/audio/online_entries.dart';
import '../services/audio/play_queue.dart';
import '../services/radio/radio_station.dart';
import '../services/audio/playback_persistence.dart';
import '../services/online/youtube_service.dart';
import 'youtube_providers.dart' show downloadIndexProvider;
import 'database_providers.dart';
import '../services/jam/jam_models.dart' show JamAddResult;
import 'jam_providers.dart' show jamProvider;
import 'queue_tracks.dart';
import 'settings_providers.dart';
import '../services/shuffle_plus/plus_allowed.dart';

/// Overridden in `main` once the handler has been created (and, on Android,
/// registered with `AudioService.init`).
final audioHandlerProvider = Provider<CodecoreAudioHandler>(
  (ref) => throw UnimplementedError('audioHandlerProvider not overridden'),
);

/// The streamed entries of the queue (negative ids); null where there are none.
final onlineEntriesProvider = Provider<OnlineEntries?>(
  (ref) => ref.watch(audioHandlerProvider).online,
);

final playbackPersistenceProvider = Provider<PlaybackPersistence?>(
  (ref) => null,
);

final playerErrorsProvider = Provider<Stream<PlaybackFailure>>(
  (ref) => const Stream<PlaybackFailure>.empty(),
);

/// Where the current queue came from, shown as «In riproduzione da».
enum PlayContextKind { album, artist, playlist, favorites, library, search, podcast, radio }

class PlayContext {
  const PlayContext(this.kind, [this.name]);

  final PlayContextKind kind;

  /// Album / playlist / artist name; null for the fixed kinds.
  final String? name;
}

class PlayContextNotifier extends Notifier<PlayContext?> {
  @override
  PlayContext? build() => null;

  void set(PlayContext? c) => state = c;
}

/// In memory only: not persisted across launches.
final playContextProvider = NotifierProvider<PlayContextNotifier, PlayContext?>(
  PlayContextNotifier.new,
);

/// One entry of a mixed list: a library [track] or an [online] song.
typedef MixItem = ({Track? track, YtResult? online});

class PlayerController {
  PlayerController(
    this._handler,
    this._persistence, {
    this.onContext,
    this.shufflePlus,
    this.setShufflePlus,
    this.libraryIdOf,
    this.jamActive,
    this.addToJam,
    this.jamQueueFullNow,
    this.addOnlineToJam,
    this.plusBlock,
    Random? random,
  }) : _random = random ?? Random();

  final Random _random;

  /// The Shuffle+ flag of the settings, and a way to change it.
  final bool Function()? shufflePlus;
  final void Function(bool)? setShufflePlus;

  /// The library track already holding [YtResult] (a download), if any.
  final Future<int?> Function(YtResult)? libraryIdOf;

  /// With a Jam active queueing goes to the shared queue (D-89): library ids
  /// to [addToJam], online results to [addOnlineToJam] (true = accepted).
  final bool Function()? jamActive;
  /// Returns how many of the ids got in (a full Jam refuses).
  final Future<JamAddResult> Function(List<int>)? addToJam;

  /// The shared queue refuses every add now (online adds cannot tell later).
  final bool Function()? jamQueueFullNow;
  bool get jamQueueFull => inJam && (jamQueueFullNow?.call() ?? false);
  final bool Function(YtResult)? addOnlineToJam;

  /// Why Shuffle+ is out of the cycle for [ids] (the list the button plays) or,
  /// without ids, for the current queue (null: it is in).
  final Future<ShufflePlusBlock?> Function(List<int>? ids)? plusBlock;

  bool get inJam => jamActive?.call() ?? false;

  final CodecoreAudioHandler _handler;
  final void Function(PlayContext?)? onContext;
  final PlaybackPersistence? _persistence;
  bool _askedNotifications = false;

  /// Only the ids travel to the player; it resolves tracks via the repository.
  Future<void> playFromList(
    List<Track> snapshot,
    int index, {
    PlayContext? context,
  }) async {
    if (snapshot.isEmpty) return;
    // D-89: in a Jam a tap queues the track in the shared queue, like a swipe.
    if (inJam) {
      await addToJam?.call([snapshot[index].id]);
      return;
    }
    onContext?.call(context);
    _handler.setPlayContext(context?.kind.index, context?.name);
    _requestNotificationPermissionOnce();
    await _handler.playQueue([for (final t in snapshot) t.id], index);
  }

  /// The list's Play button: from a random track when shuffle is on (the
  /// queue keeps it first and shuffles the rest), else from the first.
  Future<void> playAll(List<Track> snapshot, {PlayContext? context}) =>
      playFromList(
        snapshot,
        _handler.shuffleEnabled && snapshot.isNotEmpty
            ? _random.nextInt(snapshot.length)
            : 0,
        context: context,
      );

  /// Play of a list that mixes library tracks and online songs (a genre page):
  /// like [playAll], from a random item when shuffle is on, else the first. The
  /// online ones enter the queue as every streamed song does. In a Jam, as
  /// [playFromList]: the picked item joins the shared queue (D-89).
  Future<void> playMixed(List<MixItem> items, {PlayContext? context}) async {
    if (items.isEmpty) return;
    final at = _handler.shuffleEnabled ? _random.nextInt(items.length) : 0;
    if (inJam) {
      final t = items[at].track, r = items[at].online;
      if (t != null) await addToJam?.call([t.id]);
      if (r != null) _onlineToJam(r);
      return;
    }
    final ids = <int>[];
    try {
      for (final i in items) {
        ids.add(i.track?.id ?? (await _idOf(i.online!))!);
      }
    } on Object catch (e, st) {
      AppLog.w('mixed list not played', e, st);
      return;
    }
    onContext?.call(context);
    _handler.setPlayContext(context?.kind.index, context?.name);
    _requestNotificationPermissionOnce();
    await _handler.playQueue(ids, at);
  }

  /// Plays a list of radio stations from [index]; next and previous move
  /// between them. Radio leaves no history and no statistics.
  Future<void> playStations(
    List<RadioStation> stations,
    int index, {
    PlayContext? context,
  }) async {
    if (stations.isEmpty) return;
    final ctx = context ?? const PlayContext(PlayContextKind.radio);
    onContext?.call(ctx);
    _handler.setPlayContext(null, null);
    _requestNotificationPermissionOnce();
    await _handler.playStations(stations, index);
  }

  Future<void> togglePlayPause() => _handler.togglePlayPause();
  Future<void> pause() => _handler.pause();
  Future<void> next() => _handler.skipToNext();
  bool get hasNext => _handler.hasNext;
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration position) => _handler.seek(position);
  Future<void> jumpToQueueIndex(int index) => _handler.skipToQueueItem(index);
  Future<void> removeFromQueue(int index) => _handler.removeFromQueue(index);
  Future<void> removeTracks(Set<int> ids) => _handler.removeTracks(ids);
  void reorderQueue(int from, int to) {
    _handler.moveInQueue(from, to);
  }

  /// «Svuota»: see [CodecoreAudioHandler.rebuildUpcoming].
  QueueState? rebuildUpcoming() => _handler.rebuildUpcoming();
  bool get hasQueueSource => _handler.hasSource;
  void restoreQueue(QueueState state) => _handler.restoreQueue(state);

  /// Null outside a Jam; in one, how many tracks the shared queue took (0 or 1).
  Future<JamAddResult?> playNext(int trackId) async {
    if (inJam) return addToJam?.call([trackId]);
    _handler.playNext(trackId);
    return null;
  }

  Future<JamAddResult?> addToQueue(int trackId) async {
    if (inJam) return addToJam?.call([trackId]);
    _handler.addToQueue(trackId);
    return null;
  }

  /// The queue id of [r]: its library track when downloaded (D-81), else a
  /// new online entry; null without an online registry.
  Future<int?> _idOf(YtResult r) async =>
      await libraryIdOf?.call(r) ?? _handler.online?.register(r);

  /// Plays [id] alone, with the search context (empty queue, or radio: no stations to insert among).
  Future<void> _playAlone(int id) {
    onContext?.call(const PlayContext(PlayContextKind.search));
    _handler.setPlayContext(PlayContextKind.search.index, null);
    _requestNotificationPermissionOnce();
    return _handler.playQueue([id], 0);
  }

  Future<int?> _idOrLog(YtResult r) async {
    final int? id;
    try {
      id = await _idOf(r);
    } on Object catch (e, st) {
      AppLog.w('online play ignored: lookup failed for ${r.indexKey}', e, st);
      return null;
    }
    if (id == null) AppLog.w('online play ignored: no online registry');
    return id;
  }

  /// Tap on an online result: plays it right after the current track (R-01).
  /// A library id already in the queue appears twice (accepted).
  Future<void> playOnline(YtResult r) async {
    if (inJam) return _onlineToJam(r);
    final id = await _idOrLog(r);
    if (id == null) return;
    if (_handler.queueIds.isEmpty || _handler.isRadio) return _playAlone(id);
    _requestNotificationPermissionOnce();
    final at = _handler.currentIndex + 1;
    _handler.insertAt(at, id);
    await _handler.skipToQueueItem(at);
  }

  /// In a Jam: before any id lookup (library and negative ids mean nothing to guests); returns once accepted.
  void _onlineToJam(YtResult r) {
    if (addOnlineToJam?.call(r) != true) AppLog.w('jam: ${r.indexKey} not accepted');
  }

  Future<void> enqueueOnline(YtResult r) async {
    if (inJam) return _onlineToJam(r);
    final id = await _idOrLog(r);
    if (id == null) return;
    if (_handler.isRadio) return _playAlone(id);
    _handler.addToQueue(id);
  }

  Future<void> playOnlineNext(YtResult r) async {
    if (inJam) return _onlineToJam(r);
    final id = await _idOrLog(r);
    if (id == null) return;
    if (_handler.isRadio) return _playAlone(id);
    _handler.playNext(id);
  }

  /// Plays [list] in order; [shuffle] turns plain shuffle on (else off), never Shuffle+ (R-18).
  Future<void> playOnlineList(List<YtResult> list, {bool shuffle = false}) async {
    if (list.isEmpty) return;
    if (inJam) return list.forEach(_onlineToJam);
    final ids = <int>[];
    try {
      for (final r in list) {
        ids.add((await _idOf(r))!);
      }
    } on Object catch (e, st) {
      AppLog.w('online list not played', e, st);
      return;
    }
    onContext?.call(const PlayContext(PlayContextKind.search));
    _handler.setPlayContext(PlayContextKind.search.index, null);
    _requestNotificationPermissionOnce();
    final load = _handler.playQueue(ids, shuffle ? _random.nextInt(ids.length) : 0);
    // After playQueue has set the queue (it does so before its first await) and
    // not after the load: it would shuffle the upcoming of a shuffle already on,
    // and the first track takes minutes to load.
    setShufflePlus?.call(false);
    await setShuffle(shuffle);
    await load;
  }

  Future<void> setVolume(double v) {
    _persistence?.setVolume(v);
    return _handler.setVolume(v);
  }

  /// The shuffle button of a list: on or off, never starts playback.
  Future<void> toggleShuffle() {
    final on = !_handler.shuffleEnabled;
    if (!on) setShufflePlus?.call(false);
    return setShuffle(on);
  }

  /// The shuffle button: off, shuffle, Shuffle+, off. Returns why it skipped
  /// Shuffle+ (then: off, shuffle, off), else null.
  /// [ids]: the list this button plays (D-137); null: the current queue.
  Future<ShufflePlusBlock?> cycleShuffle({List<int>? ids}) {
    // Serialized: a second tap reads the state the first one left.
    final run = _cycle.then((_) => _cycleShuffle(ids));
    _cycle = run.then<void>((_) {}, onError: (Object e) {
      AppLog.w('shuffle cycle failed', e);
    });
    return run;
  }

  Future<void> _cycle = Future<void>.value();

  Future<ShufflePlusBlock?> _cycleShuffle(List<int>? ids) async {
    final plus = shufflePlus?.call() ?? false;
    if (!_handler.shuffleEnabled) {
      setShufflePlus?.call(false);
      await setShuffle(true);
      return null;
    }
    final block = plus ? null : await plusBlock?.call(ids);
    if (!plus && block == null) {
      setShufflePlus?.call(true);
      return null;
    }
    setShufflePlus?.call(false);
    await setShuffle(false);
    return block; // null when a stored plus goes off: no skip
  }

  Future<void> setShuffle(bool on) => _handler.setShuffleMode(
    on ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
  );

  Future<void> cycleRepeat() =>
      _handler.setRepeatMode(switch (_handler.repeatMode) {
        PlayRepeat.off => AudioServiceRepeatMode.all,
        PlayRepeat.all => AudioServiceRepeatMode.one,
        PlayRepeat.one => AudioServiceRepeatMode.none,
      });

  void _requestNotificationPermissionOnce() {
    if (_askedNotifications || !isAndroid) return;
    _askedNotifications = true;
    // No activity (the player was started by a widget or a key): no dialog.
    unawaited(Permission.notification.request().then<void>((_) {}, onError: (Object e) {
      AppLog.d('notification permission not asked', e);
    }));
  }
}

/// Why the shuffle button may not reach Shuffle+ now (null: it may).
/// [ids]: the list the button is going to play, instead of the queue now.
Future<ShufflePlusBlock?> plusAllowedNow(Ref ref, {List<int>? ids}) async {
  try {
    final h = ref.read(audioHandlerProvider);
    final local = await ref.read(trackRepositoryProvider).getByIdsLight([
      for (final i in ids ?? h.sourceIds ?? h.queueIds)
        if (!isOnlineId(i)) i,
    ]);
    return plusAllowed(
      queueIds: ids ?? h.queueIds,
      jam: ref.read(jamProvider).active,
      radio: ref.read(playContextProvider)?.kind == PlayContextKind.radio,
      localCount: local.where((t) => !t.missing && t.kind == 0).length,
    );
  } on Object catch (e, st) {
    AppLog.w('shuffle+ allowed check failed', e, st);
    return null;
  }
}

final playerControllerProvider = Provider<PlayerController>(
  (ref) => PlayerController(
    ref.watch(audioHandlerProvider),
    ref.watch(playbackPersistenceProvider),
    onContext: (c) => ref.read(playContextProvider.notifier).set(c),
    shufflePlus: () => ref.read(settingsProvider).shufflePlus,
    setShufflePlus: (on) => ref
        .read(settingsProvider.notifier)
        .update((c) => c.copyWith(shufflePlus: on)),
    jamActive: () => ref.read(jamProvider).active,
    addToJam: ref.read(jamProvider.notifier).addLibraryIds,
    jamQueueFullNow: () => ref.read(jamProvider.notifier).queueFull,
    addOnlineToJam: (r) => ref.read(jamProvider.notifier).addOnline(r),
    plusBlock: (ids) => plusAllowedNow(ref, ids: ids),
    libraryIdOf: (r) async {
      final path = (await ref.read(downloadIndexProvider.future))
          .pathFor(r.id, source: r.source);
      return path == null ? null : ref.read(trackRepositoryProvider).idForPath(path);
    },
  ),
);

final currentTrackProvider = StreamProvider<Track?>((ref) async* {
  final h = ref.watch(audioHandlerProvider);
  yield h.currentTrack;
  yield* h.currentTrackStream;
});

final isPlayingProvider = StreamProvider<bool>((ref) {
  final h = ref.watch(audioHandlerProvider);
  return h.playbackState.map((s) => s.playing).distinct();
});

/// Playback rate as published by the handler (1 for a radio).
final playbackSpeedProvider = StreamProvider<double>((ref) {
  final h = ref.watch(audioHandlerProvider);
  return h.playbackState.map((s) => s.speed).distinct();
});

/// A stream is loading (R-02): a bool of its own, so nothing rebuilds for the download progress (K-03).
final streamLoadingProvider = StreamProvider<bool>((ref) {
  final h = ref.watch(audioHandlerProvider);
  return h.playbackState.map((_) => h.loadingStream).distinct();
});

final shuffleProvider = StreamProvider<bool>((ref) {
  final h = ref.watch(audioHandlerProvider);
  return h.playbackState
      .map((s) => s.shuffleMode != AudioServiceShuffleMode.none)
      .distinct();
});

final repeatProvider = StreamProvider<PlayRepeat>((ref) {
  final h = ref.watch(audioHandlerProvider);
  return h.playbackState
      .map(
        (s) => switch (s.repeatMode) {
          AudioServiceRepeatMode.one => PlayRepeat.one,
          AudioServiceRepeatMode.all ||
          AudioServiceRepeatMode.group => PlayRepeat.all,
          AudioServiceRepeatMode.none => PlayRepeat.off,
        },
      )
      .distinct();
});

/// Separate from everything else so only the slider rebuilds on each tick.
final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioHandlerProvider).positionStream,
);

final durationProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(audioHandlerProvider).durationStream,
);

final queueProvider = StreamProvider<List<Track>>((ref) async* {
  final h = ref.watch(audioHandlerProvider);
  final repo = ref.watch(trackRepositoryProvider);
  final online = ref.watch(onlineEntriesProvider);
  yield await queueTracks(h.queueIds, repo, online);
  await for (final _ in h.queueChanges) {
    yield await queueTracks(h.queueIds, repo, online);
  }
});

class VolumeNotifier extends Notifier<double> {
  double _beforeMute = 1.0;

  @override
  double build() {
    final sub = ref
        .read(audioHandlerProvider)
        .volumeRequests
        .listen((v) => set(v.clamp(0.0, 1.0)));
    ref.onDispose(sub.cancel);
    return ref.read(settingsStoreProvider).readPlayback().volume;
  }

  void set(double v) {
    state = v;
    ref.read(playerControllerProvider).setVolume(v);
  }

  void toggleMute() {
    if (state > 0) {
      _beforeMute = state;
      set(0);
    } else {
      set(_beforeMute <= 0 ? 1.0 : _beforeMute);
    }
  }
}

final volumeProvider = NotifierProvider<VolumeNotifier, double>(
  VolumeNotifier.new,
);

final playerFailuresProvider = StreamProvider<PlaybackFailure>(
  (ref) => ref.watch(playerErrorsProvider),
);

/// The shadow row id of the playing stream entry: now, and again whenever the
/// entry is (re)bound (a download merges the row into a library track).
final _shadowRowId = StreamProvider<int?>((ref) async* {
  final id = ref.watch(currentTrackProvider.select((t) => t.value?.id));
  final entries = ref.watch(onlineEntriesProvider);
  if (entries == null || id == null || !isOnlineId(id)) {
    yield null;
    return;
  }
  if (entries.entryOf(id) == null) {
    yield null;
    return;
  }
  // Listen before the first yield: a bind in between must not be lost.
  final out = StreamController<int?>()..add(entries.entryOf(id)?.trackId);
  final sub = entries.bound.where((i) => i == id).listen((_) => out.add(entries.entryOf(id)?.trackId));
  ref.onDispose(() {
    sub.cancel();
    out.close();
  });
  yield* out.stream;
});

final _shadowRowStream = StreamProvider<Track?>((ref) async* {
  final rowId = ref.watch(_shadowRowId).value;
  if (rowId == null) {
    yield null;
    return;
  }
  yield* ref.watch(trackRepositoryProvider).watchById(rowId);
});

/// The shadow row (real id) of the streamed track now playing, kept in sync
/// with the DB; null for a library track, a radio, or before the row exists.
/// A row left over from the previous track is dropped (the stream keeps its
/// last value while loading).
final currentShadowRowProvider = Provider<Track?>((ref) {
  final id = ref.watch(currentTrackProvider.select((t) => t.value?.id));
  final row = ref.watch(_shadowRowStream).value;
  final rowId = id == null ? null : ref.watch(onlineEntriesProvider)?.entryOf(id)?.trackId;
  return row != null && row.id == rowId ? row : null;
});

/// Current track kept in sync with DB edits (favourite flag, title, ...).
final liveCurrentTrackProvider = StreamProvider<Track?>((ref) async* {
  final id = ref.watch(currentTrackProvider.select((t) => t.value?.id));
  if (id == null) {
    yield null;
    return;
  }
  if (!isOnlineId(id)) {
    yield* ref.watch(trackRepositoryProvider).watchById(id);
    return;
  }
  // A streamed entry shows its synthetic track until the preparer makes the
  // shadow row; then the row's data (lyrics and trivia appear as enrichment
  // ends) under the entry's own negative id, so the online menus and cover keep working.
  final row = ref.watch(currentShadowRowProvider);
  yield row?.copyWith(id: id) ?? ref.read(onlineEntriesProvider)?.trackOf(id);
});

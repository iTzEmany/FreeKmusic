import 'dart:async';
import 'dart:math';

import '../core/app_log.dart';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show ValueNotifier, listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/platform.dart';
import '../data/db/app_database.dart';
import '../services/audio/codecore_audio_handler.dart';
import '../services/audio/online_entries.dart';
import '../services/audio/play_queue.dart';
import '../services/stream/stream_preparer.dart' show StreamPhase;
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
import '../services/shuffle_plus/radio_fill.dart';
import '../services/shuffle_plus/similar_queue.dart';
import '../services/shuffle_plus/suggestion_pool.dart' show RadioSeed;
import 'shuffle_plus_providers.dart'
    show
        ShuffleMode,
        libraryMatchIdProvider,
        listKeyOf,
        listShuffleProvider,
        similarFillProvider;
import 'suggestion_log_provider.dart';

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
// .index is stored (prefs lastContextKind, DB plays.context): only append values, never reorder.
enum PlayContextKind {
  album,
  artist,
  playlist,
  favorites,
  library,
  search,
  podcast,
  radio,
}

class PlayContext {
  const PlayContext(this.kind, [this.name]);

  final PlayContextKind kind;

  /// Album / playlist / artist name; null for the fixed kinds.
  final String? name;
}

/// The context the handler holds (saved with the queue); null for none or an unknown kind.
PlayContext? playContextOf(CodecoreAudioHandler h) {
  final c = h.playContext;
  return c == null || c.kind < 0 || c.kind >= PlayContextKind.values.length
      ? null
      : PlayContext(PlayContextKind.values[c.kind], c.name);
}

/// The handler's context, followed live (restore, a list started, Android Auto clearing it).
final playContextProvider = Provider<PlayContext?>((ref) {
  final h = ref.watch(audioHandlerProvider);
  final l = h.playContextListenable;
  void changed() => ref.invalidateSelf();
  l.addListener(changed);
  ref.onDispose(() => l.removeListener(changed));
  return playContextOf(h);
});

/// One entry of a mixed list: a library [track] or an [online] song. A
/// [seedTitle] marks the online song as a Shuffle+ suggestion made from that
/// song (it shows «Suggerito» in the queue).
typedef MixItem = ({Track? track, YtResult? online, String? seedTitle});

/// The queue that played last, when nothing plays (D-364): how many songs and
/// the one it would start with.
typedef LastQueue = ({int count, Track first});

class PlayerController {
  PlayerController(
    this._handler,
    this._persistence, {
    this.shufflePlus,
    this.setShufflePlus,
    this.libraryIdOf,
    this.jamActive,
    this.addToJam,
    this.jamQueueFullNow,
    this.addOnlineToJam,
    this.plusBlock,
    this.listMode,
    this.setListMode,
    this.onSuggested,
    this.similarFill,
    this.libraryMatchIdOf,
    this.similarNow,
    this.similarSchedule,
    this.similarRetryAfter = const Duration(minutes: 1),
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

  /// The mode chosen on the page of the list [key] for its own next Play, and
  /// a way to change it (D-534); without them every list is «off».
  final ShuffleMode Function(Object key)? listMode;
  final void Function(Object key, ShuffleMode mode)? setListMode;

  /// The list started last through a keyed Play and the queue it made.
  Object? _listKey;
  List<int>? _listKeySource;

  /// Is the list [key] the one playing? A key is the page's own (a Play that
  /// passed it) or the hash of the list's ids ([listKeyOf]), so a row tap
  /// counts too (D-534).
  bool isPlayingList(Object key) {
    final src = _handler.sourceIds;
    if (src == null) return false;
    return (_listKey == key && listEquals(src, _listKeySource)) ||
        listKeyOf(src) == key;
  }

  /// A suggested song entered the queue (it goes to the suggestions log).
  final void Function(YtResult r, String seedTitle)? onSuggested;

  /// The radio of [RadioSeed] for the songs similar to a Search pick; null
  /// when the source is off (Jam, metered or no network, no yt-dlp, 429).
  final Future<RadioFill?> Function(RadioSeed seed)? similarFill;

  /// The title of the song whose similar songs keep filling the queue; null
  /// when no such session runs.
  final similarTitle = ValueNotifier<String?>(null);

  /// True while the first block of similar songs is still being asked.
  final similarLoading = ValueNotifier<bool>(false);

  /// The library track an online song already is (same title and artist,
  /// not a download), for the similar songs.
  final Future<int?> Function(YtResult)? libraryMatchIdOf;

  /// Clock, timer and failure wait of the similar-songs session (tests).
  final DateTime Function()? similarNow;
  final Timer Function(Duration, void Function())? similarSchedule;
  final Duration similarRetryAfter;
  SimilarQueue? _similar;
  int _epoch = 0;
  bool _disposed = false;

  bool get inJam => jamActive?.call() ?? false;

  /// Ends the similar-songs session: every way of starting another queue
  /// calls this first.
  void _stopSimilar() {
    _epoch++;
    _similar?.close();
    _similar = null;
    _setSimilar(null);
  }

  void _setSimilar(String? title, {bool loading = false}) {
    if (_disposed) return;
    similarTitle.value = title;
    similarLoading.value = loading;
  }

  void dispose() {
    if (_disposed) return;
    _stopSimilar();
    _disposed = true;
    similarTitle.dispose();
    similarLoading.dispose();
  }

  final CodecoreAudioHandler _handler;
  final PlaybackPersistence? _persistence;
  bool _askedNotifications = false;

  /// The context of the list started last, read from the handler.
  PlayContext? get _context => playContextOf(_handler);

  /// The one way a list starts: context, notification permission, then the
  /// queue from [at]. [plus] / [shuffle] set Shuffle+ / plain shuffle once the
  /// queue is set (null: leave it), without waiting for the first track: a
  /// stream takes minutes to load, and the new queue must not be shuffled twice.
  Future<void> _start(
    List<int> ids,
    int at,
    PlayContext? context, {
    bool? plus,
    bool? shuffle,
    Object? listKey,
  }) async {
    _stopSimilar();
    _handler.setPlayContext(context?.kind.index, context?.name);
    _requestNotificationPermissionOnce();
    final load = _handler.playQueue(ids, at);
    _listKey = listKey;
    _listKeySource = _handler.sourceIds;
    if (plus != null) setShufflePlus?.call(plus);
    if (shuffle != null) await setShuffle(shuffle);
    await load;
  }

  /// Only the ids travel to the player; it resolves tracks via the repository.
  /// In a Jam a tap queues the track in the shared queue, like a swipe (D-89).
  Future<void> playFromList(
    List<Track> snapshot,
    int index, {
    PlayContext? context,
  }) => playMixed(
    [for (final t in snapshot) (track: t, online: null, seedTitle: null)],
    index: index,
    context: context,
  );

  /// The list's Play button: from a random track when shuffle is on (the
  /// queue keeps it first and shuffles the rest), else from the first.
  /// [listKey]: the Play of a list page, which applies the mode chosen on its
  /// control instead of the player's (D-534).
  Future<void> playAll(
    List<Track> snapshot, {
    PlayContext? context,
    Object? listKey,
  }) => listKey != null
      ? playMixed(
          [for (final t in snapshot) (track: t, online: null, seedTitle: null)],
          context: context,
          listKey: listKey,
        )
      : playFromList(
        snapshot,
        _handler.shuffleEnabled && snapshot.isNotEmpty
            ? _random.nextInt(snapshot.length)
            : 0,
        context: context,
      );

  /// Play of a list that mixes library tracks and online songs (a genre page):
  /// from item [index], else like [playAll] (a random item when shuffle is on,
  /// else the first). Shuffle+ goes off when the list has online songs, as in
  /// [playOnlineList] (R-18): the list brings its own suggestions. The
  /// online ones enter the queue as every streamed song does; those with a
  /// seed title as Shuffle+ suggestions. [shuffle]: sets plain shuffle on or
  /// off. In a Jam only the picked item joins the shared queue (D-89).
  Future<void> playMixed(
    List<MixItem> items, {
    int? index,
    PlayContext? context,
    bool? shuffle,
    Object? listKey,
  }) async {
    if (items.isEmpty) return;
    // An explicit [shuffle] (a row tap) wins over the page's mode.
    final mode = listKey == null || shuffle != null
        ? null
        : (listMode?.call(listKey) ?? ShuffleMode.off);
    if (mode != null) shuffle = mode != ShuffleMode.off;
    final at =
        (index ??
                ((shuffle ?? _handler.shuffleEnabled)
                    ? _random.nextInt(items.length)
                    : 0))
            .clamp(0, items.length - 1);
    if (inJam) {
      final t = items[at].track, r = items[at].online;
      if (t != null) await addToJam?.call([t.id]);
      if (r != null) _onlineToJam(r);
      return;
    }
    final ids = <int>[];
    final suggested = <(YtResult, String)>[];
    try {
      for (final i in items) {
        final id =
            i.track?.id ?? (await _idOf(i.online!, seedTitle: i.seedTitle))!;
        ids.add(id);
        final seed = i.seedTitle;
        if (i.track == null && seed != null && isOnlineId(id)) {
          suggested.add((i.online!, seed));
        }
      }
    } on Object catch (e, st) {
      AppLog.w('mixed list not played', e, st);
      return;
    }
    final online = items.any((i) => i.online != null);
    await _start(
      ids,
      at,
      context,
      plus: online
          ? false
          : mode == null
          ? null
          : mode == ShuffleMode.plus && await plusBlock?.call(ids) == null,
      shuffle: shuffle,
      listKey: listKey,
    );
    // Logged once the list plays: a failed lookup must not spend the 30-day memory.
    for (final (r, seed) in suggested) {
      onSuggested?.call(r, seed);
    }
  }

  /// «Shuffle+ della libreria»: [ids] from a random one, shuffle on and
  /// Shuffle+ with it where the list allows it (D-137).
  Future<void> playShufflePlus(
    List<int> ids, {
    PlayContext? context,
    Object? listKey,
  }) async {
    if (ids.isEmpty || inJam) return;
    final block = await plusBlock?.call(ids);
    await _start(
      ids,
      _random.nextInt(ids.length),
      context,
      plus: block == null,
      shuffle: true,
      listKey: listKey,
    );
  }

  /// Plays the queue that ended again, from its first song, with its context;
  /// false when there is none (D-364). A failure is logged and still answers
  /// true: something was there to play, so the caller must not start another.
  Future<bool> resumeLastQueue() async {
    final ids = List.of(_handler.queueIds);
    if (ids.isEmpty) return false;
    if (inJam) return true; // the Jam queue is shared (D-89)
    try {
      final stations = [
        for (final i in ids) _handler.online?.radioOf(i)?.station,
      ];
      if (stations.every((s) => s != null)) {
        await playStations(
          [for (final s in stations) s!],
          0,
          context: _context,
        );
      } else {
        await _start(ids, 0, _context);
      }
    } on Object catch (e, st) {
      AppLog.w('last queue not resumed', e, st);
    }
    return true;
  }

  /// Plays a list of radio stations from [index]; next and previous move
  /// between them. Radio leaves no history and no statistics.
  Future<void> playStations(
    List<RadioStation> stations,
    int index, {
    PlayContext? context,
  }) async {
    if (stations.isEmpty) return;
    _stopSimilar();
    final ctx = context ?? const PlayContext(PlayContextKind.radio);
    _handler.setPlayContext(ctx.kind.index, ctx.name);
    _requestNotificationPermissionOnce();
    await _handler.playStations(stations, index);
  }

  /// The player's «Riprova» on a streamed track still without its row.
  Future<void> retryShadow() => _handler.retryShadow();

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
  QueueState? rebuildUpcoming() {
    _stopSimilar(); // the user emptied what follows: no refill
    return _handler.rebuildUpcoming();
  }

  bool get hasQueueSource => _handler.hasSource;
  void restoreQueue(QueueState state) => _handler.restoreQueue(state);

  Future<JamAddResult?> addToQueue(int trackId) async {
    if (inJam) return addToJam?.call([trackId]);
    _handler.addToQueue(trackId);
    return null;
  }

  /// The queue id of [r]: its library track when downloaded (D-81), else a
  /// new online entry; null without an online registry.
  /// With a [seedTitle] the entry is a Shuffle+ suggestion (badge, «mai più»).
  Future<int?> _idOf(YtResult r, {String? seedTitle}) async {
    final lib = await libraryIdOf?.call(r);
    if (lib != null) return lib;
    return _handler.online?.register(
      r,
      seedTitle: seedTitle,
      suggested: seedTitle != null,
    );
  }

  /// Plays [id] alone, with the search context (empty queue, or radio: no stations to insert among).
  Future<void> _playAlone(int id) =>
      _start([id], 0, const PlayContext(PlayContextKind.search));

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
    // Past the user block (insertAt would move it there anyway); the jump then keeps the block right after it.
    final at = _handler.currentIndex + 1 + _handler.userAhead;
    _handler.insertAt(at, id);
    await _handler.skipToQueueItem(at);
  }

  /// A pick in Search (D-429): [track] (library) or [online] plays at once,
  /// alone; then the songs similar to it follow, from the radio, library and
  /// online mixed, and keep coming while it plays (D-467). The old queue is
  /// dropped. In a Jam it only joins the shared queue. True when similar
  /// songs came; false: only the pick plays; null: nothing to tell (no song
  /// to play, or another pick or queue took over meanwhile).
  Future<bool?> playFromSearch({Track? track, YtResult? online}) async {
    if (inJam) {
      if (track != null) await addToJam?.call([track.id]);
      if (online != null) _onlineToJam(online);
      return false;
    }
    final id = track?.id ?? await _idOrLog(online!);
    if (id == null) return null;
    // Not awaited: a stream may take minutes to load and the radio need not wait.
    unawaited(
      _start(
        [id],
        0,
        const PlayContext(PlayContextKind.search),
        shuffle: false,
      ).catchError(
        (Object e, StackTrace st) => AppLog.w('search pick not played', e, st),
      ),
    );
    final epoch = _epoch; // after _start, which ended the old session
    final seed = track != null
        ? RadioSeed(track)
        : RadioSeed.online(online!.id, online.title);
    _setSimilar(seed.title, loading: true);
    try {
      final fill = await similarFill?.call(seed);
      if (epoch != _epoch) return null;
      if (fill == null || inJam) {
        _setSimilar(null);
        return false;
      }
      final session = _similar = SimilarQueue(
        handler: _handler,
        fill: fill,
        seedId: id,
        seedVideoId: online?.id,
        register: (r, seedTitle) => _similarId(r, seedTitle),
        onSuggested: (r, t) => onSuggested?.call(r, t),
        onClosed: () {
          if (epoch != _epoch) return; // stopped from outside: already reset
          _similar = null;
          _setSimilar(null);
        },
        blocked: () => inJam,
        retryAfter: similarRetryAfter,
        now: similarNow,
        schedule: similarSchedule,
      );
      final found = await session.start();
      if (epoch != _epoch) return null;
      if (found) _setSimilar(seed.title);
      return found;
    } on Object catch (e, st) {
      AppLog.w('similar songs not queued', e, st);
      if (epoch != _epoch) return null;
      _stopSimilar();
      return false;
    }
  }

  /// The queue id of a similar song: its library track (a download, or the
  /// same song by title and artist), else a new online entry.
  Future<int?> _similarId(YtResult r, String seedTitle) async {
    final lib = await libraryIdOf?.call(r) ?? await libraryMatchIdOf?.call(r);
    return lib ??
        _handler.online?.register(r, seedTitle: seedTitle, suggested: true);
  }

  /// In a Jam: before any id lookup (library and negative ids mean nothing to guests); returns once accepted.
  void _onlineToJam(YtResult r) {
    if (addOnlineToJam?.call(r) != true) {
      AppLog.w('jam: ${r.indexKey} not accepted');
    }
  }

  Future<void> enqueueOnline(YtResult r) async {
    if (inJam) return _onlineToJam(r);
    final id = await _idOrLog(r);
    if (id == null) return;
    if (_handler.isRadio) return _playAlone(id);
    _handler.addToQueue(id);
  }

  /// Plays [list] in order; [shuffle] turns plain shuffle on (else off), never Shuffle+ (R-18).
  /// [listKey]: the page's own mode decides instead (D-534).
  Future<void> playOnlineList(
    List<YtResult> list, {
    bool shuffle = false,
    Object? listKey,
  }) async {
    if (list.isEmpty) return;
    if (inJam) return list.forEach(_onlineToJam);
    await playMixed(
      [for (final r in list) (track: null, online: r, seedTitle: null)],
      index: listKey == null ? (shuffle ? _random.nextInt(list.length) : 0) : null,
      context: const PlayContext(PlayContextKind.search),
      shuffle: listKey == null ? shuffle : null,
      listKey: listKey,
    );
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

  /// The «Casuale» control of the list page [key] (D-534): the list playing
  /// takes it like the player's button; any other list only changes the mode
  /// its next Play applies. [plus] false: off and shuffle only (online lists).
  Future<ShufflePlusBlock?> cycleListShuffle(
    Object key, {
    List<int>? ids,
    bool plus = true,
  }) async {
    if (isPlayingList(key)) {
      if (plus) return cycleShuffle(ids: ids);
      await toggleShuffle();
      return null;
    }
    final mode = listMode?.call(key) ?? ShuffleMode.off;
    ShufflePlusBlock? block;
    final next = switch (mode) {
      ShuffleMode.off => ShuffleMode.shuffle,
      ShuffleMode.shuffle when plus =>
        (block = await plusBlock?.call(ids)) == null
            ? ShuffleMode.plus
            : ShuffleMode.off,
      _ => ShuffleMode.off,
    };
    setListMode?.call(key, next);
    return block;
  }

  /// The shuffle button: off, shuffle, Shuffle+, off. Returns why it skipped
  /// Shuffle+ (then: off, shuffle, off), else null.
  /// [ids]: the list this button plays (D-137); null: the current queue.
  Future<ShufflePlusBlock?> cycleShuffle({List<int>? ids}) {
    // Serialized: a second tap reads the state the first one left.
    final run = _cycle.then((_) => _cycleShuffle(ids));
    _cycle = run.then<void>(
      (_) {},
      onError: (Object e) {
        AppLog.w('shuffle cycle failed', e);
      },
    );
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
    unawaited(
      Permission.notification.request().then<void>(
        (_) {},
        onError: (Object e) {
          AppLog.d('notification permission not asked', e);
        },
      ),
    );
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
      // A list of its own is not the radio queue, whatever the context says.
      radio:
          ids == null &&
          ref.read(playContextProvider)?.kind == PlayContextKind.radio,
      localCount: local.where((t) => !t.missing && t.kind == 0).length,
    );
  } on Object catch (e, st) {
    AppLog.w('shuffle+ allowed check failed', e, st);
    return null;
  }
}

/// What the cards of a streamed track wait for: its row, or nothing now.
enum ShadowWait { waiting, unavailable }

/// Past this the preparer's word is not enough: a job still queued or
/// downloading counts as stuck (it exposes no download progress). 60 s in all,
/// the first 20 s waited by `StreamCardsWait` before it first watches this.
const shadowWaitCap = Duration(seconds: 40);

/// Whether the cards of the streamed queue [id] still wait for their row: emits
/// now and on each phase change; unavailable once the job failed, is unknown,
/// or [shadowWaitCap] passed since first watched (autoDispose: it restarts then).
final shadowWaitProvider = StreamProvider.autoDispose.family<ShadowWait, int>((
  ref,
  id,
) {
  final h = ref.watch(audioHandlerProvider);
  final phases = h.preparer?.phases;
  final key = h.online?.entryOf(id)?.result.indexKey;
  final c = StreamController<ShadowWait>();
  var capped = false;
  void emit() {
    final phase = phases?.value[key];
    c.add(
      capped || phase == null || phase == StreamPhase.failed
          ? ShadowWait.unavailable
          : ShadowWait.waiting,
    );
  }

  phases?.addListener(emit);
  final cap = Timer(shadowWaitCap, () {
    capped = true;
    emit();
  });
  ref.onDispose(() {
    phases?.removeListener(emit);
    cap.cancel();
    c.close();
  });
  emit();
  return c.stream;
});

final playerControllerProvider = Provider<PlayerController>((ref) {
  final c = PlayerController(
    ref.watch(audioHandlerProvider),
    ref.watch(playbackPersistenceProvider),
    shufflePlus: () => ref.read(settingsProvider).shufflePlus,
    setShufflePlus: (on) => ref
        .read(settingsProvider.notifier)
        .update((c) => c.copyWith(shufflePlus: on)),
    jamActive: () => ref.read(jamProvider).active,
    addToJam: ref.read(jamProvider.notifier).addLibraryIds,
    jamQueueFullNow: () => ref.read(jamProvider.notifier).queueFull,
    addOnlineToJam: (r) => ref.read(jamProvider.notifier).addOnline(r),
    plusBlock: (ids) => plusAllowedNow(ref, ids: ids),
    listMode: (key) => ref.read(listShuffleProvider(key)),
    setListMode: (key, m) => ref.read(listShuffleProvider(key).notifier).set(m),
    onSuggested: (r, seed) =>
        ref.read(suggestionLogProvider).addSuggestion(r, seed),
    similarFill: ref.read(similarFillProvider),
    libraryMatchIdOf: ref.read(libraryMatchIdProvider),
    libraryIdOf: (r) async {
      final path = (await ref.read(downloadIndexProvider.future))
          .pathFor(r.id, source: r.source);
      return path == null
          ? null
          : ref.read(trackRepositoryProvider).idForPath(path);
    },
  );
  ref.onDispose(c.dispose);
  return c;
});

/// The song whose similar songs fill the queue, and whether the first block
/// is still on its way; null when no such session runs.
final similarSeedProvider = Provider<({String title, bool loading})?>((ref) {
  final c = ref.watch(playerControllerProvider);
  void changed() => ref.invalidateSelf();
  c.similarTitle.addListener(changed);
  c.similarLoading.addListener(changed);
  ref.onDispose(() {
    c.similarTitle.removeListener(changed);
    c.similarLoading.removeListener(changed);
  });
  final t = c.similarTitle.value;
  return t == null ? null : (title: t, loading: c.similarLoading.value);
});

/// The queue that ended and stays in the player, for the empty states (D-364):
/// null when there is none. Read again whenever the current track changes.
final lastQueueProvider = FutureProvider.autoDispose<LastQueue?>((ref) async {
  ref.watch(currentTrackProvider);
  final h = ref.watch(audioHandlerProvider);
  final ids = h.queueIds;
  if (ids.isEmpty) return null;
  final first = await queueTracks(
    [ids.first],
    ref.watch(trackRepositoryProvider),
    h.online,
  );
  return first.isEmpty ? null : (count: ids.length, first: first.first);
});

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
  final sub = entries.bound
      .where((i) => i == id)
      .listen((_) => out.add(entries.entryOf(id)?.trackId));
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
  final rowId = id == null
      ? null
      : ref.watch(onlineEntriesProvider)?.entryOf(id)?.trackId;
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

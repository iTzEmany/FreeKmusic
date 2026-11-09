import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/constants.dart';
import '../core/paths.dart';
import '../data/repositories/track_genre_repository.dart';
import '../services/daylist/daylist_builder.dart';
import '../services/daylist/daylist_slots.dart';
import '../services/daylist/daylist_store.dart';
import '../services/daylist/mood_table.dart';
import '../services/online/youtube_service.dart' show YtErrorKind, YtException;
import '../services/shuffle_plus/dislike_store.dart';
import '../services/shuffle_plus/radio_fill.dart';
import '../services/shuffle_plus/suggestion_pool.dart'
    show RadioSeed, SuggestionCandidate, inLibraryTest, suggestionArtistKey;
import 'dislike_store_provider.dart';
import 'history_providers.dart' show statsQueriesProvider;
import 'jam_providers.dart';
import 'library_providers.dart' show libraryIndexProvider;
import 'player_providers.dart';
import 'seed_resolver_provider.dart';
import 'settings_providers.dart';
import 'shuffle_plus_providers.dart';
import 'database_providers.dart';
import 'youtube_providers.dart';

/// The slots the user set (D-433, D-443), read from and written to the
/// settings. Slot names and the hours are the UI's to show.
class DaylistConfigNotifier extends Notifier<DaylistConfig> {
  @override
  DaylistConfig build() => ref.read(settingsStoreProvider).readDaylistConfig();

  Future<void> _set(DaylistConfig c) async {
    state = c;
    await ref.read(settingsStoreProvider).writeDaylistConfig(c);
  }

  Future<void> setSlot(int i, DaylistSlot slot) =>
      _set(state.withSlot(i, slot));

  /// Moves the start of slot [i]; false (nothing changes) when [hour] would
  /// leave a slot shorter than 1 h.
  Future<bool> setStart(int i, int hour) async {
    final c = state.withStart(i, hour);
    if (c == null) return false;
    await _set(c);
    return true;
  }

  Future<void> reset() async {
    state = DaylistConfig.defaults();
    await ref.read(settingsStoreProvider).resetDaylistSlots();
  }
}

final daylistConfigProvider =
    NotifierProvider<DaylistConfigNotifier, DaylistConfig>(
      DaylistConfigNotifier.new,
    );

/// The genre -> mood table with the user's changes (D-439).
class MoodTableNotifier extends Notifier<MoodTable> {
  @override
  MoodTable build() => ref.read(settingsStoreProvider).readMoodTable();

  Future<void> _set(MoodTable t) async {
    state = t;
    await ref.read(settingsStoreProvider).writeMoodTable(t);
  }

  Future<void> setMoods(String genre, Set<Mood> moods) =>
      _set(state.withMoods(genre, moods));

  Future<void> reset() async {
    state = MoodTable.defaults();
    await ref.read(settingsStoreProvider).resetMoodTable();
  }
}

final moodTableProvider = NotifierProvider<MoodTableNotifier, MoodTable>(
  MoodTableNotifier.new,
);

/// The clock of the daylist (a test sets it).
final daylistClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// `daylist.json` in the data folder (a test points it elsewhere).
final daylistFileProvider = Provider<Future<File> Function()>(
  (_) =>
      () async => File(p.join(await appSupportDir(), daylistFileName)),
);

/// How long a change of the settings waits before the daylist is made again,
/// so a few taps on a slot make one build, not one each (a test sets zero).
final daylistSettleProvider = Provider<Duration>(
  (_) => const Duration(seconds: 2),
);

/// How far back the listens of a slot are looked at.
const daylistHistory = Duration(days: 90);

/// The suggestions of the daylist, or null when the radio must not be asked
/// (the same rules as the genre mix: Jam, no yt-dlp, offline, metered with
/// «Solo su Wi-Fi», a 429 pause). [cancelled] stops the requests when the
/// daylist is made again meanwhile. A test overrides this.///
/// Unless [force] (the user asked for a new daylist) it asks only when the
/// [RadioGate] allows a request now, so a build set off by the app itself
/// never goes against the minute between requests.
final daylistSuggestProvider =
    Provider<
      Future<DaylistSuggest?> Function(bool Function() cancelled, {bool force})
    >((ref) {
      return (cancelled, {force = false}) async {
        if (!kEnableYoutube) return null;
        final gate = ref.read(radioGateProvider);
        if (!force && !gate.canAsk) return null;
        final off = await radioOffReason(
          jam: ref.read(jamProvider).active,
          toolVersion: ref
              .read(ytDlpStatusProvider.future)
              .then((s) => s.version),
          probe: ref.read(networkProbeProvider),
          unmeteredOnly: ref.read(shufflePlusConfigProvider).unmeteredOnly,
          gate: gate,
        );
        if (off != null) return null;
        final log = ref.read(suggestionLogProvider);
        final filter = ref.read(suggestionGateProvider);
        final radio = ref.read(ytmRadioServiceProvider);
        await log.load();
        await filter.load();
        final resolver = await ref.read(seedResolverProvider.future);
        final downloads = await ref.read(downloadIndexProvider.future);
        final library = await ref.read(libraryIndexProvider.future);
        return (seeds, want, accept, inQueue) async* {
          final fill = RadioFill(
            seeds: [for (final s in seeds) RadioSeed(s)],
            resolver: resolver,
            radioPage: radio.page,
            log: log,
            filter: filter,
            gate: gate,
            inLibrary: inLibraryTest(
              hasDownload: downloads.contains,
              library: library,
            ),
          );
          try {
            yield* fill.take(
              want,
              inQueue: inQueue,
              accept: accept,
              cancelled: cancelled,
            );
          } on YtException catch (e) {
            if (e.kind == YtErrorKind.rateLimited) gate.trip();
            rethrow; // the builder logs it and keeps what it has
          }
        };
      };
    });

/// The daylist of the slot the clock is in (D-433).
class DaylistState {
  const DaylistState({
    required this.result,
    required this.slot,
    required this.slotIndex,
    required this.nextChange,
  });

  /// [DaylistResult.tooFew]: no card, no daylist (D-473).
  final DaylistResult result;
  final DaylistSlot slot;
  final int slotIndex;

  /// When the next slot starts, and the daylist changes.
  final DateTime nextChange;
}

/// What of the settings makes the daylist of slot [i]: the slot as set (start,
/// quota, genres, moods) and where it ends.
String _slotKey(DaylistConfig c, int i) =>
    '$i|${jsonEncode(c.slots[i].toJson())}|${c.slots[(i + 1) % DaylistConfig.slotCount].startHour}';

/// The current daylist; null when the slot is switched off. The reads run in
/// the DB isolate and the ranking in a worker isolate (`planInIsolate`); only
/// the suggestions and the final pick run here. It is saved until the slot
/// ends (D-474), made again when the slot changes (timer; on resume if the
/// timer did not fire while suspended; at start if it changed while the app
/// was closed) and, after a short wait, when the slots or the mood table
/// change. The queue that is playing is never touched.
class DaylistNotifier extends AsyncNotifier<DaylistState?> {
  bool _force = false;
  String? _lastKey;

  /// Throws the saved daylist away and makes a new one now (the user asked:
  /// the radio is asked even inside the minute between requests).
  Future<void> regenerate() async {
    await DaylistStore(ref.read(daylistFileProvider)).clear();
    _force = true;
    ref.invalidateSelf();
  }

  @override
  Future<DaylistState?> build() async {
    // This build's ref: `mounted` turns false when the daylist is made again.
    final r = ref;
    final clock = r.read(daylistClockProvider);
    final force = _force;
    _force = false;
    final now = clock();
    final config = r.read(daylistConfigProvider);
    final index = config.slotAt(now);
    // Only this slot (and where it ends) rebuilds the daylist: touching
    // another one leaves it alone.
    final slotKey = r.watch(
      daylistConfigProvider.select((c) => _slotKey(c, c.slotAt(now))),
    );
    final moods = r.watch(moodTableProvider);
    final next = config.nextChange(now);
    final timer = Timer(next.difference(now), r.invalidateSelf);
    r.onDispose(timer.cancel);
    // A suspended app may not have run the timer: check at every resume.
    final life = AppLifecycleListener(
      onResume: () {
        if (r.mounted && !clock().isBefore(next)) r.invalidateSelf();
      },
    );
    r.onDispose(life.dispose);
    final slot = config.slots[index];
    if (!slot.enabled) return null;
    DaylistState of(DaylistResult res) => DaylistState(
      result: res,
      slot: slot,
      slotIndex: index,
      nextChange: next,
    );

    final key = '$slotKey|${moods.toJsonString()}';
    if (_lastKey != null && _lastKey != key) {
      await Future<void>.delayed(r.read(daylistSettleProvider));
      if (!r.mounted) return null;
    }
    _lastKey = key;

    final store = DaylistStore(r.read(daylistFileProvider));
    final tracks = r.read(trackRepositoryProvider);
    final stats = r.read(statsQueriesProvider);
    final db = r.read(databaseProvider);
    final saved = await store.load(
      key: key,
      until: next,
      tracksOf: tracks.getByIdsLight,
    );
    if (saved != null) return of(saved);

    final library = await tracks.musicLight();
    final plays = await stats.listensSince(now.subtract(daylistHistory));
    final genres = await TrackGenreRepository(db).musicGenres();
    final plan = await DaylistBuilder.planInIsolate(
      config: config,
      moods: moods,
      now: now,
      randomSeed: Random().nextInt(1 << 30),
      library: library,
      plays: plays,
      genresOf: genres,
    );
    DaylistSuggest? suggest;
    if (r.mounted) {
      try {
        suggest = await r.read(daylistSuggestProvider)(
          () => !r.mounted,
          force: force,
        );
      } on Object catch (e, st) {
        // Never an error for this: the daylist is made of the user's songs.
        AppLog.w('daylist suggestions not available', e, st);
      }
    }
    final result = await DaylistBuilder().finish(plan, suggest: suggest);
    // Not saved without the network when suggestions are wanted: the next
    // start tries again.
    final partial = suggest == null && slot.sharePercent > 0;
    if (r.mounted && !result.tooFew && !partial) {
      await store.save(key: key, until: next, result: result);
    }
    return of(result);
  }
}

final daylistProvider = AsyncNotifierProvider<DaylistNotifier, DaylistState?>(
  DaylistNotifier.new,
);

/// Ticks at every change of the «Non mi piace» lists, once they are loaded.
final _dislikeTickProvider = StreamProvider<int>((ref) async* {
  final store = ref.watch(dislikeStoreProvider);
  await store.load();
  var n = 0;
  yield n;
  await for (final _ in store.changes) {
    yield ++n;
  }
});

/// [d] without the suggested songs blocked now (a «Non mi piace» after it was
/// made or saved). The one list the screen, the card and Play all use, so
/// rows, count and indexes agree; the saved daylist itself is not touched.
DaylistState withoutBlocked(DaylistState d, DislikeStore store) {
  bool blocked(SuggestionCandidate c) =>
      store.trackBlocked(c.result.id) ||
      store.artistBlocked(suggestionArtistKey(c.result));
  final items = [
    for (final i in d.result.items)
      if (i.suggestion == null || !blocked(i.suggestion!)) i,
  ];
  if (items.length == d.result.items.length) return d;
  final r = d.result;
  return DaylistState(
    result: DaylistResult(
      slotIndex: r.slotIndex,
      items: items,
      genres: r.genres,
      tooFew: r.tooFew,
      off: r.off,
    ),
    slot: d.slot,
    slotIndex: d.slotIndex,
    nextChange: d.nextChange,
  );
}

/// The daylist to show and play: [daylistProvider] minus the blocked songs.
final daylistVisibleProvider = Provider<DaylistState?>((ref) {
  final d = ref.watch(daylistProvider).value;
  ref.watch(_dislikeTickProvider);
  return d == null ? null : withoutBlocked(d, ref.watch(dislikeStoreProvider));
});

/// What the card and the daylist screen do.
class DaylistActions {
  DaylistActions(this._ref);

  final Ref _ref;

  /// Starts the daylist's queue: the user's songs and the suggested ones as
  /// online entries marked «Suggerito», as the genre page does. [shuffle]
  /// starts from a random song with shuffle on; [startIndex] (a row of the
  /// daylist) from that song. Suggested songs blocked since the daylist was
  /// made (or saved) are left out.
  Future<void> play({bool shuffle = false, int? startIndex}) async {
    DaylistState? s;
    try {
      // A slot that has just changed but is not made yet is waited for.
      final cur = _ref.read(daylistProvider).value;
      if (cur != null &&
          !_ref.read(daylistClockProvider)().isBefore(cur.nextChange)) {
        _ref.invalidate(daylistProvider);
      }
      s = await _ref.read(daylistProvider.future);
    } on Object catch (e, st) {
      AppLog.w('daylist not ready to play', e, st);
      return;
    }
    final r = s?.result;
    if (r == null || r.tooFew || r.items.isEmpty) return;
    final store = _ref.read(dislikeStoreProvider);
    await store.load();
    // [startIndex] is a row of the visible list, the same one built here.
    final items = [
      for (final i in withoutBlocked(s!, store).result.items)
        (
          track: i.track,
          online: i.suggestion?.result,
          seedTitle: i.suggestion?.seedTitle,
        ),
    ];
    if (items.isEmpty) return;
    final at = startIndex ?? 0;
    await _ref
        .read(playerControllerProvider)
        .playMixed(
          items,
          index: startIndex != null
              ? at.clamp(0, items.length - 1)
              : (shuffle ? Random().nextInt(items.length) : 0),
          context: const PlayContext(PlayContextKind.library),
          shuffle: shuffle,
        );
  }

  Future<void> regenerate() => _ref.read(daylistProvider.notifier).regenerate();
}

final daylistActionsProvider = Provider<DaylistActions>(DaylistActions.new);

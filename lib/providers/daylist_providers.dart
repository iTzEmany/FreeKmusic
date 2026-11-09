import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/constants.dart';
import '../core/paths.dart';
import '../data/repositories/track_genre_repository.dart';
import '../services/daylist/daylist_builder.dart';
import '../services/daylist/daylist_slots.dart';
import '../services/daylist/daylist_store.dart';
import '../services/daylist/mood_table.dart';
import '../services/online/youtube_service.dart' show YtErrorKind, YtException;
import '../services/shuffle_plus/radio_fill.dart';
import '../services/shuffle_plus/suggestion_pool.dart' show RadioSeed, inLibraryTest;
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

  Future<void> setSlot(int i, DaylistSlot slot) => _set(state.withSlot(i, slot));

  /// Moves the start of slot [i]; false (nothing changes) when [hour] would
  /// leave a slot shorter than 1 h.
  Future<bool> setStart(int i, int hour) async {
    final c = state.withStart(i, hour);
    if (c == null) return false;
    await _set(c);
    return true;
  }

  Future<void> reset() => _set(DaylistConfig.defaults());
}

final daylistConfigProvider = NotifierProvider<DaylistConfigNotifier, DaylistConfig>(DaylistConfigNotifier.new);

/// The genre -> mood table with the user's changes (D-439).
class MoodTableNotifier extends Notifier<MoodTable> {
  @override
  MoodTable build() => ref.read(settingsStoreProvider).readMoodTable();

  Future<void> _set(MoodTable t) async {
    state = t;
    await ref.read(settingsStoreProvider).writeMoodTable(t);
  }

  Future<void> setMoods(String genre, Set<Mood> moods) => _set(state.withMoods(genre, moods));

  Future<void> reset() => _set(MoodTable.defaults());
}

final moodTableProvider = NotifierProvider<MoodTableNotifier, MoodTable>(MoodTableNotifier.new);

/// The clock of the daylist (a test sets it).
final daylistClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// `daylist.json` in the data folder (a test points it elsewhere).
final daylistFileProvider = Provider<Future<File> Function()>(
  (_) => () async => File(p.join(await appSupportDir(), 'daylist.json')),
);

/// How far back the listens of a slot are looked at.
const daylistHistory = Duration(days: 90);

/// The suggestions of the daylist, or null when the radio must not be asked
/// (the same rules as the genre mix: Jam, no yt-dlp, offline, metered with
/// «Solo su Wi-Fi», a 429 pause). [cancelled] stops the requests when the
/// daylist is made again meanwhile. A test overrides this.
final daylistSuggestProvider = Provider<Future<DaylistSuggest?> Function(bool Function() cancelled)>((ref) {
  return (cancelled) async {
    if (!kEnableYoutube) return null;
    final gate = ref.read(radioGateProvider);
    final off = await radioOffReason(
      jam: ref.read(jamProvider).active,
      toolVersion: ref.read(ytDlpStatusProvider.future).then((s) => s.version),
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
        inLibrary: inLibraryTest(hasDownload: downloads.contains, library: library),
      );
      try {
        yield* fill.take(want, inQueue: inQueue, accept: accept, cancelled: cancelled);
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

/// The current daylist; null when the slot is switched off. It is made off
/// the UI thread (the database reads run in the DB isolate; the builder only
/// sorts a library's worth of rows), saved until the slot ends (D-474), made
/// again when the slot changes (timer, or at start if it changed while the app
/// was closed) and when the slots or the mood table change. The queue that is
/// playing is never touched.
class DaylistNotifier extends AsyncNotifier<DaylistState?> {
  @override
  Future<DaylistState?> build() async {
    final config = ref.watch(daylistConfigProvider);
    final moods = ref.watch(moodTableProvider);
    final now = ref.read(daylistClockProvider)();
    final index = config.slotAt(now);
    final next = config.nextChange(now);
    final timer = Timer(next.difference(now), ref.invalidateSelf);
    ref.onDispose(timer.cancel);
    final slot = config.slots[index];
    if (!slot.enabled) return null;
    DaylistState of(DaylistResult r) =>
        DaylistState(result: r, slot: slot, slotIndex: index, nextChange: next);

    final store = DaylistStore(ref.read(daylistFileProvider));
    final tracks = ref.read(trackRepositoryProvider);
    final key = '${config.toJsonString()}|${moods.toJsonString()}';
    final saved = await store.load(key: key, until: next, tracksOf: tracks.getByIdsLight);
    if (saved != null) return of(saved);

    final library = await tracks.watchTracks().first;
    final plays = await ref.read(statsQueriesProvider).listensSince(now.subtract(daylistHistory));
    final genres = await TrackGenreRepository(ref.read(databaseProvider)).allByTrack();
    final suggest = await ref.read(daylistSuggestProvider)(() => !ref.mounted);
    final result = await DaylistBuilder().build(DaylistInputs(
      config: config,
      moods: moods,
      now: () => now,
      random: Random(),
      library: library,
      plays: plays,
      genresOf: genres,
      suggest: suggest,
    ));
    if (ref.mounted && !result.tooFew) await store.save(key: key, until: next, result: result);
    return of(result);
  }
}

final daylistProvider = AsyncNotifierProvider<DaylistNotifier, DaylistState?>(DaylistNotifier.new);

/// What the card and the daylist screen do.
class DaylistActions {
  DaylistActions(this._ref);

  final Ref _ref;

  /// Starts the daylist's queue: the user's songs and the suggested ones as
  /// online entries marked «Suggerito», as the genre page does. [shuffle]
  /// starts from a random song with shuffle on.
  Future<void> play({bool shuffle = false}) async {
    final r = _ref.read(daylistProvider).value?.result;
    if (r == null || r.tooFew || r.items.isEmpty) return;
    final items = <MixItem>[
      for (final i in r.items)
        (track: i.track, online: i.suggestion?.result, seedTitle: i.suggestion?.seedTitle),
    ];
    await _ref.read(playerControllerProvider).playMixed(
      items,
      index: shuffle ? Random().nextInt(items.length) : 0,
      context: const PlayContext(PlayContextKind.library),
      shuffle: shuffle,
    );
  }

  /// Throws the saved daylist away and makes a new one now.
  Future<void> regenerate() async {
    await DaylistStore(_ref.read(daylistFileProvider)).clear();
    _ref.invalidate(daylistProvider);
  }
}

final daylistActionsProvider = Provider<DaylistActions>(DaylistActions.new);

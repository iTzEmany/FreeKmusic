import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/constants.dart';
import '../core/network_kind.dart';
import '../data/settings/settings_store.dart';
import '../services/audio/codecore_audio_handler.dart';
import '../services/import/track_matcher.dart';
import '../services/online/merge_results.dart' show libraryMatchOf;
import '../services/online/youtube_service.dart' show YtResult;
import '../services/online/ytm_radio_service.dart';
import '../services/shuffle_plus/plus_allowed.dart' show ShufflePlusBlock;
import '../services/shuffle_plus/genre_mix.dart';
import '../services/shuffle_plus/radio_fill.dart';
import '../services/shuffle_plus/radio_gate.dart';
import '../services/shuffle_plus/suggestion_pool.dart' show RadioSeed;
import '../services/shuffle_plus/shuffle_host.dart';
import '../services/stream/stream_preparer.dart' show StreamPhase;
import '../services/shuffle_plus/shuffle_plus_controller.dart';
import 'database_providers.dart';
import 'library_providers.dart' show genreTracksProvider, libraryIndexProvider;
import 'jam_providers.dart';
import 'seed_resolver_provider.dart';
import 'dislike_store_provider.dart';
import 'suggestion_log_provider.dart';
import 'player_providers.dart';
import 'settings_providers.dart';
import 'stream_providers.dart';
import 'youtube_providers.dart';

export '../services/shuffle_plus/plus_allowed.dart' show ShufflePlusBlock;
export 'seed_resolver_provider.dart' show seedIndexProvider;
export 'suggestion_log_provider.dart' show suggestionLogProvider;

/// The user's Shuffle+ choices, read from the settings. [set] is for tests.
class ShufflePlusConfigNotifier extends Notifier<ShufflePlusConfig> {
  @override
  ShufflePlusConfig build() {
    ref.listen(settingsProvider, (_, s) => state = _of(s));
    // Shuffle turned off from anywhere (notification, MPRIS, the button)
    // takes the «+» with it.
    ref.listen(shuffleProvider, (prev, next) {
      if (prev?.value == true &&
          next.value == false &&
          ref.read(settingsProvider).shufflePlus) {
        ref
            .read(settingsProvider.notifier)
            .update((c) => c.copyWith(shufflePlus: false));
      }
    });
    return _of(ref.read(settingsProvider));
  }

  static ShufflePlusConfig _of(AppSettings s) => ShufflePlusConfig(
    enabled: s.shufflePlus,
    every: s.shufflePlusEvery,
    unmeteredOnly: s.shufflePlusUnmeteredOnly,
  );

  void set(ShufflePlusConfig c) => state = c;
}

final shufflePlusConfigProvider =
    NotifierProvider<ShufflePlusConfigNotifier, ShufflePlusConfig>(
      ShufflePlusConfigNotifier.new,
    );

/// The Android `codecore/net` channel (desktop: never metered, always online).
final networkProbeProvider = Provider<NetworkProbe>((ref) {
  final probe = NetworkProbe()..listen();
  ref.onDispose(probe.dispose);
  return probe;
});

/// Whether Shuffle+ must stay off the network: metered, or no network at all.
final shufflePlusMeteredProvider = Provider<Future<bool> Function()>((ref) {
  final probe = ref.watch(networkProbeProvider);
  return () async {
    final k = await probe.current();
    return k.metered || !k.online;
  };
});

final ytmRadioServiceProvider = Provider<YtmRadioService>(
  (ref) => YtmRadioService(
    ref.watch(innerTubeClientProvider),
    ref.watch(ytDlpServiceProvider),
  ),
);

/// One request gap and one 429 pause for every radio user: Shuffle+ and the
/// genre mix.
final radioGateProvider = Provider<RadioGate>((ref) => RadioGate());

/// The handler seen by the engine.
class HandlerShuffleHost implements ShuffleHost {
  HandlerShuffleHost(this._h);

  final CodecoreAudioHandler _h;

  @override
  List<int> get queueIds => _h.queueIds;
  @override
  int get currentIndex => _h.currentIndex;
  @override
  List<int>? get sourceIds => _h.sourceIds;
  @override
  bool get shuffleEnabled => _h.shuffleEnabled;
  @override
  bool get isPlaying => _h.isPlaying;

  @override
  Stream<void> get changes {
    final c = StreamController<void>.broadcast();
    final subs = <StreamSubscription<Object?>>[];
    c.onListen = () {
      subs
        ..add(_h.queueChanges.listen((_) => c.add(null)))
        ..add(_h.currentTrackStream.listen((_) => c.add(null)))
        ..add(
          _h.playbackState
              .map((s) => (s.playing, s.shuffleMode))
              .distinct()
              .listen((_) => c.add(null)),
        );
    };
    c.onCancel = () {
      for (final s in subs) {
        unawaited(s.cancel());
      }
    };
    return c.stream;
  }

  @override
  Stream<Duration> get positionStream => _h.positionStream;
  @override
  Stream<Duration?> get durationStream => _h.durationStream;

  @override
  Stream<PlaybackFailure> get failures => _failures;
  Stream<PlaybackFailure> _failures = const Stream.empty();

  /// Failures come from the handler's `onError`, which `main` routes to
  /// [playerErrorsProvider].
  void listenFailures(Stream<PlaybackFailure> s) => _failures = s;

  @override
  void insertAt(int index, int id) => _h.insertAt(index, id);
  @override
  Future<void> removeQueueId(int id) => _h.removeQueueId(id);
}

/// A suggestion is queued as soon as its stream address is known (D-352);
/// the preparer goes on with the file in the background.
final shufflePlusPrepareProvider = Provider<Future<void> Function(YtResult)>(
  (ref) =>
      (r) => ref.read(streamPreparerProvider).start(r.indexKey, r, keep: false),
);

/// Enriches queued suggestions (D-353): each one as soon as its file has made
/// the shadow row (nothing binds the row to the entry before the entry loads,
/// so it is read by key). Entries forgotten meanwhile and downloads that
/// failed are skipped; no entry waits longer than the given time. The wait
/// outlives the block's own time limit, so a slow file is still enriched.
final shufflePlusEnrichProvider =
    Provider<Future<void> Function(List<int>, Duration)>((ref) {
      Future<void> one(int id, Duration within) async {
        final online = ref.read(onlineEntriesProvider);
        final preparer = ref.read(streamPreparerProvider);
        final tracks = ref.read(trackRepositoryProvider);
        final end = DateTime.now().add(within);
        for (var e = online?.entryOf(id); e != null; e = online?.entryOf(id)) {
          final key = e.result.indexKey;
          final row = await tracks.streamRow(key);
          if (row != null) {
            AppLog.i('shuffle+ enrich of $id row=${row.id}');
            return ref.read(streamEnrichRowProvider)(row.id);
          }
          if (preparer.phases.value[key] == StreamPhase.failed) {
            AppLog.w('shuffle+ enrich of $id: the download failed');
            return;
          }
          if (!DateTime.now().isBefore(end)) {
            AppLog.w('shuffle+ enrich of $id: no file in time');
            return;
          }
          final next = Completer<void>();
          void wake() {
            if (!next.isCompleted) next.complete();
          }

          try {
            preparer.phases.addListener(wake);
          } on Object catch (err) {
            AppLog.w(
              'shuffle+ enrich of $id: the preparer is gone',
              err,
            ); // a rebuilt preparer
            return;
          }
          try {
            // Re-check after listening: the row may have landed meanwhile.
            if (await tracks.streamRow(key) == null) {
              // A short wake-up too: a forgotten entry changes no phase.
              final left = end.difference(DateTime.now());
              await next.future.timeout(
                left < const Duration(seconds: 1)
                    ? left
                    : const Duration(seconds: 1),
                onTimeout: () {},
              );
            }
          } finally {
            preparer.phases.removeListener(wake);
          }
        }
      }

      return (ids, within) => Future.wait([
        for (final id in ids)
          one(id, within).catchError(
            (Object e, StackTrace st) =>
                AppLog.w('shuffle+ enrich of $id failed', e, st),
          ),
      ]);
    });

/// The Shuffle+ engine, started the first time it is read (the shell reads it
/// in 31.12). Null when the player has no online registry (tests).
final shufflePlusProvider = FutureProvider<ShufflePlusController?>((ref) async {
  final handler = ref.watch(audioHandlerProvider);
  final online = handler.online;
  if (online == null) return null;
  final downloads = await ref.watch(downloadIndexProvider.future);
  final tracks = ref.watch(trackRepositoryProvider);
  final host = HandlerShuffleHost(handler)
    ..listenFailures(ref.watch(playerErrorsProvider));
  final controller = ShufflePlusController(
    host: host,
    online: online,
    log: ref.watch(suggestionLogProvider),
    filter: ref.watch(suggestionGateProvider),
    resolver: await ref.watch(seedResolverProvider.future),
    radio: ref.watch(ytmRadioServiceProvider),
    gate: ref.watch(radioGateProvider),
    config: () => ref.read(shufflePlusConfigProvider),
    jamActive: () => ref.read(jamProvider).active,
    isMetered: () => ref.read(shufflePlusMeteredProvider)(),
    toolAvailable: () async =>
        (await ref.read(ytDlpStatusProvider.future)).version != null,
    loadTracks: tracks.getByIdsLight,
    loadLibrary: () => ref.read(libraryIndexProvider.future),
    hasDownload: downloads.contains,
    prepare: ref.read(shufflePlusPrepareProvider),
    enrichSuggested: ref.read(shufflePlusEnrichProvider),
  );
  ref.listen(shufflePlusConfigProvider, (_, _) => controller.poke());
  ref.listen(jamProvider, (_, _) => controller.poke());
  final net = ref
      .watch(networkProbeProvider)
      .changes
      .listen((_) => controller.poke());
  ref.onDispose(net.cancel);
  ref.onDispose(controller.dispose);
  controller.start();
  return controller;
});

/// Suggestions still on their way and the block being enriched (F-53), for
/// the screens that show a placeholder row meanwhile.
final shufflePlusPendingProvider =
    NotifierProvider<ShufflePlusPendingNotifier, ShufflePlusPending>(
      ShufflePlusPendingNotifier.new,
    );

class ShufflePlusPendingNotifier extends Notifier<ShufflePlusPending> {
  @override
  ShufflePlusPending build() {
    // Same rule as the engine (`plusOn`), applied at once; the engine clears `pending` for its other stops.
    final mode = ref.watch(shuffleModeProvider);
    if (!plusOn(
      enabled: mode == ShuffleMode.plus,
      shuffle: mode != ShuffleMode.off,
      jam: ref.watch(jamProvider.select((j) => j.active)),
    )) {
      return ShufflePlusPending.none;
    }
    final c = ref.watch(shufflePlusProvider).value;
    if (c == null) return ShufflePlusPending.none;
    void sync() {
      if (ref.mounted) state = c.pending.value;
    }

    c.pending.addListener(sync);
    ref.onDispose(() => c.pending.removeListener(sync));
    return c.pending.value;
  }
}

/// Why the radio must not be asked (null: it may), the same for the genre mix
/// and for the songs similar to a Search pick.
Future<GenreMixOff?> radioOffReason({
  required bool jam,
  required Future<String?> toolVersion,
  required NetworkProbe probe,
  required bool unmeteredOnly,
  required RadioGate gate,
}) async {
  if (jam) return GenreMixOff.jam;
  if (await toolVersion == null) return GenreMixOff.noTool;
  final net = await probe.current();
  if (!net.online) return GenreMixOff.offline;
  if (net.metered && unmeteredOnly) return GenreMixOff.metered;
  return gate.rateLimited ? GenreMixOff.rateLimited : null;
}

/// The library track an online song already is by title and artist, for the
/// similar songs of a Search pick (null: none, or the index is not ready).
final libraryMatchIdProvider = Provider<Future<int?> Function(YtResult r)>((
  ref,
) {
  return (r) async =>
      libraryMatchOf(r, await ref.read(libraryIndexProvider.future))?.id;
});

/// The radio of a Search pick (D-429, D-467): null when [radioOffReason] says
/// so. The library is not left out: its songs and the online ones mix.
final similarFillProvider =
    Provider<Future<RadioFill?> Function(RadioSeed seed)>((ref) {
      return (seed) async {
        if (!kEnableYoutube) return null;
        final gate = ref.read(radioGateProvider);
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
        await log.load();
        final filter = ref.read(suggestionGateProvider);
        await filter.load();
        return RadioFill(
          seeds: [seed],
          resolver: await ref.read(seedResolverProvider.future),
          radioPage: ref.read(ytmRadioServiceProvider).page,
          log: log,
          filter: filter,
          gate: gate,
          inLibrary: (_) => false,
        );
      };
    });

/// The online songs of a genre page (D-356): the library songs of the genre
/// seed the radios, as in Shuffle+, with the same limits (Jam, metered network,
/// no yt-dlp, rate limit) but whether Shuffle+ is on or not. Worked out once
/// per opening: every dependency is read once, before the first await (the
/// library index, read when the radio is about to be asked, apart), so a
/// download or a promotion does not restart it. It stays for 5 minutes after
/// the page is left, so opening the genre again does not repeat the requests.
final genreMixProvider = StreamProvider.autoDispose
    .family<GenreMixState, String>((ref, genre) {
      if (!kEnableYoutube) return const Stream.empty();
      final link = ref.keepAlive();
      Timer? timer;
      ref.onCancel(() => timer = Timer(const Duration(minutes: 5), link.close));
      ref.onResume(() => timer?.cancel());
      ref.onDispose(() => timer?.cancel());
      // Listened (not restarting): an unlistened stream provider stays paused.
      ref.listen(genreTracksProvider(genre), (_, _) {});
      final tracks = ref.read(genreTracksProvider(genre).future);
      final resolver = ref.read(seedResolverProvider.future);
      final downloads = ref.read(downloadIndexProvider.future);
      final tool = ref.read(ytDlpStatusProvider.future);
      final probe = ref.read(networkProbeProvider);
      final radio = ref.read(ytmRadioServiceProvider);
      final log = ref.read(suggestionLogProvider);
      final filter = ref.read(suggestionGateProvider);
      final jam = ref.read(jamProvider).active;
      final unmeteredOnly = ref.read(shufflePlusConfigProvider).unmeteredOnly;
      final gate = ref.read(radioGateProvider);
      return genreMixOf(
        tracks: tracks,
        resolver: resolver,
        downloads: downloads,
        radioPage: radio.page,
        log: log,
        filter: filter,
        gate: gate,
        offReason: () => radioOffReason(
          jam: jam,
          toolVersion: tool.then((s) => s.version),
          probe: probe,
          unmeteredOnly: unmeteredOnly,
          gate: gate,
        ),
        // Read after awaits: a disposed ref cannot read, and the mix is cancelled anyway.
        library: () async => ref.mounted
            ? ref.read(libraryIndexProvider.future)
            : LibraryIndex(const []),
        cancelled: () => !ref.mounted,
      );
    });

/// Told to the user once (rate limit, too many errors): the shell shows them.
final shufflePlusNoticesProvider = StreamProvider<ShufflePlusNotice>((
  ref,
) async* {
  final c = await ref.watch(shufflePlusProvider.future);
  if (c != null) yield* c.notices;
});

/// What the three-state shuffle button shows.
enum ShuffleMode { off, shuffle, plus }

final shuffleModeProvider = Provider<ShuffleMode>((ref) {
  final on = ref.watch(shuffleProvider).value ?? false;
  final plus = ref.watch(settingsProvider.select((s) => s.shufflePlus));
  return !on
      ? ShuffleMode.off
      : (plus ? ShuffleMode.plus : ShuffleMode.shuffle);
});

/// The first reason in the order the sheet reports them.
ShufflePlusBlock? shufflePlusBlock({
  required bool jam,
  required bool toolAvailable,
  required bool metered,
  required bool unmeteredOnly,
  required bool stopped,
}) {
  if (jam) return ShufflePlusBlock.jam;
  if (stopped) return ShufflePlusBlock.stopped;
  if (!toolAvailable) return ShufflePlusBlock.noTool;
  if (unmeteredOnly && metered) return ShufflePlusBlock.metered;
  return null;
}

/// Read by the Shuffle+ sheet; recomputed when the song, the Jam or the
/// settings change.
final shufflePlusBlockProvider = FutureProvider.autoDispose<ShufflePlusBlock?>((
  ref,
) async {
  final cfg = ref.watch(shufflePlusConfigProvider);
  ref.watch(currentTrackProvider);
  final jam = ref.watch(jamProvider).active;
  ref.watch(playContextProvider);
  final allowed = await plusAllowedNow(ref);
  if (allowed != null) return allowed;
  final controller = await ref.watch(shufflePlusProvider.future);
  final tool = (await ref.watch(ytDlpStatusProvider.future)).version != null;
  final metered = await ref.read(shufflePlusMeteredProvider)();
  return shufflePlusBlock(
    jam: jam,
    toolAvailable: tool,
    metered: metered,
    unmeteredOnly: cfg.unmeteredOnly,
    stopped: controller?.stoppedForSession ?? false,
  );
});

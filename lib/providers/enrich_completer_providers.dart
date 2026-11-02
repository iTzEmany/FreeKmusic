import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/clock.dart';
import '../data/db/app_database.dart';
import '../data/repositories/recog_pass_query.dart';
import '../services/online/enrich_completer.dart';
import '../services/online/enrich_parts.dart';
import '../services/recognition/track_identity.dart' show kRecogVersion;
import 'activity_log_providers.dart';
import 'activity_providers.dart';
import 'database_providers.dart';
import 'online_providers.dart';
import 'settings_providers.dart';
import 'user_activity_provider.dart';

/// How long the user must leave the app alone before the next track.
const _idleFor = Duration(seconds: 5);

class EnrichCompleterState {
  const EnrichCompleterState({
    this.running = false,
    this.paused = false,
    this.waiting = false,
    this.complete = 0,
    this.total = 0,
  });

  /// A run is going (also while it ends after a pause: the track in hand is aborted).
  final bool running;

  /// Stopped by hand until «Riprendi» (or the next start of the app).
  final bool paused;

  /// The run waits for the user to leave the app alone, or for another activity.
  final bool waiting;

  /// Tracks with nothing left to ask, and all of them; moves every 10 tracks.
  final int complete, total;

  /// Shown in the Activity centre.
  bool get visible => running || paused;

  EnrichCompleterState copyWith({
    bool? running,
    bool? paused,
    bool? waiting,
    int? complete,
    int? total,
  }) => EnrichCompleterState(
    running: running ?? this.running,
    paused: paused ?? this.paused,
    waiting: waiting ?? this.waiting,
    complete: complete ?? this.complete,
    total: total ?? this.total,
  );
}

/// Completes the library in the background while the app is open (D-102).
/// A pause is a stop of the run: its line goes to the Registro, and «Riprendi»
/// starts the next run where the database says (the state is all there).
class EnrichCompleterNotifier extends Notifier<EnrichCompleterState> {
  /// How often a waiting run looks at the user again.
  Duration poll = const Duration(seconds: 1);

  Future<void>? _current;
  bool _halt = false, _again = false;

  EnrichCompleter? _built;

  // Built on the first run: it needs the whole enrichment engine.
  EnrichCompleter get _completer => _built ??= EnrichCompleter(
    engine: ref.read(enrichEngineProvider),
    repo: ref.read(creditsRepositoryProvider),
    parts: () => autoParts(ref.read(settingsProvider)),
    waitIdle: _waitIdle,
    loadMark: () => ref.read(settingsStoreProvider).enrichMark,
    saveMark: (id) => unawaited(
      ref
          .read(settingsStoreProvider)
          .writeEnrichMark(id)
          .catchError((Object e, StackTrace st) {
            AppLog.w('completion: mark not saved', e, st);
          }),
    ),
    recogQuery: recogPassQuery(ref.read(databaseProvider)),
    recogNeeds: recogPassNeeds(ref.read(databaseProvider)),
    yieldPass: () => _again,
    loadPassAfter: () => ref.read(settingsStoreProvider).recogPassAfter,
    savePassAfter: (id) => unawaited(
      ref.read(settingsStoreProvider).writeRecogPassAfter(id).catchError((Object e, StackTrace st) {
        AppLog.w('completion: re-pass mark not saved', e, st);
      }),
    ),
    passDone: () => ref.read(settingsStoreProvider).recogPassDone >= kRecogVersion,
    markPassDone: () => unawaited(
      ref.read(settingsStoreProvider).writeRecogPassDone(kRecogVersion).catchError((Object e, StackTrace st) {
        AppLog.w('completion: re-pass done not saved', e, st);
      }),
    ),
    onProgress: (c, t) {
      if (ref.mounted) state = state.copyWith(complete: c, total: t);
    },
    onWaiting: (w) {
      if (ref.mounted) state = state.copyWith(waiting: w);
    },
  );

  @override
  EnrichCompleterState build() {
    ref.onDispose(() {
      _halt = true;
      _built?.cancel();
    });
    return const EnrichCompleterState();
  }

  /// Set by [enrichCompleterStartProvider]: reading the provider from here
  /// would close a cycle (the activity list watches this notifier, the busy
  /// flag listens to the activity list). Without it nothing waits.
  UserActivity? activity;

  /// The Registro's `add`, set by [enrichCompleterStartProvider] for the same
  /// reason (the Registro listens to the activity list). Without it a round
  /// leaves no line.
  Future<void> Function(LogEntry)? addLog;

  bool _warnedNoActivity = false;

  Future<void> _waitIdle() async {
    if (activity == null && !_warnedNoActivity) {
      _warnedNoActivity = true;
      AppLog.w('completion: no user activity wired, a plain run never starts');
    }
    // Fails closed: without the activity the user is never idle.
    while (!_halt && !(activity?.idleFor(_idleFor) ?? false)) {
      await Future<void>.delayed(poll);
    }
  }

  /// A run until nothing is due. Does nothing while paused by hand or when
  /// everything is complete. Called during a run (a switch changed, a scan
  /// ended) it asks for another one when this ends.
  Future<void> start() {
    if (state.paused) return Future.value();
    final current = _current;
    if (current != null) {
      _again = true;
      return current;
    }
    return _current = _go().whenComplete(() {
      _current = null;
      if (_again && ref.mounted) {
        _again = false;
        unawaited(start());
      }
    });
  }

  Future<void> _go() async {
    _halt = false;
    try {
      final c = await ref
          .read(creditsRepositoryProvider)
          .enrichCounts(
            autoParts(ref.read(settingsProvider)),
            DateTime.fromMillisecondsSinceEpoch(nowMs()),
          );
      if (_halt || !ref.mounted) return; // stopped while counting
      // A complete library still gets the one-off re-pass (R-176).
      if (c.complete >= c.total && !_completer.passDue) return;
      state = EnrichCompleterState(
        running: true,
        complete: c.complete,
        total: c.total,
      );
      final round = await _completer.run();
      if (round.worked > 0 || round.failed) {
        await _log(round, stopped: _halt, failed: round.failed);
      }
      if (_completer.passInterrupted && !_halt) _again = true; // normal work first, then the pass resumes
      final pass = _completer.pass;
      if (pass != null && (pass.worked > 0 || pass.failed)) {
        await _log(pass, stopped: _halt, failed: pass.failed, recogPass: true);
      }
    } on Object catch (e, st) {
      // A programming error is not a warning.
      if (e is Error) {
        AppLog.e('completion failed', e, st);
      } else {
        AppLog.w('completion failed', e, st);
      }
    } finally {
      if (ref.mounted) state = state.copyWith(running: false, waiting: false);
    }
  }

  /// Stops the run until [resume]: the track in hand is aborted and the
  /// bookmark stays before it. The Registro gets the line of the round so far.
  void pause() {
    if (!state.running) return;
    state = state.copyWith(paused: true);
    _halt = true;
    _completer.cancel();
  }

  Future<void> resume() async {
    if (!state.paused) return;
    await _current; // the run that was paused may still be ending
    if (!state.paused) return; // «Interrompi» came first
    state = state.copyWith(paused: false);
    unawaited(start());
  }

  /// «Interrompi»: the track in hand is aborted; the next start of the app
  /// (or a change of the switches) carries on.
  void cancel() {
    state = state.copyWith(paused: false);
    _halt = true;
    _again = false;
    if (_current != null) _completer.cancel();
  }

  Future<void> _log(
    EnrichRound round, {
    required bool stopped,
    required bool failed,
    bool recogPass = false,
  }) {
    Map<String, List<int>> byPart(Map<EnrichPart, List<int>> m) => {
      for (final e in m.entries) e.key.name: e.value,
    };
    final add = addLog;
    if (add == null) {
      AppLog.w('completion: no Registro wired, the round leaves no line');
      return Future.value();
    }
    return add(
      LogEntry(
        at: DateTime.now(),
        item: ActivityItem(
          kind: ActivityKind.enrichBackground,
          key: 'enrichBackground-${DateTime.now().microsecondsSinceEpoch}',
          name: null,
          done: round.updatedTracks,
          total: round.notFoundTracks,
          running: false,
          failed: failed,
        ),
        detail: {
          if (recogPass) 'recogPass': true,
          if (stopped) 'stopped': true,
          if (round.noAnswer) 'noAnswer': true,
          'updated': byPart(round.updated),
          'none': byPart(round.none),
          if (round.sources.isNotEmpty) 'sources': round.sources,
        },
      ),
    );
  }
}

final enrichCompleterProvider =
    NotifierProvider<EnrichCompleterNotifier, EnrichCompleterState>(
      EnrichCompleterNotifier.new,
    );

typedef EnrichRoundRow = ({EnrichPart part, Track track});

/// The two groups of a round line of the Registro.
class EnrichRoundView {
  const EnrichRoundView(this.updated, this.none);

  final List<EnrichRoundRow> updated, none;
}

/// The tracks behind a round line of the Registro, from its `detail`. A track
/// deleted since is left out.
final enrichRoundProvider = FutureProvider.autoDispose
    .family<EnrichRoundView, LogEntry>((ref, entry) async {
      final tracks = ref.watch(trackRepositoryProvider);
      Future<List<EnrichRoundRow>> group(String key) async {
        final raw = entry.detail?[key];
        if (raw is! Map) return const [];
        return [
          for (final part in EnrichPart.values)
            if (raw[part.name] case final List ids)
              for (final t in await tracks.getByIdsLight([
                for (final i in ids)
                  if (i is int) i,
              ]))
                (part: part, track: t),
        ];
      }

      return EnrichRoundView(await group('updated'), await group('none'));
    });

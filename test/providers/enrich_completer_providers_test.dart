import 'dart:async';

import 'package:codecore/data/repositories/activity_log_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/activity_log_providers.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/enrich_completer_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/startup_providers.dart';
import 'package:codecore/providers/user_activity_provider.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:codecore/services/recognition/track_identity.dart' show kRecogVersion;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/enrich_fakes.dart';

class _Settings extends SettingsNotifier {
  _Settings(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;

  void put(AppSettings s) => state = s;
}

/// A Registro that holds the write of the line until [gate] opens.
class _GatedLog extends ActivityLogRepository {
  _GatedLog(super.db, this.gate);

  final Completer<void> gate;

  @override
  Future<int> add({
    required int at,
    required String kind,
    required String name,
    int done = 0,
    int total = 0,
    bool failed = false,
    String? detail,
  }) async {
    await gate.future;
    return super.add(
      at: at,
      kind: kind,
      name: name,
      done: done,
      total: total,
      failed: failed,
      detail: detail,
    );
  }
}

/// Counts how often the completion looks at the user; the third look breaks.
class _Watched extends UserActivity {
  _Watched({this.breakAt});

  final int? breakAt;
  int checks = 0;

  @override
  bool idleFor(Duration d) {
    if (++checks == breakAt) throw StateError('boom');
    return super.idleFor(d);
  }
}

class _Job extends EnrichJobNotifier {
  @override
  EnrichJobState build() => const EnrichJobState(running: true);
}

void main() {
  late EnrichRig r;
  late UserActivity user;
  late ProviderContainer c;
  late SettingsStore store;
  var n = 0;

  Future<int> track() => r.add(path: '/t${n++}.mp3');

  ProviderContainer open({
    AppSettings? settings,
    List<Override> extra = const [],
  }) {
    final c = ProviderContainer(
      overrides: [
        ...extra,
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(r.db),
        enrichEngineProvider.overrideWithValue(r.engine),
        creditsRepositoryProvider.overrideWithValue(r.credits),
        settingsProvider.overrideWith(
          () => _Settings(settings ?? helpersOff(autoLyrics: true)),
        ),
        userActivityProvider.overrideWithValue(user),
        activityProvider.overrideWithValue(const ActivityState([], [])),
        startupSettledProvider.overrideWith((ref) async {}),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  EnrichCompleterNotifier completer() {
    final notifier = c.read(enrichCompleterProvider.notifier)
      ..activity = user
      ..addLog = c.read(activityLogProvider.notifier).add
      ..poll = const Duration(milliseconds: 10);
    return notifier;
  }

  EnrichCompleterState state() => c.read(enrichCompleterProvider);

  Future<void> until(bool Function() ok) async {
    for (var i = 0; i < 300 && !ok(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ok(), isTrue);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'recogPassDone': kRecogVersion}); // the re-pass is a test of its own
    store = SettingsStore(await SharedPreferences.getInstance());
    r = EnrichRig();
    user = UserActivity()..busy = true; // the user is busy until a test says no
    c = open();
  });
  tearDown(() => r.dispose());

  test(
    'a run completes the tracks and leaves one line with the ids behind it',
    () async {
      user = UserActivity(); // idle
      c = open();
      final ids = [await track(), await track()];
      await completer().start();
      expect(r.chain.calls, 2);
      expect(state().running, isFalse);
      final rows = await r.db.select(r.db.activityLogRows).get();
      expect(rows.single.kind, 'enrichBackground');
      expect([rows.single.done, rows.single.total], [2, 0]);
      expect(rows.single.detail, contains('"updated"'));
      for (final id in ids) {
        expect(rows.single.detail, contains('$id'));
      }
    },
  );

  test('a track that got one part and missed another is counted once, as completed', () async {
    user = UserActivity(); // idle
    c = open();
    final id = await track();
    await track();
    // Plain text found, no synced one: lyrics updated, synced «none» for the same track.
    r.chain.resultFor = (t) =>
        t.id == id ? const LyricsResult(plain: 'la la') : null;
    await completer().start();
    final row = (await r.db.select(r.db.activityLogRows).get()).single;
    expect([row.done, row.total], [1, 1], reason: 'one completed, one without result');
  });

  test(
    'a pause by hand holds the run until resumed',
    () async {
      await track();
      await track();
      final notifier = completer();
      unawaited(notifier.start());
      await until(() => state().running);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(r.chain.calls, 0, reason: 'the user is busy');

      notifier.pause();
      expect(state().paused, isTrue);
      await until(() => !state().running);
      notifier.activity = UserActivity(); // the user is idle
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        r.chain.calls,
        0,
        reason: 'a pause by hand lasts until «Riprendi»',
      );

      await notifier.resume();
      expect(state().paused, isFalse);
      await until(() => r.chain.calls == 2);
      await until(() => !state().running);
    },
  );

  test('the state says waiting while the run waits for the user, and not once it works', () async {
    await track();
    final notifier = completer();
    unawaited(notifier.start());
    await until(() => state().waiting);
    expect([state().running, r.chain.calls], [true, 0]);
    notifier.activity = UserActivity(); // the user is idle
    await until(() => r.chain.calls == 1);
    await until(() => !state().running);
    expect(state().waiting, isFalse);
  });

  test('resume starts again by itself, once the user is idle', () async {
    await track();
    final notifier = completer();
    unawaited(notifier.start());
    await until(() => state().running);
    notifier.pause();
    await until(() => !state().running);
    user.busy = false;
    // Still within 5 s of the end of the busy spell: waits, then works.
    await notifier.resume();
    expect(state().paused, isFalse);
    await until(() => state().running);
    notifier.cancel();
    await until(() => !state().running);
    expect(r.chain.calls, 0);
  });

  test('cancel while waiting for the user ends the run at once', () async {
    await track();
    final notifier = completer();
    unawaited(notifier.start());
    await until(() => state().running);
    notifier.cancel();
    await until(() => !state().running);
    expect([state().paused, r.chain.calls], [false, 0]);
    expect(await r.db.select(r.db.activityLogRows).get(), isEmpty);
  });

  test('without the activity wired, a plain run never works a track', () async {
    await track();
    final notifier = c.read(enrichCompleterProvider.notifier)
      ..poll = const Duration(milliseconds: 10);
    unawaited(notifier.start());
    await until(() => state().running);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(r.chain.calls, 0);
    notifier.cancel();
    await until(() => !state().running);
  });

  test('nothing due: no run shows up', () async {
    await r.add(plain: 'a', synced: '[00:01.00]a', path: '/done.mp3');
    await completer().start();
    expect(state().running, isFalse);
    expect(r.chain.calls, 0);
  });

  test('a start asked while a run is closing makes another run', () async {
    user = UserActivity(); // idle
    final gate = Completer<void>();
    c = open(
      extra: [
        activityLogRepositoryProvider.overrideWithValue(_GatedLog(r.db, gate)),
      ],
    );
    await track();
    final notifier = completer();
    final first = notifier.start();
    await until(() => r.chain.calls == 1);
    await until(() => r.chain.calls == 1 && state().running);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(state().running, isTrue, reason: 'the run waits for its line');
    await track(); // what a switch that came on would now ask for
    unawaited(notifier.start());
    gate.complete();
    await first;
    await until(() => r.chain.calls == 2);
    await until(() => !state().running);
  });

  test('a cancel while the run is still counting is not lost', () async {
    user = UserActivity();
    c = open();
    await track();
    final notifier = completer();
    final run = notifier.start();
    notifier.cancel();
    await run;
    expect([r.chain.calls, state().running], [0, false]);
  });

  test('with the real activity list, an enrichment in progress holds the completion', () async {
    // Real activityProvider and userActivityProvider, fed by this job.
    c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(r.db),
        enrichEngineProvider.overrideWithValue(r.engine),
        creditsRepositoryProvider.overrideWithValue(r.credits),
        settingsProvider.overrideWith(
          () => _Settings(helpersOff(autoLyrics: true)),
        ),
        startupSettledProvider.overrideWith((ref) async {}),
        enrichJobProvider.overrideWith(_Job.new),
      ],
    );
    addTearDown(c.dispose);
    await track();
    final notifier = c.read(enrichCompleterProvider.notifier)
      ..poll = const Duration(milliseconds: 10);
    // The app's root starts the completion and keeps the busy flag listened.
    final sub = c.listen(enrichCompleterStartProvider, (_, _) {});
    addTearDown(sub.close);
    await until(() => state().running);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(c.read(userActivityProvider).isBusy, isTrue);
    expect(r.chain.calls, 0);
    notifier.cancel();
    await until(() => !state().running);
  });

  /// The completion stops looking at the user once [stop] is done.
  Future<void> expectNoMoreWaiting(
    _Watched w,
    void Function() stop, {
    bool disposed = false,
  }) async {
    final notifier = completer()..activity = w;
    unawaited(notifier.start());
    await until(() => state().running);
    await until(() => w.checks > 2);
    stop();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final seen = w.checks;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(w.checks, seen, reason: 'a waiting run ended');
    if (!disposed) expect(state().running, isFalse);
    expect(r.chain.calls, 0);
  }

  test('pause, cancel and dispose each end a wait for the user', () async {
    await track();
    // The busy user keeps the run waiting; the runs below are told to stop.
    EnrichCompleterNotifier n() => c.read(enrichCompleterProvider.notifier);
    await expectNoMoreWaiting(_Watched()..busy = true, () => n().pause());
    c = open();
    await expectNoMoreWaiting(_Watched()..busy = true, () => n().cancel());
    c = open();
    await expectNoMoreWaiting(
      _Watched()..busy = true,
      () => c.dispose(),
      disposed: true,
    );
  });

  test(
    'cancel forgets a start asked meanwhile: no run begins by itself',
    () async {
      await track();
      final notifier = completer();
      unawaited(notifier.start());
      await until(() => state().running);
      unawaited(notifier.start()); // a switch changed
      notifier.cancel();
      await until(() => !state().running);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(state().running, isFalse);
      expect(r.chain.calls, 0);
    },
  );

  test('a run stopped with Pausa leaves its line marked as stopped', () async {
    user = UserActivity();
    c = open();
    await track();
    await track();
    final notifier = completer();
    r.chain.during = () async {
      if (r.chain.calls == 2) notifier.pause(); // aborts the second
    };
    await notifier.start();
    expect(r.chain.calls, 2);
    final rows = await r.db.select(r.db.activityLogRows).get();
    expect(rows.single.detail, contains('"stopped":true'));
    expect(rows.single.failed, 0);
  });

  test(
    'a run that breaks in the middle still leaves its line, as failed',
    () async {
      user = _Watched(breakAt: 3);
      c = open();
      final ids = [for (var n = 0; n < 5; n++) await track()];
      await completer().start();
      expect(r.chain.calls, 2);
      final row = (await r.db.select(r.db.activityLogRows).get()).single;
      expect([row.kind, row.done, row.failed], ['enrichBackground', 2, 1]);
      expect(row.detail, contains('${ids[1]}'));
      expect(state().running, isFalse);
    },
  );

  test('an error before any work leaves a failed line with nothing done', () async {
    user = _Watched(breakAt: 1);
    c = open();
    await track();
    await completer().start();
    final row = (await r.db.select(r.db.activityLogRows).get()).single;
    expect([row.kind, row.done, row.total, row.failed], ['enrichBackground', 0, 0, 1]);
  });

  test('five tracks with no answer leave one failed line with nothing done', () async {
    user = UserActivity();
    c = open();
    r.chain.failed = true;
    for (var n = 0; n < 6; n++) {
      await track();
    }
    await completer().start();
    final row = (await r.db.select(r.db.activityLogRows).get()).single;
    expect([row.kind, row.done, row.total, row.failed], ['enrichBackground', 0, 0, 1]);
    expect(row.detail, contains('"noAnswer":true'));
  });

  test('with everything complete a start never shows a run', () async {
    user = UserActivity();
    c = open();
    await r.add(plain: 'a', synced: '[00:01.00]a', path: '/done.mp3');
    final seen = <bool>[];
    c.listen(enrichCompleterProvider, (_, s) => seen.add(s.running));
    await completer().start();
    expect(seen, isNot(contains(true)));
  });

  test('turning a switch on starts the completion', () async {
    user = UserActivity(); // idle
    await track();
    c = open(settings: helpersOff());
    final sub = c.listen(enrichCompleterStartProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(r.chain.calls, 0, reason: 'no switch is on');

    (c.read(settingsProvider.notifier) as _Settings).put(
      helpersOff(autoLyrics: true),
    );
    await until(() => r.chain.calls == 1);
    await until(() => !state().running);
  });
}

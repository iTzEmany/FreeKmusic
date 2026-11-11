import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/enrich_fakes.dart';

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => helpersOff();
}

void main() {
  late EnrichRig r;
  late ProviderContainer c;

  setUp(() {
    r = EnrichRig();
    c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(r.db),
        enrichEngineProvider.overrideWithValue(r.engine),
        creditsRepositoryProvider.overrideWithValue(r.credits),
        settingsProvider.overrideWith(_Settings.new),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await r.dispose();
  });

  Future<EnrichJobState> finished() async {
    for (var i = 0; i < 300; i++) {
      final s = c.read(enrichJobProvider);
      if (!s.running && s.result != null) return s;
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the job never ended');
  }

  test('onFinished runs when the job ends, not when it was cancelled', () async {
    var calls = 0;
    final job = c.read(enrichJobProvider.notifier);
    expect(job.start([await r.add()], onFinished: () => calls++), isTrue);
    expect(c.read(enrichJobProvider).progress?.total, 1); // the bar starts at «0 di 1»
    await finished();
    expect(calls, 1);

    // Cancelled before the first block: the job ends without «finished».
    job.clearResult();
    final ids = [await r.add(path: '/b.mp3'), await r.add(path: '/c.mp3')];
    expect(job.start(ids, onFinished: () => calls++), isTrue);
    job.cancel();
    final s = await finished();
    expect([s.result!.cancelled, calls], [true, 1]);
  });

  test('a job that loses every write is marked failed and does not finish', () async {
    final ids = [for (var i = 0; i < 3; i++) await r.add(path: '/$i.mp3')];
    await r.db.customStatement(
      "CREATE TRIGGER boom BEFORE UPDATE ON tracks BEGIN SELECT RAISE(ABORT,'boom'); END",
    );
    var calls = 0;
    c.read(enrichJobProvider.notifier).start(ids, onFinished: () => calls++);
    final s = await finished();
    expect([s.result!.failed, s.result!.total, calls], [true, 3, 0]);
    expect(s.result!.logDetail, {'updated': 0, 'notFound': 0});
  });

  test('offline: 2 tracks end failed, and the second opinion (onFinished) is not started', () async {
    r.web.itunes = ItunesMode.down;
    r.chain.failed = true;
    r.finder.error = StateError('offline');
    var calls = 0;
    final ids = [await r.add(path: '/a.mp3'), await r.add(path: '/b.mp3')];
    c.read(enrichJobProvider.notifier).start(ids, onFinished: () => calls++);
    final s = await finished();
    expect([s.result!.failed, s.result!.done, s.result!.total, calls], [true, 2, 2, 0]);
  });

  test('one offline track ends failed, with no second opinion', () async {
    r.web.itunes = ItunesMode.down;
    r.chain.failed = true;
    r.finder.error = StateError('offline');
    var calls = 0;
    c.read(enrichJobProvider.notifier).start([await r.add()], onFinished: () => calls++);
    final s = await finished();
    expect([s.result!.failed, calls], [true, 0]);
  });

  test('one track while the only asked sources rest: rate limited, not failed', () async {
    r.web.itunes = ItunesMode.limited;
    r.chain.limited = true;
    r.finder.error = StateError('offline');
    c.read(enrichJobProvider.notifier).start([await r.add()]);
    final s = await finished();
    expect([s.result!.failed, s.result!.rateLimited], [false, true]);
  });

  /// [start] on 3 tracks; after the first one is done, [breakIt] runs.
  Future<EnrichJobResult> afterFirst(void Function() breakIt) async {
    final ids = [for (var i = 0; i < 3; i++) await r.add(path: '/$i.mp3')];
    c.listen(enrichJobProvider, (_, s) {
      if (s.progress?.done == 1) breakIt();
    });
    c.read(enrichJobProvider.notifier).start(ids);
    return (await finished()).result!;
  }

  test('some tracks answer, then silence: the job is not failed', () async {
    final res = await afterFirst(() {
      r.web.itunes = ItunesMode.down;
      r.chain.failed = true;
      r.finder.error = StateError('offline');
    });
    expect([res.failed, res.updated], [false, 1]);
  });

  test('rate limited after some work: the job is not rateLimited', () async {
    final res = await afterFirst(() {
      r.web.itunes = ItunesMode.limited;
      r.chain.limited = true;
    });
    expect([res.rateLimited, res.failed], [false, false]);
  });

  test('a second start while running is refused, and the first job still cancels', () async {
    final ids = [for (var i = 0; i < 3; i++) await r.add(path: '/$i.mp3')];
    r.chain.hold = Completer<void>();
    final job = c.read(enrichJobProvider.notifier);
    expect(job.start(ids), isTrue);
    expect(job.start(ids), isFalse);
    expect(await job.startDue(), EnrichStart.busy);
    for (var i = 0; i < 300 && r.chain.calls < 1; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    job.cancel();
    final s = await finished().timeout(const Duration(seconds: 5));
    expect(s.result!.cancelled, isTrue);
  });

  test('«Interrompi» aborts the request in flight, and done is the real count', () async {
    final ids = [for (var i = 0; i < 3; i++) await r.add(path: '/$i.mp3')];
    final job = c.read(enrichJobProvider.notifier);
    r.chain.during = () async {
      if (r.chain.calls == 2) r.chain.hold = Completer<void>(); // the second search never answers
    };
    job.start(ids);
    for (var i = 0; i < 300 && r.chain.calls < 2; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    job.cancel();
    final s = await finished().timeout(const Duration(seconds: 5));
    expect([s.result!.cancelled, s.result!.failed, s.result!.done, s.result!.total], [true, false, 1, 3]);
  });

  test('startDue asks again a part marked «nothing» yesterday', () async {
    final id = await r.add();
    final yesterday = DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    await r.db.into(r.db.trackEnrich).insert(
      TrackEnrichCompanion(trackId: Value(id), lyricsNoneAt: Value(yesterday)),
    );
    expect(await c.read(enrichJobProvider.notifier).startDue(), EnrichStart.started);
    await finished();
    expect((await r.repo.getById(id))!.lyricsPlain, 'la la');
  });

  test('startDue asks the tracks with something due, then finds nothing', () async {
    await r.add();
    final job = c.read(enrichJobProvider.notifier);
    expect(await job.startDue(), EnrichStart.started);
    final s = await finished();
    expect([s.result!.total, s.result!.updated], [1, 1]);
    job.clearResult();
    expect(await job.startDue(), EnrichStart.nothing);
  });
}

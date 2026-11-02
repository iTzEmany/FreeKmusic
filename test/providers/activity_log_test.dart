import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/import_repository.dart';
import 'package:codecore/providers/activity_log_providers.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/import_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/second_opinion_providers.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/scanner/library_scanner.dart' show ScanProgress;
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/import/playlist_import_service.dart';
import 'package:codecore/core/import_row.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Activity extends Notifier<ActivityState> {
  @override
  ActivityState build() => const ActivityState([], []);
  void set(ActivityState s) => state = s;
}

class _Downloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => const [];
  @override
  void clearFinished() {}
}

class _SecondOpinion extends SecondOpinionNotifier {
  @override
  SecondOpinionState build() => const SecondOpinionState();
  void set(SecondOpinionState s) => state = s;
}

class _Scan extends ScanNotifier {
  @override
  ScanState build() => const ScanState(error: 'disk gone');
}

class _DoneScan extends ScanNotifier {
  @override
  ScanState build() => const ScanState(progress: ScanProgress(done: 147, total: 147, finished: true));
}

class _Job extends EnrichJobNotifier {
  @override
  EnrichJobState build() => const EnrichJobState();
  void set(EnrichJobState s) => state = s;
}

final _activity = NotifierProvider<_Activity, ActivityState>(_Activity.new);

ActivityItem _done(String key, String name, {bool failed = false}) =>
    ActivityItem(
      kind: ActivityKind.download,
      key: key,
      name: name,
      running: false,
      failed: failed,
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('each ended item is written once, newest first; imports by name; «Pulisci» empties', () async {
    final events = StreamController<ImportEvent>();
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        downloadsProvider.overrideWith(_Downloads.new),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
        importEventsProvider.overrideWith((ref) => events.stream),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    final playlistId = await db
        .into(db.playlists)
        .insert(PlaylistsCompanion.insert(name: 'L', createdAt: 0));
    final importId = await ImportRepository(db).create(
      playlistId: playlistId,
      sourceName: 'Liked Songs (23/23)',
      rows: const [
        ImportRow(index: 0, title: 'T', artists: ['A']),
      ],
    );

    c
        .read(_activity.notifier)
        .set(ActivityState(const [], [_done('dl-1', 'Uno')]));
    c
        .read(_activity.notifier)
        .set(
          ActivityState(const [], [
            _done('dl-1', 'Uno'),
            _done('dl-2', 'Due', failed: true),
          ]),
        );
    await pumpEventQueue();
    expect(c.read(activityLogProvider).entries.map((e) => e.item!.name), [
      'Due',
      'Uno',
    ]);
    expect(c.read(activityLogProvider).entries.first.failed, isTrue);

    events.add(ImportEvent(ImportEventKind.completed, importId));
    await pumpEventQueue();
    final top = c.read(activityLogProvider).entries.first;
    expect(top.importName, 'Liked Songs', reason: 'the import, not the block');
    expect(top.failed, isFalse);
    events.add(ImportEvent(ImportEventKind.rateLimited, importId));
    await pumpEventQueue();
    expect(c.read(activityLogProvider).entries.first.failed, isTrue);
    await events.close();

    await c.read(activityLogProvider.notifier).clear();
    expect(c.read(activityLogProvider).entries, isEmpty);
    expect(await db.select(db.activityLogRows).get(), isEmpty);
  });

  // The background completion writes its own line (enrich_completer_providers_test).
  test('a job leaves one line when it leaves running; a download that ends leaves one', () async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    const once = [
      ActivityKind.scan,
      ActivityKind.enrich,
      ActivityKind.cleanup,
      ActivityKind.releases,
    ];
    final running = [
      for (final k in once)
        ActivityItem(kind: k, key: k.name, name: null, done: 2, total: 5),
      const ActivityItem(kind: ActivityKind.download, key: 'dl-1', name: 'Uno'),
    ];
    c.read(_activity.notifier).set(ActivityState(running, const []));
    await pumpEventQueue();
    c
        .read(_activity.notifier)
        .set(ActivityState(const [], [_done('dl-1', 'Uno')]));
    await pumpEventQueue();
    final entries = c.read(activityLogProvider).entries;
    expect(entries.length, once.length + 1);
    expect(entries.map((e) => e.item!.kind).toSet(), {
      ...once,
      ActivityKind.download,
    });
    expect(
      entries.where((e) => e.item!.kind == ActivityKind.scan).single.stopped,
      isTrue,
      reason: 'it left running with 2 of 5 done',
    );
  });

  test('a batch enrichment that finished is not «stopped» by a snapshot one short', () async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
        enrichJobProvider.overrideWith(_Job.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    const last = ActivityItem(
      kind: ActivityKind.enrich,
      key: 'enrich',
      name: null,
      done: 2999,
      total: 3000,
    );
    c.read(_activity.notifier).set(const ActivityState([last], []));
    await pumpEventQueue();
    (c.read(enrichJobProvider.notifier) as _Job).set(const EnrichJobState(
      result: EnrichJobResult(done: 3000, total: 3000),
    ));
    c.read(_activity.notifier).set(const ActivityState([], []));
    await pumpEventQueue();
    var line = c.read(activityLogProvider).entries.single;
    expect([line.stopped, line.item!.done, line.item!.total], [false, 3000, 3000]);

    c.read(_activity.notifier).set(const ActivityState([last], []));
    await pumpEventQueue();
    (c.read(enrichJobProvider.notifier) as _Job).set(const EnrichJobState(
      result: EnrichJobResult(done: 40, total: 3000, cancelled: true),
    ));
    c.read(_activity.notifier).set(const ActivityState([], []));
    await pumpEventQueue();
    line = c.read(activityLogProvider).entries.first;
    expect([line.stopped, line.item!.done], [true, 40]);
  });

  test('a batch enrichment stopped by an error leaves a failed line with its counts', () async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
        enrichJobProvider.overrideWith(_Job.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    const item = ActivityItem(kind: ActivityKind.enrich, key: 'enrich', name: null, done: 2, total: 5);
    c.read(_activity.notifier).set(const ActivityState([item], []));
    await pumpEventQueue();
    (c.read(enrichJobProvider.notifier) as _Job).set(const EnrichJobState(
      result: EnrichJobResult(done: 2, total: 5, updated: 1, notFound: 1, failed: true),
    ));
    c.read(_activity.notifier).set(const ActivityState([], []));
    await pumpEventQueue();
    final line = c.read(activityLogProvider).entries.single;
    expect([line.failed, line.detail?['updated'], line.detail?['notFound']], [true, 1, 1]);
  });

  test('a batch refused by every source leaves a stopped line with the real count', () async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
        enrichJobProvider.overrideWith(_Job.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    const item = ActivityItem(kind: ActivityKind.enrich, key: 'enrich', name: null, done: 1, total: 4);
    c.read(_activity.notifier).set(const ActivityState([item], []));
    await pumpEventQueue();
    (c.read(enrichJobProvider.notifier) as _Job).set(const EnrichJobState(
      result: EnrichJobResult(done: 1, total: 4, rateLimited: true),
    ));
    c.read(_activity.notifier).set(const ActivityState([], []));
    await pumpEventQueue();
    final line = c.read(activityLogProvider).entries.single;
    expect([line.stopped, line.failed, line.item!.done, line.item!.total], [true, false, 1, 4]);
  });

  test('a scan that finished is not «stopped» by a snapshot at 100 of 147', () async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
        scanStateProvider.overrideWith(_DoneScan.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    const scan = ActivityItem(kind: ActivityKind.scan, key: 'scan', name: null, done: 100, total: 147);
    c.read(_activity.notifier).set(const ActivityState([scan], []));
    await pumpEventQueue();
    c.read(_activity.notifier).set(const ActivityState([], []));
    await pumpEventQueue();
    final line = c.read(activityLogProvider).entries.single;
    expect([line.stopped, line.item!.done, line.item!.total], [false, 147, 147]);
  });

  test('a scan that ends with an error leaves its line as failed', () async {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
        scanStateProvider.overrideWith(_Scan.new),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    const scan = ActivityItem(kind: ActivityKind.scan, key: 'scan', name: null);
    c.read(_activity.notifier).set(const ActivityState([scan], []));
    await pumpEventQueue();
    c.read(_activity.notifier).set(const ActivityState([], []));
    await pumpEventQueue();
    expect(c.read(activityLogProvider).entries.single.item!.failed, isTrue);
  });

  test('after a restart the rows are there; the old one is gone, the detail survives', () async {
    final day = const Duration(days: 1).inMilliseconds;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.activityLogRows)
        .insert(
          ActivityLogRowsCompanion.insert(
            at: now - 31 * day,
            kind: 'scan',
            name: 'old',
          ),
        );
    await db
        .into(db.activityLogRows)
        .insert(
          ActivityLogRowsCompanion.insert(
            at: now - 29 * day,
            kind: 'scan',
            name: 'recent',
          ),
        );
    ProviderContainer open() => ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
      ],
    );
    final first = open();
    first.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    await first
        .read(activityLogProvider.notifier)
        .add(
          LogEntry(
            at: DateTime.now(),
            item: const ActivityItem(
              kind: ActivityKind.enrichBackground,
              key: 'r',
              name: null,
              running: false,
            ),
            detail: const {
              'ids': [1, 2],
            },
          ),
        );
    first.dispose();

    final second = open();
    addTearDown(second.dispose);
    second.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    final s = second.read(activityLogProvider);
    expect(s.total, 2);
    expect(s.entries.first.detail, {
      'ids': [1, 2],
    });
    expect(s.entries.last.item!.name, 'recent');
  });

  test('loadMore reads the next pages, stops at the total and never doubles a line added meanwhile', () async {
    for (var i = 1; i <= 120; i++) {
      await db
          .into(db.activityLogRows)
          .insert(
            ActivityLogRowsCompanion.insert(
              at: DateTime.now().millisecondsSinceEpoch + i,
              kind: 'scan',
              name: 'n$i',
            ),
          );
    }
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    final log = c.read(activityLogProvider.notifier);
    expect(
      c.read(activityLogProvider).entries,
      hasLength(ActivityLogNotifier.pageSize),
    );
    await log.add(
      LogEntry(
        at: DateTime.now().add(const Duration(days: 1)),
        item: const ActivityItem(
          kind: ActivityKind.radio,
          key: 'r',
          name: 'new',
          running: false,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await log.loadMore();
    }
    final s = c.read(activityLogProvider);
    expect(s.entries, hasLength(121));
    expect(s.total, 121);
    expect({for (final e in s.entries) e.item!.name}, hasLength(121));
    expect(s.entries.first.item!.name, 'new');
  });

  group('no doubles', () {
    late ProviderContainer c;
    setUp(() {
      c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        activityProvider.overrideWith((ref) => ref.watch(_activity)),
        secondOpinionJobProvider.overrideWith(_SecondOpinion.new),
      ]);
      c.listen(activityLogProvider, (_, _) {});
    });
    tearDown(() => c.dispose());

    test('an item that stays in completed over several states is written once', () async {
      final done = _done('dl-1', 'Uno');
      c.read(_activity.notifier).set(ActivityState(const [], [done]));
      await pumpEventQueue();
      c.read(_activity.notifier).set(ActivityState(const [], [done, _done('dl-2', 'Due')]));
      await pumpEventQueue();
      c.read(_activity.notifier).set(ActivityState(const [], [done, _done('dl-2', 'Due')]));
      c.read(_activity.notifier).set(ActivityState(
          const [ActivityItem(kind: ActivityKind.scan, key: 'scan', name: null)], [done, _done('dl-2', 'Due')]));
      await pumpEventQueue();
      expect(c.read(activityLogProvider).entries.map((e) => e.item!.name), ['Due', 'Uno']);
    });

    test('a finished second opinion is written once, not again at the next state', () async {
      final so = c.read(secondOpinionJobProvider.notifier) as _SecondOpinion;
      so.set(const SecondOpinionState(running: true, total: 3));
      await pumpEventQueue();
      so.set(const SecondOpinionState(done: 3, total: 3));
      await pumpEventQueue();
      so.set(const SecondOpinionState(done: 3, total: 3, updated: 1));
      await pumpEventQueue();
      expect(c.read(activityLogProvider).entries, hasLength(1));
    });
  });

  test('loadMore with every row already loaded reads nothing more', () async {
    for (var i = 1; i <= 3; i++) {
      await db.into(db.activityLogRows).insert(
          ActivityLogRowsCompanion.insert(at: DateTime.now().millisecondsSinceEpoch + i, kind: 'scan', name: 'n$i'));
    }
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    // A row the notifier does not know about: only a read would show it.
    await db.into(db.activityLogRows).insert(
        ActivityLogRowsCompanion.insert(at: DateTime.now().millisecondsSinceEpoch, kind: 'scan', name: 'hidden'));
    await c.read(activityLogProvider.notifier).loadMore();
    expect(c.read(activityLogProvider).entries, hasLength(3));
  });
}

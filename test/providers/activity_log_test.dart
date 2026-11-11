import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/activity_log_repository.dart';
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
import 'package:drift/drift.dart' show ApplyInterceptor, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the Registro rows the page queries return (not the counts).
class _Reads extends QueryInterceptor {
  int rows = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor e, String sql, List<Object?> args) async {
    final r = await super.runSelect(e, sql, args);
    if (sql.contains('activity_log') && !sql.contains('GROUP BY') && !sql.contains('COUNT')) rows += r.length;
    return r;
  }
}

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

  test('an import keeps one Registro line that follows the count and becomes its ending', () async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      downloadsProvider.overrideWith(_Downloads.new),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    ActivityState at(int saved) => ActivityState([
          ActivityItem(kind: ActivityKind.import, key: 'imp-1', name: 'Mood', done: saved, total: 50, ref: 1),
        ], const []);
    for (final n in [3, 20, 21]) {
      c.read(_activity.notifier).set(at(n));
      await pumpEventQueue();
    }
    final rows = await db.select(db.activityLogRows).get();
    expect(rows, hasLength(1));
    expect((rows.single.done, rows.single.total), (21, 50));
    final shown = c.read(activityLogProvider).entries.single;
    expect((shown.progress, shown.item!.done), (true, 21), reason: 'the loaded line follows too');
  });

  test('a pause event of an import stays until the count moves again', () async {
    final events = StreamController<ImportEvent>();
    addTearDown(events.close);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      downloadsProvider.overrideWith(_Downloads.new),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
      importEventsProvider.overrideWith((ref) => events.stream),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    final playlistId = await db.into(db.playlists).insert(PlaylistsCompanion.insert(name: 'L', createdAt: 0));
    final importId = await ImportRepository(db).create(
      playlistId: playlistId,
      sourceName: 'Mood',
      rows: const [ImportRow(index: 0, title: 'T', artists: ['A'])],
    );
    ActivityState at(int saved) => ActivityState([
          ActivityItem(kind: ActivityKind.import, key: 'imp-$importId', name: 'Mood', done: saved, total: 50, ref: importId),
        ], const []);
    c.read(_activity.notifier).set(at(3));
    await pumpEventQueue();
    events.add(ImportEvent(ImportEventKind.network, importId));
    await pumpEventQueue();
    c.read(_activity.notifier).set(at(3)); // same count: another tick
    await pumpEventQueue();
    var row = (await db.select(db.activityLogRows).get()).single;
    expect(c.read(activityLogProvider).entries.single.event, ImportEventKind.network);
    expect(row.detail, contains('network'));
    c.read(_activity.notifier).set(at(4)); // runs again
    await pumpEventQueue();
    row = (await db.select(db.activityLogRows).get()).single;
    expect(row.done, 4);
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

  test('the filter counts come from the whole Registro, not from the loaded page', () async {
    Future<void> row(String kind, {int failed = 0, String? detail}) => db
        .into(db.activityLogRows)
        .insert(ActivityLogRowsCompanion.insert(
          at: DateTime.now().millisecondsSinceEpoch,
          kind: kind,
          name: 'n',
          failed: Value(failed),
          detail: Value(detail),
        ));
    for (var i = 0; i < 70; i++) {
      await row('download');
    }
    await row('download', failed: 1);
    await row('scan', failed: 1);
    await row('enrichBackground', failed: 1, detail: '{"noAnswer":true}');
    await row('correction');
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    final s = c.read(activityLogProvider);
    expect(s.entries, hasLength(ActivityLogNotifier.pageSize));
    expect(s.counts, {
      LogFilter.all: 74,
      LogFilter.download: 71,
      LogFilter.library: 1,
      LogFilter.enrich: 1,
      LogFilter.correction: 1,
      LogFilter.errors: 2,
    }, reason: 'a completion that nobody answered is stopped, not an error');
  });

  ActivityLogRow importRow({required int failed, String? detail}) =>
      ActivityLogRow(id: 1, at: 0, kind: 'import', name: 'Spotify', done: 0, total: 0, failed: failed, detail: detail);

  test('an import row whose detail cannot be read follows its failed column, as the counts do', () {
    expect(LogEntry.fromRow(importRow(failed: 1, detail: '{broken')).failed, isTrue);
    expect(LogEntry.fromRow(importRow(failed: 0, detail: '{broken')).failed, isFalse);
  });

  test('a planned import is not an error, in the line or in the counts', () async {
    await db.into(db.activityLogRows).insert(ActivityLogRowsCompanion.insert(
      at: 1, kind: 'import', name: 'Spotify', detail: const Value('{"event":"planned"}')));
    expect(LogEntry.fromRow(importRow(failed: 0, detail: '{"event":"planned"}')).failed, isFalse);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.read(activityLogProvider).counts[LogFilter.errors], 0);
  });

  test('a row written straight to the database shows up by itself, with its id', () async {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.read(activityLogProvider).entries, isEmpty);
    final id = await ActivityLogRepository(db).add(at: 1000, kind: 'correction', name: 'x', detail: '{"old":{"title":"a"},"new":{"title":"b"}}');
    await pumpEventQueue();
    final s = c.read(activityLogProvider);
    expect([s.entries.single.id, s.total, s.counts[LogFilter.correction]], [id, 1, 1]);
    expect(s.entries.single.oldIdent?.title, 'a');
  });

  test('with many pages loaded a new row costs one small read, not the loaded pages again', () async {
    final reads = _Reads();
    final big = AppDatabase(NativeDatabase.memory().interceptWith(reads));
    addTearDown(big.close);
    final repo = ActivityLogRepository(big);
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 120; i++) {
      await repo.add(at: base + i, kind: 'scan', name: 'n$i');
    }
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(big),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    final log = c.read(activityLogProvider.notifier);
    await log.loadMore();
    await log.loadMore();
    expect(c.read(activityLogProvider).entries, hasLength(120));
    reads.rows = 0;
    final id = await repo.add(at: base + 500, kind: 'scan', name: 'new');
    await pumpEventQueue();
    final s = c.read(activityLogProvider);
    expect(reads.rows, 1);
    expect([s.entries.first.id, s.entries.length, s.total, s.counts[LogFilter.all]], [id, 121, 121, 121]);
  });

  test('prune drops the old rows at start and again when asked, and the lines follow', () async {
    final repo = ActivityLogRepository(db);
    await repo.add(at: 1, kind: 'scan', name: 'old');
    await repo.add(at: DateTime.now().millisecondsSinceEpoch, kind: 'scan', name: 'new');
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    expect(c.read(activityLogProvider).entries.map((e) => e.item!.name), ['new']);
    await repo.add(at: 2, kind: 'scan', name: 'old too');
    await pumpEventQueue();
    await c.read(activityLogProvider.notifier).prune();
    expect(c.read(activityLogProvider).entries.map((e) => e.item!.name), ['new']);
    expect(c.read(activityLogProvider).total, 1);
  });

  test('prune with several pages loaded reads them all again, not only the first', () async {
    final repo = ActivityLogRepository(db);
    final base = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < 120; i++) {
      await repo.add(at: base + i, kind: 'scan', name: 'n$i');
    }
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    final log = c.read(activityLogProvider.notifier);
    await log.loadMore();
    await repo.add(at: 1, kind: 'scan', name: 'old');
    await pumpEventQueue();
    await log.prune();
    final s = c.read(activityLogProvider);
    expect(s.total, 120);
    expect(s.entries.length, greaterThan(ActivityLogNotifier.pageSize));
  });

  test('rows with the same time that arrive later are put newest id first', () async {
    final repo = ActivityLogRepository(db);
    final at = DateTime.now().millisecondsSinceEpoch;
    final first = await repo.add(at: at, kind: 'scan', name: 'a');
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    final second = await repo.add(at: at, kind: 'scan', name: 'b');
    await pumpEventQueue();
    final third = await repo.add(at: at, kind: 'scan', name: 'c');
    await pumpEventQueue();
    expect(c.read(activityLogProvider).entries.map((e) => e.id), [third, second, first]);
  });

  test('a second opinion line belongs to Arricchimento', () {
    expect(LogEntry.categoryOfKind('secondOpinion'), LogFilter.enrich);
  });

  test('the counts stay those of the whole Registro after add and after loadMore', () async {
    for (var i = 1; i <= 120; i++) {
      await db.into(db.activityLogRows).insert(ActivityLogRowsCompanion.insert(
        at: DateTime.now().millisecondsSinceEpoch + i, kind: 'scan', name: 'n$i', failed: Value(i == 1 ? 1 : 0)));
    }
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      activityProvider.overrideWith((ref) => ref.watch(_activity)),
    ]);
    addTearDown(c.dispose);
    c.listen(activityLogProvider, (_, _) {});
    await pumpEventQueue();
    final log = c.read(activityLogProvider.notifier);
    await log.add(LogEntry(
      at: DateTime.now().add(const Duration(days: 1)),
      item: const ActivityItem(kind: ActivityKind.download, key: 'd', name: 'x', running: false, failed: true),
    ));
    var counts = c.read(activityLogProvider).counts;
    expect(counts[LogFilter.all], 121);
    expect(counts[LogFilter.download], 1);
    expect(counts[LogFilter.library], 120);
    expect(counts[LogFilter.errors], 2);
    await log.loadMore();
    expect(c.read(activityLogProvider).entries.length, greaterThan(ActivityLogNotifier.pageSize));
    counts = c.read(activityLogProvider).counts;
    expect(counts[LogFilter.all], 121);
    expect(counts[LogFilter.library], 120);
    expect(counts[LogFilter.errors], 2);
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

  group('groupLog', () {
    LogEntry dl(DateTime at, {bool failed = false}) => LogEntry(
      at: at,
      item: ActivityItem(kind: ActivityKind.download, key: 'k$at', name: 'S', running: false, failed: failed),
    );
    final today = DateTime(2026, 11, 5, 12);

    test('by local day, newest first; two finished downloads of a day make one row', () {
      final days = groupLog([
        dl(today),
        dl(today.subtract(const Duration(hours: 1)), failed: true),
        dl(today.subtract(const Duration(hours: 2))),
        dl(today.subtract(const Duration(days: 1))),
      ], LogFilter.all);
      expect(days.map((d) => d.day), [DateTime(2026, 11, 5), DateTime(2026, 11, 4)]);
      expect(days[0].rows.map((r) => r.group.length), [2, 0], reason: 'the failed one stays alone');
      expect(days[1].rows.single.group, isEmpty, reason: 'one download is no group');
    });

    test('counts and filters: Errori is every failed line, a correction is its own category', () {
      final fix = LogEntry(
        at: today,
        correction: ActivityLogRow(id: 1, at: 0, kind: 'correction', name: 'n', done: 0, total: 0, failed: 0),
      );
      final fileFail = LogEntry(
        at: today,
        correction: ActivityLogRow(
          id: 2, at: 0, kind: 'correction', name: 'n', done: 0, total: 0, failed: 1, detail: '{"trackId":1,"file":"x"}'),
        detail: const {'trackId': 1, 'file': 'x'},
      );
      final all = [dl(today), dl(today, failed: true), fix, fileFail];
      expect(logCounts(all), {
        LogFilter.all: 4,
        LogFilter.download: 2,
        LogFilter.library: 0,
        LogFilter.enrich: 0,
        LogFilter.correction: 2,
        LogFilter.errors: 2,
      });
      final noAnswer = LogEntry(
        at: today,
        detail: const {'noAnswer': true},
        item: const ActivityItem(kind: ActivityKind.enrichBackground, key: 'b', name: null, running: false, failed: true),
      );
      expect(noAnswer.failed, isFalse);
      expect(noAnswer.stopped, isTrue);
      expect(fileFail.revertible, isFalse, reason: 'no old/new to put back');
      expect(groupLog(all, LogFilter.errors).single.rows, hasLength(2));
    });
  });
}

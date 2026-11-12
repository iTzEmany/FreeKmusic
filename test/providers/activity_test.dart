import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/activity_log_providers.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/import_providers.dart';
import 'package:codecore/providers/podcast_ops.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/providers/radio_ops.dart';
import 'package:codecore/providers/radio_providers.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/podcast_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/scanner/library_scanner.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:codecore/services/import/playlist_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  YtResult yt(String id) =>
      YtResult(id: id, title: 'Titolo $id', channel: 'C', duration: null);

  test('an import is one item with the songs saved and the total; its downloads do not appear', () {
    const imp = ImportProgress(
        id: 7, playlistId: 1, name: 'Liked Songs', total: 2253, done: 120, saved: 100, review: 0, missing: 20, paused: false, blockIds: [7]);
    DownloadItem dl(int id, DownloadStatus st, String? tag) => DownloadItem(id: id, result: yt('$id'), status: st, tag: tag);
    final s = buildActivity(
      scan: const ScanState(),
      enrich: const EnrichJobState(),
      downloads: [
        dl(1, DownloadStatus.downloading, 'import:7:0'),
        dl(2, DownloadStatus.done, 'import:7:1'),
        dl(3, DownloadStatus.done, null),
      ],
      outgoing: const [],
      imports: const [imp],
    );
    final item = s.running.single;
    expect((item.kind, item.name, item.done, item.total), (ActivityKind.import, 'Liked Songs', 100, 2253));
    expect(s.completed.map((c) => c.ref), [3], reason: 'only the download that is not an import row');
  });

  test('nothing running → empty', () {
    final s = buildActivity(
      scan: const ScanState(),
      enrich: const EnrichJobState(),
      downloads: const [],
      outgoing: const [],
    );
    expect(s.isEmpty, isTrue);
  });

  test('scan, enrichment, downloads and transfers are aggregated', () {
    final offer = OutgoingOffer(
      offerId: 'o',
      toId: 'x',
      toName: 'Telefono',
      token: 't',
      entries: {},
    );
    final done = OutgoingOffer(
      offerId: 'p',
      toId: 'x',
      toName: 'PC',
      token: 't',
      entries: {},
    )..status = OfferStatus.done;
    final s = buildActivity(
      scan: const ScanState(
        running: true,
        progress: ScanProgress(done: 10, total: 40),
      ),
      enrich: const EnrichJobState(
        running: true,
        progress: EnrichJobResult(done: 1, total: 4),
      ),
      downloads: [
        DownloadItem(
          id: 1,
          result: yt('a'),
          status: DownloadStatus.downloading,
          progress: 0.5,
        ),
        DownloadItem(id: 2, result: yt('b'), status: DownloadStatus.done),
        DownloadItem(id: 3, result: yt('c'), status: DownloadStatus.failed),
      ],
      outgoing: [offer, done],
    );
    expect(s.running.map((e) => e.kind), [
      ActivityKind.scan,
      ActivityKind.enrich,
      ActivityKind.download,
      ActivityKind.transfer,
    ]);
    expect(s.running.first.progress, 0.25);
    expect(s.running[2].progress, 0.5);
    expect(s.completed.length, 3);
    expect(s.completed.where((e) => e.failed).length, 1);
    expect(s.running[2].cancellable, isTrue);
    expect(s.running.first.cancellable, isFalse);
  });

  test('a download waiting to retry is still running and says when', () {
    final s = buildActivity(
      scan: const ScanState(),
      enrich: const EnrichJobState(),
      downloads: [
        DownloadItem(
          id: 1,
          result: yt('a'),
          status: DownloadStatus.waitingRetry,
          attempt: 2,
          retryDelay: const Duration(seconds: 20),
        ),
      ],
      outgoing: const [],
    );
    final item = s.running.single;
    expect(item.kind, ActivityKind.download);
    expect(item.retryDelaySec, 20);
    expect(item.done, 2);
    expect(item.total, 3);
    expect(item.cancellable, isTrue);
    expect(s.completed, isEmpty);
  });

  test(
    'the downloads of an import are not items: its one line counts them',
    () {
      const r = YtResult(
        id: 'v',
        title: 'Song',
        channel: 'Band',
        duration: null,
      );
      final s = buildActivity(
        scan: const ScanState(),
        enrich: const EnrichJobState(),
        downloads: [
          DownloadItem(
            id: 1,
            result: r,
            status: DownloadStatus.downloading,
            tag: importTag(4, 2),
          ),
          const DownloadItem(
            id: 2,
            result: r,
            status: DownloadStatus.downloading,
          ),
          DownloadItem(
            id: 3,
            result: r,
            status: DownloadStatus.done,
            tag: importTag(4, 3),
          ),
        ],
        outgoing: const [],
      );
      expect(s.running.map((a) => a.key), ['dl-2']);
      expect(s.completed, isEmpty, reason: 'the import has its own line in the Registro');
    },
  );

  test('«Controlla ora» is a running line that cannot be cancelled', () {
    final s = buildActivity(
      scan: const ScanState(),
      enrich: const EnrichJobState(),
      downloads: const [],
      outgoing: const [],
      releases: true,
    );
    expect(s.running.single.kind, ActivityKind.releases);
    expect(s.running.single.cancellable, isFalse);
  });

  group('the podcast refresh and the radio check', () {
    late AppDatabase db;
    late ProviderContainer c;
    var radioAsks = true;
    var radioOk = true;
    var feedsFailed = false;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      c = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          activityProvider.overrideWithValue(const ActivityState([], [])),
          importEventsProvider.overrideWith((ref) => const Stream.empty()),
          // Like the real one: the flag goes up only for a real request.
          radioRefreshProvider.overrideWithValue(() async {
            if (radioAsks) c.read(radioCheckingProvider.notifier).set(true);
            return radioOk;
          }),
          podcastServiceProvider.overrideWithValue(_Service(() => feedsFailed)),
        ],
      );
      c.listen(activityLogProvider, (_, _) {});
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    Future<List<LogEntry>> entries() async {
      await pumpEventQueue();
      return c.read(activityLogProvider).entries;
    }

    test(
      'a real radio request raises the flag, lowers it and logs how it went',
      () async {
        radioAsks = true;
        radioOk = false;
        expect(await c.read(radioOpsProvider).refreshSaved(), isFalse);
        expect(c.read(radioCheckingProvider), isFalse);
        final e = await entries();
        expect(e.single.item!.kind, ActivityKind.radio);
        expect(e.single.failed, isTrue);
      },
    );

    test(
      'no request (not due, or offline before asking) leaves no line',
      () async {
        radioAsks = false;
        radioOk = false;
        await c.read(radioOpsProvider).refreshSaved();
        expect(await entries(), isEmpty);
      },
    );

    test('the podcast refresh logs a failed line when a feed failed, a good one otherwise', () async {
      feedsFailed = true;
      await c.read(podcastOpsProvider).refreshAll();
      feedsFailed = false;
      await c.read(podcastOpsProvider).refreshAll();
      expect(c.read(podcastRefreshingProvider), isFalse);
      expect((await entries()).map((e) => e.failed), [false, true]);
    });
  });
}

class _Service implements PodcastService {
  _Service(this.failed);

  final bool Function() failed;

  @override
  Future<RefreshReport> refreshAll() async {
    final r = RefreshReport();
    if (failed()) r.failed[1] = PodcastException(PodcastErrorKind.network, 'x');
    return r;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

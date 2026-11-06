import 'dart:async';

import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/activity_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/online_providers.dart' show EnrichJobState;
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/podcast/episode_downloader.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/native.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the real downloader: each episode finishes when its gate opens.
class _Gated extends EpisodeDownloader {
  _Gated(PodcastRepository repo, TrackRepository tracks)
      : super(repo: repo, tracks: tracks, tags: _NoTags(), baseDir: '/tmp/none');

  final gates = <int, Completer<int?>>{};
  final started = <int>[];
  final cancelled = <int>[];

  @override
  Future<int?> download(int episodeId,
      {dynamic cancel, void Function(int received, int total)? onProgress}) {
    started.add(episodeId);
    onProgress?.call(50, 100);
    cancel.whenCancel.then((_) {
      cancelled.add(episodeId);
      gates[episodeId]?.complete(null);
    });
    return (gates[episodeId] = Completer<int?>()).future;
  }
}

class _NoTags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => const TagInfo();
}

void main() {
  late AppDatabase db;
  late _Gated downloader;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    downloader = _Gated(PodcastRepository(db), TrackRepository(db));
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      episodeDownloaderProvider.overrideWith((ref) async => downloader),
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  PodcastDownloadsNotifier notifier() => c.read(podcastDownloadsProvider.notifier);
  Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));
  EpisodeDownload of(int id) => c.read(podcastDownloadsProvider).firstWhere((d) => d.episodeId == id);

  test('cancelAll stops the running downloads of the given episodes only', () async {
    notifier().add(1, 'a');
    notifier().add(2, 'b');
    await tick();
    notifier().cancelAll([1, 3]);
    await tick();
    expect(downloader.cancelled, [1]);
  });

  test('two at a time, the rest wait their turn', () async {
    for (final id in [1, 2, 3]) {
      notifier().add(id, 'Episode $id');
    }
    await tick();
    expect(downloader.started, [1, 2]);
    expect(of(1).status, EpisodeDownloadStatus.downloading);
    expect(of(3).status, EpisodeDownloadStatus.queued);
    expect(of(1).progress, 0.5);

    downloader.gates[1]!.complete(10);
    await tick();
    expect(of(1).status, EpisodeDownloadStatus.done);
    expect(downloader.started, [1, 2, 3], reason: 'a place freed, the third starts');
  });

  test('asking for the same episode twice while it is on its way does nothing', () async {
    notifier().add(1, 'One');
    notifier().add(1, 'One');
    await tick();
    expect(c.read(podcastDownloadsProvider), hasLength(1));
    expect(downloader.started, [1]);
  });

  test('cancelling drops the entry and starts the next one', () async {
    for (final id in [1, 2, 3]) {
      notifier().add(id, 'Episode $id');
    }
    await tick();
    notifier().cancel(1);
    await tick();
    expect(downloader.cancelled, [1]);
    expect(c.read(podcastDownloadsProvider).map((d) => d.episodeId), [2, 3]);
    expect(downloader.started, [1, 2, 3]);
  });

  test('a failure is kept with its reason; the others go on', () async {
    notifier().add(1, 'One');
    notifier().add(2, 'Two');
    await tick();
    downloader.gates[1]!.completeError(const PodcastException(PodcastErrorKind.unsupportedFormat));
    downloader.gates[2]!.complete(5);
    await tick();
    expect(of(1).status, EpisodeDownloadStatus.failed);
    expect(of(1).error, PodcastErrorKind.unsupportedFormat);
    expect(of(2).status, EpisodeDownloadStatus.done);
  });

  test('«Pulisci» forgets the finished ones and keeps those still running', () async {
    notifier().add(1, 'One');
    notifier().add(2, 'Two');
    await tick();
    downloader.gates[1]!.complete(5);
    await tick();
    notifier().clearFinished();
    expect(c.read(podcastDownloadsProvider).map((d) => d.episodeId), [2]);
  });

  test('a finished episode can be fetched again as a new entry', () async {
    notifier().add(1, 'One');
    await tick();
    final first = of(1).serial;
    downloader.gates[1]!.complete(5);
    await tick();
    notifier().add(1, 'One');
    await tick();
    expect(of(1).serial, greaterThan(first));
    expect(of(1).status, EpisodeDownloadStatus.downloading);
  });

  group('in the Activity centre', () {
    ActivityState build(List<EpisodeDownload> eps) => buildActivity(
          scan: const ScanState(),
          enrich: const EnrichJobState(),
          downloads: const <DownloadItem>[],
          outgoing: const <OutgoingOffer>[],
          episodes: eps,
        );

    test('a running episode is a download line with its title and progress, cancellable', () {
      final a = build([
        const EpisodeDownload(
            episodeId: 7, title: 'Big talk', serial: 1, status: EpisodeDownloadStatus.downloading, progress: 0.25),
      ]);
      final item = a.running.single;
      expect(item.kind, ActivityKind.download);
      expect(item.name, 'Big talk');
      expect(item.progress, 0.25);
      expect(item.cancellable, isTrue);
      expect(item.ref, isA<PodcastDownloadRef>().having((r) => r.episodeId, 'id', 7));
    });

    test('finished and failed ones go to the completed list; a second download of one episode has another key', () {
      final a = build([
        const EpisodeDownload(episodeId: 1, title: 'A', serial: 1, status: EpisodeDownloadStatus.done),
        const EpisodeDownload(episodeId: 2, title: 'B', serial: 2, status: EpisodeDownloadStatus.failed),
        const EpisodeDownload(episodeId: 1, title: 'A', serial: 3, status: EpisodeDownloadStatus.queued),
      ]);
      expect(a.completed.map((i) => i.failed), [false, true]);
      expect(a.running.single.key, isNot(a.completed.first.key));
    });
  });
}

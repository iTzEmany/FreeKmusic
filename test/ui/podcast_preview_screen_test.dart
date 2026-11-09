import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/podcast/episode_downloader.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/providers/podcast_discover_providers.dart';
import 'package:codecore/ui/screens/podcast/podcast_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _NoTags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => const TagInfo();
}

class _Downloader extends EpisodeDownloader {
  _Downloader(PodcastRepository repo, TrackRepository tracks)
      : super(repo: repo, tracks: tracks, tags: _NoTags(), baseDir: '/tmp/none');
  final deleted = <int>[];
  @override
  Future<void> deleteFile(int episodeId) async => deleted.add(episodeId);
}

class _Downloads extends PodcastDownloadsNotifier {
  final cancelledAll = <int>[];
  @override
  void cancelAll(Iterable<int> ids) => cancelledAll.addAll(ids);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('«Segui» follows the show and turns into «Segui già»; touched again it unfollows', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    const listing = PodcastListing(origin: PodcastOrigin.apple, title: 'Show', feedUrl: 'https://x/feed');
    const preview = PodcastPreview(
      feedUrl: 'https://x/feed',
      feed: PodcastFeed(title: 'Show', episodes: [PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'https://x/1.mp3')]),
    );
    await h.pump(tester, const PodcastPreviewScreen(listing: listing), extraOverrides: [
      podcastPreviewProvider.overrideWith((ref, key) async => preview),
      podcastCoverSaverProvider.overrideWithValue((id, url) async => null),
    ]);
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settle();
    expect(find.text('Segui'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('follow')));
    await settle();
    expect(find.text('Segui già'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('follow')));
    await settle();
    expect(find.text('Segui'), findsOneWidget);
    // Let drift's stream timers go before the test ends.
    await tester.pumpWidget(const SizedBox());
    await settle();
  });

  /// A followed show opened as a preview, optionally with one downloaded episode; taps «Segui già».
  Future<({_Downloader dl, _Downloads downloads, PodcastRepository repo, int podcastId})> unfollow(
      WidgetTester tester, {required bool downloaded}) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final repo = PodcastRepository(h.db);
    const feed = PodcastFeed(
      title: 'Show',
      episodes: [PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'https://x/1.mp3')],
    );
    final id = await repo.subscribe('https://x/feed', feed, now: 1);
    if (downloaded) {
      final ep = await h.db.select(h.db.podcastEpisodes).getSingle();
      final t = await h.db.into(h.db.tracks).insert(TracksCompanion.insert(
          path: '/p/e.mp3', title: 'One', albumKey: 'podcast|$id', format: 'mp3', sizeBytes: 1,
          mtimeMs: 1, addedAt: 1, kind: const Value(1)));
      await repo.setTrackId(ep.id, t);
    }
    final dl = _Downloader(repo, TrackRepository(h.db));
    final downloads = _Downloads();
    await h.pump(
        tester,
        const PodcastPreviewScreen(
            listing: PodcastListing(origin: PodcastOrigin.apple, title: 'Show', feedUrl: 'https://x/feed')),
        extraOverrides: [
          podcastPreviewProvider.overrideWith((ref, key) async =>
              const PodcastPreview(feedUrl: 'https://x/feed', feed: feed)),
          episodeDownloaderProvider.overrideWith((ref) async => dl),
          podcastDownloadsProvider.overrideWith(() => downloads),
        ]);
    await _settle(tester);
    expect(find.text('Segui già'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('follow')));
    await _settle(tester);
    return (dl: dl, downloads: downloads, repo: repo, podcastId: id);
  }

  Future<void> end(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
  }

  testWidgets('a show saved but not followed: its episodes show where they were left and what was heard', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final repo = PodcastRepository(h.db);
    const feed = PodcastFeed(title: 'Show', episodes: [
      PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'https://x/1.mp3'),
      PodcastEpisodeInfo(guid: 'e2', title: 'Two', audioUrl: 'https://x/2.mp3'),
      PodcastEpisodeInfo(guid: 'e3', title: 'Three', audioUrl: 'https://x/3.mp3'),
    ]);
    final id = await repo.subscribe('https://x/feed', feed, now: 1, followed: false);
    final e1 = (await repo.episodeByGuid(id, 'e1'))!;
    final t = await h.db.into(h.db.tracks).insert(TracksCompanion.insert(
        path: 'https://x/1.mp3', title: 'One', albumKey: 'podcast|$id', format: 'mp3', sizeBytes: 0, mtimeMs: 0,
        addedAt: 1, durationMs: const Value(3600000), kind: const Value(1), resumePositionMs: const Value(212417)));
    await repo.setTrackId(e1.id, t);
    await repo.markPlayed((await repo.episodeByGuid(id, 'e2'))!.id, true, now: 1);
    await h.pump(
        tester,
        const PodcastPreviewScreen(
            listing: PodcastListing(origin: PodcastOrigin.apple, title: 'Show', feedUrl: 'https://x/feed')),
        extraOverrides: [
          podcastPreviewProvider.overrideWith((ref, key) async =>
              const PodcastPreview(feedUrl: 'https://x/feed', feed: feed)),
        ]);
    await _settle(tester);
    expect(find.text('riprendi da 3:32'), findsOneWidget);
    expect(find.text('Ascoltato'), findsOneWidget);
    expect(find.text('Segui'), findsOneWidget, reason: 'still not followed');
    await tester.pumpWidget(const SizedBox());
    await _settle(tester);
  });

  testWidgets('unfollowing with downloads asks; «Tieni» deletes nothing', (tester) async {
    final r = await unfollow(tester, downloaded: true);
    expect(find.text('Smettere di seguire?'), findsOneWidget);
    await tester.tap(find.text('Tieni'));
    await _settle(tester);
    expect(r.dl.deleted, isEmpty);
    expect((await tester.runAsync(() => r.repo.byId(r.podcastId)))!.followed, isFalse);
    await end(tester);
  });

  testWidgets('unfollowing with downloads: «Cancella» deletes them and cancels the running ones', (tester) async {
    final r = await unfollow(tester, downloaded: true);
    await tester.tap(find.text('Cancella'));
    await _settle(tester);
    expect(r.dl.deleted, hasLength(1));
    expect(r.downloads.cancelledAll, hasLength(1));
    expect((await tester.runAsync(() => r.repo.byId(r.podcastId)))!.followed, isFalse);
    await end(tester);
  });

  testWidgets('unfollowing without downloads does not ask', (tester) async {
    final r = await unfollow(tester, downloaded: false);
    expect(find.text('Smettere di seguire?'), findsNothing);
    expect((await tester.runAsync(() => r.repo.byId(r.podcastId)))!.followed, isFalse);
    await end(tester);
  });
}

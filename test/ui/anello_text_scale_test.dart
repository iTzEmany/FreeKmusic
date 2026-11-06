import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/data/repositories/tag_repository.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/podcast_discover_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/ui/screens/jam/jam_screen.dart';
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/library/review_screen.dart';
import 'package:codecore/ui/screens/memory/memory_screen.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/screens/online/artist_page_screen.dart';
import 'package:codecore/ui/screens/podcast/podcast_detail_screen.dart';
import 'package:codecore/ui/screens/podcast/podcasts_screen.dart';
import 'package:codecore/ui/screens/releases/new_releases_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/screens/stats/stats_screen.dart';
import 'package:codecore/ui/screens/tags/tags_screen.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';
import '../support/memory_fakes.dart';
import '../support/results_host.dart';
import '../support/search_input.dart';

/// Every screen of the redesign at 150 % text, 360x780, in the three themes:
/// nothing may overflow, and every block label stays inside the screen.
class _FakeJam extends JamController {
  @override
  JamUiState build() => const JamUiState(
        phase: JamPhase.active,
        role: JamRole.host,
        peerName: 'Telefono con un nome molto lungo',
        peerId: 'peer',
        jam: JamState(
          version: 1,
          items: [
            JamItem(id: 1, ownerDeviceId: 'host', title: 'Una canzone dal titolo davvero lungo', ext: 'mp3', artist: 'Band', durationMs: 180000),
          ],
          currentIndex: 0,
          playing: true,
          hostDeviceId: 'host',
          outputDeviceId: 'host',
        ),
      );
}

void main() {
  final themes = <String, CcColors>{
    'Notte viola': CcColors.notte.copyWith(accent: const Color(0xFF9B7BFF)),
    'OLED ambra': CcColors.oled.copyWith(accent: const Color(0xFFFFB300)),
    'Chiaro rosa': CcColors.chiaro.copyWith(accent: const Color(0xFFE91E63)),
  };
  // Built after seeding: the podcast id and the jam override come from it.
  final screens = <String, Widget Function(int podcastId)>{
    'Stats': (_) => const StatsScreen(),
    'Review': (_) => const ReviewScreen(),
    'NewReleases': (_) => const NewReleasesScreen(),
    'Podcasts': (_) => const PodcastsScreen(),
    'PodcastDetail': (id) => PodcastDetailScreen(podcastId: id),
    'Memory': (_) => const MemoryScreen(),
    'TagTracks': (_) => const TagTracksScreen(name: 'Live'),
    'QueueSheet': (_) => QueueSheet(scrollController: ScrollController()),
    'Jam': (_) => const JamScreen(),
    'AllTracks': (_) => const AllTracksScreen(),
    'Settings': (_) => const SettingsScreen(),
  };
  for (final t in themes.entries) {
    for (final s in screens.entries) {
      testWidgets('${s.key} at 150 % in ${t.key}', (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final h = await Harness.create(tester, tracks: 6);
        // Real data, so the real layouts are drawn: a tag with tracks, a queue,
        // a podcast with an author, an active jam. Search and the online artist
        // page are not here (plan 2.4).
        final podcastId = (await tester.runAsync(() async {
          final ids = [for (final r in await h.db.select(h.db.tracks).get()) r.id];
          final tag = await TagRepository(h.db).create('Live');
          await TagRepository(h.db).assign(ids, tag);
          await h.handler.playQueue(ids, 0);
          return PodcastRepository(h.db).subscribe(
            'https://x/feed',
            const PodcastFeed(title: 'Un podcast con un titolo molto lungo', author: 'Autrice Lunga', episodes: []),
            now: 1,
          );
        }))!;
        await h.pump(tester, Scaffold(body: s.value(podcastId)),
            textScale: 1.5, colors: t.value, extraOverrides: [
              jamProvider.overrideWith(_FakeJam.new),
              // Never a request to Apple from the Podcasts page.
              podcastGenresProvider.overrideWith((ref) async => const []),
              podcastChartProvider.overrideWith((ref, genre) async => const []),
            ]);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        for (final blocks in find.byWidgetPredicate((w) => w is SegmentedBlocks).evaluate()) {
          for (final text in find.descendant(of: find.byWidget(blocks.widget), matching: find.byType(Text)).evaluate()) {
            final r = tester.getRect(find.byWidget(text.widget));
            expect(r.left, greaterThanOrEqualTo(0));
            expect(r.right, lessThanOrEqualTo(360), reason: 'a block label leaves the screen');
          }
        }
        await h.dispose(tester);
      });
    }
  }

  // The matrix above renders Memoria on an unselected tab (empty). Here it is
  // shown for real, tall enough that every section is laid out.
  for (final t in themes.entries) {
    testWidgets('Memory (shown) at 150 % in ${t.key}', (tester) async {
      tester.view.physicalSize = const Size(360, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await tester.runAsync(() => seedMemory(h.db,
          playlistName: 'Una playlist con un nome davvero molto molto lungo da non stare in una riga',
          suffix: ' con un titolo lunghissimo che non entra in una riga'));
      await h.pump(tester, const MemoryScreen(),
          textScale: 1.5, colors: t.value, extraOverrides: memoryOverrides(FakeMemoryActions(), memoryDisk));
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Svuota cache'), findsOneWidget);
      expect(find.text('Mai ascoltati'), findsOneWidget);
      expect(find.text('Strumenti'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  }

  // Search with results and the online artist page, long names, tall view.
  const longName = 'Un artista dal nome davvero molto molto lungo da non stare in una riga';
  final artistPage = YtmArtistPage(
    ref: const YtmArtistRef(id: 'UCx', name: longName, audience: '25.9M ascoltatori mensili'),
    description: 'Una band inglese. ' * 20,
    shelves: [
      YtmSongShelf('Brani più ascoltati', [ytmSong('s1', 'Una canzone dal titolo lunghissimo che non entra')],
          allSongs: const YtmBrowseLink('VLOLAK', null)),
      const YtmReleaseShelf('Album', [
        YtmRelease(browseId: 'MPREb_1', title: 'Un album dal titolo lunghissimo', subtitle: 'Album • 1979'),
      ], more: YtmBrowseLink('MPAD', 'p')),
      const YtmArtistShelf('Ai fan potrebbe anche piacere', [YtmArtistRef(id: 'UC2', name: 'Roger Waters')]),
    ],
  );
  for (final t in themes.entries) {
    testWidgets('Search results at 150 % in ${t.key}', (tester) async {
      tester.view.physicalSize = const Size(360, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 4);
      await h.pump(tester, const ResultsHost(), textScale: 1.5, colors: t.value);
      typeSearch(tester, 'Song');
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.text('Brani'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });

    testWidgets('Online artist page at 150 % in ${t.key}', (tester) async {
      tester.view.physicalSize = const Size(360, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await h.pump(tester, ArtistPageScreen(artist: artistPage.ref),
          textScale: 1.5,
          colors: t.value,
          extraOverrides: [
            artistPageProvider.overrideWith((ref, id) async => CatalogResult(artistPage, DateTime(2026, 10, 22))),
          ]);
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Brani più ascoltati'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  }
}

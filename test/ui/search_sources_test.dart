import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:codecore/providers/online_collection_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/collection_matcher.dart';
import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/external_links.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/ui/screens/online/online_playlist_screen.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';
import '../support/fake_youtube.dart';
import '../support/search_input.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

class _SongCtrl implements PlayerController {
  final played = <String>[];
  @override
  bool inJam = false;
  @override
  bool isPlayingList(Object key) => false;
  @override
  Future<bool?> playFromSearch({Track? track, YtResult? online}) async {
    played.add(online?.id ?? 'library');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _OneSongReader implements ExternalReader {
  @override
  Future<ExternalCollection> read(ExternalLink link, {CancelToken? cancelToken}) async =>
      const ExternalCollection(
        title: 'Song',
        kind: CollectionKind.playlist,
        sourceUrl: 'https://www.deezer.com/track/1',
        tracks: [ExternalTrack(title: 'Song', artists: ['Band'], key: 'k')],
      );
}

class _OneMatcher implements CollectionMatcher {
  _OneMatcher(this.answer);
  final TrackMatch answer;
  int calls = 0;
  @override
  Stream<(int, TrackMatch)> match(List<ExternalTrack> tracks) {
    calls++;
    return Stream.value((0, answer));
  }

  @override
  void cancel() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Harness h;
  late FakeYoutube svc;

  Future<void> open(WidgetTester tester,
      {int tracks = 2, List<Override> extra = const []}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: tracks);
    svc = FakeYoutube();
    await h.pump(
      tester,
      const SearchScreen(),
      extraOverrides: [
        youtubeServiceProvider.overrideWithValue(svc),
        ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
        ...extra,
      ],
    );
    await _settle(tester);
  }

  Future<void> searchOnline(WidgetTester tester, String text) async {
    typeSearch(tester, text);
    submitSearch(tester);
    await _settle(tester);
  }

  testWidgets(
    'Search is online only: no mode selector, no SoundCloud, nothing asked before the submit',
    (tester) async {
      await open(tester);
      expect(find.byType(SegmentedBlocks<bool>), findsNothing);
      expect(find.text('SoundCloud'), findsNothing);
      expect(
        find.text('YouTube Music'),
        findsNothing,
        reason: 'the filters come with the results',
      );
      typeSearch(tester, 'daft punk');
      await _settle(tester);
      expect(svc.calls, isEmpty);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'Online asks YouTube Music and YouTube together for the same words, once, and nothing else',
    (tester) async {
      await open(tester);
      await searchOnline(tester, 'daft punk');
      expect(
        svc.calls,
        unorderedEquals(['music:daft punk:10', 'youtube:daft punk']),
      );
      expect(find.text('From YouTube Music'), findsOneWidget);
      expect(
        find.text('Altri risultati (1)'),
        findsOneWidget,
        reason: 'the video of another song is less sure',
      );
      await h.dispose(tester);
    },
  );

  testWidgets('submit in the dock field runs the page search once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 2);
    svc = FakeYoutube();
    await h.pump(
      tester,
      const AppShell(),
      extraOverrides: [
        youtubeServiceProvider.overrideWithValue(svc),
        ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
      ],
    );
    await _settle(tester);
    await tester.tap(
      find.descendant(of: find.byType(ShellDock), matching: find.text('Cerca')),
    );
    await _settle(tester);
    final field = find.descendant(
      of: find.byType(ShellDock),
      matching: find.byType(TextField),
    );
    expect(
      find.text('Cerca o incolla un link'),
      findsOneWidget,
      reason: 'online hint',
    );
    await tester.enterText(field, 'daft punk');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await _settle(tester);
    expect(
      svc.calls,
      unorderedEquals(['music:daft punk:10', 'youtube:daft punk']),
    );
    await h.dispose(tester);
  });

  testWidgets(
    'the filter keeps the rows of one source, asks nothing, and a new search starts from «Tutte»',
    (tester) async {
      await open(tester);
      await searchOnline(tester, 'daft punk');
      await tester.tap(find.byKey(const ValueKey('others-chip')));
      await _settle(tester);
      expect(find.text('From YouTube'), findsOneWidget);
      await tester.tap(_filter('YouTube Music'));
      await _settle(tester);
      expect(find.text('From YouTube Music'), findsOneWidget);
      expect(find.text('From YouTube'), findsNothing);
      expect(svc.calls, hasLength(2));

      typeSearch(tester, 'daft punk around');
      submitSearch(tester);
      await _settle(tester);
      expect(
        tester
            .widget<SegmentedBlocks<MediaKind?>>(
              find.byType(SegmentedBlocks<MediaKind?>),
            )
            .selected,
        isNull,
      );
      expect(
        svc.calls,
        hasLength(4),
        reason: 'the new words were asked, both sources',
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    'the info icon next to the title opens the legal explanation and closing leaves Cerca in place',
    (tester) async {
      // Like the Cerca tab: the screen lives in a nested Navigator, the dialog in the root one.
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      h = await Harness.create(tester);
      await h.pump(
        tester,
        Scaffold(
          body: Navigator(
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
          ),
        ),
        extraOverrides: [
          youtubeServiceProvider.overrideWithValue(FakeYoutube()),
          ytmCatalogProvider.overrideWithValue(FakeCatalog((_) async => null)),
        ],
      );
      await _settle(tester);
      final info = find.byIcon(Icons.info_outline_rounded);
      final infoButton = find.ancestor(
        of: info,
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(infoButton).shortestSide, greaterThanOrEqualTo(48));
      await tester.tap(info);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('uso personale'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SearchScreen), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'source filter chips are text only, painted 36 dp, tap area at least 48 dp',
    (tester) async {
      await open(tester);
      await searchOnline(tester, 'daft punk');
      final chips = find.byType(SegmentedBlocks<MediaKind?>);
      expect(chips, findsOneWidget);
      expect(
        find.descendant(of: chips, matching: find.byType(Icon)),
        findsNothing,
      );
      final label = _filter('Tutte');
      final painted = find.ancestor(of: label, matching: find.byType(InkWell));
      final target = find.ancestor(
        of: label,
        matching: find.byType(GestureDetector),
      );
      // Up to 40: the wide test font wraps a label.
      expect(tester.getSize(painted.first).height, inInclusiveRange(36, 40));
      expect(
        target.evaluate().map(
          (e) => tester.getSize(find.byWidget(e.widget)).height,
        ),
        anyElement(greaterThanOrEqualTo(48.0)),
      );
      await h.dispose(tester);
    },
  );

  Future<(_SongCtrl, _OneMatcher)> pasteTrackLink(WidgetTester tester, TrackMatch answer) async {
    final ctrl = _SongCtrl(), matcher = _OneMatcher(answer);
    await open(tester, extra: [
      playerControllerProvider.overrideWithValue(ctrl),
      externalReaderProvider.overrideWith((ref, s) => _OneSongReader()),
      collectionMatcherProvider.overrideWith((ref, page) => matcher),
    ]);
    await searchOnline(tester, 'https://www.deezer.com/track/1');
    return (ctrl, matcher);
  }

  testWidgets('a track link plays its song once, even if the page rebuilds', (tester) async {
    final (ctrl, matcher) = await pasteTrackLink(tester, TrackReady.online(ytmSong('y1', 'Song')));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(ctrl.played, ['y1']);
    expect(matcher.calls, 1);
    expect(find.byType(OnlinePlaylistScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a track link with no match opens a page with that one row', (tester) async {
    final (ctrl, matcher) = await pasteTrackLink(tester, const TrackNotFound());
    await _settle(tester);
    expect(ctrl.played, isEmpty);
    expect(find.byType(OnlinePlaylistScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('notfound-0')), findsOneWidget);
    expect(matcher.calls, 1);
    await h.dispose(tester);
  });
}

/// A block of the source filter (the rows carry the same words).
Finder _filter(String label) => find.descendant(
  of: find.byType(SegmentedBlocks<MediaKind?>),
  matching: find.text(label),
);

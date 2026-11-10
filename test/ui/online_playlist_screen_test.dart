import 'package:codecore/providers/online_collection_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/shuffle_plus/plus_allowed.dart' show ShufflePlusBlock;
import 'package:codecore/ui/screens/online/online_playlist_screen.dart';
import 'package:codecore/ui/screens/youtube/playlist_source_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';
import '../support/fake_youtube.dart';

class _Yt extends FakeYoutube {
  _Yt(this.listing);
  PlaylistListing? listing; // null = fail
  int reads = 0;

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async {
    reads++;
    return listing ?? (throw const YtException(YtErrorKind.network));
  }
}

class _Ctrl implements PlayerController {
  final calls = <String>[];
  @override
  bool inJam = false;
  @override
  Future<void> playOnlineList(List<YtResult> list, {bool shuffle = false, Object? listKey}) async =>
      calls.add('list ${list.map((r) => r.id).join(',')}');
  @override
  Future<ShufflePlusBlock?> cycleListShuffle(Object key, {List<int>? ids, bool plus = true}) async {
    calls.add('toggle plus=$plus');
    return null;
  }

  @override
  bool isPlayingList(Object key) => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

PlaylistListing _listing({bool truncated = false}) => PlaylistListing(
      title: 'Road mix',
      owner: 'Chan',
      truncated: truncated,
      entries: [ytmSong('a', 'First song', seconds: 100), ytmSong('b', 'Second song', seconds: 200)],
    );

void main() {
  late _Ctrl ctrl;

  Future<Harness> show(WidgetTester tester, _Yt yt) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ctrl = _Ctrl();
    final h = await Harness.create(tester);
    await h.pump(tester, const OnlinePlaylistScreen(OnlineCollectionRef.youtubeListing('u')),
        extraOverrides: [
          youtubeServiceProvider.overrideWithValue(yt),
          playerControllerProvider.overrideWithValue(ctrl),
        ]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('shows the header and the songs', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    expect(find.text('Road mix'), findsWidgets);
    expect(find.text('Chan'), findsOneWidget);
    expect(find.text('First song'), findsOneWidget);
    expect(find.text('Second song'), findsOneWidget);
    expect(find.byKey(const ValueKey('playlist-truncated')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('Play plays the list from the first song', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    await tester.tap(find.byKey(const ValueKey('playlist-play')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['list a,b']);
    await h.dispose(tester);
  });

  testWidgets('Shuffle toggles the list shuffle and starts nothing', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    await tester.tap(find.byKey(const ValueKey('playlist-shuffle')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['toggle plus=false']);
    await h.dispose(tester);
  });

  testWidgets('«Scarica» in the menu opens the source sheet', (tester) async {
    final h = await show(tester, _Yt(_listing()));
    await tester.tap(find.byKey(const ValueKey('playlist-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<Object>('playlist-menu-download')));
    await tester.pumpAndSettle();
    expect(find.byType(PlaylistSourceSheet), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an error offers «Riprova», which reads again', (tester) async {
    final yt = _Yt(null);
    final h = await show(tester, yt);
    expect(find.byKey(const ValueKey('error-retry')), findsOneWidget);
    yt.listing = _listing();
    await tester.tap(find.byKey(const ValueKey('error-retry')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pumpAndSettle();
    expect(yt.reads, 2);
    expect(find.text('First song'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a truncated list says so at the bottom', (tester) async {
    final h = await show(tester, _Yt(_listing(truncated: true)));
    expect(find.byKey(const ValueKey('playlist-truncated')), findsOneWidget);
    expect(find.text('Mostro i primi 2 video.'), findsOneWidget);
    await h.dispose(tester);
  });
}

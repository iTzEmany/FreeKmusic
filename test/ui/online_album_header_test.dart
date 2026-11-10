import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/selection_providers.dart' show SelectionKey;
import 'package:codecore/services/shuffle_plus/plus_allowed.dart' show ShufflePlusBlock;
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/online/online_album_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

final _album = YtmAlbum(
  browseId: 'MPREb_wall',
  title: 'The Wall',
  artist: const YtmArtistRef(id: 'UCpf', name: 'Pink Floyd'),
  tracks: [
    YtmAlbumTrack(1, ytmSong('a', 'In the Flesh?', seconds: 199)),
    YtmAlbumTrack(2, ytmSong('b', 'The Thin Ice', seconds: 147)),
  ],
);

class _Ctrl implements PlayerController {
  final calls = <String>[];
  @override
  bool inJam = false;

  @override
  Future<void> playOnlineList(List<YtResult> list, {bool shuffle = false, Object? listKey}) async =>
      calls.add('list ${list.map((r) => r.id).join(',')} key=$listKey');
  @override
  Future<ShufflePlusBlock?> cycleListShuffle(Object key, {List<int>? ids, bool plus = true}) async {
    calls.add('toggle $key plus=$plus');
    return null;
  }
  @override
  bool isPlayingList(Object key) => false;
  @override
  Future<void> enqueueOnline(YtResult r) async => calls.add('enqueue ${r.id}');

  @override
  bool get jamQueueFull => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Downloads extends DownloadsNotifier {
  final adds = <String>[];
  @override
  List<DownloadItem> build() => [];
  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    adds.add('${r.id} ${tag ?? 'plain'}');
    return false;
  }
}

void main() {
  late _Ctrl ctrl;
  late _Downloads downloads;

  Future<Harness> show(WidgetTester tester, {bool jam = false}) async {
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    ctrl = _Ctrl()..inJam = jam;
    downloads = _Downloads();
    final h = await Harness.create(tester);
    await tester.runAsync(() => h.db.customStatement(
        "INSERT INTO playlists (name, created_at, uuid, updated_at) VALUES ('P1', 1, 'u1', 1)"));
    await h.pump(tester, const OnlineAlbumScreen(browseId: 'MPREb_wall'), extraOverrides: [
      onlineAlbumProvider.overrideWith((ref, id) async => CatalogResult(_album, DateTime(2026, 10, 22))),
      playerControllerProvider.overrideWithValue(ctrl),
      downloadsProvider.overrideWith(() => downloads),
    ]);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> menu(WidgetTester tester, String key) async {
    await tester.tap(find.byKey(const ValueKey('album-more')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey<Object>(key)));
    await tester.pumpAndSettle();
  }

  testWidgets('Play and Shuffle send the album in order and open the player', (tester) async {
    final h = await show(tester);
    await tester.tap(find.byKey(const ValueKey('album-play')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['list a,b key=${SelectionKey.ytmAlbumOf('MPREb_wall')}']);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Shuffle is a toggle of the album: it starts nothing (D-534)', (tester) async {
    final h = await show(tester);
    await tester.tap(find.byKey(const ValueKey('album-shuffle')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctrl.calls, ['toggle ${SelectionKey.ytmAlbumOf('MPREb_wall')} plus=false']);
    expect(find.byType(NowPlayingScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('with a Jam on, Play queues the album instead (D-89)', (tester) async {
    final h = await show(tester, jam: true);
    await tester.tap(find.byKey(const ValueKey('album-play')));
    await tester.pumpAndSettle();
    expect(ctrl.calls, ['enqueue a', 'enqueue b']);
    expect(find.byType(NowPlayingScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the ⋮ menu has 4 items; queue, playlist and share run', (tester) async {
    final h = await show(tester);
    await tester.tap(find.byKey(const ValueKey('album-more')));
    await tester.pumpAndSettle();
    for (final k in ['download', 'queue', 'playlist', 'share']) {
      expect(find.byKey(ValueKey<Object>('album-menu-$k')), findsOneWidget, reason: k);
    }
    await tester.tap(find.byKey(const ValueKey<Object>('album-menu-queue')));
    await tester.pumpAndSettle();
    expect(ctrl.calls, ['enqueue a', 'enqueue b']);

    await menu(tester, 'album-menu-playlist');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('P1'));
    await tester.pumpAndSettle();
    expect(downloads.adds.map((e) => e.split(':').first), ['a addto', 'b addto']);

    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.setData') copied = (c.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await menu(tester, 'album-menu-share');
    expect(copied, 'https://music.youtube.com/browse/MPREb_wall');
    await h.dispose(tester);
  });
}

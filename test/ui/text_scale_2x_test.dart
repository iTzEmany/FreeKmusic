import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/screens/playlists/add_tracks_screen.dart';
import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/ui/screens/share/track_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// 2,0x is the cap of the text scale (D-31). Home, genre, Registro, Da confermare
// and Da revisionare have their own 2,0x test; these are the rest of the perimeter.
void main() {
  final screens = <String, (Widget, bool)>{
    'library': (const Scaffold(body: LibraryScreen()), true),
    'all tracks': (const AllTracksScreen(), true),
    'search': (const SearchScreen(), true),
    'queue': (Scaffold(body: QueueSheet(scrollController: ScrollController())), true),
    'empty player': (const NowPlayingScreen(), false),
    'add tracks': (const AddTracksScreen(playlistId: 1), false),
    'track picker': (const TrackPickerScreen(), false),
  };
  for (final e in screens.entries) {
    testWidgets('${e.key} has no overflow at 200% text', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 2);
      if (e.value.$2) {
        final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
        await tester.runAsync(() => h.handler.playQueue(rows!.map((t) => t.id).toList(), 0));
      }
      await h.pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(size: Size(400, 800), textScaler: TextScaler.linear(2.0)),
          child: e.value.$1,
        ),
        locale: const Locale('it'),
      );
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await h.dispose(tester);
    });
  }
}

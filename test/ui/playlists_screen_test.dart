import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/ui/screens/playlists/playlist_detail_screen.dart';
import 'package:codecore/ui/screens/playlists/playlists_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets(
    'the Playlist page lists a playlist, opens it on tap and has no floating buttons',
    (tester) async {
      final h = await Harness.create(tester);
      await tester.runAsync(
        () => h.db
            .into(h.db.playlists)
            .insert(PlaylistsCompanion.insert(name: 'Rock', createdAt: 1)),
      );
      await h.pump(tester, const PlaylistsScreen());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Rock'), findsOneWidget);
      expect(find.text('Playlist di 0 brani'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.tap(find.text('Rock'));
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistDetailScreen), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'a playlist with a blank name shows «Playlist» in the list and on its page',
    (tester) async {
      final h = await Harness.create(tester);
      await tester.runAsync(
        () => h.db
            .into(h.db.playlists)
            .insert(PlaylistsCompanion.insert(name: '  ', createdAt: 1)),
      );
      await h.pump(tester, const PlaylistsScreen());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Playlist'), findsWidgets);
      await tester.tap(find.text('Playlist').last);
      await tester.pumpAndSettle();
      expect(find.byType(PlaylistDetailScreen), findsOneWidget);
      expect(find.text('Playlist'), findsWidgets);
      await h.dispose(tester);
    },
  );
}

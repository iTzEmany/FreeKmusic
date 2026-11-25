import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/ui/screens/activity/activity_log_screen.dart';
import 'package:codecore/ui/screens/daylist/daylist_screen.dart';
import 'package:codecore/ui/screens/history/history_screen.dart';
import 'package:codecore/ui/screens/library/favorites_screen.dart';
import 'package:codecore/ui/screens/library/library_genres_screen.dart';
import 'package:codecore/ui/screens/releases/followed_artists_screen.dart';
import 'package:codecore/ui/screens/stats/stats_screen.dart';
import 'package:codecore/ui/screens/tags/tags_screen.dart';
import 'package:codecore/ui/widgets/page_frame.dart';
import 'package:codecore/ui/widgets/track_table.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import 'package:codecore/data/db/app_database.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Listening and "other" pages on a 1440 px window (157.5): one 1136 px frame, centered.
void main() {
  final pages = <String, Widget Function()>{
    'history': () => const HistoryScreen(),
    'daylist': () => const DaylistScreen(),
    'stats': () => const StatsScreen(),
    'activity log': () => const ActivityLogScreen(),
    'followed artists': () => const FollowedArtistsScreen(),
    'genres': () => const LibraryGenresScreen(),
    'tags': () => const TagsScreen(),
    'favorites': () => const FavoritesScreen(),
  };

  for (final MapEntry(:key, :value) in pages.entries) {
    testWidgets('$key: 1136 px and centered at 1440', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 4);
      await tester.runAsync(() async {
        await PlayHistoryRepository(h.db).start(1, DateTime.now().millisecondsSinceEpoch);
        await (h.db.update(h.db.tracks)..where((t) => t.id.equals(1)))
            .write(const TracksCompanion(isFavorite: Value(true)));
      });
      await h.pump(tester, value());
      await _settle(tester);
      final box = find
          .descendant(of: find.byType(PageFrame), matching: find.byType(ConstrainedBox))
          .first;
      final r = tester.getRect(box);
      expect(r.width, PageFrame.maxWidth);
      expect(r.center.dx, 720);
      if (key == 'favorites') expect(find.byType(TrackTable), findsOneWidget);
      await h.dispose(tester);
    });
  }
}

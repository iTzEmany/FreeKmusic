import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/smart_playlist_repository.dart';
import 'package:codecore/data/repositories/tag_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/ui/screens/library/artist_screen.dart';
import 'package:codecore/ui/screens/search/genre_screen.dart';
import 'package:codecore/ui/screens/smart/smart_playlist_screen.dart';
import 'package:codecore/ui/screens/tags/tags_screen.dart';
import 'package:codecore/ui/widgets/collection_header.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void _expectHeader(WidgetTester tester) {
  expect(find.byType(CollectionHeader), findsOneWidget, reason: 'one header');
  expect(find.byTooltip('Riproduci'), findsOneWidget);
  expect(find.byIcon(Icons.shuffle_rounded), findsOneWidget);
  expect(find.byIcon(Icons.download_rounded), findsNothing, reason: 'files only: nothing to download');
  expect(tester.takeException(), isNull);
}

void main() {
  Future<Harness> start(WidgetTester tester, Widget page, {List<Override> extra = const []}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, page, extraOverrides: extra);
    await _settle(tester);
    return h;
  }

  testWidgets('artist page: one header with Play, Casuale, Scarica and the menu', (tester) async {
    final h = await start(
      tester,
      const ArtistDetailScreen(artist: ArtistSummary(key: 'artist', name: 'Artist', trackCount: 4, albumCount: 2)),
    );
    _expectHeader(tester);
    expect(find.byKey(const ValueKey('artist-more')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('genre page: one header with Play, Casuale and Scarica', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    await tester.runAsync(() => h.db.update(h.db.tracks).write(const TracksCompanion(genre: Value('Rock'))));
    await h.pump(tester, const GenreScreen(genre: 'Rock'),
        extraOverrides: [genreMixProvider.overrideWith((ref, genre) => const Stream.empty())]);
    await _settle(tester);
    _expectHeader(tester);
    await h.dispose(tester);
  });

  testWidgets('tag page: one header with Play, Casuale and Scarica', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await tester.runAsync(() => h.db.transaction(() async {
          final repo = TagRepository(h.db);
          final id = await repo.create('Live');
          final rows = await h.db.select(h.db.tracks).get();
          await repo.assign([for (final t in rows) t.id], id);
        }));
    await h.pump(tester, const TagTracksScreen(name: 'Live'));
    await _settle(tester);
    _expectHeader(tester);
    await h.dispose(tester);
  });

  testWidgets('smart playlist page: one header with Play, Casuale, Scarica and the menu', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    final id = (await tester.runAsync(
      () => SmartPlaylistRepository(h.db, TrackRepository(h.db)).create(name: 'Tutti', rules: 'album:"Album 0"'),
    ))!;
    await h.pump(tester, SmartPlaylistScreen(id: id));
    await _settle(tester);
    _expectHeader(tester);
    // track rows share the same «Altre azioni» tooltip since 152.4, so look in the header only
    expect(find.descendant(of: find.byType(CollectionHeader), matching: find.byTooltip('Altre azioni')), findsOneWidget);
    await h.dispose(tester);
  });
}

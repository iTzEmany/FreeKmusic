import 'package:codecore/ui/screens/search/search_screen.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/online/online_album_screen.dart';
import 'package:codecore/ui/screens/releases/followed_artists_screen.dart';
import 'package:codecore/ui/screens/releases/new_releases_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/releases_support.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _lucio = YtmArtistRef(id: 'UCl', name: 'Lucio Corsi');
const _muse = YtmArtistRef(id: 'UCm', name: 'Muse');

void main() {
  late Harness h;
  late FakeChecks checks;

  Future<void> open(WidgetTester tester,
      {Future<void> Function()? seed, Future<YtmArtistPage> Function(String)? fetch}) async {
    tester.view.physicalSize = const Size(400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester);
    checks = FakeChecks(h.db, h.store, fetch: fetch);
    if (seed != null) await tester.runAsync(seed);
    await h.pump(tester, const NewReleasesScreen(), extraOverrides: [
      checks.override,
      onlineAlbumProvider.overrideWith((ref, id) async => CatalogResult(
            YtmAlbum(browseId: id, title: 'Volevo', artist: _lucio, year: '2026', kindLabel: 'Album', tracks: const []),
            DateTime(2026, 10, 22),
          )),
    ]);
    await _settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await h.dispose(tester);
    checks.dispose();
  }

  testWidgets('without releases: the empty state, «Mai controllato» and the followed count',
      (tester) async {
    await open(tester);
    expect(find.textContaining('Nessuna nuova uscita negli ultimi 90 giorni'), findsOneWidget);
    expect(find.text('Mai controllato'), findsOneWidget);
    expect(find.text('Artisti seguiti (0)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('followed-artists-link')));
    await _settle(tester);
    expect(find.byType(FollowedArtistsScreen), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.textContaining('Non segui ancora nessun artista'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Cerca'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cerca'));
    await _settle(tester);
    expect(find.byType(SearchScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('a release row opens the online album and marks it opened', (tester) async {
    await open(tester, seed: () => seedNewRelease(h.db, _lucio, 'MPREb_1', 'Volevo'));
    expect(find.byKey(const ValueKey('row-dot-MPREb_1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('release-row-MPREb_1')));
    await _settle(tester);
    expect(find.byType(OnlineAlbumScreen), findsOneWidget);
    expect(await tester.runAsync(() => checks.releases.countNew()), 0);
    await close(tester);
  });

  testWidgets('the chips filter the list by artist', (tester) async {
    await open(tester, seed: () async {
      await seedNewRelease(h.db, _lucio, 'MPREb_1', 'Volevo');
      await seedNewRelease(h.db, _muse, 'MPREb_2', 'Will of the People');
    });
    expect(find.text('Volevo'), findsOneWidget);
    expect(find.text('Will of the People'), findsOneWidget);
    expect(
      find.ancestor(of: find.widgetWithText(ChoiceChip, 'Muse'), matching: find.byType(Wrap)),
      findsOneWidget,
      reason: 'artist chips wrap instead of scrolling',
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Muse'));
    await _settle(tester);
    expect(find.text('Volevo'), findsNothing);
    expect(find.text('Will of the People'), findsOneWidget);
    await close(tester);
  });

  testWidgets('«Controlla ora» with YouTube answering 429 says when it will try again', (tester) async {
    await open(
      tester,
      seed: () => checks.follows.follow(_lucio),
      fetch: (_) async => throw const YtException(YtErrorKind.rateLimited, 'HTTP 429'),
    );
    await tester.tap(find.byKey(const ValueKey('check-now')));
    await _settle(tester);
    expect(checks.asked, ['UCl']);
    expect(find.textContaining('YouTube chiede una pausa: riprovo alle'), findsWidgets);
    expect(find.byKey(const ValueKey('check-pause')), findsOneWidget);
    expect(h.store.releasesRetryAt, isNotNull);
    await close(tester);
  });

  testWidgets('«Controlla ora» with nothing new says so and stores the time', (tester) async {
    await open(tester, seed: () => checks.follows.follow(_lucio));
    await tester.tap(find.byKey(const ValueKey('check-now')));
    await _settle(tester);
    expect(find.text('Nessuna nuova uscita'), findsOneWidget);
    expect(find.textContaining('Ultimo controllo:'), findsOneWidget);
    expect(find.text('Mai controllato'), findsNothing);
    await close(tester);
  });

  testWidgets('the library has an «Artisti seguiti» entry that opens the list', (tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 4);
    checks = FakeChecks(h.db, h.store);
    await tester.runAsync(() => checks.follows.follow(_muse));
    await h.pump(tester, const LibraryScreen(), extraOverrides: [checks.override]);
    await _settle(tester);
    expect(find.text('Artisti seguiti'), findsOneWidget);
    expect(find.bySemanticsLabel('Artisti seguiti, 1 artista'), findsOneWidget);
    await tester.tap(find.text('Artisti seguiti'));
    await _settle(tester);
    expect(find.byType(FollowedArtistsScreen), findsOneWidget);
    expect(find.text('Muse'), findsOneWidget);
    await close(tester);
  });

  testWidgets('many artists: 8 chips and «Mostra tutti» reveals the rest', (tester) async {
    await open(tester, seed: () async {
      for (var i = 0; i < 10; i++) {
        await seedNewRelease(h.db, YtmArtistRef(id: 'UC$i', name: 'Artist $i'), 'MPREb_$i', 'Album $i');
      }
    });
    int chips() => find.byType(ChoiceChip).evaluate().length;
    expect(chips(), 9, reason: '«Tutti» and the first 8 artists');
    await tester.ensureVisible(find.text('Mostra tutto'));
    await tester.tap(find.text('Mostra tutto'));
    await _settle(tester);
    expect(chips(), 11);
    expect(find.text('Mostra tutto'), findsNothing);
    await close(tester);
  });
}

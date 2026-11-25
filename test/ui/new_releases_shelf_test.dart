import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/ui/screens/home/home_row.dart' show HomeBlock;
import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/widgets/net_thumbnail.dart';
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

void main() {
  late Harness h;
  late FakeChecks checks;

  Future<void> open(WidgetTester tester, {Future<void> Function()? seed}) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: 4);
    checks = FakeChecks(h.db, h.store);
    if (seed != null) await tester.runAsync(seed);
    await h.pump(tester, const HomeScreen(), extraOverrides: [
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

  testWidgets('«Riprendi» has no releases row until something new is found', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('resume-releases')), findsNothing);
    await close(tester);
  });

  testWidgets('«Riprendi» offers the new releases and the row opens their page', (tester) async {
    await open(tester, seed: () => seedNewRelease(h.db, _lucio, 'MPREb_1', 'Volevo'));
    expect(find.byKey(const ValueKey('resume-releases')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('resume-releases')), matching: find.byType(TextButton)));
    await _settle(tester);
    expect(find.byType(NewReleasesScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('«Nuove uscite» previews the releases as covers and «Tutti» opens the full page', (tester) async {
    await open(tester, seed: () async {
      for (var i = 1; i <= 3; i++) {
        await seedNewRelease(h.db, YtmArtistRef(id: 'UC$i', name: 'Artista $i'), 'MPREb_$i', 'Disco $i');
      }
    });
    final block = find.ancestor(of: find.byKey(const ValueKey('resume-releases')), matching: find.byType(HomeBlock));
    expect(find.descendant(of: block, matching: find.byType(NetThumbnail)), findsNWidgets(3));
    expect(find.descendant(of: block, matching: find.text('Disco 2')), findsOneWidget);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('resume-releases')), matching: find.byType(TextButton)));
    await _settle(tester);
    expect(find.byType(NewReleasesScreen), findsOneWidget);
    await close(tester);
  });

  testWidgets('the top artists card is offered once: «No, grazie» hides it for good', (tester) async {
    await open(tester);
    expect(find.byKey(const ValueKey('top-artists-card')), findsOneWidget);
    expect(find.textContaining('Vuoi sapere quando escono brani nuovi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('top-artists-no')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('top-artists-card')), findsNothing);
    expect(h.store.releasesTopCardSeen, isTrue);
    expect(h.store.releasesTopArtists, isFalse);
    await close(tester);
  });

  testWidgets('«Attiva» turns the option on and the card goes away', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('top-artists-yes')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('top-artists-card')), findsNothing);
    expect(h.store.releasesTopArtists, isTrue);
    expect(h.store.releasesTopCardSeen, isTrue);
    await close(tester);
  });
}

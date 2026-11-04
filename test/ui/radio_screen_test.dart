import 'dart:async';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:codecore/data/repositories/radio_repository.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart' show networkProbeProvider;
import 'package:codecore/providers/radio_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/radio/radio_browser_client.dart';
import 'package:codecore/services/radio/radio_catalog.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/ui/screens/radio/radio_region_sheet.dart';
import 'package:codecore/ui/screens/radio/radio_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

RadioStation st(String id, String name, {String state = 'Lombardia'}) => RadioStation(
    id: id, name: name, streamUrl: 'http://radio.test/$id', state: state, codec: 'MP3', bitrate: 128);

NetworkProbe _probe(bool metered) {
  const channel = MethodChannel('test/net');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel, (call) async => {'metered': metered, 'online': true});
  return NetworkProbe(channel: channel, android: true);
}

final near = [st('n1', 'Radio Vicina Uno'), st('n2', 'Radio Vicina Due')];
final top = [st('t1', 'Radio Nazionale', state: '')];

class _FailingReorder extends RadioRepository {
  _FailingReorder(super.db);

  @override
  Future<void> reorder(List<String> ids) async => throw Exception('disk full');
}

void main() {
  late Harness h;
  late RadioRepository repo;

  Future<void> open(
    WidgetTester tester, {
    String region = 'lombardia',
    List<RadioStation> saved = const [],
    bool stale = false,
    Future<List<RadioStation>> Function(String)? search,
    Future<List<RadioStation>> Function(String)? genre,
    bool metered = false,
    double height = 900,
    double width = 420,
    double textScale = 1,
    bool failReorder = false,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, radio: true);
    repo = RadioRepository(h.db);
    await h.store.writeSettings(
        h.store.readSettings().copyWith(radioCountry: 'IT', radioRegion: region));
    await tester.runAsync(() async {
      for (final s in saved) {
        await repo.save(s);
      }
    });
    await h.pump(tester, const RadioScreen(), textScale: textScale, extraOverrides: [
      if (failReorder) radioRepositoryProvider.overrideWithValue(_FailingReorder(h.db)),
      radioRefreshProvider.overrideWithValue(() async => false),
      networkProbeProvider.overrideWithValue(_probe(metered)),
      radioCountriesProvider.overrideWith(
          (ref) async => [const RadioCountry(name: 'Italy', code: 'IT', stationCount: 1797)]),
      nearYouProvider.overrideWith((ref) async =>
          ref.watch(settingsProvider.select((s) => s.radioRegion)).isEmpty
              ? null
              : RadioList(near, stale: stale, fetchedAt: DateTime(2026, 10, 1))),
      radioCountryStationsProvider.overrideWith((ref) async => RadioList(top)),
      radioSearchProvider.overrideWith((ref, q) => (search ?? (_) async => [near.first])(q)),
      radioGenreProvider.overrideWith((ref, t) => (genre ?? (_) async => [near.last])(t)),
    ]);
    await _settle(tester);
  }

  testWidgets('first visit without a region: the sheet opens and the choice shows in the chip',
      (tester) async {
    await open(tester, region: '');
    expect(find.text('Scegli la regione'), findsWidgets);
    expect(find.text('Radio Vicina Uno'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('region-lombardia')));
    await _settle(tester);
    expect(find.text('Lombardia'), findsOneWidget);
    expect(find.text('Radio Vicina Uno'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('with a region: the sections come in order and «Le mie radio» is hidden when empty',
      (tester) async {
    await open(tester, height: 3000); // the wrapped genres push later sections down
    expect(find.text('Le mie radio'), findsNothing);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Generi'), lessThan(y('Vicino a te')));
    expect(y('Vicino a te'), lessThan(y('Le più ascoltate')));
    expect(find.text('Lombardia'), findsOneWidget);
    expect(find.text('Radio Vicina Uno'), findsOneWidget);
    expect(find.text('Lombardia, MP3, 128 kbps'), findsWidgets);
    await h.dispose(tester);
  });

  testWidgets('a list read from the old copy says when it is from', (tester) async {
    await open(tester, stale: true);
    expect(find.textContaining('Non in linea, elenco del'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a tap plays the list it came from; next goes to the next station', (tester) async {
    await open(tester);
    await tester.tap(find.text('Radio Vicina Uno'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(h.handler.isRadio, isTrue);
    expect(h.backend.loadedUris.single.uri.toString(), 'http://radio.test/n1');
    await tester.runAsync(h.handler.skipToNext);
    expect(h.backend.loadedUris.last.uri.toString(), 'http://radio.test/n2');
    await h.dispose(tester);
  });

  testWidgets('on mobile data the first radio says what it costs, once', (tester) async {
    await open(tester, metered: true);
    await tester.tap(find.text('Radio Vicina Uno'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('La radio usa circa 1 MB al minuto di dati.'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(RadioScreen))).clearSnackBars();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Radio Vicina Due'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('La radio usa circa 1 MB al minuto di dati.'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('on wifi there is no notice', (tester) async {
    await open(tester);
    await tester.tap(find.text('Radio Vicina Uno'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    expect(find.text('La radio usa circa 1 MB al minuto di dati.'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the star saves a station and takes it out again', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.star_border_rounded).first);
    await _settle(tester);
    expect((await tester.runAsync(repo.getAll))!.map((r) => r.stationId), ['n1']);
    expect(find.text('Le mie radio'), findsOneWidget);
    await tester.tap(find.byTooltip('Togli da Le mie radio').first);
    await _settle(tester);
    expect(await tester.runAsync(repo.getAll), isEmpty);
    await h.dispose(tester);
  });

  testWidgets('«Le mie radio» can be reordered by dragging the grip', (tester) async {
    await open(tester, saved: [st('a', 'Prima'), st('b', 'Seconda'), st('c', 'Terza')]);
    expect(find.text('Le mie radio'), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.drag_handle_rounded).first));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 18));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await _settle(tester);
    expect((await tester.runAsync(repo.getAll))!.map((r) => r.stationId), ['b', 'c', 'a']);
    await h.dispose(tester);
  });

  testWidgets('a reorder that fails shows the message and keeps the old order', (tester) async {
    await open(tester,
        saved: [st('a', 'Prima'), st('b', 'Seconda'), st('c', 'Terza')], failReorder: true);
    final gesture = await tester.startGesture(tester.getCenter(find.byIcon(Icons.drag_handle_rounded).first));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 18));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await _settle(tester);
    expect(find.text('Non riesco a salvare il nuovo ordine'), findsOneWidget);
    expect((await tester.runAsync(repo.getAll))!.map((r) => r.stationId), ['a', 'b', 'c']);
    expect(tester.getTopLeft(find.text('Prima')).dy, lessThan(tester.getTopLeft(find.text('Seconda')).dy));
    await h.dispose(tester);
  });

  testWidgets('a saved station that stopped answering is marked', (tester) async {
    await open(tester, saved: [st('a', 'Muta')]);
    await tester.runAsync(() => repo.applyRefresh(const [], ['a']));
    await _settle(tester);
    expect(find.textContaining('non risponde'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('search: two letters, the results replace the sections', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('radio-search')), 'rtl');
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(find.text('Risultati'), findsOneWidget);
    expect(find.text('Vicino a te'), findsNothing);
    expect(find.text('Radio Vicina Uno'), findsOneWidget);
    expect(find.text('Solo Italia'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('search that fails shows the message and «Riprova»', (tester) async {
    await open(tester, search: (_) async => throw const RadioOffline());
    await tester.enterText(find.byKey(const ValueKey('radio-search')), 'rtl');
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(find.text('Non riesco a caricare le radio'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('search without matches says so', (tester) async {
    await open(tester, search: (_) async => const []);
    await tester.enterText(find.byKey(const ValueKey('radio-search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
    expect(find.text('Nessuna radio trovata'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('genres: 4 uniform columns at 360 dp', (tester) async {
    await open(tester, width: 360, height: 3000);
    final x = {
      for (final t in ['pop', 'rock', 'classic rock', 'jazz'])
        tester.getTopLeft(find.byKey(ValueKey('genre-$t'))).dx,
    };
    expect(x.length, 4);
    expect(tester.getSize(find.byKey(const ValueKey('genre-pop'))).height, greaterThanOrEqualTo(56));
    await h.dispose(tester);
  });

  testWidgets('a list that is loading shows a skeleton, not a spinner', (tester) async {
    final never = Completer<List<RadioStation>>();
    await open(tester, genre: (_) => never.future);
    await tester.ensureVisible(find.byKey(const ValueKey('genre-jazz')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('genre-jazz')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('genres at 1.5x text: three columns', (tester) async {
    await open(tester, width: 360, height: 3000, textScale: 1.5);
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('genre-classic rock'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('genre-pop'))).dy);
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('genre-jazz'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey('genre-pop'))).dy));
    await h.dispose(tester);
  });

  testWidgets('clearing the search brings the sections back at once', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('radio-search')), 'rtl');
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Risultati'), findsOneWidget);
    tester.widget<TextField>(find.byType(TextField)).controller!.clear();
    await tester.pump();
    expect(find.text('Risultati'), findsNothing);
    expect(find.text('Generi'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('genres at 2.0x text: two columns, no overflow', (tester) async {
    await open(tester, width: 360, height: 3000, textScale: 2.0);
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.byKey(const ValueKey('genre-rock'))).dx,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey('genre-pop'))).dx));
    expect(
        tester.getTopLeft(find.byKey(const ValueKey('genre-classic rock'))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey('genre-pop'))).dy));
    await h.dispose(tester);
  });

  testWidgets('a genre chip lists that genre and can be closed', (tester) async {
    await open(tester);
    expect(
      find.ancestor(of: find.byKey(const ValueKey('genre-jazz')), matching: find.byType(GridView)),
      findsOneWidget,
    );
    expect(find.textContaining('▾'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('genre-jazz')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('genre-jazz')));
    await _settle(tester);
    expect(find.text('Radio Vicina Due'), findsOneWidget);
    expect(find.text('Chiudi'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await _settle(tester);
    expect(find.text('Vicino a te'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the region sheet changes country and starts the choice again', (tester) async {
    await open(tester);
    await tester.tap(find.text('Lombardia'));
    await _settle(tester);
    expect(find.byKey(const ValueKey('radio-country')), findsOneWidget);
    expect(find.text('Paese: Italia'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('region-piemonte')), 100,
        scrollable: find.descendant(
            of: find.byType(RadioRegionSheet), matching: find.byType(Scrollable)));
    await tester.tap(find.byKey(const ValueKey('region-piemonte')));
    await _settle(tester);
    expect(find.text('Piemonte'), findsOneWidget);
    await h.dispose(tester);
  });
}

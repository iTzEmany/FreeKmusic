import 'package:codecore/providers/ui_providers.dart' show searchPrefillProvider;
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_controls.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/widgets/mini_player.dart';
import 'package:codecore/ui/widgets/radio_now.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

const _a = RadioStation(
    id: 'a',
    name: 'Radio Alfa',
    streamUrl: 'http://radio.test/a',
    homepage: 'http://alfa.test',
    codec: 'MP3',
    bitrate: 128);
const _b = RadioStation(id: 'b', name: 'Radio Beta', streamUrl: 'http://radio.test/b');

void main() {
  late Harness h;

  Future<void> play(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, radio: true);
    await tester.runAsync(() => h.handler.playStations([_a, _b], 0));
    await h.pump(tester, screen);
    await _settle(tester);
  }

  testWidgets('now playing for a radio: station, «In diretta», no seek bar, no shuffle or repeat',
      (tester) async {
    await play(tester, const NowPlayingScreen());
    expect(find.text('Radio Alfa'), findsOneWidget);
    expect(find.text('In diretta'), findsOneWidget);
    expect(find.textContaining('MP3, 128 kbps'), findsOneWidget);
    expect(find.byType(NpSeekRow), findsNothing);
    expect(find.byType(NpLiveRow), findsOneWidget);
    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byTooltip('Salva in Le mie radio'), findsOneWidget);
    expect(find.text('Sito della stazione'), findsOneWidget);
    expect(find.text('R'), findsWidgets); // the initial, there is no favicon
    await h.dispose(tester);
  });

  testWidgets('the title on air takes the place of the name, the station goes below',
      (tester) async {
    await play(tester, const NowPlayingScreen());
    expect(find.text('Cerca questo brano'), findsNothing);
    h.backend.titleC.add('Queen - Radio Ga Ga');
    await _settle(tester);
    expect(find.text('Queen - Radio Ga Ga'), findsOneWidget);
    expect(find.text('Radio Alfa'), findsOneWidget);
    await tester.tap(find.text('Cerca questo brano'));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(NowPlayingScreen)));
    expect(container.read(searchPrefillProvider), 'Queen - Radio Ga Ga');
    await h.dispose(tester);
  });

  testWidgets('the mini-player shows the station and no progress line', (tester) async {
    await play(tester, const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: MiniPlayer())));
    expect(find.text('Radio Alfa'), findsOneWidget);
    expect(find.text('In diretta'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the menu of a radio has only save, search and remove from the queue',
      (tester) async {
    await play(tester, const NowPlayingScreen());
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await _settle(tester);
    expect(find.text('Salva in Le mie radio'), findsWidgets);
    expect(find.text('Rimuovi dalla coda'), findsOneWidget);
    expect(find.text('Aggiungi a playlist…'), findsNothing);
    expect(find.text('Scarica'), findsNothing);
    await h.dispose(tester);
  });
}

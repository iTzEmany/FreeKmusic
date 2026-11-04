import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/shell/desktop_player_bar.dart';
import 'package:codecore/ui/widgets/mini_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

// Nothing plays (D-364): the mini player, the open player and the desktop bar
// keep their place and offer a way to start.

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

/// A queue of [h]'s tracks that played to its end.
Future<void> _endedQueue(WidgetTester t, Harness h) async {
  final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
  final ids = [for (final r in rows!) r.id];
  await t.runAsync(() async {
    await h.handler.playQueue(ids, 0);
    for (var i = 0; i < ids.length; i++) {
      await h.handler.skipToNext();
    }
  });
  expect(h.handler.currentTrack, isNull);
}

Future<void> _tapTooltip(WidgetTester t, String message) async {
  await t.tap(find.byTooltip(message));
  await _settle(t);
}

void main() {
  testWidgets('mini player: the queue ended, it stays and ▶ plays the last queue again', (t) async {
    final h = await Harness.create(t, tracks: 2);
    await _endedQueue(t, h);
    final ids = h.handler.queueIds.toList();
    await h.pump(t, const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: MiniPlayer())));
    await _settle(t);
    expect(find.text('Niente in riproduzione'), findsOneWidget);
    expect(find.text('Ultima coda: Song 0, Artist'), findsOneWidget);
    await _tapTooltip(t, "Riprendi l'ultima coda");
    expect(h.handler.currentTrack?.title, 'Song 0');
    expect(h.handler.queueIds, ids);
    expect(find.text('Niente in riproduzione'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('mini player: no last queue, ▶ is Shuffle+ of the library', (t) async {
    final h = await Harness.create(t, tracks: 3);
    await h.pump(t, const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: MiniPlayer())));
    await _settle(t);
    expect(find.text('Scegli un brano per iniziare'), findsOneWidget);
    await _tapTooltip(t, 'Shuffle+ della libreria');
    expect(h.handler.queueIds, hasLength(3));
    expect(h.handler.shuffleEnabled, isTrue);
    expect(h.handler.currentTrack, isNotNull);
    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('open player: three tiles; a live title; each tile starts something', (t) async {
    final sem = t.ensureSemantics();
    final h = await Harness.create(t, tracks: 3);
    await _endedQueue(t, h);
    await h.pump(t, const NowPlayingScreen());
    await _settle(t);
    expect(find.text("Riprendi l'ultima coda"), findsOneWidget);
    expect(find.text('Shuffle+ della libreria'), findsOneWidget);
    expect(find.text('Ultimi aggiunti'), findsOneWidget);
    expect(t.getSemantics(find.text('Niente in riproduzione')), isSemantics(isLiveRegion: true));

    // «Ultimi aggiunti» plays the newest songs first (D-379).
    await t.tap(find.text('Ultimi aggiunti'));
    await _settle(t);
    expect(h.handler.currentTrack?.title, 'Song 2');
    expect(h.handler.queueIds, hasLength(3));
    sem.dispose();
    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('open player: without a last queue the first tile is not there', (t) async {
    final h = await Harness.create(t, tracks: 2);
    await h.pump(t, const NowPlayingScreen());
    await _settle(t);
    expect(find.text("Riprendi l'ultima coda"), findsNothing);
    await t.tap(find.text('Shuffle+ della libreria'));
    await _settle(t);
    expect(h.handler.queueIds, hasLength(2));
    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('desktop bar: same words, and ▶ plays the last queue again', (t) async {
    final h = await Harness.create(t, tracks: 2);
    await _endedQueue(t, h);
    await h.pump(t, const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: DesktopPlayerBar())));
    await _settle(t);
    expect(find.text('Niente in riproduzione'), findsOneWidget);
    expect(find.text('Ultima coda: Song 0, Artist'), findsOneWidget);
    await _tapTooltip(t, "Riprendi l'ultima coda");
    expect(h.handler.currentTrack?.title, 'Song 0');
    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });
}

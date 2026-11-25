import 'package:codecore/ui/shell/desktop_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester t) async {
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  /// The bar over a queue of [tracks] songs, the first one playing.
  Future<Harness> openBar(WidgetTester t, {int tracks = 3}) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: tracks);
    final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
    await t.runAsync(() => h.handler.playQueue([for (final r in rows!) r.id], 0));
    await h.pump(
      t,
      const Scaffold(
        body: Align(alignment: Alignment.bottomCenter, child: DesktopPlayerBar()),
      ),
    );
    await _settle(t);
    return h;
  }

  Future<void> tapTip(WidgetTester t, String tip) async {
    await t.tap(find.byTooltip(tip));
    await _settle(t);
  }

  testWidgets('play/pause toggles playback', (t) async {
    final h = await openBar(t);
    expect(h.backend.playing, isTrue, reason: 'playQueue starts playing');
    await tapTip(t, 'Pausa');
    expect(h.backend.playing, isFalse);
    await tapTip(t, 'Riproduci');
    expect(h.backend.playing, isTrue);
    await h.dispose(t);
  });

  testWidgets('next and previous move through the queue', (t) async {
    final h = await openBar(t);
    await tapTip(t, 'Brano successivo');
    expect(h.handler.currentIndex, 1);
    expect(find.text('Song 1'), findsWidgets);
    await tapTip(t, 'Brano precedente');
    expect(h.handler.currentIndex, 0);
    await h.dispose(t);
  });

  testWidgets('the heart favourites the playing song', (t) async {
    final h = await openBar(t);
    await tapTip(t, 'Preferito');
    final row = await t.runAsync(
      () => (h.db.select(h.db.tracks)..where((r) => r.title.equals('Song 0'))).getSingle(),
    );
    expect(row!.isFavorite, isTrue);
    expect(find.byTooltip('Rimuovi dai preferiti'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('the volume slider sets the volume, mute zeroes it and restores it', (t) async {
    final h = await openBar(t);
    final volume = find.byType(Slider).last; // the first one is the seek line
    await t.drag(volume, const Offset(-1000, 0));
    await _settle(t);
    expect(h.backend.volumes.last, 0.0);
    await t.tap(volume);
    await _settle(t);
    expect(h.backend.volumes.last, closeTo(0.5, 0.2));
    await tapTip(t, 'Muto');
    expect(h.backend.volumes.last, 0.0);
    await tapTip(t, 'Muto');
    expect(h.backend.volumes.last, greaterThan(0));
    await h.dispose(t);
  });
}

import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/mini_player.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/ui/widgets/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_stream_preparer.dart';

// The horizontal swipe is covered in transitions_characterization_test.dart.
Future<Harness> _shell(WidgetTester t, {double textScale = 1}) async {
  t.view.physicalSize = const Size(360, 800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final h = await Harness.create(t, tracks: 2);
  final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
  await t.runAsync(
      () => h.handler.playQueue(rows!.map((r) => r.id).toList(), 0));
  await h.pump(t, const AppShell(), textScale: textScale);
  await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
  return h;
}

void main() {
  testWidgets('textScale 2.0 on 360 px: mini player and dock do not overflow',
      (t) async {
    final h = await _shell(t, textScale: 2);
    expect(t.takeException(), isNull);
    expect(find.byType(MiniPlayer), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a long title scrolls on one line (D-486)', (t) async {
    final longTitle = 'A very long title ' * 20;
    final h = await Harness.create(t, tracks: 1);
    await t.runAsync(() => h.db.update(h.db.tracks).write(TracksCompanion(title: Value(longTitle))));
    final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
    await t.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(t, const Scaffold(body: MiniPlayer()));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.widgetWithText(MarqueeText, longTitle), findsOneWidget);
    expect(t.widget<Text>(find.text(longTitle)).softWrap, isFalse);
    await h.dispose(t);
  });

  testWidgets('mini player says «Caricamento…» while a stream loads, the artist after', (t) async {
    final h = await Harness.create(t, radio: true);
    final dir = Directory.systemTemp.createTempSync('mini_loading');
    addTearDown(() => dir.deleteSync(recursive: true));
    final online = h.handler.online!;
    final preparer = FakeStreamPreparer(TrackRepository(h.db), dir);
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    final handler = h.handler..preparer = preparer;
    final id = online.register(const YtResult(
        id: 'v1', title: 'Online song', channel: 'Chan', artists: ['Ann'], duration: null));
    await h.pump(t, const Scaffold(body: MiniPlayer()), extraOverrides: [
      onlineEntriesProvider.overrideWithValue(online),
    ]);
    unawaited(handler.playQueue([id], 0));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Online song'), findsOneWidget);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Caricamento…'), findsOneWidget);
    expect(find.text('Ann'), findsNothing);
    expect(find.byKey(const ValueKey('mini-loading')), findsOneWidget);

    gate.complete();
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Caricamento…'), findsNothing);
    expect(find.text('Ann'), findsOneWidget);
    expect(find.byKey(const ValueKey('mini-loading')), findsNothing);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });
}

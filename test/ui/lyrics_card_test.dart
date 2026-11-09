import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_cards.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

String _lrc(int n) => [
  for (var i = 0; i < n; i++) '[00:${(i * 10).toString().padLeft(2, '0')}.00]${i.isEven ? 'A' : 'A much longer line number $i'}',
].join('\n');

void main() {
  Future<Size> sizeOf(
    WidgetTester tester, {
    String? synced,
    String? plain,
    Duration at = Duration.zero,
    required void Function(double width) onWidth,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    final track = await tester.runAsync(() async {
      await h.db.update(h.db.tracks).write(
        TracksCompanion(lyricsSynced: Value(synced), lyricsPlain: Value(plain)),
      );
      return (await h.db.select(h.db.tracks).get()).single;
    });
    final pos = StreamController<Duration>();
    addTearDown(() {
      pos.close(); // not awaited: it never completes when nobody listens (plain text)
    });
    await h.pump(
      tester,
      Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [LyricsCard(track: track!), InfoCard(track: track)],
        ),
      ),
      extraOverrides: [positionProvider.overrideWith((_) => pos.stream)],
    );
    pos.add(at);
    await tester.pump();
    await tester.pump();
    final card = tester.getSize(find.byType(LyricsCard));
    onWidth(tester.getSize(find.byType(InfoCard)).width);
    await h.dispose(tester);
    return card;
  }

  // Every case must give the same height: collected here, compared in the last test.
  final heights = <String, double>{};
  void check(String name, String? synced, String? plain, Duration at) =>
      testWidgets('same width as the other cards: $name', (tester) async {
        var other = 0.0;
        final s = await sizeOf(tester, synced: synced, plain: plain, at: at, onWidth: (w) => other = w);
        expect(s.width, other);
        heights[name] = s.height;
      });

  check('synced, first line', _lrc(8), null, Duration.zero);
  check('synced, last line', _lrc(8), null, const Duration(seconds: 71));
  check('synced, second to last', _lrc(8), null, const Duration(seconds: 61));
  check('plain, short', null, 'one short line', Duration.zero);
  check('plain, long', null, List.filled(12, 'long plain line').join('\n'), Duration.zero);
  check('no lyrics', null, null, Duration.zero);

  test('all cases have the same height', () {
    expect(heights.length, 6);
    expect(heights.values.toSet().length, 1, reason: '$heights');
  });

  testWidgets('with the sync switched off the card shows the plain text', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    final track = await tester.runAsync(() async {
      await h.db.update(h.db.tracks).write(
        const TracksCompanion(lyricsSynced: Value('[00:01.00]Hello\n[00:05.00]World'), lyricsPlain: Value('Plain text here')),
      );
      return (await h.db.select(h.db.tracks).get()).single;
    });
    await h.pump(
      tester,
      Scaffold(body: LyricsCard(track: track!)),
      extraOverrides: [unsyncedLyricsProvider.overrideWith(_Off.new)],
    );
    await tester.pump();
    expect(find.text('Plain text here'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
    await h.dispose(tester);
  });
}

class _Off extends UnsyncedLyricsNotifier {
  @override
  Set<int> build() => {1};
}

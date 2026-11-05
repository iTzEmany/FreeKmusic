import 'dart:async';
import 'dart:io';

import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path/path.dart' as p;
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/shuffle_plus/genre_mix.dart';
import 'package:codecore/ui/screens/search/genre_screen.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/data/db/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

final _noMix = genreMixProvider.overrideWith(
  (ref, genre) => const Stream.empty(),
);

YtResult _song(String id) => YtResult(
  id: id,
  title: 'Online $id',
  channel: 'Chan',
  duration: const Duration(minutes: 3),
  artists: const ['Chan'],
);

void main() {
  testWidgets('genre: title and both pills fit at 360 dp, 200 % text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    await tester.runAsync(
      () => h.db
          .update(h.db.tracks)
          .write(const TracksCompanion(genre: Value('Rock'))),
    );
    await h.pump(
      tester,
      extraOverrides: [_noMix],
      MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(2.0),
        ),
        child: const GenreScreen(genre: 'Rock'),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('collection-name')), findsOneWidget);
    expect(find.text('Riproduci'), findsOneWidget);
    expect(find.text('Casuale'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('genre header has a name and no cover', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    await tester.runAsync(
      () => h.db
          .update(h.db.tracks)
          .write(const TracksCompanion(genre: Value('Rock'))),
    );
    await h.pump(
      tester,
      const GenreScreen(genre: 'Rock'),
      extraOverrides: [_noMix],
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('collection-name')), findsOneWidget);
    expect(find.byKey(const ValueKey('collection-cover')), findsNothing);
    await h.dispose(tester);
  });

  /// A genre page of 4 library songs whose mix is [mix].
  Future<Harness> mixPage(
    WidgetTester tester,
    Stream<GenreMixState> mix, {
    List<Override> extra = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4, radio: true);
    await tester.runAsync(
      () => h.db
          .update(h.db.tracks)
          .write(const TracksCompanion(genre: Value('Rock'))),
    );
    await h.pump(
      tester,
      const GenreScreen(genre: 'Rock'),
      extraOverrides: [genreMixProvider.overrideWith((ref, genre) => mix), ...extra],
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return h;
  }

  testWidgets(
    'mix: skeleton rows for the incoming ones, then the suggested ones, 2 to 1',
    (tester) async {
      final c = StreamController<GenreMixState>();
      addTearDown(c.close);
      final h = await mixPage(tester, c.stream);
      c.add(const GenreMixState(incoming: 2));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Skeleton), findsNWidgets(2));
      expect(
        tester.getSize(find.byType(Skeleton).first).height,
        72,
        reason: 'as tall as a real row',
      );
      expect(find.bySemanticsLabel('Shuffle+ sta scegliendo 2 brani…'), findsOneWidget, reason: 'one node for all');
      c.add(GenreMixState(suggested: [(result: _song('a'), seedTitle: 's'), (result: _song('b'), seedTitle: 's')]));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('Suggerito'), findsNWidgets(2));
      expect(find.byIcon(Icons.public_rounded), findsNWidgets(2));
      // library, library, suggested, library, library, suggested
      final titles = [
        for (final t in [
          'Song 0',
          'Song 1',
          'Song 2',
          'Song 3',
          'Online a',
          'Online b',
        ])
          (t, tester.getTopLeft(find.text(t)).dy),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      expect(
        [for (final t in titles) t.$1.startsWith('Online')],
        [false, false, true, false, false, true],
      );
      await h.dispose(tester);
    },
  );

  testWidgets('mix off: library only and the reason in a short line', (
    tester,
  ) async {
    final h = await mixPage(
      tester,
      Stream.value(const GenreMixState(off: GenreMixOff.metered)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Suggeriti spenti: rete a consumo'), findsOneWidget);
    expect(find.byType(Skeleton), findsNothing);
    expect(find.text('Suggerito'), findsNothing);
    expect(find.text('Song 3'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets(
    'mix: Play queues library, library, suggested in the order shown',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('genre_play');
      addTearDown(() => dir.deleteSync(recursive: true));
      final h = await mixPage(
        tester,
        Stream.value(GenreMixState(
          suggested: [(result: _song('a'), seedTitle: 'Song 0'), (result: _song('b'), seedTitle: 'Song 3')],
        )),
        extra: [
          downloadIndexProvider.overrideWith(
            (ref) async => DownloadIndex(File(p.join(dir.path, 'd.json'))),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Riproduci'));
      for (var i = 0; i < 100 && h.handler.queueIds.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      final kinds = [for (final id in h.handler.queueIds) isOnlineId(id)];
      expect(kinds, [false, false, true, false, false, true]);
      expect(
        [
          for (final id in h.handler.queueIds)
            if (isOnlineId(id)) h.handler.online!.entryOf(id)!.result.id,
        ],
        ['a', 'b'],
      );
      // In the queue they carry the «Suggerito» badge, with the song they came from.
      final entries = [
        for (final id in h.handler.queueIds)
          if (isOnlineId(id)) h.handler.online!.entryOf(id)!,
      ];
      expect([for (final e in entries) e.suggested], [true, true]);
      expect([for (final e in entries) e.seedTitle], ['Song 0', 'Song 3']);
      await h.dispose(tester);
    },
  );

  testWidgets('mix: a tap on a library row plays the shown list from that row', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('genre_tap');
    addTearDown(() => dir.deleteSync(recursive: true));
    final h = await mixPage(
      tester,
      Stream.value(GenreMixState(suggested: [(result: _song('a'), seedTitle: 's'), (result: _song('b'), seedTitle: 's')])),
      extra: [
        downloadIndexProvider.overrideWith(
          (ref) async => DownloadIndex(File(p.join(dir.path, 'd.json'))),
        ),
      ],
    );
    await tester.pump(const Duration(milliseconds: 50));
    // The fourth row shown: the library song after the first suggestion.
    final rows = [
      for (final t in ['Song 0', 'Song 1', 'Song 2', 'Song 3', 'Online a'])
        (t, tester.getTopLeft(find.text(t)).dy),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    await tester.tap(find.text(rows[3].$1));
    for (var i = 0; i < 100 && h.handler.queueIds.isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect([for (final id in h.handler.queueIds) isOnlineId(id)], [
      false,
      false,
      true,
      false,
      false,
      true,
    ]);
    expect(h.handler.currentIndex, 3);
    await h.dispose(tester);
  });

  testWidgets('mix: no overflow at 150 % text, skeleton and suggested rows', (
    tester,
  ) async {
    final c = StreamController<GenreMixState>();
    addTearDown(c.close);
    final h = await mixPage(tester, c.stream);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    c.add(const GenreMixState(incoming: 1, suggested: []));
    await tester.pump(const Duration(milliseconds: 50));
    c.add(GenreMixState(suggested: [(result: _song('a'), seedTitle: 's')], incoming: 1));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Suggerito'), findsOneWidget);
    expect(find.byType(Skeleton), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });
}

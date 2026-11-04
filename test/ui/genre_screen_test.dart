import 'dart:async';

import 'package:codecore/providers/shuffle_plus_providers.dart';
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
    Stream<GenreMixState> mix,
  ) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await tester.runAsync(
      () => h.db
          .update(h.db.tracks)
          .write(const TracksCompanion(genre: Value('Rock'))),
    );
    await h.pump(
      tester,
      const GenreScreen(genre: 'Rock'),
      extraOverrides: [genreMixProvider.overrideWith((ref, genre) => mix)],
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
      c.add(GenreMixState(suggested: [_song('a'), _song('b')]));
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
}

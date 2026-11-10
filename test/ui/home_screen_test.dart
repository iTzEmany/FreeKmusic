import 'package:codecore/ui/screens/activity/activity_log_screen.dart';
import 'package:codecore/ui/widgets/play_buttons.dart';
import 'package:codecore/ui/screens/home/home_row.dart';
import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/screens/library/album_detail_screen.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('home without music: empty state with add folder', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(tester, const HomeScreen());
    await _settle(tester);
    expect(find.text('Aggiungi la tua cartella musicale'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    await h.dispose(tester);
  });

  Future<Harness> openHome(WidgetTester tester, {int tracks = 4}) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: tracks);
    await h.pump(tester, const HomeScreen());
    await _settle(tester);
    return h;
  }

  testWidgets('Play is reachable by a semantic tap (TalkBack)', (tester) async {
    final h = await openHome(tester);
    final handle = tester.ensureSemantics();
    tester.semantics.tap(find.semantics.byLabel('Riproduci'));
    await _settle(tester);
    expect(h.handler.queueIds, hasLength(4));
    handle.dispose();
    await h.dispose(tester);
  });

  testWidgets('Registro opens in one tap from the header', (tester) async {
    final h = await openHome(tester);
    await tester.tap(find.byTooltip('Registro'));
    await _settle(tester);
    expect(find.byType(ActivityLogScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the shuffle title fits at text scale 2.0', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const HomeScreen(), textScale: 2);
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.byType(PlayCircleButton), findsOneWidget);
    // displaySmall is 36 sp: at 2.0 one line is ~86 px, so >100 means it wrapped.
    expect(tester.getSize(find.text('Casuale su tutto')).height, greaterThan(100));
    await h.dispose(tester);
  });

  testWidgets('home with music: shuffle hero, shortcuts, fan, no Riprendi', (
    tester,
  ) async {
    final h = await openHome(tester);
    expect(find.text('Casuale su tutto'), findsOneWidget);
    expect(find.textContaining('4 brani'), findsOneWidget);
    expect(find.textContaining('Preferiti'), findsOneWidget);
    expect(find.text('Aggiunti da poco'), findsOneWidget);
    expect(find.text('Riprendi'), findsNothing);
    expect(find.textContaining(' · '), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('the shuffle button in Home only changes the mode', (
    tester,
  ) async {
    final h = await openHome(tester);
    await tester.tap(find.text('Casuale su tutto'));
    await _settle(tester);
    expect(
      h.handler.shuffleEnabled,
      isFalse,
      reason: 'the title is not a button',
    );
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await _settle(tester);
    expect(
      h.handler.shuffleEnabled,
      isFalse,
      reason: 'the library is not playing: only its own mode changes (D-534)',
    );
    expect(h.handler.queueIds, isEmpty, reason: 'nothing starts');
    final c = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    expect(c.read(listShuffleProvider(libraryListKey)), ShuffleMode.shuffle);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _settle(tester);
    expect(h.handler.shuffleEnabled, isTrue, reason: 'Play applies the mode');
    // Now the library plays: the button changes the real queue.
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await _settle(tester);
    // 4 tracks are too few for Shuffle+: shuffle goes straight to off.
    expect(h.handler.shuffleEnabled, isFalse);
    await h.dispose(tester);
  });

  testWidgets(
    'the Home shuffle button reaches Shuffle+ on a library of 6 while 2 tracks play (D-137)',
    (tester) async {
      final h = await openHome(tester, tracks: 6);
      final ids = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!
          .map((t) => t.id)
          .toList();
      // Only 2 tracks are in the queue, but the button works on the library.
      await tester.runAsync(() => h.handler.playQueue(ids.take(2).toList(), 0));
      final c = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byIcon(Icons.shuffle_rounded));
        await _settle(tester);
      }
      expect(c.read(listShuffleProvider(libraryListKey)), ShuffleMode.plus);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await _settle(tester);
      expect(c.read(settingsProvider).shufflePlus, isTrue);
      await h.dispose(tester);
    },
  );

  testWidgets('each shortcut is one box with one spoken label', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await openHome(tester);
    for (final label in [
      'Preferiti, 0 brani',
      'Playlist, 0 playlist',
      'Radio, In diretta',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    await h.dispose(tester);
    handle.dispose();
  });

  testWidgets('Play starts the library in order with shuffle off', (
    tester,
  ) async {
    final h = await openHome(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _settle(tester);
    expect(h.handler.shuffleEnabled, isFalse);
    expect(h.handler.queueIds, hasLength(4));
    expect(h.handler.currentIndex, 0);
    await h.dispose(tester);
  });

  testWidgets('Play with shuffle on keeps shuffle on and starts the library', (
    tester,
  ) async {
    final h = await openHome(tester);
    await tester.tap(find.byIcon(Icons.shuffle_rounded));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _settle(tester);
    expect(h.handler.shuffleEnabled, isTrue);
    expect(h.handler.queueIds, hasLength(4));
    await h.dispose(tester);
  });

  testWidgets(
    'the fan opens on the first tap and opens the album on the second',
    (tester) async {
      final h = await openHome(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('fan-cover-0')));
      await tester.tap(
        find.byKey(const ValueKey('fan-cover-1')),
        warnIfMissed: false,
      );
      await _settle(tester);
      expect(find.byType(AlbumDetailScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('fan-cover-0')));
      await _settle(tester);
      expect(find.byType(AlbumDetailScreen), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets('the closed fan opens from the accessibility tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = await openHome(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('fan-cover-0')));
    await tester.pump();
    tester.semantics.performAction(
      find.semantics.byLabel(RegExp('Mostra i brani aggiunti da poco')),
      SemanticsAction.tap,
    );
    await _settle(tester);
    expect(find.bySemanticsLabel(RegExp('Mostra i brani aggiunti da poco')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('fan-cover-0')));
    await _settle(tester);
    expect(find.byType(AlbumDetailScreen), findsOneWidget);
    await h.dispose(tester);
    handle.dispose();
  });

  testWidgets(
    'Riprendi shows a track left in the middle with the minutes left',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 4);
      await tester.runAsync(
        () => (h.db.update(h.db.tracks)..where((t) => t.title.equals('Song 2')))
            .write(
              const TracksCompanion(
                resumePositionMs: Value(60000),
                lastPlayedAt: Value(1000),
              ),
            ),
      );
      await h.pump(tester, const HomeScreen());
      await _settle(tester);
      expect(find.text('Riprendi'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
      // 185 s long, 60 s in: 125 s left rounds up to 3 minutes.
      expect(find.text('Mancano 3 minuti'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets('Riprendi shows the playing queue as «brano n di m»', (
    tester,
  ) async {
    final h = await openHome(tester);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await _settle(tester);
    final row = find.byKey(const ValueKey('resume-queue'));
    expect(row, findsOneWidget);
    expect(
      find.descendant(
        of: row,
        matching: find.textContaining(RegExp(r'rano \d di 4')),
      ),
      findsOneWidget,
    );
    await h.dispose(tester);
  });

  /// Plays/idle times far in the past, so the albums count as «da riscoprire».
  Future<Harness> openRanked(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    final plays = {'Song 3': 9, 'Song 1': 5, 'Song 0': 2, 'Song 2': 1};
    await tester.runAsync(() async {
      for (final e in plays.entries) {
        await (h.db.update(
          h.db.tracks,
        )..where((t) => t.title.equals(e.key))).write(
          TracksCompanion(
            playCount: Value(e.value),
            lastPlayedAt: const Value(1000),
          ),
        );
      }
      // Song 2 is also left in the middle.
      await (h.db.update(h.db.tracks)..where((t) => t.title.equals('Song 2')))
          .write(const TracksCompanion(resumePositionMs: Value(60000)));
    });
    await h.pump(tester, const HomeScreen());
    await _settle(tester);
    return h;
  }

  double y(WidgetTester t, Finder f) => t.getTopLeft(f.first).dy;

  testWidgets('shortcut titles stay whole at 360 dp and text scale 2.0', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const HomeScreen(), textScale: 2);
    await _settle(tester);
    expect(find.text('Preferiti'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('the blocks have no dividers and merge each row', (tester) async {
    final handle = tester.ensureSemantics();
    final h = await openRanked(tester);
    expect(find.byType(HomeBlock), findsNWidgets(3));
    expect(find.byType(Divider), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Song 3\n')), findsOneWidget);
    await h.dispose(tester);
    handle.dispose();
  });

  testWidgets('«I più ascoltati» lists the top 3 by plays, most played first', (
    tester,
  ) async {
    final h = await openRanked(tester);
    final header = y(tester, find.text('I più ascoltati'));
    final rediscover = y(tester, find.text('Da riscoprire'));
    double row(String title) => tester
        .getTopLeft(
          find
              .descendant(of: find.byType(HomeRow), matching: find.text(title))
              .last,
        )
        .dy;
    expect(row('Song 3'), greaterThan(header));
    expect(row('Song 1'), greaterThan(row('Song 3')));
    expect(row('Song 0'), greaterThan(row('Song 1')));
    expect(row('Song 0'), lessThan(rediscover));
    // The fourth is cut: Song 2 shows only in «Riprendi», above the header.
    expect(find.text('Song 2'), findsOneWidget);
    expect(y(tester, find.text('Song 2')), lessThan(header));
    await h.dispose(tester);
  });

  testWidgets(
    '«Da riscoprire» lists old, often played albums, most played first',
    (tester) async {
      final h = await openRanked(tester);
      final header = y(tester, find.text('Da riscoprire'));
      // Album 1 = Songs 1+3 (14 plays), Album 0 = Songs 0+2 (3 plays).
      final a1 = tester.getTopLeft(find.text('Album 1').last).dy;
      final a0 = tester.getTopLeft(find.text('Album 0').last).dy;
      expect(a1, greaterThan(header));
      expect(a0, greaterThan(a1));
      await h.dispose(tester);
    },
  );

  testWidgets(
    '«Riprendi» orders the queue, then tracks left in the middle, then albums',
    (tester) async {
      final h = await openRanked(tester);
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await _settle(tester);
      final queue = y(tester, find.byKey(const ValueKey('resume-queue')));
      final track = y(
        tester,
        find.byWidgetPredicate(
          (w) => w.key.toString().contains('resume-track-'),
        ),
      );
      final entry = y(
        tester,
        find.byWidgetPredicate(
          (w) => w.key.toString().contains('resume-entry-'),
        ),
      );
      expect(track, greaterThan(queue));
      expect(entry, greaterThan(track));
      await h.dispose(tester);
    },
  );

  testWidgets('wide window: Home uses the width, fan shows covers or art', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 4);
    await h.pump(tester, const HomeScreen());
    await _settle(tester);
    expect(
      tester.getSize(find.byType(ListView).first).width,
      greaterThan(1000),
    );
    final cover = find.byKey(const ValueKey('fan-cover-0'));
    expect(cover, findsOneWidget);
    expect(
      find.descendant(of: cover, matching: find.byType(Text)),
      findsOneWidget,
    );
    expect(tester.getSize(cover).width, 84);
    await h.dispose(tester);
  });
}

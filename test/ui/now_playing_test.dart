import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/ui/screens/library/artist_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_cards.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/motion.dart';
import 'package:codecore/ui/widgets/quality_tag.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_controls.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/cover_backdrop.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:codecore/ui/widgets/seek_bar.dart';
import 'package:codecore/ui/widgets/speed_button.dart';
import 'package:codecore/ui/theme/custom_theme.dart';
import 'package:codecore/providers/theme_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/ui/widgets/marquee_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

class _SeekSpy implements PlayerController {
  _SeekSpy(this.seeks);

  final List<Duration> seeks;

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('now playing: context, heart in the title row, cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    final ids = rows!.map((t) => t.id).toList();
    await tester.runAsync(() => h.handler.playQueue(ids, 0));
    await h.pump(tester, const NowPlayingScreen());
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.text('Artist'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.queue_music_rounded), findsOneWidget);
    expect(
      tester
          .widget<RingProgress>(
            find.descendant(
              of: find.byType(NowPlayingScreen),
              matching: find.byType(RingProgress),
            ),
          )
          .seekable,
      isTrue,
    );
    // 59.5: the bar is back between the two times; the quality tag and the
    // speed sit below it, centred (the ring keeps its gap).
    final bar = tester.getRect(find.byType(SeekBar));
    expect(
      tester.getCenter(find.text('0:00').first).dy,
      closeTo(bar.center.dy, 1),
    );
    expect(tester.getCenter(find.text('0:00').first).dx, lessThan(bar.left));
    expect(
      tester.getCenter(find.byType(QualityTag)).dy,
      greaterThan(bar.bottom - 8),
    );
    final chips = tester
        .getRect(find.byType(QualityTag))
        .expandToInclude(tester.getRect(find.byType(SpeedButton)));
    expect(chips.center.dx, closeTo(200, 1));
    // Without a context the header just says «In riproduzione».
    expect(find.text('In riproduzione'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a long title scrolls on one line (D-486)', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final longTitle = 'A very long title ' * 20;
    final h = await Harness.create(tester, tracks: 1);
    await tester.runAsync(
      () => h.db
          .update(h.db.tracks)
          .write(TracksCompanion(title: Value(longTitle))),
    );
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const NowPlayingScreen());
    await _settle(tester);
    expect(find.widgetWithText(MarqueeText, longTitle), findsOneWidget);
    expect(tester.widget<Text>(find.text(longTitle)).softWrap, isFalse);
    await h.dispose(tester);
  });

  testWidgets('play context shows the album name', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const NowPlayingScreen());
    h.handler.setPlayContext(PlayContextKind.album.index, 'Album 0');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('In riproduzione da'), findsOneWidget);
    expect(find.text('Album 0'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('tap on the artist opens the artist page in the Library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const AppShell());
    await _settle(tester);
    // Open Now Playing from the mini-player (tap on the title).
    await tester.tap(find.text('Song 0').last);
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await tester.tap(find.text('Artist').last);
    await tester.pump(const Duration(milliseconds: 50));
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(find.byType(ArtistDetailScreen), findsOneWidget);
    // The artist page sits in the Library tab: bar + mini-player remain.
    expect(find.text('Libreria'), findsWidgets);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('the now playing cover sits in a ring', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const NowPlayingScreen());
    expect(
      find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(RingProgress),
      ),
      findsOneWidget,
    );
    expect(find.byType(SpinWhilePlaying), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the player background is one flat tint when the option is on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const NowPlayingScreen());
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(NowPlayingScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    // No cover: the tint falls back to heroBase.
    expect(scaffold.backgroundColor, CcColors.notte.heroBase);
    expect(find.byType(CoverBackdrop), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the player background is bg when the tint option is off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(
      tester,
      const NowPlayingScreen(),
      extraOverrides: [
        themeBackgroundProvider.overrideWithValue(
          const ThemeBackground(coverBackdrop: false),
        ),
      ],
    );
    final scaffold = tester.widget<Scaffold>(
      find
          .descendant(
            of: find.byType(NowPlayingScreen),
            matching: find.byType(Scaffold),
          )
          .first,
    );
    expect(scaffold.backgroundColor, CcColors.notte.bg);
    await h.dispose(tester);
  });

  group('seek ring on the screen', () {
    final seeks = <Duration>[];
    setUp(seeks.clear);

    Future<(Harness, Offset, double)> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 2);
      final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
      await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
      await h.pump(
        tester,
        const NowPlayingScreen(),
        extraOverrides: [
          playerControllerProvider.overrideWithValue(_SeekSpy(seeks)),
          positionProvider.overrideWith((_) => Stream.value(Duration.zero)),
          durationProvider.overrideWith(
            (_) => Stream.value(const Duration(seconds: 100)),
          ),
        ],
      );
      final ring = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(RingProgress),
      );
      final size = tester.getSize(ring).width;
      return (
        h,
        tester.getCenter(ring),
        RingProgress.innerSize(size, stroke: 12) / 2,
      );
    }

    testWidgets('a drag just inside the cover edge does not seek', (
      tester,
    ) async {
      final (h, c, coverR) = await open(tester);
      final g = await tester.startGesture(c + Offset(0, coverR - 8));
      // A first move to cross the touch slop, then the ones that count.
      await g.moveBy(const Offset(0, 30));
      await g.moveBy(const Offset(0, 30));
      await tester.pump();
      final shift = tester
          .widgetList<AnimatedContainer>(
            find.descendant(
              of: find.byType(NowPlayingScreen),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .map((w) => w.transform?.getTranslation().y ?? 0)
          .fold(0.0, (a, b) => a + b);
      expect(shift, greaterThan(0), reason: 'the sheet drag took it');
      await g.up();
      expect(seeks, isEmpty);
      await h.dispose(tester);
    });

    testWidgets('a drag on the ring band seeks and moves the elapsed time', (
      tester,
    ) async {
      final (h, c, coverR) = await open(tester);
      // 30 dp past the cover edge: outside the drawing's box, inside the band.
      final g = await tester.startGesture(c + Offset(0, coverR + 30));
      await g.moveBy(const Offset(0, 4));
      await tester.pump();
      expect(find.text('0:00'), findsNothing);
      // 59.4: the bar follows the ring's drag (same fraction, same time).
      expect(
        tester
                .widget<Slider>(
                  find.descendant(
                    of: find.byType(NpSeekRow),
                    matching: find.byType(Slider),
                  ),
                )
                .value /
            100000,
        closeTo(0.36, 0.02),
      );
      await g.up();
      expect(seeks, hasLength(1));
      expect(seeks.single.inMilliseconds / 1000, closeTo(36, 2));
      await h.dispose(tester);
    });
  });

  testWidgets(
    'reduce motion: the player opens without growing and the cover does not spin',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.reset);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final h = await Harness.create(tester, tracks: 2);
      final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
      await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
      await h.pump(tester, const AppShell());
      await _settle(tester);
      await tester.tap(find.text('Song 0').last);
      await tester.pump();
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      // The grow clip is an ancestor of the page, not a descendant.
      expect(
        find.byWidgetPredicate((w) => w is ClipRRect && w.clipper != null),
        findsNothing,
      );
      final route = ModalRoute.of(
        tester.element(find.byType(NowPlayingScreen)),
      )!;
      expect(
        route.animation!.status,
        AnimationStatus.completed,
        reason: 'the route settled in one frame',
      );
      await tester.dragFrom(const Offset(200, 840), const Offset(0, -700));
      await tester.pump();
      expect(find.byType(UpNextCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SpinWhilePlaying),
          matching: find.byType(RotationTransition),
        ),
        findsNothing,
      );
      await h.dispose(tester);
    },
  );

  testWidgets('the player grows out of the dock', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, const AppShell());
    await _settle(tester);
    await tester.tap(find.text('Song 0').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final clip = tester.widget<ClipRRect>(
      find.byWidgetPredicate((w) => w is ClipRRect && w.clipper != null),
    );
    final rrect = clip.clipper!.getClip(const Size(400, 900));
    expect(rrect.height, lessThan(900));
    expect(rrect.top, greaterThan(300), reason: 'still near the dock');
    expect(
      find.byType(UpNextCard),
      findsNothing,
      reason: 'cards wait for the end',
    );
    await _settle(tester);
    await tester.dragFrom(const Offset(200, 840), const Offset(0, -700));
    await tester.pump();
    expect(find.byType(UpNextCard), findsOneWidget);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await h.dispose(tester);
  });

  Future<Harness> openPlayer(WidgetTester tester, {bool? desktop}) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
    await h.pump(tester, NowPlayingScreen(desktop: desktop));
    return h;
  }

  testWidgets('symmetry: the top-bar title sits at the screen centre', (
    tester,
  ) async {
    // Mobile: car mode + more on the right, back alone on the left.
    final h = await openPlayer(tester, desktop: false);
    expect(find.byIcon(Icons.directions_car_outlined), findsOneWidget);
    expect(tester.getCenter(find.text('In riproduzione')).dx, closeTo(200, 1));
    await h.dispose(tester);
  });

  testWidgets(
    'symmetry: the quality tag does not move when the total toggles',
    (tester) async {
      final h = await openPlayer(tester);
      final before = tester.getCenter(find.byType(QualityTag)).dx;
      // Elapsed and total are both 0:00 here; the total is the last one.
      await tester.tap(find.text('0:00').last);
      await tester.pump();
      expect(find.text('-0:00'), findsOneWidget);
      expect(
        tester.getCenter(find.byType(QualityTag)).dx,
        closeTo(before, 0.5),
      );
      await h.dispose(tester);
    },
  );

  testWidgets('symmetry: the sleep chip sits at the centre of the bottom row', (
    tester,
  ) async {
    final h = await openPlayer(tester);
    expect(find.text('Dispositivi'), findsOneWidget);
    expect(find.text('Coda'), findsOneWidget);
    expect(
      tester.getCenter(find.byKey(const Key('np-sleep-chip'))).dx,
      closeTo(200, 1),
    );
    await h.dispose(tester);
  });

  testWidgets(
    'symmetry: the title mirrors the heart and lines up with the track',
    (tester) async {
      final h = await openPlayer(tester);
      final left = tester.getTopLeft(find.text('Song 0')).dx;
      expect(
        400 - tester.getTopRight(find.byType(HeartIcon)).dx,
        closeTo(left, 1),
      );
      // Same edge as the elapsed time below the seek bar.
      expect(tester.getTopLeft(find.text('0:00').first).dx, closeTo(left, 1));
      await h.dispose(tester);
    },
  );

  testWidgets('wide layout: player and cards form one centred group', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 2);
    final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
    await tester.runAsync(
      () => h.handler.playQueue(rows!.map((t) => t.id).toList(), 0),
    );
    await h.pump(tester, const NowPlayingScreen());
    final cards = tester.getRect(find.byType(UpNextCard));
    final slider = tester.getRect(find.byType(NpSeekRow));
    // Cards end as far from the right edge as the player starts from the left.
    expect(slider.left, closeTo(1600 - cards.right, 1));
    await h.dispose(tester);
  });

  testWidgets('desktop volume row shows the percentage', (tester) async {
    final h = await openPlayer(tester);
    ProviderScope.containerOf(tester.element(find.byType(NowPlayingScreen)))
        .read(volumeProvider.notifier)
        .set(0.7);
    await tester.pump();
    expect(find.text('70%'), findsOneWidget);
    // Mute button and percentage have the same width: the slider is centred.
    expect(tester.getCenter(find.byType(Slider).last).dx, closeTo(200, 1));
    await h.dispose(tester);
    // Linux: the desktop theme shrink-wraps the mute button.
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  group('LyricsCard today', () {
    testWidgets('the bold line follows the position; the window slides', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 1);
      final track = await tester.runAsync(() async {
        await h.db
            .update(h.db.tracks)
            .write(
              TracksCompanion(
                lyricsSynced: Value(
                  [
                    for (var i = 0; i < 8; i++)
                      '[0${i * 10 ~/ 60}:${(i * 10 % 60).toString().padLeft(2, '0')}.00]Line $i',
                  ].join('\n'),
                ),
              ),
            );
        return (await h.db.select(h.db.tracks).get()).single;
      });
      final pos = StreamController<Duration>();
      addTearDown(pos.close);
      await h.pump(
        tester,
        Scaffold(body: LyricsCard(track: track!)),
        extraOverrides: [positionProvider.overrideWith((_) => pos.stream)],
      );
      FontWeight? weightOf(String t) =>
          tester.widget<Text>(find.text(t)).style?.fontWeight;

      pos.add(const Duration(seconds: 31));
      await tester.pump();
      await tester.pump();
      // Current line 3: window is lines 1..5.
      expect(weightOf('Line 3'), FontWeight.w700);
      expect(weightOf('Line 2'), FontWeight.w500);
      expect(find.text('Line 0'), findsNothing);
      expect(find.text('Line 6'), findsNothing);

      pos.add(const Duration(seconds: 51));
      await tester.pump();
      await tester.pump();
      expect(weightOf('Line 5'), FontWeight.w700);
      expect(weightOf('Line 3'), FontWeight.w500);
      expect(find.text('Line 1'), findsNothing);

      // Last lines: the window steps back and keeps 5 lines (F-58, D-161).
      pos.add(const Duration(seconds: 71));
      await tester.pump();
      await tester.pump();
      expect(weightOf('Line 7'), FontWeight.w700);
      expect(find.text('Line 2'), findsNothing);
      expect(find.text('Line 3'), findsOneWidget);
      expect(find.text('Line 5'), findsOneWidget);
      await h.dispose(tester);
    });
  });
}

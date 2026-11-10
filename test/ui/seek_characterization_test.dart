// Characterisation (phase 58): the seek behaviour of today, kept as it is until
// phase 59/63 change it on purpose. Complements ring_progress_test.dart.
import 'dart:math' as math;

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/desktop_player_bar.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_controls.dart';
import 'package:codecore/ui/widgets/seek_bar.dart';
import 'package:codecore/ui/widgets/smooth_position.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _Spy implements PlayerController {
  final seeks = <Duration>[];

  // The queue sheet watches these through similarSeedProvider (phase 100).
  @override
  final similarTitle = ValueNotifier<String?>(null);
  @override
  final similarLoading = ValueNotifier<bool>(false);

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  // Home's shuffle button asks it (D-534); a null would not be a bool.
  @override
  bool isPlayingList(Object key) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _dur = Duration(seconds: 100);

double _deg(double d) => d * math.pi / 180;

Offset _at(double deg, double r) =>
    Offset(math.cos(_deg(deg)), math.sin(_deg(deg))) * r;

/// Real async work (DB, files) settles in a few event-queue turns; no wall-clock sleep.
Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 20; i++) {
    await t.runAsync(() => pumpEventQueue());
    await t.pump();
  }
}

void main() {
  group('RingPainter.fractionAt: angle to position', () {
    // The 320 deg arc starts at -25 deg (clockwise from the right, y down)
    // and ends at 295 deg; the 40 deg gap is centred on -45 deg.
    test('the start of the arc is 0 and a point at 90 deg is 115/320', () {
      expect(RingPainter.fractionAt(_at(-25, 50)), closeTo(0, 1e-9));
      expect(RingPainter.fractionAt(_at(90, 50)), closeTo(115 / 320, 1e-9));
    });

    test('left and top of the ring map linearly along the arc', () {
      expect(RingPainter.fractionAt(_at(180, 50)), closeTo(205 / 320, 1e-9));
      expect(RingPainter.fractionAt(_at(270, 50)), closeTo(295 / 320, 1e-9));
    });

    test('the distance from the centre does not matter', () {
      expect(
        RingPainter.fractionAt(_at(135, 5)),
        RingPainter.fractionAt(_at(135, 500)),
      );
    });

    test('inside the 40 deg gap the point snaps to the nearer end', () {
      expect(RingPainter.fractionAt(_at(-30, 50)), 0.0);
      expect(RingPainter.fractionAt(_at(-40, 50)), 0.0);
      expect(RingPainter.fractionAt(_at(-50, 50)), 1.0);
      expect(RingPainter.fractionAt(_at(-60, 50)), 1.0);
    });
  });

  group('seekable ring (widget)', () {
    final spy = _Spy();
    setUp(spy.seeks.clear);

    Future<ProviderContainer> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerControllerProvider.overrideWithValue(spy),
            positionProvider.overrideWith((_) => Stream.value(Duration.zero)),
            durationProvider.overrideWith(
              (_) => Stream.value(const Duration(seconds: 100)),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('it'),
            home: const Center(
              child: RingProgress(
                size: 300,
                stroke: 12,
                seekable: true,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return ProviderScope.containerOf(
        tester.element(find.byType(RingProgress)),
      );
    }

    testWidgets('a touch in the gap near the end seeks to the full duration', (
      tester,
    ) async {
      await pump(tester);
      final c = tester.getCenter(find.byType(RingProgress));
      final g = await tester.startGesture(c + _at(-55, 139));
      await g.up();
      expect(spy.seeks.single, const Duration(seconds: 100));
    });

    testWidgets('a touch in the gap near the start seeks to zero', (
      tester,
    ) async {
      await pump(tester);
      final c = tester.getCenter(find.byType(RingProgress));
      final g = await tester.startGesture(c + _at(-35, 139));
      await g.up();
      expect(spy.seeks.single, Duration.zero);
    });

    // 59.4: ringDragProvider is now the shared seekDragProvider.
    testWidgets('while dragging seekDragProvider holds the finger fraction, '
        'null after release; a cancelled gesture does not seek', (
      tester,
    ) async {
      final box = await pump(tester);
      final c = tester.getCenter(find.byType(RingProgress));
      var g = await tester.startGesture(c + _at(90, 139));
      expect(box.read(seekDragProvider), closeTo(115 / 320, 0.02));
      await g.up();
      expect(box.read(seekDragProvider), isNull);
      expect(spy.seeks, hasLength(1));

      g = await tester.startGesture(c + _at(90, 139));
      await g.cancel();
      expect(box.read(seekDragProvider), isNull);
      expect(spy.seeks, hasLength(1), reason: 'cancel must not seek');
    });
  });

  group('desktop bar slider', () {
    testWidgets('dragging shows the finger position and seeks on release', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final spy = _Spy();
      final h = await Harness.create(tester, tracks: 2);
      final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
      await tester.runAsync(() => h.handler.playQueue([rows!.first.id], 0));
      await h.pump(
        tester,
        const AppShell(),
        extraOverrides: [
          playerControllerProvider.overrideWithValue(spy),
          positionProvider.overrideWith((_) => Stream.value(Duration.zero)),
          durationProvider.overrideWith(
            (_) => Stream.value(const Duration(seconds: 100)),
          ),
        ],
      );
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final slider = find
          .descendant(
            of: find.byType(DesktopPlayerBar),
            matching: find.byType(Slider),
          )
          .first;
      final time = find.descendant(
        of: find.byType(DesktopPlayerBar),
        matching: find.text('0:00'),
      );
      expect(time, findsOneWidget);
      final g = await tester.startGesture(tester.getCenter(slider));
      await g.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(time, findsNothing, reason: 'the elapsed time follows the finger');
      expect(
        tester.widget<Slider>(slider).value,
        greaterThan(30000),
        reason: 'thumb under the finger, roughly mid-track',
      );
      expect(spy.seeks, isEmpty, reason: 'seek only on release');
      await g.up();
      await tester.pump();
      expect(spy.seeks, hasLength(1));
      expect(spy.seeks.single.inSeconds, inInclusiveRange(30, 70));
      await h.dispose(tester);
    });
  });

  group('NpSeekRow with an injected position (the Jam)', () {
    Widget host(SmoothPosition pos, Duration dur, ValueChanged<Duration> on) =>
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 400,
                  child: NpSeekRow(position: pos, duration: dur, onSeek: on),
                ),
              ),
            ),
          ),
        );

    testWidgets('dragging sends one seek on release, shows the finger '
        'position meanwhile', (tester) async {
      final pos = SmoothPosition()
        ..update(Duration.zero, playing: false, duration: _dur);
      addTearDown(pos.dispose);
      final sent = <Duration>[];
      await tester.pumpWidget(host(pos, _dur, sent.add));
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('1:40'), findsOneWidget);
      final g = await tester.startGesture(
        tester.getCenter(find.byType(Slider)),
      );
      await g.moveBy(const Offset(1, 0));
      await tester.pump();
      expect(find.text('0:00'), findsNothing);
      expect(sent, isEmpty, reason: 'seek only on release');
      await g.up();
      await tester.pump();
      expect(sent, hasLength(1));
      expect(sent.single.inMilliseconds, inInclusiveRange(30000, 70000));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without a duration the slider is disabled', (tester) async {
      final pos = SmoothPosition();
      addTearDown(pos.dispose);
      await tester.pumpWidget(host(pos, Duration.zero, (_) {}));
      expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}

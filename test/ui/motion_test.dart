import 'dart:async';

import 'package:codecore/ui/widgets/motion.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/spin_support.dart';

Widget _app(Widget child, {bool reduce = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: child),
      ),
    );

/// The opacity [owner] gives its child (its own FadeTransition, not the page's).
double _opacity(WidgetTester tester, Finder owner) =>
    tester.widget<FadeTransition>(find.descendant(of: owner, matching: find.byType(FadeTransition)).first).opacity.value;

Finder _fades(Finder owner) => find.descendant(of: owner, matching: find.byType(FadeTransition));

void main() {
  pageTransitionTests();
  test('only the first 12 rows of a list just shown come in', () {
    final since = DateTime(2026, 10, 21, 12);
    expect(EnterOnce.shouldEnter(0, since, since), isTrue);
    expect(EnterOnce.shouldEnter(11, since, since.add(const Duration(milliseconds: 100))), isTrue);
    expect(EnterOnce.shouldEnter(12, since, since), isFalse);
    expect(EnterOnce.shouldEnter(0, since, since.add(const Duration(seconds: 1))), isFalse,
        reason: 'scrolling back later: no movement');
    expect(EnterOnce.shouldEnter(0, null, since), isFalse, reason: 'no scope, no movement');
  });

  testWidgets('a new list: the first row fades in, the 13th is just there', (tester) async {
    await tester.pumpWidget(_app(EntranceScope(
      child: ListView(children: [
        for (var i = 0; i < 14; i++) EnterOnce(index: i, child: SizedBox(height: 10, child: Text('r$i'))),
      ]),
    )));
    final first = find.byType(EnterOnce).first, thirteenth = find.byType(EnterOnce).at(12);
    expect(_opacity(tester, first), lessThan(1));
    expect(_fades(thirteenth), findsNothing);
    await tester.pump(const Duration(milliseconds: 500));
    expect(_opacity(tester, first), 1);
  });

  testWidgets('pressed, a card shrinks a little and comes back', (tester) async {
    await tester.pumpWidget(_app(const Center(child: PressScale(child: SizedBox(width: 50, height: 50, child: Text('c'))))));
    final gesture = await tester.startGesture(tester.getCenter(find.text('c')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 0.97);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });

  testWidgets('the heart beats once when it becomes a favourite', (tester) async {
    Widget heart(bool fav, {bool reduce = false}) => _app(Center(child: HeartIcon(favorite: fav)), reduce: reduce);
    double scale() => tester
        .widget<ScaleTransition>(find.descendant(of: find.byType(HeartIcon), matching: find.byType(ScaleTransition)))
        .scale
        .value;
    await tester.pumpWidget(heart(false));
    await tester.pumpWidget(heart(true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(), greaterThan(1.1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(scale(), 1);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });

  group('with «Riduci animazioni» nothing moves', () {
    testWidgets('rows, cards, heart, tabs and the mini-player', (tester) async {
      var tab = 0;
      late StateSetter setTab;
      var fav = false;
      await tester.pumpWidget(_app(
        StatefulBuilder(builder: (context, set) {
          setTab = set;
          return Column(children: [
            EntranceScope(child: EnterOnce(index: 0, child: Text('row', key: ValueKey(tab)))),
            const PressScale(child: Text('card')),
            HeartIcon(favorite: fav),
            Expanded(child: TabFade(child: Text('tab $tab'))),
            const RiseIn(child: Text('mini')),
          ]);
        }),
        reduce: true,
      ));
      expect(_fades(find.byType(EnterOnce)), findsNothing);
      expect(find.byType(AnimatedScale), findsNothing);
      setTab(() {
        tab = 1;
        fav = true;
      });
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse, reason: 'durations are zero');
      expect(_opacity(tester, find.byType(RiseIn)), 1);
    });
  });

  group('SpinWhilePlaying', () {
    Widget spin(Object key, {bool playing = true, bool reduce = false, bool spinCover = true}) => ProviderScope(
          overrides: spinOverrides(playing: playing, spinCover: spinCover),
          child: _app(SpinWhilePlaying(trackKey: key, child: const SizedBox(width: 10, height: 10)), reduce: reduce),
        );
    final rotation = find.descendant(of: find.byType(SpinWhilePlaying), matching: find.byType(RotationTransition));
    double angle(WidgetTester t) => t.widget<RotationTransition>(rotation).turns.value;

    testWidgets('the cover spin restarts at 0 on a new track', (tester) async {
      await tester.pumpWidget(spin('a'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(angle(tester), closeTo(5 / 30, 0.01));
      await tester.pumpWidget(spin('b'));
      expect(angle(tester), 0);
      await tester.pump(const Duration(seconds: 3));
      expect(angle(tester), greaterThan(0), reason: 'it goes on turning while playing');
    });

    testWidgets('pausing keeps the angle', (tester) async {
      final ctl = StreamController<bool>.broadcast();
      addTearDown(ctl.close);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...spinOverrides(stream: (() async* {
            yield true;
            yield* ctl.stream;
          })()),
        ],
        child: _app(const SpinWhilePlaying(trackKey: 'a', child: SizedBox(width: 10, height: 10))),
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      final turned = angle(tester);
      expect(turned, greaterThan(0));
      ctl.add(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      final paused = angle(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(angle(tester), paused);
      expect(paused, greaterThanOrEqualTo(turned));
    });

    testWidgets('paused, it does not turn', (tester) async {
      await tester.pumpWidget(spin('a', playing: false));
      await tester.pump(const Duration(seconds: 5));
      expect(angle(tester), 0);
    });

    testWidgets('reduce motion: no rotation at all', (tester) async {
      await tester.pumpWidget(spin('a', reduce: true));
      await tester.pump(const Duration(seconds: 5));
      expect(rotation, findsNothing);
    });

    testWidgets('the setting toggled live starts and stops the spin', (tester) async {
      await tester.pumpWidget(spin('a', spinCover: false));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(rotation, findsNothing);
      final c = ProviderScope.containerOf(tester.element(find.byType(SpinWhilePlaying)));
      c.read(settingsProvider.notifier).update((s) => s.copyWith(spinCover: true));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(angle(tester), greaterThan(0));
      c.read(settingsProvider.notifier).update((s) => s.copyWith(spinCover: false));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('inside a route it waits for the opening transition', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: spinOverrides(),
        child: const MaterialApp(home: Scaffold(body: Text('home'))),
      ));
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: SpinWhilePlaying(trackKey: 'a', child: SizedBox(width: 10, height: 10)))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(angle(tester), 0, reason: 'no spin while the page opens');
      await tester.pump(const Duration(seconds: 1)); // the route is done (it keeps turning, so no pumpAndSettle)
      await tester.pump(const Duration(seconds: 3));
      expect(angle(tester), greaterThan(0));
    });
  });
}

Widget _routes({bool reduce = false}) => MaterialApp(
      theme: ThemeData(
        pageTransitionsTheme: PageTransitionsTheme(builders: {
          for (final p in TargetPlatform.values) p: const CcPageTransitionsBuilder(),
        }),
      ),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(disableAnimations: reduce),
        child: child!,
      ),
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const Text('next'))),
          child: const Text('go'),
        ),
      ),
    );

void pageTransitionTests() {
  testWidgets('a normal route fades in at full size, with no slide', (tester) async {
    await tester.pumpWidget(_routes());
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final next = find.ancestor(of: find.text('next'), matching: find.byType(FadeTransition));
    expect(tester.widget<FadeTransition>(next.first).opacity.value, inExclusiveRange(0, 1));
    expect(find.descendant(of: find.byType(MaterialApp), matching: find.byType(SlideTransition)), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
  });

  testWidgets('with reduced motion the page switch is instant', (tester) async {
    await tester.pumpWidget(_routes(reduce: true));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.ancestor(of: find.text('next'), matching: find.byType(FadeTransition)), findsNothing);
    expect(find.text('next'), findsOneWidget);
  });
}

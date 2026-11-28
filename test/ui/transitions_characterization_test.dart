// Transitions (born as the 38.3 safety net of the "ui fluida" refactor): push and
// pop of the player, TabFade, mini player swipe thresholds, cover Hero counts.
import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/bottom_bar.dart';
import 'package:codecore/ui/widgets/mini_player.dart';
import 'package:codecore/ui/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

// Drags lose about 18 px to touch slop: offsets below are effective delta + 18.
void _size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Shell with a two-song queue playing from the first one.
Future<Harness> _shellPlaying(WidgetTester tester, Size s) async {
  _size(tester, s);
  final h = await Harness.create(tester, tracks: 2);
  final rows = await tester.runAsync(() => h.db.select(h.db.tracks).get());
  final ids = rows!.map((t) => t.id).toList();
  await tester.runAsync(() => h.handler.playQueue(ids, 0));
  await h.pump(tester, const AppShell());
  await _settle(tester);
  return h;
}

Finder _coverHeroes(String tag) =>
    find.byWidgetPredicate((w) => w is Hero && w.tag == tag);

String? _currentTitle(WidgetTester t) => ProviderScope.containerOf(
        t.element(find.byType(MiniPlayer)))
    .read(currentTrackProvider)
    .value
    ?.title;

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;
  @override
  Widget build(BuildContext context) => TextButton(
      onPressed: () => setState(() => n++), child: Text('count $n'));
}

void main() {
  testWidgets('push and pop: the player opens over the shell and closing keeps its state',
      (tester) async {
    final h = await _shellPlaying(tester, const Size(400, 900));
    await tester.tap(find.descendant(
        of: find.byType(ShellDock), matching: find.text('Libreria')));
    await _settle(tester);
    await tester.tap(find.text('Song 0').last);
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsNothing);
    expect(find.byType(MiniPlayer), findsOneWidget);
    expect(_currentTitle(tester), 'Song 0');
    final c = ProviderScope.containerOf(tester.element(find.byType(AppShell)));
    expect(c.read(navIndexProvider), NavTab.library.index);
    await h.dispose(tester);
  });

  // 39.3 (F-44): TabFade no longer fades the body (a full-screen opacity
  // layer on every tab change); what stays pinned is the kept state.
  testWidgets('TabFade: changing tab keeps the child state, with no opacity layer',
      (tester) async {
    Widget app(int i) => MaterialApp(home: TabFade(child: const _Counter()));
    await tester.pumpWidget(app(0));
    await tester.tap(find.text('count 0'));
    await tester.pump();
    await tester.pumpWidget(app(1));
    expect(
        find.descendant(of: find.byType(TabFade), matching: find.byType(FadeTransition)),
        findsNothing);
    expect(find.text('count 1'), findsOneWidget);
  });

  testWidgets('mini player: a short swipe snaps back, the track stays',
      (tester) async {
    final h = await _shellPlaying(tester, const Size(400, 800));
    final x0 = tester.getTopLeft(find.byType(MiniPlayer)).dx;
    await tester.drag(find.byType(MiniPlayer), const Offset(-78, 0));
    await _settle(tester);
    expect(_currentTitle(tester), 'Song 0');
    expect(tester.getTopLeft(find.byType(MiniPlayer)).dx, x0);
    await h.dispose(tester);
  });

  testWidgets('mini player: a swipe of about 85 px (threshold 72) goes to the next track',
      (tester) async {
    final h = await _shellPlaying(tester, const Size(400, 800));
    await tester.drag(find.byType(MiniPlayer), const Offset(-103, 0));
    await _settle(tester);
    expect(_currentTitle(tester), 'Song 1');
    await h.dispose(tester);
  });

  testWidgets('mini player: on the last track a left swipe snaps back, a right one goes back',
      (tester) async {
    final h = await _shellPlaying(tester, const Size(400, 800));
    await tester.drag(find.byType(MiniPlayer), const Offset(-120, 0));
    await _settle(tester);
    expect(_currentTitle(tester), 'Song 1');
    await tester.drag(find.byType(MiniPlayer), const Offset(-120, 0));
    await _settle(tester);
    expect(_currentTitle(tester), 'Song 1');
    await tester.drag(find.byType(MiniPlayer), const Offset(120, 0));
    await _settle(tester);
    expect(_currentTitle(tester), 'Song 0');
    await h.dispose(tester);
  });

  testWidgets('mini player: tap opens Now Playing', (tester) async {
    final h = await _shellPlaying(tester, const Size(400, 800));
    await tester.tap(find.text('Song 0').last);
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Now Playing: a drag down of about 140 px closes it, about 100 px does not (threshold 120)',
      (tester) async {
    final h = await _shellPlaying(tester, const Size(400, 900));
    await tester.tap(find.text('Song 0').last);
    await _settle(tester);
    final header = find.byIcon(Icons.keyboard_arrow_down_rounded);
    await tester.drag(header, const Offset(0, 118));
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    await tester.drag(header, const Offset(0, 158));
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('phone: one cover Hero in the mini player, still one with the player open',
      (tester) async {
    final h = await _shellPlaying(tester, const Size(400, 900));
    expect(_coverHeroes(kMiniCoverHero), findsOneWidget);
    await tester.tap(find.text('Song 0').last);
    await _settle(tester);
    expect(find.descendant(of: find.byType(NowPlayingScreen), matching: _coverHeroes(kMiniCoverHero)), findsOneWidget);
    // The opaque route hides the shell, so the mini player's Hero is gone.
    expect(_coverHeroes(kMiniCoverHero), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('desktop: one cover Hero in the player bar, one with the player open',
      (tester) async {
    final h = await _shellPlaying(tester, const Size(1280, 800));
    expect(_coverHeroes(kBarCoverHero), findsOneWidget);
    await tester.tap(_coverHeroes(kBarCoverHero));
    await _settle(tester);
    expect(find.byType(NowPlayingScreen), findsOneWidget);
    expect(_coverHeroes(kBarCoverHero), findsOneWidget);
    await h.dispose(tester);
  });
}

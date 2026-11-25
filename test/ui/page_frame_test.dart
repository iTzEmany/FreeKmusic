import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/online/online_page_frame.dart';
import 'package:codecore/ui/screens/podcast/podcasts_screen.dart';
import 'package:codecore/ui/screens/radio/radio_screen.dart';
import 'package:codecore/ui/widgets/page_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 150)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

/// The box the frame gives to the page, on a 1920 px window.
Rect _content(WidgetTester tester) => tester.getRect(
  find
      .descendant(of: find.byType(PageFrame), matching: find.byType(ConstrainedBox))
      .first,
);

void main() {
  final pages = <String, Widget Function()>{
    'home': () => const HomeScreen(),
    'library': () => const LibraryScreen(),
    'online page': () => const OnlinePageFrame(title: 'x', slivers: []),
    'radio': () => const RadioScreen(),
    'podcasts': () => const PodcastsScreen(),
  };

  for (final MapEntry(:key, :value) in pages.entries) {
    testWidgets('$key: 1136 px and centered at 1920', (tester) async {
      tester.view.physicalSize = const Size(1920, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 4);
      await h.pump(tester, value());
      await _settle(tester);
      final r = _content(tester);
      expect(r.width, PageFrame.maxWidth);
      expect(r.center.dx, 960);
      await tester.pump(const Duration(seconds: 10)); // let a page's timers end

      await h.dispose(tester);
    });
  }

  testWidgets('the real side margin is 32 px from 1168 px up, 16 px below (D-720)', (tester) async {
    for (final (w, margin) in [(1168.0, 32.0), (1000.0, 0.0)]) {
      tester.view.physicalSize = Size(w, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const MaterialApp(home: PageFrame(child: SizedBox.expand(key: Key('page')))),
      );
      expect(tester.getRect(find.byKey(const Key('page'))).left, margin, reason: '$w');
    }
  });

  testWidgets('at 360 px the frame leaves the page alone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: PageFrame(child: SizedBox.expand(key: Key('page'))),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('page'))).width, 360);
  });
}

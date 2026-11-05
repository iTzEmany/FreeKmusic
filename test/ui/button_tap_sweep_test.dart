// TalkBack double tap runs the tap action of the focused node: a node flagged
// as button without that action is dead (docs/gotchas.md). Sweeps the main
// screens for such nodes.
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:codecore/ui/screens/home/home_screen.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/now_playing/queue_sheet.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  late SemanticsHandle handle;
  setUp(
    () => handle = TestWidgetsFlutterBinding.ensureInitialized()
        .ensureSemantics(),
  );
  tearDown(() => handle.dispose());

  final screens = <String, Widget Function()>{
    'shell (home)': () => const AppShell(),
    'home': () => const HomeScreen(),
    'library': () => const LibraryScreen(),
    'now playing': () => const NowPlayingScreen(desktop: false),
    'settings': () => const SettingsScreen(),
    'queue': () =>
        Scaffold(body: QueueSheet(scrollController: ScrollController())),
  };

  for (final e in screens.entries) {
    testWidgets('${e.key}: every button node has the tap action', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 3);
      await h.pump(tester, e.value());
      final dead = <String>[];
      var buttons = 0;
      void visit(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (n.flagsCollection.isButton) buttons++;
        if (n.flagsCollection.isButton &&
            n.flagsCollection.isEnabled != Tristate.isFalse &&
            !d.hasAction(SemanticsAction.tap)) {
          dead.add('"${n.label}" ${n.rect}');
        }
        n.visitChildren((c) {
          visit(c);
          return true;
        });
      }

      visit(
        tester
            .binding
            .renderViews
            .first
            .owner!
            .semanticsOwner!
            .rootSemanticsNode!,
      );
      // The sweep saw something (the queue is empty here: no buttons).
      if (e.key != 'queue') expect(buttons, greaterThan(0));
      expect(dead, isEmpty);
      await h.dispose(tester);
    });
  }
}

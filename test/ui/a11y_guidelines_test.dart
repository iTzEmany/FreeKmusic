// Flutter's accessibility guidelines on the main screens, as they are TODAY
// (38.6). Every failure is listed in an exception map, so the test is green now
// and goes red when a NEW failure appears; phase 40 shrinks the maps.
import 'package:codecore/ui/screens/home/home_screen.dart' show clockProvider;
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/screens/library/library_screen.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Failure counts per node: its tooltip or label, else 'unnamed'. A line that
/// cannot be parsed becomes its own key, so it fails loudly.
Map<String, int> _failures(Evaluation e) {
  if (e.passed) return {};
  final lines = e.reason!.split('\n');
  final nodes = lines.where((l) => l.startsWith('SemanticsNode#')).toList();
  final marker = RegExp(
    'expected tap|expected tappable|expected contrast',
    caseSensitive: false,
  );
  final total = lines.where(marker.hasMatch).length;
  expect(
    nodes.length,
    total,
    reason: 'unparsed guideline output:\n${e.reason}',
  );
  final counts = <String, int>{};
  for (final line in nodes) {
    final name =
        RegExp(r'tooltip: "([^"]*)"').firstMatch(line)?.group(1) ??
        RegExp(r'label: "([^"]*)"').firstMatch(line)?.group(1) ??
        (line.contains('Rect.fromLTRB(') ? 'unnamed' : 'unparsed: $line');
    counts[name] = (counts[name] ?? 0) + 1;
  }
  return counts;
}

/// Every failure that exists today, per (screen, guideline). Known defects:
/// phase 40 (D-14 and the tap-target work) removes entries as it fixes them.
const _known = <(String, String), Map<String, int>>{
  // The speed chip is under 48 px (the sleep timer got its 48 px in 154.3).
  ('now playing', 'androidTapTarget'): {
    'Velocità di riproduzione': 1,
  },
  // 150.5: the desktop player bar's dense controls (and the artist link) are
  // under 48 px by design (D-14); phase 152 / 157 close them with the bar rework.
  ('desktop shell (home, sidebar, player bar)', 'androidTapTarget'): {
    'Artist': 1,
    'Casuale: spenta': 1,
    'Brano precedente': 1,
    'Pausa': 1,
    'Brano successivo': 1,
    'Ripeti': 1,
    'Velocità di riproduzione': 1,
  },
};

void main() {
  final screens = <String, Widget>{
    'shell (home, mini player, dock)': const AppShell(),
    'now playing': const NowPlayingScreen(),
    'all tracks': const AllTracksScreen(),
    'settings': const Scaffold(body: SettingsScreen()),
  };
  final guidelines = <String, AccessibilityGuideline>{
    'androidTapTarget': androidTapTargetGuideline,
    'labeledTapTarget': labeledTapTargetGuideline,
    'textContrast': textContrastGuideline,
  };
  // 150.5: the desktop shell (home, library) at 1280 px, before the refactor.
  final desktopScreens = <String, Widget>{
    'desktop shell (home, sidebar, player bar)': const AppShell(),
    'desktop library': const Scaffold(body: LibraryScreen()),
  };
  final all = [
    for (final s in screens.entries) (s.key, s.value, false),
    for (final s in desktopScreens.entries) (s.key, s.value, true),
  ];
  for (final (name, screen, desktop) in all) {
    for (final g in guidelines.entries) {
      testWidgets('$name: ${g.key}', (tester) async {
        // Phone: 48 dp targets; desktop: the dense ones, as the app shows them.
        debugIsDesktopOverride = desktop;
        addTearDown(() => debugIsDesktopOverride = null);
        final sem = tester.ensureSemantics();
        // A tear-down would run after the handle check, so dispose in finally.
        try {
          tester.view.physicalSize = desktop ? const Size(1280, 800) : const Size(400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final h = await Harness.create(tester, tracks: 3);
          final ids = (await tester.runAsync(
            () => h.db.select(h.db.tracks).get(),
          ))!.map((t) => t.id).toList();
          await tester.runAsync(() => h.handler.playQueue(ids, 0));
          await h.pump(
            tester,
            screen,
            extraOverrides: [
              clockProvider.overrideWithValue(() => DateTime(2026, 1, 1, 14)),
            ],
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 500));
          final e = await g.value.evaluate(tester);
          final found = _failures(e);
          expect(
            found,
            _known[(name, g.key)] ?? <String, int>{},
            reason: 'a new failure, or one fixed: update the exception list',
          );
          await h.dispose(tester);
        } finally {
          sem.dispose();
        }
      });
    }
  }
}

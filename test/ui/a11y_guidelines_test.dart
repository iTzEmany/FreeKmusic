// Flutter's accessibility guidelines on the main screens, as they are TODAY
// (38.6). Every failure is listed in an exception map, so the test is green now
// and goes red when a NEW failure appears; phase 40 shrinks the maps.
import 'package:codecore/ui/screens/home/home_screen.dart' show clockProvider;
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
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
  // Sleep timer and speed chips are under 48 px (the total time got its 48 px
  // in phase 59.5).
  ('now playing', 'androidTapTarget'): {
    'Timer di spegnimento': 1,
    'Velocità di riproduzione': 1,
  },
  // Row nodes without a label: the preview cover (custom action) and the swipe area.
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
  for (final s in screens.entries) {
    for (final g in guidelines.entries) {
      testWidgets('${s.key}: ${g.key}', (tester) async {
        debugIsDesktopOverride = false; // phone targets (48 dp), not the desktop's dense ones
        addTearDown(() => debugIsDesktopOverride = null);
        final sem = tester.ensureSemantics();
        // A tear-down would run after the handle check, so dispose in finally.
        try {
          tester.view.physicalSize = const Size(400, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final h = await Harness.create(tester, tracks: 3);
          final ids = (await tester.runAsync(
            () => h.db.select(h.db.tracks).get(),
          ))!.map((t) => t.id).toList();
          await tester.runAsync(() => h.handler.playQueue(ids, 0));
          await h.pump(
            tester,
            s.value,
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
            _known[(s.key, g.key)] ?? <String, int>{},
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

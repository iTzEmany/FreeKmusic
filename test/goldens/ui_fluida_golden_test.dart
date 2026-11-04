// Goldens added by the «ui-fluida» safety net (38.6): they pin today's look of
// Home on desktop, mini player + dock, and car mode at 100 % and 200 % text.
// Linux only, like screens_golden_test.dart.
//   flutter test --update-goldens test/goldens/ui_fluida_golden_test.dart
import 'dart:io';

import 'package:codecore/ui/screens/car/car_mode_screen.dart';
import 'package:codecore/ui/screens/home/home_screen.dart' show clockProvider;
import 'package:codecore/ui/screens/library/all_tracks_screen.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/widgets/cover_image.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_shots/support/shot_harness.dart';
import 'tolerant_comparator.dart';

/// Same colour for the same cover key, on every run.
Color _colourOf(String key) {
  var h = 0x811C9DC5;
  for (final c in key.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFF;
  }
  return Color(0xFF000000 | h | 0x303030);
}

void main() {
  if (!Platform.isLinux) return;

  setUpAll(() {
    TolerantComparator.install();
    coverImageStub = (key) => ColoredBox(color: _colourOf(key));
  });
  tearDownAll(() => coverImageStub = null);

  final clock = clockProvider.overrideWithValue(() => DateTime(2026, 1, 1, 14));

  testWidgets('home on desktop', (tester) => withGoldenShot(tester, ShotSize.desktop, (s) async {
        await tester.runAsync(() => s.h.handler.playQueue(s.seed.trackIds.take(6).toList(), 2));
        await s.show(const AppShell(), extra: [clock]);
        await s.expectGolden('desktop_100_home.png');
      }));

  for (final scale in const [1.0, 2.0]) {
    final tag = (scale * 100).round();
    testWidgets('mini player and dock at $tag %', (tester) => withGoldenShot(tester, ShotSize.phone, (s) async {
          await tester.runAsync(() => s.h.handler.playQueue(s.seed.trackIds.take(6).toList(), 2));
          await s.show(const AppShell(), textScale: scale, extra: [clock]);
          // At 200 % the mini player overflows (pinned in
          // accessibility_characterization_test); drain it so the capture works.
          while (tester.takeException() != null) {}
          await s.expectGolden('phone_${tag}_mini_dock.png');
        }));

    testWidgets('car mode at $tag %', (tester) => withGoldenShot(tester, ShotSize.phone, (s) async {
          await tester.runAsync(() => s.h.handler.playQueue(s.seed.trackIds.take(6).toList(), 2));
          await s.show(const CarModeScreen(), textScale: scale);
          await s.expectGolden('phone_${tag}_car_mode.png');
        }));
  }

  // Phase 58.6: cover fan and track ⋮ sheet, as they look today.
  testWidgets('home with the cover fan open', (tester) => withGoldenShot(tester, ShotSize.phone, (s) async {
        await s.show(const AppShell(), extra: [clock]);
        final cover = find.byKey(const ValueKey('fan-cover-1'));
        await tester.ensureVisible(cover);
        await tester.pump();
        await tester.tap(cover);
        await s.settle();
        await tester.pump(const Duration(seconds: 2));
        await s.expectGolden('phone_100_home_fan_open.png');
      }));

  testWidgets('track actions sheet', (tester) => withGoldenShot(tester, ShotSize.phone, (s) async {
        // Search is online only now: the sheet opens from a library list.
        await s.show(const AllTracksScreen());
        await tester.tap(find.descendant(
            of: find.byType(TrackRow).first, matching: find.byIcon(Icons.more_vert_rounded)));
        await s.settle();
        await s.expectGolden('phone_100_track_actions.png');
      }));
}

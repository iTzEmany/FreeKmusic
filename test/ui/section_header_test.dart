import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/ui/screens/home/home_row.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildThemeFromColors(CcColors.notte, false),
  home: Scaffold(body: Column(children: [child])),
);

void main() {
  testWidgets('shows the title and no action by default', (t) async {
    await t.pumpWidget(_app(const SectionHeader('Brani')));
    expect(find.text('Brani'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('the action label calls the callback', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _app(SectionHeader('Brani', actionLabel: 'Tutti', onAction: () => taps++)),
    );
    await t.tap(find.text('Tutti'));
    expect(taps, 1);
  });

  testWidgets('the action does not change the header height', (t) async {
    await t.pumpWidget(_app(const SectionHeader('Brani')));
    final plain = t.getSize(find.byType(SectionHeader));
    await t.pumpWidget(
      _app(SectionHeader('Brani', actionLabel: 'Tutti', onAction: () {})),
    );
    expect(t.getSize(find.byType(SectionHeader)).height, plain.height);
  });

  for (final desktop in [false, true]) {
    testWidgets('HomeBlock: same space above and below (desktop=$desktop)', (
      t,
    ) async {
      debugIsDesktopOverride = desktop;
      addTearDown(() => debugIsDesktopOverride = null);
      await t.pumpWidget(_app(const HomeBlock(children: [SizedBox(height: 40)])));
      final block = t.getRect(find.byType(HomeBlock));
      final box = t.getRect(find.byType(Material).last);
      expect(box.top - block.top, block.bottom - box.bottom);
      expect((box.top - block.top) * 2, desktop ? 32 : 24);
    });
  }
}

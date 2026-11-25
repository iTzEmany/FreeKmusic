import 'package:codecore/ui/widgets/focus_ring_button.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keyboard focus on an icon button draws an accent outline', (t) async {
    final colors = CcColors.notte;
    final key = GlobalKey();
    await t.pumpWidget(MaterialApp(
      theme: buildThemeFromColors(colors, false),
      home: Material(
        child: IconButton(
          key: key,
          onPressed: () {},
          icon: const Icon(Icons.play_arrow_rounded),
        ),
      ),
    ));
    BorderSide? side() {
      final m = t.widget<Material>(find.descendant(
          of: find.byKey(key), matching: find.byType(Material)).first);
      return (m.shape as OutlinedBorder?)?.side;
    }
    expect(side()?.width ?? 0, 0);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    Focus.of(t.element(find.byIcon(Icons.play_arrow_rounded))).requestFocus();
    await t.pumpAndSettle();
    expect(side()?.width, 2);
    expect(side()?.color, colors.accent);
  });

  testWidgets('keyboard focus on the player-bar cover draws a ring over it', (t) async {
    final colors = CcColors.notte;
    await t.pumpWidget(MaterialApp(
      theme: buildThemeFromColors(colors, false),
      home: Material(
        child: FocusRingButton(
          onTap: () {},
          child: const SizedBox(width: 56, height: 56),
        ),
      ),
    ));
    Finder ring() => find.byWidgetPredicate((w) =>
        w is DecoratedBox &&
        w.position == DecorationPosition.foreground &&
        (w.decoration as BoxDecoration).border != null);
    expect(ring(), findsNothing);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    Focus.of(t.element(find.byType(SizedBox).first)).requestFocus();
    await t.pumpAndSettle();
    expect(ring(), findsOneWidget);
  });
}

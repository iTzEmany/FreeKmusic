import 'dart:ui' as ui;
import 'package:codecore/ui/widgets/focus_ring_button.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:flutter/services.dart';
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

  // 157.6: the ring marks focus only, never selection (F-115).
  testWidgets('after 3 Tabs the focused block has the ring and is not the selected one', (t) async {
    final colors = CcColors.notte;
    var selected = 0;
    await t.pumpWidget(MaterialApp(
      theme: buildThemeFromColors(colors, false),
      home: Material(
        child: StatefulBuilder(
          builder: (_, set) => SegmentedBlocks<int>(
            items: [for (var i = 0; i < 4; i++) BlockItem(value: i, label: 'B$i')],
            selected: selected,
            onChanged: (v) => set(() => selected = v),
          ),
        ),
      ),
    ));
    Finder ring() => find.byWidgetPredicate((w) =>
        w is DecoratedBox &&
        w.position == DecorationPosition.foreground &&
        (w.decoration as BoxDecoration).border != null);
    // Selected (block 0) but not focused: no ring.
    expect(ring(), findsNothing);
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    for (var i = 0; i < 3; i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
    }
    // Focus is on block 2 (third Tab): it has the ring, the selection is still block 0.
    expect(ring(), findsOneWidget);
    expect(find.descendant(of: ring(), matching: find.text('B2')), findsOneWidget);
    expect(selected, 0);
    final nodes = t.getSemantics(find.text('B2'));
    expect(nodes.flagsCollection.isSelected, isNot(ui.Tristate.isTrue));
  });
}

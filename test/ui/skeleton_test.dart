import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app({bool reduce = false}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('it'),
  theme: buildThemeFromColors(
    buildPalette(AppThemeId.notte, CcAccent.viola),
    false,
  ),
  builder: (c, child) => MediaQuery(
    data: MediaQuery.of(c).copyWith(disableAnimations: reduce),
    child: child!,
  ),
  home: const Scaffold(
    body: SingleChildScrollView(child: Skeleton.list(rows: 4)),
  ),
);

void main() {
  testWidgets('rowHeight sets the height of the rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: buildThemeFromColors(
          buildPalette(AppThemeId.notte, CcAccent.viola),
          false,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: Skeleton.list(rows: 3, rowHeight: 80),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(Skeleton)).height, 240);
  });

  testWidgets('one «Caricamento…» node, blocks excluded from semantics', (
    tester,
  ) async {
    final h = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    expect(find.bySemanticsLabel('Caricamento…'), findsOneWidget);
    final node = tester.getSemantics(find.byType(Skeleton));
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    var count = 0;
    node.visitChildren((_) {
      count++;
      return true;
    });
    expect(count, 0);
    h.dispose();
  });

  double opacity(WidgetTester t) => t
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(Skeleton),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('pulses, then stands still at 0.8 when motion is reduced', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    expect(opacity(tester), closeTo(0.55, 0.01));
    await tester.pump(const Duration(milliseconds: 1400));
    expect(opacity(tester), closeTo(1.0, 0.01));

    await tester.pumpWidget(_app(reduce: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    final o = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(Skeleton),
        matching: find.byType(Opacity),
      ),
    );
    expect(o.opacity, 0.8);
  });

  testWidgets('bars fill a bounded height, gridCell lays out its cells', (
    tester,
  ) async {
    for (final sk in [
      const Skeleton.bars(count: 12),
      const Skeleton.gridCell(count: 4),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildThemeFromColors(
            buildPalette(AppThemeId.notte, CcAccent.viola),
            false,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(height: 200, child: sk),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Skeleton), findsOneWidget);
    }
  });

  testWidgets('card: lineHeight, roles rows and list label', (tester) async {
    final h = tester.ensureSemantics();
    Future<void> pump(Widget w) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        theme: buildThemeFromColors(buildPalette(AppThemeId.notte, CcAccent.viola), false),
        home: Scaffold(body: SingleChildScrollView(child: w)),
      ),
    );
    await pump(const Skeleton.card(lines: 3, lineHeight: 30));
    expect(tester.getSize(find.byType(Skeleton)).height, 90);
    await pump(const Skeleton.card(lines: 3, roles: true));
    expect(tester.getSize(find.byType(Skeleton)).height, 144);
    await pump(const Skeleton.list(rows: 1, label: 'Sto scegliendo 3 brani…'));
    expect(find.bySemanticsLabel('Sto scegliendo 3 brani…'), findsOneWidget);
    expect(find.bySemanticsLabel('Caricamento…'), findsNothing);
    h.dispose();
  });
}

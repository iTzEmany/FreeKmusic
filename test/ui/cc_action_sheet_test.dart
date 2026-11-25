import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/menu_support.dart';

String? _result = 'none';

Future<void> _open(WidgetTester tester, {String? title, bool wide = false}) async {
  tester.view.physicalSize = wide ? const Size(1600, 900) : const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _result = 'none';
  await tester.pumpWidget(
    MaterialApp(
      theme: buildThemeFromColors(CcColors.notte, false),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (c) => TextButton(
          onPressed: () async => _result = await showCcActionSheet<String>(
            context: c,
            title: title,
            subtitle: title == null ? null : 'Sub',
            groups: [
              [
                const CcAction(icon: Icons.delete, label: 'Elimina', value: 'del', destructive: true),
                const CcAction(icon: Icons.add, label: 'Aggiungi', value: 'add'),
              ],
              [const CcAction(icon: Icons.sort, label: 'Ordina', value: 'sort', selected: true)],
            ],
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an action that throws after an await closes the sheet and is logged', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final logged = <String?>[];
    final oldPrint = debugPrint;
    debugPrint = (m, {wrapWidth}) => logged.add(m);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildThemeFromColors(CcColors.notte, false),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showCcActionSheet<String>(
              context: c,
              groups: [
                [
                  CcAction(
                    icon: Icons.bolt,
                    label: 'Boom',
                    onTap: () async {
                      await Future<void>.delayed(Duration.zero);
                      throw StateError('x');
                    },
                  ),
                ],
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boom'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Boom'), findsNothing);
    expect(tester.takeException(), isNull);
    debugPrint = oldPrint; // before the framework checks its debug variables
    expect(logged.where((m) => m != null && m.startsWith('[W] sheet action failed: Boom')), isNotEmpty);
  });

  testWidgets('a long label at 2x text grows the row without overflow', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildThemeFromColors(CcColors.notte, false),
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () => showCcActionSheet<String>(
              context: c,
              groups: [
                [CcAction(icon: Icons.add, label: 'Un\'etichetta molto molto lunga che va a capo ' * 2)],
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(ListTile).first).height, greaterThan(59));
  });

  testWidgets('header, rows of 59 dp, destructive last and red', (tester) async {
    await _open(tester, title: 'Brano');
    expect(find.text('Brano'), findsOneWidget);
    expect(find.text('Sub'), findsOneWidget);
    expect(shownMenuEntries(tester), ['add', 'sort', 'del']);
    expect(tester.getSize(find.ancestor(of: find.text('Aggiungi'), matching: find.byType(ConstrainedBox)).first).height, 59);
    final red = tester.widget<Text>(find.text('Elimina')).style!.color;
    expect(red, CcColors.notte.error);
  });

  testWidgets('first row has the focus; Esc closes without a value', (tester) async {
    await _open(tester);
    expect(Focus.of(tester.element(find.text('Aggiungi'))).hasPrimaryFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Aggiungi'), findsNothing);
    expect(_result, isNull);
  });

  testWidgets('barrierLabel is localized', (tester) async {
    await _open(tester);
    final route = ModalRoute.of(tester.element(find.text('Aggiungi')))! as PopupRoute;
    expect(route.barrierLabel, 'Chiudi');
  });

  testWidgets('at most 560 dp wide on desktop', (tester) async {
    await _open(tester, wide: true);
    expect(tester.getSize(find.byType(ListTile).first).width, lessThanOrEqualTo(560));
  });

  // 155.1: same actions and same value whichever way the platform is said (the sheet becomes a dialog later).
  for (final desktop in [false, true]) {
    testWidgets('tapping a row returns its value, desktop: $desktop', (tester) async {
      debugIsDesktopOverride = desktop;
      addTearDown(() => debugIsDesktopOverride = null);
      await _open(tester);
      expect(shownMenuEntries(tester), ['add', 'sort', 'del']);
      await tester.tap(find.text('Ordina'));
      await tester.pumpAndSettle();
      expect(_result, 'sort');
    });
  }
}

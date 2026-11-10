import 'package:codecore/providers/jam_gate_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_providers.dart';
import 'package:codecore/providers/theme_providers.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/screens/stats/stats_screen.dart';
import 'package:codecore/ui/theme/custom_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _titles = [
  'Aspetto e lingua',
  'Riproduzione',
  'Libreria',
  'Daylist',
  'Online e download',
  'Rete e dispositivi',
  'Backup',
  'Avanzate e info',
];

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

ProviderContainer _container(WidgetTester t) =>
    ProviderScope.containerOf(t.element(find.byType(SettingsScreen)));

void main() {
  testWidgets('phone index shows 8 entries with summaries', (t) async {
    _size(t, 400, 800);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    for (final s in _titles) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.textContaining('Notte'), findsOneWidget);
    expect(
      find.text('Dissolvenza'),
      findsNothing,
      reason: 'tiles live on the pages',
    );
    await h.dispose(t);
  });

  testWidgets('the fixed Statistiche entry opens the stats screen', (t) async {
    _size(t, 400, 1200);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    await t.tap(find.text('Statistiche'));
    await t.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('entry opens its page with no group title', (t) async {
    _size(t, 400, 1200);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    await t.tap(find.text('Riproduzione'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsPageView), findsOneWidget);
    expect(find.text('Registra la cronologia di ascolto'), findsOneWidget);
    expect(find.text('Normalizza volume'), findsOneWidget);
    // One group: the title is only in the app bar.
    expect(find.text('Riproduzione'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets(
    'network page without trusted devices: one group, no title, summary is the device name',
    (t) async {
      _size(t, 400, 1200);
      final h = await Harness.create(t);
      await h.pump(t, const Scaffold(body: SettingsScreen()));
      final name = _container(t).read(deviceNameProvider);
      expect(find.text(name), findsOneWidget);
      await t.tap(find.text('Rete e dispositivi'));
      await t.pumpAndSettle();
      expect(find.text('Rete locale'), findsNothing);
      expect(find.text('Dispositivi fidati'), findsNothing);
      await h.dispose(t);
    },
  );

  testWidgets('network page: unblocking removes the entry without reopening', (
    t,
  ) async {
    _size(t, 400, 1200);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    _container(t).read(jamGateProvider).block('abcdefgh', 'Mario Blocked');
    await t.tap(find.text('Rete e dispositivi'));
    await t.pumpAndSettle();
    expect(find.text('Mario Blocked'), findsOneWidget);
    await t.tap(find.text('Sblocca'));
    await t.pumpAndSettle();
    expect(find.text('Mario Blocked'), findsNothing);
    await h.dispose(t);
  });

  testWidgets('online page keeps enrich and auto tiles', (t) async {
    _size(t, 400, 1200);
    final h = await Harness.create(t);
    await h.pump(
      t,
      const Scaffold(body: SettingsScreen(initial: SettingsPage.online)),
    );
    expect(find.text('Arricchisci tutta la libreria'), findsOneWidget);
    expect(find.text('Arricchimento automatico'), findsOneWidget);
    expect(find.text('Testi automatici'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('backup page keeps create and restore', (t) async {
    _size(t, 400, 1200);
    final h = await Harness.create(t);
    await h.pump(
      t,
      const Scaffold(body: SettingsScreen(initial: SettingsPage.backup)),
    );
    expect(find.text('Crea backup'), findsOneWidget);
    expect(find.text('Ripristina da backup'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('library summary counts all tracks, not the search result', (
    t,
  ) async {
    _size(t, 400, 800);
    final h = await Harness.create(t, tracks: 3);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    expect(find.textContaining('3 brani'), findsOneWidget);
    _container(t)
        .read(trackQueryProvider(false).notifier)
        .update((q) => q.copyWith(text: 'zzz-no-match'));
    await t.pumpAndSettle();
    expect(find.textContaining('3 brani'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a page with several groups keeps their titles', (t) async {
    _size(t, 400, 1200);
    final h = await Harness.create(t);
    await h.pump(
      t,
      const Scaffold(body: SettingsScreen(initial: SettingsPage.appearance)),
    );
    expect(find.text('Aspetto'), findsOneWidget);
    expect(find.text('Lingua'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('index at 150 % with a long summary', (t) async {
    _size(t, 360, 780);
    final h = await Harness.create(t);
    await h.pump(
      t,
      Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: const Scaffold(body: SettingsScreen()),
        ),
      ),
    );
    final c = _container(t);
    c
        .read(customThemesProvider.notifier)
        .put(
          const CustomTheme(
            id: 'long',
            name: 'Un tema dal nome molto lungo che non sta in una riga sola',
          ),
        );
    c
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(theme: customThemeSettingValue('long')));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
    final summary = find.textContaining('Un tema dal nome');
    expect(summary, findsOneWidget);
    expect(t.widget<Text>(summary).maxLines, 1);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(9)); // 8 pages + Statistiche
    await h.dispose(t);
  });

  testWidgets('desktop shows index and page side by side', (t) async {
    _size(t, 1280, 800);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    final index = t.getRect(find.text('Backup').first);
    final tile = t.getRect(find.text('Tema'));
    expect(tile.left, greaterThanOrEqualTo(index.left + 280));
    await t.tap(find.text('Backup'));
    await t.pumpAndSettle();
    expect(find.text('Crea backup'), findsOneWidget);
    expect(
      t.widget<ListTile>(find.widgetWithText(ListTile, 'Backup')).selected,
      isTrue,
    );
    await h.dispose(t);
  });

  testWidgets('resize across the breakpoint keeps the page', (t) async {
    _size(t, 1280, 800);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    await t.tap(find.text('Backup'));
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(400, 800);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('Tema'), findsNothing);
    t.view.physicalSize = const Size(1280, 800);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(
      t.widget<ListTile>(find.widgetWithText(ListTile, 'Backup')).selected,
      isTrue,
    );
    expect(find.text('Crea backup'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('index entries take keyboard focus', (t) async {
    _size(t, 1280, 800);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen()));
    final entry = find.widgetWithText(ListTile, 'Riproduzione');
    bool focused() =>
        t
            .widgetList<Focus>(
              find.descendant(of: entry, matching: find.byType(Focus)),
            )
            .any((f) => f.focusNode?.hasFocus ?? false) ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<ListTile>() ==
            t.widget<ListTile>(entry);
    for (var i = 0; i < 20 && !focused(); i++) {
      await t.sendKeyEvent(LogicalKeyboardKey.tab);
      await t.pump();
    }
    expect(focused(), isTrue);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(t.widget<ListTile>(entry).selected, isTrue);
    await h.dispose(t);
  });
}

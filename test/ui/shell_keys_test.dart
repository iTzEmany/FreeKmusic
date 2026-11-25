import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/app_restart_provider.dart';
import 'package:codecore/providers/nav_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/ui_providers.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/shell/shortcuts_overlay.dart';
import 'package:codecore/providers/preview_providers.dart';
import 'package:codecore/services/audio/preview_player.dart';
import 'package:codecore/ui/shell/app_shell.dart';
import 'package:codecore/ui/shell/shell_keys.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _space = SingleActivator(LogicalKeyboardKey.space);
const _next = SingleActivator(LogicalKeyboardKey.arrowRight, control: true);

Widget _app({
  required List<String> log,
  required TextEditingController text,
  required bool Function() showField,
}) => MaterialApp(
  home: ShellKeys(
    bindings: {_space: () => log.add('space'), _next: () => log.add('next')},
    textOnly: const {_space},
    child: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => Column(
          children: [
            Offstage(
              offstage: !showField(),
              child: ExcludeFocus(
                excluding: !showField(),
                child: TextField(controller: text),
              ),
            ),
            const Text('page'),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a text field gets Space as text, not as a shortcut', (
    tester,
  ) async {
    final log = <String>[];
    final text = TextEditingController();
    addTearDown(text.dispose);
    await tester.pumpWidget(_app(log: log, text: text, showField: () => true));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'long');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(log, isEmpty);
    // Other shortcuts still work with the field focused.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(log, ['next']);
  });

  testWidgets('shortcuts come back after the focused widget goes offstage', (
    tester,
  ) async {
    final log = <String>[];
    final text = TextEditingController();
    addTearDown(text.dispose);
    var show = true;
    late StateSetter set;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return _app(log: log, text: text, showField: () => show);
          },
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    set(() => show = false);
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(log, ['space']);
  });

  // Today's key -> action map of AppShell (Ctrl+F, Alt+Left and Esc on a sheet: app_shell_test).
  Future<void> chord(WidgetTester t, LogicalKeyboardKey mod, LogicalKeyboardKey key) async {
    await t.sendKeyDownEvent(mod);
    await t.sendKeyEvent(key);
    await t.sendKeyUpEvent(mod);
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<Harness> shell(WidgetTester t, {List<Override> extra = const []}) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 3);
    final rows = await t.runAsync(() => h.db.select(h.db.tracks).get());
    await t.runAsync(() => h.handler.playQueue([for (final r in rows!) r.id], 1));
    await h.pump(t, const AppShell(), extraOverrides: extra);
    return h;
  }

  ProviderContainer container(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(AppShell)));

  Future<void> until(WidgetTester t, bool Function() ok) async {
    for (var i = 0; i < 40 && !ok(); i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
      await t.pump(const Duration(milliseconds: 25));
    }
  }

  testWidgets('shell: Space toggles play/pause', (t) async {
    final h = await shell(t);
    final before = h.handler.isPlaying;
    await t.sendKeyEvent(LogicalKeyboardKey.space);
    await until(t, () => h.handler.isPlaying != before);
    expect(h.handler.isPlaying, !before);
    await h.dispose(t);
  });

  testWidgets('shell: Ctrl+Right goes to the next track, Ctrl+Left back', (t) async {
    final h = await shell(t);
    expect(h.handler.currentTrack?.title, 'Song 1');
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowRight);
    await until(t, () => h.handler.currentTrack?.title == 'Song 2');
    expect(h.handler.currentTrack?.title, 'Song 2');
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowLeft);
    await until(t, () => h.handler.currentTrack?.title == 'Song 1');
    expect(h.handler.currentTrack?.title, 'Song 1');
    await h.dispose(t);
  });

  testWidgets('shell: Ctrl+Up / Ctrl+Down move the volume by 5 %', (t) async {
    final h = await shell(t);
    final c = container(t);
    c.read(volumeProvider.notifier).set(0.5);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowUp);
    expect(c.read(volumeProvider), closeTo(0.55, 1e-9));
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowDown);
    await chord(t, LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.arrowDown);
    expect(c.read(volumeProvider), closeTo(0.45, 1e-9));
    await h.dispose(t);
  });

  Future<void> tap(WidgetTester t, LogicalKeyboardKey key, {LogicalKeyboardKey? mod}) async {
    if (mod != null) await t.sendKeyDownEvent(mod);
    await t.sendKeyEvent(key);
    if (mod != null) await t.sendKeyUpEvent(mod);
    await t.pump(const Duration(milliseconds: 300));
  }

  GlobalKey<NavigatorState> homeNav(ProviderContainer c) => c.read(tabNavigatorKeysProvider)[NavTab.home.index];

  Future<void> pushPage(WidgetTester t, ProviderContainer c) async {
    homeNav(c).currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('inner'))));
    await t.pumpAndSettle();
  }

  testWidgets('shell: Backspace goes back, Alt+Right forward again', (t) async {
    final h = await shell(t);
    final c = container(t);
    await pushPage(t, c);
    await tap(t, LogicalKeyboardKey.backspace);
    await t.pumpAndSettle();
    expect(find.text('inner'), findsNothing);
    await tap(t, LogicalKeyboardKey.arrowRight, mod: LogicalKeyboardKey.altLeft);
    await t.pumpAndSettle();
    expect(find.text('inner'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('shell: F5 asks the page on screen to reload', (t) async {
    final h = await shell(t);
    final c = container(t);
    await tap(t, LogicalKeyboardKey.f5);
    expect(c.read(reloadRequestProvider), 1);
    await h.dispose(t);
  });

  testWidgets('shell: «/» goes to search with the field focused', (t) async {
    final h = await shell(t);
    final c = container(t);
    await tap(t, LogicalKeyboardKey.slash);
    expect(c.read(navIndexProvider), isNot(NavTab.home.index));
    await h.dispose(t);
  });

  testWidgets('shell: Ctrl+L opens Search with the link on the clipboard', (t) async {
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return <String, Object?>{'text': 'https://example.com/x'};
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final h = await shell(t);
    final c = container(t);
    await tap(t, LogicalKeyboardKey.keyL, mod: LogicalKeyboardKey.controlLeft);
    await t.pump(const Duration(milliseconds: 300));
    expect(c.read(navIndexProvider), NavTab.search.index);
    expect(c.read(searchControllerProvider).text, 'https://example.com/x');
    await h.dispose(t);
  });

  testWidgets('shell: Ctrl+, opens the settings', (t) async {
    final h = await shell(t);
    await tap(t, LogicalKeyboardKey.comma, mod: LogicalKeyboardKey.controlLeft);
    await t.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('shell: Ctrl+Q quits', (t) async {
    var quit = 0;
    final h = await shell(t, extra: [quitAppProvider.overrideWithValue(() async => quit++)]);
    await tap(t, LogicalKeyboardKey.keyQ, mod: LogicalKeyboardKey.controlLeft);
    expect(quit, 1);
    await h.dispose(t);
  });

  // «?» is the slash key with that character (the table matches the character).
  Future<void> question(WidgetTester t) async {
    await t.sendKeyDownEvent(LogicalKeyboardKey.slash, character: '?');
    await t.sendKeyUpEvent(LogicalKeyboardKey.slash);
    await t.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shell: «?» opens the list with every action of the table', (t) async {
    final h = await shell(t);
    t.view.physicalSize = const Size(1280, 2400);
    await question(t);
    await t.pumpAndSettle();
    for (final a in ShortcutAction.values) {
      expect(find.byKey(ValueKey('shortcut-${a.name}')), findsOneWidget, reason: a.name);
    }
    await h.dispose(t);
  });

  testWidgets('the overlay can be opened on its own', (t) async {
    await t.pumpWidget(MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, home: Builder(builder: (c) => TextButton(onPressed: () => showShortcutsOverlay(c), child: const Text('go')))));
    await t.tap(find.text('go'));
    await t.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('with a text field focused Backspace, «/» and «?» are text, not shortcuts', (t) async {
    final log = <String>[];
    final text = TextEditingController();
    addTearDown(text.dispose);
    final k = shortcutBindings({for (final a in ShortcutAction.values) a: () => log.add(a.name)});
    await t.pumpWidget(MaterialApp(
      home: ShellKeys(bindings: k.bindings, textOnly: k.textOnly, child: Scaffold(body: TextField(controller: text))),
    ));
    await t.tap(find.byType(TextField));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.backspace);
    await t.sendKeyEvent(LogicalKeyboardKey.slash);
    await question(t);
    expect(log, isEmpty);
    await t.sendKeyEvent(LogicalKeyboardKey.f5);
    expect(log, ['reload']);

  });

  testWidgets('listenReload: only the page on top reloads', (t) async {
    final hits = <String>[];
    late ProviderContainer c;
    Widget page(String name) => Consumer(builder: (ctx, ref, _) {
      listenReload(ctx, ref, () => hits.add(name));
      return Text(name);
    });
    await t.pumpWidget(ProviderScope(child: MaterialApp(home: Consumer(builder: (ctx, ref, _) {
      c = ProviderScope.containerOf(ctx);
      return page('under');
    }))));
    Navigator.of(t.element(find.text('under'))).push(MaterialPageRoute<void>(builder: (_) => page('top')));
    await t.pumpAndSettle();
    c.read(reloadRequestProvider.notifier).request();
    await t.pump();
    expect(hits, ['top']);
  });

  testWidgets('shell: Esc with no preview running does not call stop', (t) async {
    final fake = _Preview(active: false);
    final h = await shell(t, extra: [previewProvider.overrideWith(() => fake)]);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(fake.stopped, 0);
    await h.dispose(t);
  });

  testWidgets('shell: Esc ends a running preview', (t) async {
    final fake = _Preview();
    final h = await shell(t, extra: [previewProvider.overrideWith(() => fake)]);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(fake.stopped, 1);
    await h.dispose(t);
  });
}

class _Preview extends PreviewNotifier {
  _Preview({this.active = true});

  final bool active;
  int stopped = 0;

  @override
  PreviewState build() => active ? PreviewState(trackId: 1, startedAt: DateTime(2020)) : const PreviewState();

  @override
  Future<void> stop() async => stopped++;
}

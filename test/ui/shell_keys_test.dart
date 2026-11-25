import 'package:codecore/providers/player_providers.dart';
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

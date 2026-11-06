import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/theme_providers.dart';
import 'package:codecore/ui/screens/settings/theme_background_editor.dart';
import 'package:codecore/ui/screens/settings/theme_editor_screen.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 600)); // a page leaving takes a moment
}

/// Real I/O (files, the image codec) only moves while the test yields to the
/// real event loop, so wait in small steps until [done]. The budget is generous
/// (it is only spent on a loaded machine): a short one made this flaky.
Future<void> _until(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _back(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  await tester.runAsync(nav.maybePop);
  await _settle(tester);
}

/// A page with a button that opens the editor, like the settings screen does.
class _Opener extends StatelessWidget {
  const _Opener(this.theme);

  final CustomTheme theme;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ThemeEditorScreen(initial: theme)),
            ),
            child: const Text('open'),
          ),
        ),
      );
}

const _theme = CustomTheme(id: 'sea', name: 'Mare');

void main() {
  late Harness h;

  Future<ProviderContainer> open(WidgetTester tester, {CustomTheme theme = _theme}) async {
    tester.view.physicalSize = const Size(500, 4200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester);
    await h.pump(tester, _Opener(theme));
    await tester.tap(find.text('open'));
    await _settle(tester);
    return ProviderScope.containerOf(tester.element(find.byType(ThemeEditorScreen)));
  }

  Finder saveButton() => find.descendant(of: find.byType(AppBar), matching: find.text('Salva'));
  Finder hexField() => find.descendant(of: find.byType(CcColorPicker), matching: find.byType(TextField));

  testWidgets('a simple theme asks for background, accent and text; advanced shows all twelve', (tester) async {
    await open(tester);
    for (final t in [CcToken.bg, CcToken.accent, CcToken.text]) {
      expect(find.byKey(ValueKey('token-${t.name}')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('token-surface2')), findsNothing);
    await tester.tap(find.text('Avanzata'));
    await _settle(tester);
    for (final t in CcToken.values) {
      expect(find.byKey(ValueKey('token-${t.name}')), findsOneWidget, reason: t.name);
    }
    await h.dispose(tester);
  });

  testWidgets('typing a colour changes the theme, saving stores it and makes it the one in use', (tester) async {
    final c = await open(tester);
    await tester.tap(find.byKey(const ValueKey('token-bg')));
    await _settle(tester);
    await tester.enterText(hexField(), '#10203F');
    await _settle(tester);
    expect(find.text('#10203F'), findsWidgets);

    await tester.tap(saveButton());
    await _settle(tester);
    final saved = c.read(customThemesProvider).byId('sea')!;
    expect(saved.overrides[CcToken.bg], const Color(0xFF10203F));
    expect(c.read(settingsProvider).theme, 'custom:sea');
    expect(find.byType(ThemeEditorScreen), findsNothing, reason: 'back on the page that opened it');
    expect(find.text('Tema salvato'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('nothing is stored until «Salva»; leaving with changes asks, without changes does not', (tester) async {
    final c = await open(tester);
    await _back(tester);
    expect(find.byType(ThemeEditorScreen), findsNothing, reason: 'no change: no question');

    await tester.tap(find.text('open'));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('token-accent')));
    await _settle(tester);
    await tester.enterText(hexField(), '#FF8800');
    await _settle(tester);
    await _back(tester);
    expect(find.text('Scartare le modifiche?'), findsOneWidget);
    await tester.tap(find.text('Scarta'));
    await _settle(tester);
    expect(find.byType(ThemeEditorScreen), findsNothing);
    expect(c.read(customThemesProvider).items, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('a colour set by hand can be taken back with its reset button', (tester) async {
    await open(tester, theme: _theme.withColor(CcToken.accent, const Color(0xFFFF8800)));
    final reset = find.descendant(
      of: find.byKey(const ValueKey('token-accent')),
      matching: find.byTooltip('Ripristina il colore'),
    );
    expect(reset, findsOneWidget);
    await tester.tap(reset);
    await _settle(tester);
    expect(reset, findsNothing);
    expect(find.descendant(of: find.byKey(const ValueKey('token-accent')), matching: find.text('#A06BFF')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('unreadable text is flagged and «Correggi» makes it readable', (tester) async {
    final bad = _theme.withColor(CcToken.text, const Color(0xFF07050D)); // text close to the dark bg
    await open(tester, theme: bad);
    final row = find.byKey(const ValueKey('contrast-Testo su sfondo'));
    expect(find.descendant(of: row, matching: find.textContaining('Poco leggibile')), findsOneWidget);
    await tester.tap(find.descendant(of: row, matching: find.text('Correggi')));
    await _settle(tester);
    expect(find.descendant(of: row, matching: find.textContaining('Poco leggibile')), findsNothing);
    expect(find.descendant(of: row, matching: find.text('Correggi')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('an empty name is saved as the editor title; a full list refuses a new theme', (tester) async {
    final c = await open(tester, theme: const CustomTheme(id: 'new', name: ''));
    for (var i = 0; i < kMaxCustomThemes; i++) {
      c.read(customThemesProvider.notifier).put(CustomTheme(id: 'x$i', name: 'x$i'));
    }
    await tester.tap(saveButton());
    await _settle(tester);
    expect(find.text('Hai già 20 temi: eliminane uno'), findsOneWidget);
    expect(find.byType(ThemeEditorScreen), findsOneWidget, reason: 'stays open so nothing is lost');
    c.read(customThemesProvider.notifier).remove('x0');
    await tester.tap(saveButton());
    await _settle(tester);
    expect(c.read(customThemesProvider).byId('new')!.name, 'Tema personalizzato');
    await h.dispose(tester);
  });

  group('background', () {
    Future<Uint8List> png(WidgetTester tester, int w, int h) async => (await tester.runAsync(() async {
          final rec = ui.PictureRecorder();
          ui.Canvas(rec).drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const Color(0xFFCC3300));
          final img = await rec.endRecording().toImage(w, h);
          return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        }))!;

    Future<(List<ThemeBackground>, Directory)> pumpEditor(
      WidgetTester tester, {
      ThemeBackground start = const ThemeBackground(),
      Future<File?> Function()? pick,
      Directory? dir,
    }) async {
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      h = await Harness.create(tester);
      final seen = <ThemeBackground>[];
      var current = start;
      await h.pump(
        tester,
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => SingleChildScrollView(
              child: ThemeBackgroundEditor(
                themeId: 'sea',
                colors: CcColors.notte,
                background: current,
                recent: const [],
                pickImage: pick,
                imageDir: () async => dir ?? Directory.systemTemp,
                onChanged: (b) {
                  seen.add(b);
                  setState(() => current = b);
                },
              ),
            ),
          ),
        ),
      );
      return (seen, Directory.systemTemp);
    }

    testWidgets('choosing a gradient gives it an end colour and an angle', (tester) async {
      final (seen, _) = await pumpEditor(tester);
      await tester.tap(find.text('Sfumatura'));
      await _settle(tester);
      expect(seen.last.kind, ThemeBackgroundKind.gradient);
      expect(seen.last.gradientEnd, CcColors.notte.heroBase);
      expect(find.byKey(const ValueKey('bg-gradient-end')), findsOneWidget);
      expect(find.text('Direzione'), findsOneWidget);
      expect(find.text('Scegli immagine…'), findsNothing);
      await h.dispose(tester);
    });

    testWidgets('a picture that cannot be read says so and changes nothing', (tester) async {
      final junk = File('${Directory.systemTemp.path}/not-a-picture-${DateTime.now().microsecondsSinceEpoch}.png')
        ..writeAsStringSync('this is text');
      addTearDown(() => junk.deleteSync());
      final (seen, _) = await pumpEditor(
        tester,
        start: const ThemeBackground(kind: ThemeBackgroundKind.image),
        pick: () async => junk,
        dir: Directory.systemTemp.createTempSync('bgjunk'),
      );
      await tester.tap(find.text('Scegli immagine…'));
      await _until(tester, () => find.text("Impossibile usare l'immagine").evaluate().isNotEmpty);
      expect(find.text("Impossibile usare l'immagine"), findsOneWidget);
      expect(seen, isEmpty);
      await h.dispose(tester);
    });

    // The scaling itself is covered by test/services/theme/background_image_test.dart:
    // a small picture keeps this test quick on a loaded machine.
    testWidgets('a picture is copied in and becomes the background', (tester) async {
      final dir = Directory.systemTemp.createTempSync('bgdir');
      addTearDown(() => dir.deleteSync(recursive: true));
      final src = File('${dir.path}/src.png')..writeAsBytesSync(await png(tester, 64, 36));
      final (seen, _) = await pumpEditor(
        tester,
        start: const ThemeBackground(kind: ThemeBackgroundKind.image),
        pick: () async => src,
        dir: Directory('${dir.path}/theme'),
      );
      await tester.tap(find.text('Scegli immagine…'));
      await _until(tester, () => seen.isNotEmpty);
      final path = seen.last.imagePath!;
      expect(File(path).existsSync(), isTrue);
      expect(path, contains('bg-sea-'));
      expect(seen.last.isCustom, isTrue);
      expect(find.text('Oscuramento'), findsOneWidget);
      expect(find.text('Sfocatura'), findsOneWidget);
      expect(find.text('Rimuovi immagine'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('without a picture the sliders are not shown; the cover-tint switch is', (tester) async {
      await pumpEditor(tester, start: const ThemeBackground(kind: ThemeBackgroundKind.image));
      expect(find.text('Oscuramento'), findsNothing);
      expect(find.text('In riproduzione: tinta della copertina'), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('plain colour has no extra controls', (tester) async {
      await pumpEditor(tester);
      expect(find.text('Direzione'), findsNothing);
      expect(find.text('Scegli immagine…'), findsNothing);
      expect(find.text('In riproduzione: tinta della copertina'), findsNothing);
      await h.dispose(tester);
    });
  });
}

import 'package:codecore/ui/widgets/play_buttons.dart';
import 'package:flutter/rendering.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/collection_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

ThemeData _theme(AppThemeId id) => buildThemeFromColors(
    buildPalette(id, accentFromName('')), false);

Future<void> _pump(WidgetTester tester, Widget child,
    {AppThemeId id = AppThemeId.notte, double scale = 1}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: _theme(id),
    builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: w!),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
}

void main() {
  for (final scale in [1.0, 1.5]) {
    testWidgets('long single word title shrinks instead of breaking ($scale)',
        (tester) async {
      await _pump(tester,
          const CollectionHeader(name: 'Supercalifragilis'),
          scale: scale);
      final text = tester.widget<Text>(find.byKey(const ValueKey('collection-name')));
      final box = tester.renderObject<RenderParagraph>(
          find.byKey(const ValueKey('collection-name')));
      expect(box.size.height, lessThan(text.style!.fontSize! * scale * 1.6));
      final base = _theme(AppThemeId.notte).textTheme.headlineSmall!.fontSize!;
      expect(text.style!.fontSize!, lessThan(base));
    });
  }

  testWidgets('normal title keeps theme size', (tester) async {
    await _pump(tester, const CollectionHeader(name: 'Corsa del sabato'));
    final text = tester.widget<Text>(find.byKey(const ValueKey('collection-name')));
    expect(text.style!.fontSize,
        _theme(AppThemeId.notte).textTheme.headlineSmall!.fontSize);
  });

  for (final id in [AppThemeId.notte, AppThemeId.chiaro]) {
    testWidgets('selected chip is the text-coloured block ($id)', (tester) async {
      late CcColors cc;
      await _pump(
          tester,
          Builder(builder: (context) {
            cc = context.cc;
            return Column(children: [
              const ChoiceChip(label: Text('On'), selected: true, onSelected: null),
              ChoiceChip(label: const Text('Off'), selected: false, onSelected: (_) {}),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('Uno')),
                  ButtonSegment(value: 2, label: Text('Due')),
                ],
                selected: const {1},
              ),
            ]);
          }),
          id: id);
      final chipTheme = Theme.of(tester.element(find.text('On'))).chipTheme;
      expect(chipTheme.secondaryLabelStyle!.color, cc.bg);
      expect(chipTheme.selectedColor, cc.text);
      expect(chipTheme.backgroundColor, cc.surface2);
      final seg = Theme.of(tester.element(find.text('Uno'))).segmentedButtonTheme.style!;
      expect(seg.backgroundColor!.resolve({WidgetState.selected}), cc.text);
      expect(seg.foregroundColor!.resolve({WidgetState.selected}), cc.bg);
      expect(seg.backgroundColor!.resolve({}), cc.surface2);
    });
  }

  group('icon row', () {
    Future<Harness> pumpScaffold(WidgetTester tester, {VoidCallback? onDownload}) async {
      final h = await Harness.create(tester, tracks: 0);
      await h.pump(
        tester,
        CollectionScaffold(
          title: 'T',
          name: 'Nome',
          slivers: const [],
          onPlay: () {},
          shuffleIds: const [1, 2],
          onDownload: onDownload,
          menu: const SizedBox.square(dimension: 48),
        ),
      );
      return h;
    }

    testWidgets('sizes, labels and tooltips', (tester) async {
      final sem = tester.ensureSemantics();
      final h = await pumpScaffold(tester, onDownload: () {});
      expect(tester.getSize(find.byType(PlayCircleButton)), const Size(56, 56));
      expect(tester.getSize(find.byIcon(Icons.shuffle_rounded).hitTestable()).width, lessThan(48));
      expect(find.bySemanticsLabel('Riproduci'), findsOneWidget);
      expect(find.byTooltip('Riproduci'), findsOneWidget);
      // IconButton hands its tooltip to the semantics node as its name.
      expect(find.byTooltip('Scarica'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('[Cc]asuale|[Ss]huffle|mescol', caseSensitive: false)), findsWidgets);
      final shuffle = tester.getSize(find.ancestor(
          of: find.byIcon(Icons.shuffle_rounded), matching: find.byType(SizedBox)).first);
      expect(shuffle, const Size(48, 48));
      expect(tester.getSize(find.ancestor(
          of: find.byIcon(Icons.download_rounded), matching: find.byType(SizedBox)).first),
          const Size(48, 48));
      sem.dispose();
      await h.dispose(tester);
    });

    testWidgets('download icon is hidden without callback', (tester) async {
      final h = await pumpScaffold(tester);
      expect(find.byIcon(Icons.download_rounded), findsNothing);
      await h.dispose(tester);
    });
  });
}

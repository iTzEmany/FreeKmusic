import 'package:codecore/core/platform.dart' show debugIsDesktopOverride;
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/online/online_song_row.dart';
import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/context_menu.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _r = YtResult(id: 'v1', title: 'Online song', channel: 'Chan', duration: Duration(seconds: 90), artists: ['Ann'], artistIds: ['UC1']);

class _Downloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => [];
}

Finder get _items => find.byType(PopupMenuItem<MenuAction>);

Future<void> _rightClick(WidgetTester tester, Offset at) async {
  final g = await tester.startGesture(at, kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await g.up();
  await tester.pumpAndSettle();
}

/// Texts of the entries of the menu open now.
List<String?> _menuLabels(WidgetTester tester) => [
  for (final i in tester.widgetList<PopupMenuItem<MenuAction>>(_items)) i.value!.label,
];

Future<void> _plain(WidgetTester tester, Widget Function(BuildContext) home) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildThemeFromColors(CcColors.notte, false),
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Builder(builder: home)),
    ),
  );
}

void main() {
  tearDown(() => debugIsDesktopOverride = null);

  Future<Harness> pumpOnlineRow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: OnlineSongTile(result: _r, index: 0, selectionKey: 'k')),
      extraOverrides: [downloadsProvider.overrideWith(_Downloads.new)],
    );
    return h;
  }

  testWidgets('desktop: right click on an online row opens the menu at the click; Esc closes it', (tester) async {
    debugIsDesktopOverride = true;
    final h = await pumpOnlineRow(tester);
    const click = Offset(300, 30);
    await _rightClick(tester, click);
    expect(_items, findsWidgets);
    final first = tester.getTopLeft(_items.first);
    expect(first.dx, inInclusiveRange(click.dx, click.dx + 24));
    expect(first.dy, inInclusiveRange(click.dy, click.dy + 24));
    expect(tester.getSize(_items.first).height, 36);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(_items, findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the menu has the entries of the sheet (the ⋮ of a phone)', (tester) async {
    debugIsDesktopOverride = false;
    final h = await pumpOnlineRow(tester);
    await tester.tap(find.byTooltip('Altre opzioni'));
    await tester.pumpAndSettle();
    final sheet = [
      for (final t in tester.widgetList<ListTile>(find.descendant(of: find.byType(BottomSheet), matching: find.byType(ListTile))))
        if (t.leading != null) (t.title! as Text).data,
    ];
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(sheet, isNotEmpty);
    debugIsDesktopOverride = true;
    await _rightClick(tester, const Offset(300, 30));
    expect(_menuLabels(tester), sheet);
    await h.dispose(tester);
  });

  testWidgets('desktop: the ⋮ opens the same menu under the button', (tester) async {
    debugIsDesktopOverride = true;
    final h = await pumpOnlineRow(tester);
    await tester.tap(find.byTooltip('Altre opzioni'));
    await tester.pumpAndSettle();
    expect(_items, findsWidgets);
    final button = tester.getBottomLeft(find.byTooltip('Altre opzioni'));
    expect((tester.getTopLeft(_items.first).dy - button.dy).abs(), lessThan(24));
    await h.dispose(tester);
  });

  testWidgets('phone: right click opens no pointer menu, the sheet stays', (tester) async {
    debugIsDesktopOverride = false;
    final h = await pumpOnlineRow(tester);
    await _rightClick(tester, const Offset(300, 30));
    expect(_items, findsNothing);
    await h.dispose(tester);
  });

  testWidgets('focus starts on the first entry, a choice runs after closing, and focus goes back', (tester) async {
    final ran = <String>[];
    final opener = FocusNode();
    addTearDown(opener.dispose);
    await _plain(
      tester,
      (c) => TextButton(
        focusNode: opener,
        onPressed: () => showContextMenu(c, const Offset(100, 100), [
          [MenuAction(Icons.add, 'Uno', () => ran.add('uno')), MenuAction(Icons.add, 'Due', () => ran.add('due'))],
          [MenuAction(Icons.delete, 'Tre', () => ran.add('tre'), destructive: true, shortcut: 'Canc')],
        ]),
        child: const Text('open'),
      ),
    );
    opener.requestFocus();
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(Focus.of(tester.element(find.text('Uno'))).hasPrimaryFocus, isTrue);
    expect(find.text('Canc'), findsOneWidget);
    expect(find.bySemanticsLabel('Altre azioni'), findsWidgets);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(ran, ['due']);
    expect(opener.hasPrimaryFocus, isTrue);
  });

  testWidgets('the Menu key and Shift+F10 open it from the keyboard', (tester) async {
    final key = FocusNode();
    addTearDown(key.dispose);
    var opened = 0;
    await _plain(
      tester,
      (_) => ContextMenuKey(
        onOpen: (_) => opened++,
        child: Focus(focusNode: key, child: const Text('row')),
      ),
    );
    key.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f10);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(opened, 2);
  });
}

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/user_activity_provider.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:codecore/ui/widgets/cc_search_field.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

var _activity = UserActivity();

Future<(TextEditingController, FocusNode)> _pump(
  WidgetTester t, {
  VoidCallback? onClear,
  ValueChanged<String>? onQuery,
}) async {
  _activity = UserActivity();
  final c = TextEditingController();
  final f = FocusNode();
  addTearDown(c.dispose);
  addTearDown(f.dispose);
  await t.pumpWidget(
    ProviderScope(
      overrides: [userActivityProvider.overrideWithValue(_activity)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        home: Scaffold(
          body: CcSearchField(
            controller: c,
            focusNode: f,
            hint: 'Cerca',
            onClear: onClear,
            onQuery: onQuery,
          ),
        ),
      ),
    ),
  );
  return (c, f);
}

void main() {
  testWidgets('with text the ✕ clears it', (t) async {
    final (c, f) = await _pump(t);
    f.requestFocus();
    await t.enterText(find.byType(TextField), 'abc');
    await t.pump();
    await t.tap(find.byTooltip('Cancella ricerca'));
    await t.pump();
    expect(c.text, isEmpty);
    expect(f.hasFocus, isTrue);
  });

  testWidgets('the ✕ calls onClear, and a mouse click keeps the focus', (
    t,
  ) async {
    var cleared = 0;
    final (c, f) = await _pump(t, onClear: () => cleared++);
    f.requestFocus();
    await t.enterText(find.byType(TextField), 'abc');
    await t.pump();
    await t.tap(
      find.byTooltip('Cancella ricerca'),
      kind: PointerDeviceKind.mouse,
    );
    await t.pump();
    expect(cleared, 1);
    expect(f.hasFocus, isTrue);
    expect(c.text, 'abc'); // onClear replaces the default clear
  });

  testWidgets('empty and focused the ✕ hides the keyboard', (t) async {
    final (_, f) = await _pump(t);
    expect(find.byTooltip('Chiudi tastiera'), findsNothing);
    f.requestFocus();
    await t.pump();
    await t.tap(find.byTooltip('Chiudi tastiera'));
    await t.pump();
    expect(f.hasFocus, isFalse);
    expect(find.byTooltip('Cancella ricerca'), findsOneWidget);
  });

  testWidgets('empty and unfocused the ✕ is inert and 48 dp', (t) async {
    final (_, f) = await _pump(t);
    f.requestFocus();
    await t.pump();
    expect(find.byTooltip('Chiudi tastiera'), findsOneWidget);
    f.unfocus();
    await t.pump();
    final x = find.byTooltip('Cancella ricerca');
    final btn = find.ancestor(of: x, matching: find.byType(IconButton));
    expect(t.widget<IconButton>(btn).onPressed, isNull);
    expect(t.getSize(btn).height, greaterThanOrEqualTo(48));
  });

  testWidgets('without a focusNode it owns one; onChanged and autofocus work', (
    t,
  ) async {
    final c = TextEditingController();
    addTearDown(c.dispose);
    String? changed;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        home: Scaffold(
          body: CcSearchField(
            controller: c,
            hint: 'Cerca',
            autofocus: true,
            onChanged: (v) => changed = v,
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byTooltip('Chiudi tastiera'), findsOneWidget); // focused
    await t.enterText(find.byType(TextField), 'abc');
    expect(changed, 'abc');
  });

  testWidgets('the default ✕ also reports an empty onChanged', (t) async {
    final c = TextEditingController(text: 'abc');
    addTearDown(c.dispose);
    String? changed;
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('it'),
        home: Scaffold(
          body: CcSearchField(
            controller: c,
            hint: 'Cerca',
            onChanged: (v) => changed = v,
          ),
        ),
      ),
    );
    await t.tap(find.byTooltip('Cancella ricerca'));
    await t.pump();
    expect(c.text, isEmpty);
    expect(changed, '');
  });

  testWidgets('onQuery waits for the debounce, trims and skips repeats', (
    t,
  ) async {
    final got = <String>[];
    await _pump(t, onQuery: got.add);
    await t.enterText(find.byType(TextField), 'ab');
    await t.enterText(find.byType(TextField), ' abc ');
    await t.pump(CcTiming.debounce - const Duration(milliseconds: 1));
    expect(got, isEmpty);
    await t.pump(const Duration(milliseconds: 1));
    expect(got, ['abc']);
    await t.enterText(find.byType(TextField), 'abc  ');
    await t.pump(CcTiming.debounce);
    expect(got, ['abc']);
  });

  testWidgets(
    'onQuery runs at once on Enter and on the ✕, and typing touches the activity',
    (t) async {
      final got = <String>[];
      await _pump(t, onQuery: got.add);
      expect(_activity.lastActivityAt, isNull);
      await t.enterText(find.byType(TextField), 'abc');
      expect(_activity.lastActivityAt, isNotNull);
      await t.testTextInput.receiveAction(TextInputAction.search);
      expect(got, ['abc']);
      await t.pump();
    await t.tap(find.byIcon(Icons.close_rounded));
      await t.pump();
      expect(got, ['abc', '']);
      await t.pump(CcTiming.debounce);
      expect(got, ['abc', '']);
    },
  );
}

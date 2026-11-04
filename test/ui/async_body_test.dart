import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/ui/widgets/async_body.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(AsyncValue<List<int>> v, {VoidCallback? onRetry, String? errorMessage}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('it'),
  home: Scaffold(
    body: AsyncBody<List<int>>(
      value: v,
      onRetry: onRetry,
      errorMessage: errorMessage,
      isEmpty: (d) => d.isEmpty,
      empty: const Text('vuoto'),
      data: (d) => Text('dati ${d.length}'),
    ),
  ),
);

void main() {
  testWidgets('loading shows the row skeleton, not a spinner', (tester) async {
    await tester.pumpWidget(_app(const AsyncLoading()));
    expect(find.byType(Skeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('loading skeleton copes with unbounded and bounded height', (tester) async {
    Widget body() => AsyncBody<List<int>>(value: const AsyncLoading(), data: (_) => const SizedBox());
    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
    await tester.pumpWidget(host(ListView(children: [body()])));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(host(SizedBox(height: 100, child: body())));
    expect(tester.takeException(), isNull);
  });

  testWidgets('data and empty', (tester) async {
    await tester.pumpWidget(_app(const AsyncData([1, 2])));
    expect(find.text('dati 2'), findsOneWidget);
    await tester.pumpWidget(_app(const AsyncData([])));
    expect(find.text('vuoto'), findsOneWidget);
  });

  testWidgets('error shows the retry button and calls onRetry', (tester) async {
    var n = 0;
    await tester.pumpWidget(
      _app(AsyncError(Exception('boom'), StackTrace.empty), onRetry: () => n++),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(n, 1);
  });

  testWidgets('error shows the custom errorMessage', (tester) async {
    await tester.pumpWidget(
      _app(AsyncError(Exception('boom'), StackTrace.empty), errorMessage: 'su misura'),
    );
    await tester.pumpAndSettle();
    expect(find.text('su misura'), findsOneWidget);
  });
}

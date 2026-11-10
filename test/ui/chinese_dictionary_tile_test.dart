import 'package:codecore/services/lyrics/pinyin_dictionary.dart';
import 'package:codecore/providers/chinese_dictionary_providers.dart';
import 'package:codecore/ui/screens/settings/chinese_dictionary_tile.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake extends ChineseDictionaryNotifier {
  _Fake(this.initial, {this.failDelete = false});

  final ChineseDictionaryState initial;
  final bool failDelete;
  int deletes = 0, downloads = 0;

  @override
  ChineseDictionaryState build() => initial;

  @override
  Future<void> delete() async {
    deletes++;
    if (failDelete) throw StateError('boom');
    state = const ChineseDictionaryState(ChineseDictionaryStatus.notDownloaded);
  }

  @override
  Future<PinyinDictionary?> ensure({
    required bool download,
    bool automatic = false,
  }) async {
    downloads++;
    return null;
  }
}

void main() {
  Future<_Fake> pump(
    WidgetTester tester,
    ChineseDictionaryState s, {
    bool failDelete = false,
  }) async {
    final fake = _Fake(s, failDelete: failDelete);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [chineseDictionaryProvider.overrideWith(() => fake)],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ChineseDictionaryTile()),
        ),
      ),
    );
    return fake;
  }

  testWidgets('not downloaded: «Scarica» asks for the download', (
    tester,
  ) async {
    final f = await pump(
      tester,
      const ChineseDictionaryState(ChineseDictionaryStatus.notDownloaded),
    );
    expect(find.textContaining('Non scaricato'), findsOneWidget);
    await tester.tap(find.text('Scarica'));
    expect(f.downloads, 1);
  });

  testWidgets('downloading shows a labelled progress indicator', (
    tester,
  ) async {
    await pump(
      tester,
      const ChineseDictionaryState(
        ChineseDictionaryStatus.downloading,
        progress: 0.4,
      ),
    );
    final p = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(p.semanticsLabel, 'Scarico…');
    expect(find.text('Scarica'), findsNothing);
  });

  testWidgets('error offers the download again', (tester) async {
    await pump(
      tester,
      const ChineseDictionaryState(ChineseDictionaryStatus.error),
    );
    expect(find.text('Download non riuscito'), findsOneWidget);
    expect(find.text('Scarica'), findsOneWidget);
  });

  testWidgets('ready: «Elimina» asks to confirm, then deletes', (tester) async {
    final f = await pump(
      tester,
      const ChineseDictionaryState(
        ChineseDictionaryStatus.ready,
        sizeBytes: 5 * 1024 * 1024,
      ),
    );
    await tester.tap(find.byTooltip('Elimina il dizionario cinese'));
    await tester.pumpAndSettle();
    // Cancelling deletes nothing.
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(f.deletes, 0);
    await tester.tap(find.byTooltip('Elimina il dizionario cinese'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Elimina'),
      ),
    );
    await tester.pumpAndSettle();
    expect(f.deletes, 1);
    expect(find.text('Scarica'), findsOneWidget);
  });

  testWidgets('a failed delete says so', (tester) async {
    await pump(
      tester,
      const ChineseDictionaryState(ChineseDictionaryStatus.ready, sizeBytes: 1),
      failDelete: true,
    );
    await tester.tap(find.byTooltip('Elimina il dizionario cinese'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Elimina'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // not settle: the snackbar ring animates until it closes
    expect(
      find.text('Impossibile eliminare il dizionario cinese'),
      findsOneWidget,
    );
  });
}

import 'dart:io';

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/dislike_store_provider.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:codecore/ui/screens/settings/dislikes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('dislikes_screen'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<DislikeStore> open(WidgetTester tester, {bool seeded = true}) async {
    final store = DislikeStore(
      file: () async => File(p.join(dir.path, 'd.json')),
      writeDelay: const Duration(days: 1),
    );
    await tester.runAsync(store.load);
    if (seeded) {
      store.blockTrack(
        const DislikedTrack(
          videoId: 'v1',
          title: 'Despacito',
          artist: 'Luis Fonsi',
        ),
      );
      store.blockArtist(const DislikedArtist(key: 'shakira', name: 'Shakira'));
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [dislikeStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(
          locale: Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DislikesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('tabs, Togli and Annulla put the block back', (tester) async {
    final store = await open(tester);
    expect(find.text('Despacito'), findsOneWidget);
    expect(find.text('Brani 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dislikes-tab-artists')));
    await tester.pumpAndSettle();
    expect(find.text('Shakira'), findsOneWidget);
    expect(find.text('Despacito'), findsNothing);

    await tester.tap(find.text('Togli'));
    await tester.pumpAndSettle();
    expect(store.artistBlocked('shakira'), isFalse);
    expect(find.byKey(const ValueKey('dislikes-empty')), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(store.artistBlocked('shakira'), isTrue);
    expect(find.text('Shakira'), findsOneWidget);
    await tester.runAsync(store.flush); // cancels the pending write timer
  });

  testWidgets('empty lists show the explanation', (tester) async {
    final store = await open(tester, seeded: false);
    expect(find.byKey(const ValueKey('dislikes-empty')), findsOneWidget);
    expect(find.text('Nessun brano escluso'), findsOneWidget);
    await tester.runAsync(store.flush);
  });

  testWidgets('Togli has a TalkBack name with the item', (tester) async {
    final handle = tester.ensureSemantics();
    final store = await open(tester);
    expect(
      find.bySemanticsLabel('Togli «Despacito» dai non mi piace'),
      findsOneWidget,
    );
    handle.dispose();
    await tester.runAsync(store.flush);
  });
}

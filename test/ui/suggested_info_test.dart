import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/library_add_providers.dart' show savedStreamKeysProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/suggestion_actions.dart';
import 'package:codecore/providers/youtube_providers.dart'
    show downloadIndexProvider, downloadsProvider, DownloadsNotifier;
import 'package:codecore/services/online/download_queue.dart' show DownloadItem;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/now_playing/suggested_info.dart';
import 'package:codecore/ui/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Track implements Track {
  _Track(this.id);
  @override
  final int id;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Actions implements SuggestionActions {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Downloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => [];
}

void main() {
  Future<void> open(
    WidgetTester tester, {
    required bool suggested,
    VoidCallback? onDislike,
  }) async {
    final entries = OnlineEntries();
    final id = entries.register(
      const YtResult(
        id: 'v1',
        title: 'Oroscopo',
        channel: 'ch',
        duration: null,
        artists: ['Calcutta'],
      ),
      seedTitle: 'Nella stanza 2',
      suggested: suggested,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineEntriesProvider.overrideWithValue(entries),
          downloadsProvider.overrideWith(_Downloads.new),
          suggestionActionsProvider.overrideWithValue(_Actions()),
          savedStreamKeysProvider.overrideWith((ref) => Stream.value(const <String>{})),
          downloadIndexProvider.overrideWith(
            (ref) => Completer<DownloadIndex>().future,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SuggestedInfo(track: _Track(id), onDislike: onDislike),
          ),
        ),
      ),
    );
  }

  testWidgets('a suggested song has three tiles and an active Non mi piace', (
    tester,
  ) async {
    var taps = 0;
    await open(tester, suggested: true, onDislike: () => taps++);
    expect(find.text('Suggerito: simile a «Nella stanza 2»'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(3));
    await tester.tap(find.text('Non mi piace'));
    expect(taps, 1);
  });

  testWidgets('an online song that is not suggested has two tiles', (
    tester,
  ) async {
    await open(tester, suggested: false);
    expect(find.byType(TextButton), findsNWidgets(2));
    expect(find.text('Non mi piace'), findsNothing);
  });

  testWidgets('each tile is a surface2 block with card corners', (
    tester,
  ) async {
    await open(tester, suggested: true, onDislike: () {});
    final cc = tester.element(find.byType(SuggestedInfo)).cc;
    final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
    expect(buttons, hasLength(3));
    for (final b in buttons) {
      expect(b.style!.backgroundColor!.resolve({}), cc.surface2);
      final shape = b.style!.shape!.resolve({}) as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(CcDims.rCard));
    }
  });

  testWidgets('the first tile is «Aggiungi alla libreria» and calls the action', (
    tester,
  ) async {
    await open(tester, suggested: false);
    expect(find.text('Aggiungi alla libreria'), findsOneWidget);
    expect(find.text('Scarica'), findsNothing);
    expect(find.text('Aggiungi a playlist…'), findsOneWidget);
  });
}

import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/suggestion_actions.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/widgets/dislike_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeActions implements SuggestionActions {
  final calls = <String>[];
  static const token = DislikeUndo(trackId: 'x');

  @override
  Future<DislikeUndo> dislikeTrack(int queueId) async {
    calls.add('track $queueId');
    return token;
  }

  @override
  Future<DislikeUndo> dislikeArtist(int queueId) async {
    calls.add('artist $queueId');
    return token;
  }

  @override
  Future<void> undo(DislikeUndo u) async => calls.add('undo ${u.trackId}');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late _FakeActions actions;
  late int id;

  Future<void> open(WidgetTester tester) async {
    actions = _FakeActions();
    final entries = OnlineEntries();
    id = entries.register(
      const YtResult(
        id: 'v1',
        title: 'Oroscopo',
        channel: 'ch',
        duration: null,
        artists: ['Calcutta'],
      ),
      suggested: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlineEntriesProvider.overrideWithValue(entries),
          suggestionActionsProvider.overrideWithValue(actions),
        ],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showDislikeSheet(context, ref, id),
                child: const Text('apri'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  testWidgets('track and artist choices run different actions', (tester) async {
    await open(tester);
    expect(find.text('Tutto Calcutta'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dislike-track')));
    await tester.pumpAndSettle();
    expect(actions.calls, ['track $id']);

    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('dislike-artist')));
    await tester.pumpAndSettle();
    expect(actions.calls, ['track $id', 'artist $id']);
  });

  testWidgets(
    'Annulla in the notice calls undo; Annulla in the sheet does nothing',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(actions.calls, isEmpty);

      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('dislike-artist')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annulla'));
      await tester.pumpAndSettle();
      expect(actions.calls.last, 'undo x');
    },
  );
}

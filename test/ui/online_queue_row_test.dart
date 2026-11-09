import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/widgets/online_queue_row.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets(
    'a streamed row says «Suggerito» and its menu has only the online actions',
    (tester) async {
      final h = await Harness.create(tester, tracks: 1);
      final online = OnlineEntries();
      final id = online.register(
        const YtResult(
          id: 'v1',
          title: 'Streamed',
          channel: 'Chan',
          duration: null,
          artists: ['Ann'],
        ),
        seedTitle: 'Seed',
        suggested: true,
      );
      await h.pump(
        tester,
        Scaffold(
          body: LiveTrackRow(
            track: online.trackOf(id)!,
            variant: TrackRowVariant.queue,
            onTap: () {},
          ),
        ),
        extraOverrides: [onlineEntriesProvider.overrideWithValue(online)],
      );
      expect(find.byType(OnlineQueueRow), findsOneWidget);
      expect(find.text('Suggerito'), findsOneWidget);
      expect(find.text('Streamed'), findsOneWidget);
      // One node «Suggerito, Ann»; the ', ' is not read on its own.
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp('Suggerito, Ann')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^[, \n]+$')), findsNothing);
      handle.dispose();

      await tester.tap(find.byTooltip('Altre opzioni'));
      await tester.pumpAndSettle();
      expect(find.text('Scarica'), findsOneWidget);
      expect(find.text('Aggiungi a playlist…'), findsOneWidget);
      expect(find.text('Non mi piace'), findsOneWidget);
      expect(find.text('Rimuovi dalla coda'), findsOneWidget);
      for (final library in [
        'Preferito',
        'Modifica…',
        'Elimina',
        'Aggiungi alla coda',
      ]) {
        expect(find.text(library), findsNothing, reason: library);
      }
      await h.dispose(tester);
    },
  );

  testWidgets(
    'a searched online row has no «Suggerito» and no «Non mi piace»',
    (tester) async {
      final h = await Harness.create(tester, tracks: 1);
      final online = OnlineEntries();
      final id = online.register(
        const YtResult(
          id: 'v2',
          title: 'Searched',
          channel: 'Chan',
          duration: null,
          artists: ['Ann'],
        ),
      );
      await h.pump(
        tester,
        Scaffold(
          body: LiveTrackRow(
            track: online.trackOf(id)!,
            variant: TrackRowVariant.queue,
            onTap: () {},
          ),
        ),
        extraOverrides: [onlineEntriesProvider.overrideWithValue(online)],
      );
      expect(find.text('Searched'), findsOneWidget);
      expect(find.text('Suggerito'), findsNothing);
      expect(find.text('Ann'), findsOneWidget);
      expect(find.text(', '), findsNothing);
      await tester.tap(find.byTooltip('Altre opzioni'));
      await tester.pumpAndSettle();
      expect(find.text('Scarica'), findsOneWidget);
      expect(find.text('Non mi piace'), findsNothing);
      await h.dispose(tester);
    },
  );

  testWidgets('a library row has no «Suggerito» marker', (tester) async {
    final h = await Harness.create(tester, tracks: 1);
    final track = (await h.db.select(h.db.tracks).get()).single;
    await h.pump(
      tester,
      Scaffold(
        body: LiveTrackRow(
          track: track,
          variant: TrackRowVariant.queue,
          onTap: () {},
        ),
      ),
    );
    expect(find.byType(OnlineQueueRow), findsNothing);
    expect(find.text('Suggerito'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the «in libreria» check shows on a queue row only when asked', (
    tester,
  ) async {
    final h = await Harness.create(tester, tracks: 1);
    final track = (await h.db.select(h.db.tracks).get()).single;
    for (final on in [false, true]) {
      await h.pump(
        tester,
        Scaffold(
          body: LiveTrackRow(
            track: track,
            variant: TrackRowVariant.queue,
            inLibrary: on,
            onTap: () {},
          ),
        ),
      );
      expect(
        find.byIcon(Icons.check_circle_rounded),
        on ? findsOneWidget : findsNothing,
      );
      if (on) {
        expect(
          tester
              .widget<Icon>(find.byIcon(Icons.check_circle_rounded))
              .semanticLabel,
          'Già in libreria',
        );
      }
    }
    await h.dispose(tester);
  });
}

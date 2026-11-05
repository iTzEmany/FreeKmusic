// Characterization (38.5): the three screens that used their own Set<int>;
// since 42.2 they use selectionProvider, with the same behaviour (none of them
// has a «select all» bar).
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/providers/share_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/track_ops.dart';
import 'package:codecore/services/share/lan_client.dart';
import 'package:codecore/ui/screens/playlists/add_tracks_screen.dart';
import 'package:codecore/ui/screens/share/receive_tab.dart';
import 'package:codecore/ui/screens/share/track_picker_screen.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<List<Track>> _all(WidgetTester tester, Harness h) async =>
    (await tester.runAsync(
      () => (h.db.select(
        h.db.tracks,
      )..orderBy([(t) => OrderingTerm.asc(t.id)])).get(),
    ))!;

class _Remote extends LanClient {
  @override
  Future<RemoteInfo> hello(String host, int port, {cancel}) async =>
      const RemoteInfo('Altro telefono');

  @override
  Future<List<RemoteTrack>> manifest(
    String host,
    int port,
    String pin, {
    cancel,
  }) async => [
    for (var i = 1; i <= 3; i++)
      RemoteTrack(
        id: i,
        title: 'Remote $i',
        sizeBytes: 1,
        durationMs: 1000,
        ext: 'mp3',
      ),
  ];
}

void main() {
  group('AddTracksScreen', () {
    Future<(Harness, int)> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester, tracks: 4);
      final rows = await _all(tester, h);
      final pid = (await tester.runAsync(() async {
        final repo = PlaylistRepository(h.db);
        final id = await repo.create('Mix');
        await repo.addTracks(id, [rows[3].id]);
        return id;
      }))!;
      await h.pump(tester, AddTracksScreen(playlistId: pid));
      await _settle(tester);
      return (h, pid);
    }

    testWidgets(
      'tapping a row toggles it; the bottom bar counts the picks and appears only with picks',
      (tester) async {
        final (h, _) = await open(tester);
        expect(find.text('Aggiungi (1)'), findsNothing);
        await tester.tap(find.text('Song 0'));
        await tester.pump();
        await tester.tap(find.text('Song 1'));
        await tester.pump();
        expect(find.text('Aggiungi (2)'), findsOneWidget);
        await tester.tap(find.text('Song 0'));
        await tester.pump();
        expect(find.text('Aggiungi (1)'), findsOneWidget);
        await tester.tap(find.text('Song 1'));
        await tester.pump();
        expect(find.textContaining('Aggiungi ('), findsNothing);
        await h.dispose(tester);
      },
    );

    testWidgets(
      'tracks already in the playlist are not offered; there is no «select all»',
      (tester) async {
        final (h, _) = await open(tester);
        expect(find.text('Song 3'), findsNothing);
        expect(find.text('Song 0'), findsOneWidget);
        expect(find.byTooltip('Seleziona tutto'), findsNothing);
        await h.dispose(tester);
      },
    );

    testWidgets('«Aggiungi» appends the picks in tap order', (tester) async {
      final (h, pid) = await open(tester);
      await tester.tap(find.text('Song 2'));
      await tester.pump();
      await tester.tap(find.text('Song 0'));
      await tester.pump();
      await tester.tap(find.text('Aggiungi (2)'));
      await _settle(tester);
      final order = await tester.runAsync(
        () async => [
          for (final t in await PlaylistRepository(h.db).watchTracks(pid).first)
            t.title,
        ],
      );
      expect(order, ['Song 3', 'Song 2', 'Song 0']);
      await h.dispose(tester);
    });
  });

  group('TrackPickerScreen', () {
    Future<(Harness, ValueNotifier<Set<int>?>)> open(
      WidgetTester tester, {
      Set<int> initial = const {},
    }) async {
      final h = await Harness.create(tester, tracks: 3);
      final result = ValueNotifier<Set<int>?>(null);
      await h.pump(
        tester,
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => result.value = await Navigator.of(c)
                  .push<Set<int>>(
                    MaterialPageRoute(
                      builder: (_) => TrackPickerScreen(initial: initial),
                    ),
                  ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await _settle(tester);
      return (h, result);
    }

    testWidgets('starts from the given ids; a checkbox toggles a track', (
      tester,
    ) async {
      final (h, _) = await open(tester, initial: {1});
      bool? on(String title) => tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, title),
          )
          .value;
      expect([on('Song 0'), on('Song 1'), on('Song 2')], [true, false, false]);
      await tester.tap(find.text('Song 1'));
      await tester.pump();
      expect([on('Song 0'), on('Song 1'), on('Song 2')], [true, true, false]);
      await tester.tap(find.text('Song 0'));
      await tester.pump();
      expect([on('Song 0'), on('Song 1'), on('Song 2')], [false, true, false]);
      await h.dispose(tester);
    });

    testWidgets(
      '«Salva» returns the picked ids; the screen has no count and no «select all»',
      (tester) async {
        final (h, result) = await open(tester, initial: {1});
        await tester.tap(find.text('Song 2'));
        await tester.pump();
        expect(find.byTooltip('Seleziona tutto'), findsNothing);
        await tester.tap(find.text('Salva'));
        await _settle(tester);
        expect(result.value, {1, 3});
        await h.dispose(tester);
      },
    );
  });

  group('ReceiveTab', () {
    Future<Harness> connect(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        const Scaffold(body: ReceiveTab()),
        extraOverrides: [lanClientProvider.overrideWithValue(_Remote())],
      );
      await tester.enterText(find.byType(TextField).first, '10.0.0.2:8080');
      await tester.tap(find.text('Connetti'));
      await _settle(tester);
      return h;
    }

    testWidgets(
      'connecting selects every remote track; a checkbox deselects one and the button counts',
      (tester) async {
        final h = await connect(tester);
        expect(find.text('Connesso a Altro telefono'), findsOneWidget);
        expect(find.text('Scarica selezionati (3)'), findsOneWidget);
        await tester.tap(find.text('Remote 2'));
        await tester.pump();
        expect(find.text('Scarica selezionati (2)'), findsOneWidget);
        await h.dispose(tester);
      },
    );

    testWidgets('with nothing selected the download button is disabled', (
      tester,
    ) async {
      final h = await connect(tester);
      for (final n in [1, 2, 3]) {
        await tester.tap(find.text('Remote $n'));
        await tester.pump();
      }
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Scarica selezionati (0)'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );
      expect(button.onPressed, isNull);
      await h.dispose(tester);
    });
  });

  group('pickers: search state', () {
    // 'bad' fails, 'slow' never answers, anything else lists the library.
    Future<Harness> open(WidgetTester tester, Widget screen) async {
      final h = await Harness.create(tester, tracks: 3);
      await h.pump(
        tester,
        screen,
        extraOverrides: [
          trackSearchProvider.overrideWith((ref, q) {
            if (q == 'bad') {
              return Stream<List<Track>>.error(StateError('boom'));
            }
            if (q == 'slow') return const Stream<List<Track>>.empty();
            return ref.watch(trackRepositoryProvider).watchTracks(query: q);
          }),
        ],
      );
      await _settle(tester);
      return h;
    }

    Future<void> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byType(TextField), q);
      await tester.pump(const Duration(milliseconds: 600));
      await _settle(tester);
    }

    testWidgets(
      'AddTracksScreen: a query matching nothing shows the empty state',
      (tester) async {
        final h = await open(tester, const AddTracksScreen(playlistId: 999));
        await search(tester, 'zzzz');
        expect(find.text('Nessun risultato'), findsOneWidget);
        await h.dispose(tester);
      },
    );

    final screens = {
      'AddTracksScreen': const AddTracksScreen(playlistId: 999),
      'TrackPickerScreen': const TrackPickerScreen(),
    };
    for (final e in screens.entries) {
      testWidgets('${e.key}: a failed search shows the error with «Riprova»', (
        tester,
      ) async {
        final h = await open(tester, e.value);
        expect(find.text('Song 0'), findsOneWidget);
        await search(tester, 'bad');
        expect(find.text('Riprova'), findsOneWidget);
        expect(find.text('Song 0'), findsNothing);
        await h.dispose(tester);
      });

      testWidgets(
        '${e.key}: while a new search loads the previous results stay',
        (tester) async {
          final h = await open(tester, e.value);
          await search(tester, 'slow');
          expect(find.text('Song 0'), findsOneWidget);
          await h.dispose(tester);
        },
      );
    }
  });
}

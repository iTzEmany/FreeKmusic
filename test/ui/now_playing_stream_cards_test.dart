import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_info_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/providers/player_providers.dart' show liveCurrentTrackProvider, onlineEntriesProvider, playerControllerProvider, shadowWaitProvider;
import 'package:codecore/providers/youtube_providers.dart'
    show downloadIndexProvider;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/ui/screens/now_playing/credits_card.dart';
import 'package:codecore/ui/screens/now_playing/now_playing_cards.dart' show InfoCard, LyricsCard, NpCard, StreamCardsWait, UpNextCard;
import 'package:codecore/ui/screens/now_playing/now_playing_screen.dart';
import 'package:codecore/ui/screens/now_playing/proposal_card.dart';
import 'package:codecore/providers/nav_providers.dart' show SidePanel;
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/services/stream/stream_preparer.dart' show StreamPhase;
import 'package:codecore/ui/shell/side_panel.dart';
import 'package:codecore/ui/widgets/skeleton.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_stream_preparer.dart';

const _station = RadioStation(id: 'a', name: 'Radio Alfa', streamUrl: 'http://radio.test/a');

const _r2 = YtResult(
  id: 'v2',
  title: 'Second song',
  channel: 'Chan',
  artists: ['Bob'],
  duration: Duration(minutes: 3),
);

const _r = YtResult(
  id: 'v1',
  title: 'Online song',
  channel: 'Chan',
  artists: ['Ann'],
  duration: Duration(minutes: 3),
);

Future<void> _wait(WidgetTester t) async {
  // Real async work (DB, files) settles in a few event-queue turns; no wall-clock sleep.
  for (var i = 0; i < 20; i++) {
    await t.runAsync(() => pumpEventQueue());
    await t.pump();
  }
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Future<(Harness, Directory, FakeStreamPreparer, WidgetRef Function())> _open(WidgetTester t, {Widget? panel}) async {
  t.view.physicalSize = const Size(1400, 1000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final h = await Harness.create(t, radio: true);
  final dir = Directory.systemTemp.createTempSync('np_stream_cards');
  addTearDown(() => dir.deleteSync(recursive: true));
  final preparer = FakeStreamPreparer(TrackRepository(h.db), dir);
  h.handler.preparer = preparer;
  late WidgetRef ref;
  await h.pump(
    t,
    Consumer(
      builder: (c, r, _) {
        ref = r;
        final go = TextButton(
          onPressed: () => playOnlineAndOpen(c, r, _r),
          child: const Text('go'),
        );
        return Scaffold(
          body: panel == null ? go : Column(children: [go, Expanded(child: panel)]),
        );
      },
    ),
    extraOverrides: [
      downloadIndexProvider.overrideWith(
        (ref) async => DownloadIndex(File('${dir.path}/idx.json')),
      ),
    ],
  );
  return (h, dir, preparer, () => ref);
}

void main() {
  testWidgets('a streamed track shows lyrics, trivia and credits of its row, no proposal; before the row a placeholder', (t) async {
    final (h, _, preparer, ref) = await _open(t);
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);

    // No row yet: a fixed-height placeholder, not the empty lyrics state.
    expect(find.text('Nessun testo disponibile'), findsNothing);
    expect(find.text('Cerca testo'), findsNothing);
    expect(find.byType(StreamCardsWait), findsOneWidget);

    gate.complete();
    await _wait(t);
    await t.runAsync(() => (h.db.update(h.db.tracks)..where((r) => r.kind.equals(kStreamKind))).write(
      const TracksCompanion(
        lyricsPlain: Value('Parole del brano'),
        curiosities: Value('Una curiosita sul brano\nhttps://it.wikipedia.org/wiki/Song'),
      ),
    ));
    await _wait(t);
    // The id the cards got must be the row's: credits saved on it show up.
    final rowId = t.widget<InfoCard>(find.byType(InfoCard)).track.id;
    expect(rowId, greaterThan(0));
    await t.runAsync(() => h.db.into(h.db.trackCredits).insert(
      TrackCreditsCompanion.insert(
        trackId: rowId,
        name: 'Person 0',
        nameKey: 'person 0',
        role: 'producer',
        source: 'deezer',
      ),
    ));
    await _wait(t);

    expect(find.text('Parole del brano'), findsOneWidget);
    expect(find.textContaining('Una curiosita sul brano'), findsOneWidget);
    expect(find.text('Person 0'), findsOneWidget);
    expect(t.widget<InfoCard>(find.byType(InfoCard)).track.id, rowId);
    expect(t.widget<CreditsCard>(find.byType(CreditsCard)).track.id, rowId);
    expect(find.byType(ProposalCard), findsNothing);
    // The player's own track keeps the negative id (D-71) with the row's data.
    final live = ref().read(liveCurrentTrackProvider).value!;
    expect(live.id, lessThan(0));
    expect(live.lyricsPlain, 'Parole del brano');

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('moving to a streamed track without a row drops the previous row data', (t) async {
    final (h, _, preparer, ref) = await _open(t);
    await t.tap(find.text('go'));
    await _wait(t);
    await t.runAsync(() => (h.db.update(h.db.tracks)..where((r) => r.kind.equals(kStreamKind))).write(
      const TracksCompanion(lyricsPlain: Value('Parole del brano')),
    ));
    await _wait(t);
    expect(find.text('Parole del brano'), findsOneWidget);

    preparer.gates['youtube:v2'] = Completer<void>();
    unawaited(ref().read(playerControllerProvider).playOnline(_r2)); // waits for the gate
    await _wait(t);

    expect(find.text('Second song'), findsWidgets);
    expect(find.text('Parole del brano'), findsNothing);
    expect(find.byType(StreamCardsWait), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('a download merges the shadow row: the cards follow the entry to the new row', (t) async {
    final (h, dir, _, ref) = await _open(t);
    await t.tap(find.text('go'));
    await _wait(t);
    final file = File('${dir.path}/other.m4a')..writeAsStringSync('x');
    final newId = (await t.runAsync(() => TrackRepository(h.db).upsertStreamRow('youtube:v9', _r2, file)))!;
    await t.runAsync(() => (h.db.update(h.db.tracks)..where((r) => r.id.equals(newId))).write(
      const TracksCompanion(lyricsPlain: Value('Testo della libreria')),
    ));
    final entries = ref().read(onlineEntriesProvider)!;
    entries.bindRow(entries.idsOf(_r).single, newId);
    await _wait(t);

    expect(find.text('Testo della libreria'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('a shadow row with a positive id, playing as a library track, shows its own cards', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 1);
    final id = (await t.runAsync(() async {
      final row = await h.db.select(h.db.tracks).getSingle();
      await (h.db.update(h.db.tracks)..where((r) => r.id.equals(row.id))).write(
        const TracksCompanion(kind: Value(kStreamKind), lyricsPlain: Value('Parole del brano')),
      );
      return row.id;
    }))!;
    await t.runAsync(() => h.handler.playQueue([id], 0));
    await h.pump(t, const NowPlayingScreen());
    await _wait(t);

    expect(find.text('Parole del brano'), findsOneWidget);
    expect(find.byType(StreamCardsWait), findsNothing);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('the skeleton cards have the height of the real ones, so nothing jumps', (t) async {
    final (h, _, preparer, _) = await _open(t);
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);
    final fake = [for (final c in t.widgetList(find.byType(NpCard))) t.getSize(find.byWidget(c)).height];
    expect(fake.length, greaterThanOrEqualTo(3)); // Testo, Info, Crediti (UpNext is not one)

    gate.complete();
    await _wait(t);
    final long = List.filled(12, 'una frase abbastanza lunga da riempire la riga').join(' ');
    await t.runAsync(() => (h.db.update(h.db.tracks)..where((r) => r.kind.equals(kStreamKind))).write(
      TracksCompanion(lyricsPlain: Value(List.filled(8, 'riga').join('\n')), curiosities: Value('$long\nhttps://it.wikipedia.org/wiki/Song')),
    ));
    final rowId = t.widget<InfoCard>(find.byType(InfoCard)).track.id;
    await t.runAsync(() => ArtistInfoRepository(h.db).save('Ann',
        body: long, source: Uri.parse('https://it.wikipedia.org/wiki/Ann'), lang: 'it'));
    for (var i = 0; i < 3; i++) {
      await t.runAsync(() => h.db.into(h.db.trackCredits).insert(
        TrackCreditsCompanion.insert(trackId: rowId, name: 'Person $i', nameKey: 'person $i', role: 'producer', source: 'deezer'),
      ));
    }
    await _wait(t);
    final lyrics = t.getSize(find.byType(LyricsCard)).height;
    final info = t.getSize(find.byType(InfoCard)).height;
    expect(fake[0], lyrics);
    expect(fake[1], info);
    expect(fake[2] + 12, t.getSize(find.byType(CreditsCard)).height);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('after 20 s without a row: «Non disponibile»; Riprova brings the skeleton back and waits again', (t) async {
    final (h, _, preparer, _) = await _open(t);
    preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);
    await t.pump(const Duration(seconds: 19));
    expect(find.text('Non disponibile'), findsNothing);
    await t.pump(const Duration(seconds: 2));
    await t.pump(); // the handler's answer arrives after the frame that asked
    expect(find.text('Non disponibile'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);

    await t.tap(find.text('Riprova'));
    await t.pump();
    expect(find.text('Non disponibile'), findsNothing);
    expect(find.byType(Skeleton), findsWidgets);
    await t.pump(const Duration(seconds: 21));
    await t.pump();
    expect(find.text('Non disponibile'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('Riprova in one place restarts the 60 s cap of the other widget on the same track', (t) async {
    final (h, _, preparer, _) = await _open(t, panel: const SidePanelView(panel: SidePanel.info));
    preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);
    preparer.phases.value = {'youtube:v1': StreamPhase.downloading};
    await t.pump(const Duration(seconds: 21));
    await t.pump(const Duration(seconds: 30)); // 51 s: the cap is near
    expect(find.text('Non disponibile'), findsNothing);
    final wait = find.byType(StreamCardsWait);
    expect(wait, findsWidgets);

    // The retry of one widget (its own timer is armed again) resets the cap of every subscriber.
    final ctx = t.element(wait.first);
    final container = ProviderScope.containerOf(ctx);
    container.invalidate(shadowWaitProvider((id: t.widget<StreamCardsWait>(wait.first).trackId, waited: StreamCardsWait.wait)));
    await t.pump();
    await t.pump(const Duration(seconds: 30)); // 81 s since the start, 30 s since the retry
    expect(find.text('Non disponibile'), findsNothing);
    await t.pump(const Duration(seconds: 15));
    await t.pump();
    expect(find.text('Non disponibile'), findsWidgets);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('after 20 s a slow but working download keeps the skeleton; a failed one shows «Non disponibile»', (t) async {
    final (h, _, preparer, _) = await _open(t);
    preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);
    preparer.phases.value = {'youtube:v1': StreamPhase.downloading};
    await t.pump(const Duration(seconds: 21));
    expect(find.text('Non disponibile'), findsNothing);
    expect(find.byType(Skeleton), findsWidgets);

    preparer.phases.value = {'youtube:v1': StreamPhase.failed};
    await t.pump();
    expect(find.text('Non disponibile'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('a download still «downloading» after 60 s counts as stuck: «Non disponibile»', (t) async {
    final (h, _, preparer, _) = await _open(t);
    preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);
    preparer.phases.value = {'youtube:v1': StreamPhase.downloading};
    await t.pump(const Duration(seconds: 21)); // the 20 s timer fires, a frame subscribes the cards
    await t.pump(const Duration(seconds: 38));
    expect(find.text('Non disponibile'), findsNothing);
    await t.pump(const Duration(seconds: 2));
    await t.pump();
    expect(find.text('Non disponibile'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('side panel Info on a low window: the waiting skeleton scrolls, no overflow', (t) async {
    final (h, _, preparer, _) = await _open(t, panel: const SidePanelView(panel: SidePanel.info));
    t.view.physicalSize = const Size(1400, 500);
    preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);
    expect(find.byType(StreamCardsWait), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('a radio on air: no «in arrivo» placeholder, no text or credits cards, only the queue', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, radio: true);
    await t.runAsync(() => h.handler.playStations([_station], 0));
    await h.pump(t, const NowPlayingScreen());
    await _wait(t);

    expect(find.byType(StreamCardsWait), findsNothing);
    expect(find.byType(LyricsCard), findsNothing);
    expect(find.byType(CreditsCard), findsNothing);
    expect(find.byType(UpNextCard), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('desktop Info panel on a stream: placeholder, then the row card with the real id', (t) async {
    final (h, _, preparer, _) = await _open(t, panel: const SidePanelView(panel: SidePanel.info));
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    await t.tap(find.text('go'));
    await _wait(t);
    expect(find.byType(StreamCardsWait), findsOneWidget);
    expect(find.byType(InfoCard), findsNothing);

    gate.complete();
    await _wait(t);
    expect(find.byType(StreamCardsWait), findsNothing);
    expect(t.widget<InfoCard>(find.byType(InfoCard)).track.id, greaterThan(0));

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });

  testWidgets('desktop Info panel on a radio is empty', (t) async {
    t.view.physicalSize = const Size(1400, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, radio: true);
    await t.runAsync(() => h.handler.playStations([_station], 0));
    await h.pump(t, const SidePanelView(panel: SidePanel.info));
    await _wait(t);

    expect(find.byType(StreamCardsWait), findsNothing);
    expect(find.byType(InfoCard), findsNothing);

    await t.pumpWidget(const SizedBox());
    await h.dispose(t);
  });
}

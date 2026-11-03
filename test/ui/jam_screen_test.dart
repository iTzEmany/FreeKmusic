import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/ui/screens/online/online_song_row.dart';
import 'package:codecore/ui/widgets/track_row.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/services/jam/jam_guest.dart' show JamJoinOutcome;
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/jam/jam_request_dialog.dart';
import 'package:codecore/ui/screens/jam/jam_screen.dart';
import 'package:codecore/ui/widgets/empty_state.dart';
import 'package:codecore/ui/widgets/ring_progress.dart';
import 'package:codecore/ui/widgets/play_buttons.dart';
import 'package:codecore/ui/widgets/seek_bar.dart';
import 'package:codecore/ui/widgets/show_msg.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeJam extends JamController {
  _FakeJam(this.initial);
  final JamUiState initial;
  final sent = <JamCommand>[];
  JamError? sendResult;

  final addedTracks = <int>[];
  final addedOnline = <String>[];

  @override
  JamUiState build() => initial;

  @override
  Future<JamAddResult> addTracks(List<Track> tracks, {bool inherited = false}) async {
    addedTracks.addAll(tracks.map((t) => t.id));
    return (added: tracks.length, full: false);
  }

  @override
  bool addOnline(YtResult r) {
    addedOnline.add(r.id);
    return true;
  }

  @override
  bool get queueFull => false;

  int ended = 0;

  void setState(JamUiState s) => state = s;

  /// A host clock that differs from the device's.
  int? clockMs;

  @override
  int jamNowMs() => clockMs ?? super.jamNowMs();

  @override
  Future<void> end() async => ended++;

  @override
  Future<JamError?> send(JamCommand cmd) async {
    sent.add(cmd);
    return sendResult;
  }
}

JamUiState active({required bool host}) => JamUiState(
      phase: JamPhase.active,
      role: host ? JamRole.host : JamRole.guest,
      peerName: 'Telefono',
      peerId: 'peer',
      jam: const JamState(
        version: 3,
        items: [
          JamItem(id: 1, ownerDeviceId: 'host', title: 'Prima', ext: 'mp3',
              artist: 'Band', durationMs: 180000),
          JamItem(id: 2, ownerDeviceId: 'peer', title: 'Seconda', ext: 'mp3',
              durationMs: 200000),
        ],
        currentIndex: 0,
        playing: true,
        hostDeviceId: 'host',
        outputDeviceId: 'host',
      ),
    );

void main() {
  for (final host in [true, false]) {
    testWidgets('jam screen as ${host ? 'host' : 'guest'}', (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final h = await Harness.create(tester);
      final fake = _FakeJam(active(host: host));
      await tester.pumpWidget(ProviderScope(
        overrides: [...h.overrides, jamProvider.overrideWith(() => fake)],
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const JamScreen(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Jam'), findsWidgets);
      expect(find.text('Prima'), findsWidgets);
      expect(find.byType(FloatingActionButton), findsNothing);
      // Next and previous for everyone (D-160); the queue is in the «Coda» sheet.
      expect(find.byTooltip('Brano successivo'), findsOneWidget);
      expect(find.byTooltip('Brano precedente'), findsOneWidget);
      expect(find.text(host ? 'Termina Jam' : 'Esci dalla Jam'), findsOneWidget);
      // Strict symmetry: Play sits at the screen centre for host and guest.
      expect(tester.getCenter(find.byTooltip('Pausa')).dx, closeTo(250, 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await h.dispose(tester);
    });
  }

  testWidgets('a screen opened after «wait a moment» shows it and closes (R-147)', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(
        tester,
        Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const JamScreen())),
                    child: const Text('apri')))),
        extraOverrides: [
          jamProvider.overrideWith(() => _FakeJam(const JamUiState(
              peerName: 'Telefono', outcome: JamJoinOutcome.tooSoon)))
        ]);
    await tester.tap(find.text('apri'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Aspetta un momento prima di riprovare'), findsOneWidget);
    expect(find.byType(JamScreen), findsNothing);
    await h.dispose(tester);
  });

  testWidgets(
      'request dialog offers accept and decline, and closes by itself when '
      'the requester cancels', (tester) async {
    final h = await Harness.create(tester);
    final req = JamRequest(
        id: 'r', fromId: 'x', fromName: 'Telefono', fromHost: '10.0.0.2',
        fromPort: 1, token: 'tttttttt', receivedAt: DateTime.now());
    await h.pump(
        tester,
        Builder(
            builder: (c) => Scaffold(
                body: Center(
                    child: TextButton(
                        onPressed: () => showDialog<void>(
                            context: c,
                            builder: (_) => JamRequestDialog(request: req)),
                        child: const Text('apri'))))));
    await tester.tap(find.text('apri'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Telefono vuole avviare una Jam'), findsOneWidget);
    expect(find.text('Accetta'), findsOneWidget);
    expect(find.text('Rifiuta'), findsOneWidget);
    req.status = JamRequestStatus.cancelled;
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Telefono vuole avviare una Jam'), findsNothing);
    // the page underneath is still there
    expect(find.text('apri'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('synchronised outputs show the offset and the latency control',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final base = active(host: true);
    final synced = JamUiState(
      phase: base.phase,
      role: base.role,
      peerName: base.peerName,
      peerId: base.peerId,
      syncErrorMs: -12,
      jam: base.jam!.copyWith(
        outputDeviceId: 'host',
        outputDeviceIds: const ['host', 'peer'],
        participants: const [
          JamParticipant(id: 'host', name: 'PC'),
          JamParticipant(id: 'peer', name: 'Telefono', host: '10.0.0.3', port: 1),
        ],
      ),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...h.overrides,
        jamProvider.overrideWith(() => _FakeJam(synced)),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const JamScreen(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Dispositivi'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sincronizzato, scarto 12 ms'), findsOneWidget);
    expect(find.textContaining('Latenza di questa uscita'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await h.dispose(tester);
  });

  testWidgets('a jam without songs and an idle jam use the quiet empty state', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final idle = _FakeJam(const JamUiState());
    await h.pump(tester, const JamScreen(), extraOverrides: [jamProvider.overrideWith(() => idle)]);
    expect(find.byType(EmptyState), findsOneWidget);
    final empty = _FakeJam(JamUiState(
      phase: JamPhase.active,
      role: JamRole.host,
      peerName: 'Telefono',
      peerId: 'peer',
      jam: const JamState(version: 1, items: [], currentIndex: -1, playing: false, hostDeviceId: 'host', outputDeviceId: 'host'),
    ));
    await h.pump(tester, const JamScreen(), extraOverrides: [jamProvider.overrideWith(() => empty)]);
    expect(find.byType(EmptyState), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an empty shared queue guides the user to queue from the library or search', (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final empty = _FakeJam(JamUiState(
      phase: JamPhase.active,
      role: JamRole.host,
      peerName: 'Telefono',
      peerId: 'peer',
      jam: const JamState(version: 1, items: [], currentIndex: -1, playing: false, hostDeviceId: 'host', outputDeviceId: 'host'),
    ));
    await h.pump(tester, const JamScreen(), extraOverrides: [jamProvider.overrideWith(() => empty)]);
    expect(find.text('Metti in coda dalla libreria o dalla ricerca'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('with the Jam active a swipe queues a library row and an online row in the Jam',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, tracks: 1);
    final t = (await tester.runAsync(() => h.db.select(h.db.tracks).get()))!.single;
    final fake = _FakeJam(active(host: true));
    await h.pump(
      tester,
      Scaffold(
        body: Column(children: [
          SizedBox(height: 64, child: LiveTrackRow(track: t, onTap: () {})),
          const SizedBox(
            height: 72,
            child: OnlineSongTile(
              result: YtResult(id: 'v1', title: 'Online song', channel: 'C', duration: null),
              index: 0,
              selectionKey: 'k',
            ),
          ),
        ]),
      ),
      extraOverrides: [jamProvider.overrideWith(() => fake)],
    );
    await tester.dragFrom(Offset(100, tester.getCenter(find.text('Song 0')).dy), const Offset(250, 0));
    await tester.pumpAndSettle();
    await tester.dragFrom(Offset(100, tester.getCenter(find.text('Online song')).dy), const Offset(250, 0));
    await tester.pumpAndSettle();
    expect(fake.addedTracks, [t.id]);
    expect(fake.addedOnline, ['v1']);
    expect(h.handler.queueIds, isEmpty);
    await h.dispose(tester);
  });

  Future<(_FakeJam, Harness)> openJam(
    WidgetTester tester, {
    bool host = true,
    JamUiState? state,
    JamError? sendResult,
    Size size = const Size(500, 1000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    final fake = _FakeJam(state ?? active(host: host))..sendResult = sendResult;
    await h.pump(
      tester,
      const JamScreen(),
      textScale: textScale,
      extraOverrides: [jamProvider.overrideWith(() => fake)],
    );
    return (fake, h);
  }

  for (final host in [true, false]) {
    testWidgets(
        'seek dall\'anello nella Jam invia JamCommand.seek (${host ? 'host' : 'ospite'})',
        (tester) async {
      final (fake, h) = await openJam(tester, host: host);
      final ring = tester.getRect(find.byType(RingProgress));
      // A touch at the bottom of the ring seeks at 115/320 of the track.
      final g = await tester.startGesture(ring.center + Offset(0, ring.width * 0.48));
      await g.up();
      await tester.pump();
      final seeks = fake.sent.where((c) => c.type == JamCommandType.seek);
      expect(seeks, hasLength(1));
      expect(seeks.single.positionMs, closeTo(180000 * 115 / 320, 2000));
      await h.dispose(tester);
    });
  }

  testWidgets('la barra della Jam invia JamCommand.seek e un esito invalid mostra il messaggio',
      (tester) async {
    final (fake, h) = await openJam(tester, host: false, sendResult: JamError.invalid);
    final g = await tester.startGesture(tester.getCenter(find.descendant(of: find.byType(SeekBar), matching: find.byType(Slider))));
    await g.moveBy(const Offset(1, 0));
    await g.up();
    await tester.pump();
    await tester.pump();
    expect(fake.sent.single.type, JamCommandType.seek);
    expect(find.text('Posizione non valida per questo brano'), findsOneWidget);
    // The Jam keeps its own drag state: the player's one is untouched.
    final box = ProviderScope.containerOf(tester.element(find.byType(JamScreen)));
    expect(box.read(seekDragProvider), isNull);
    await h.dispose(tester);
  });

  testWidgets('la posizione in riproduzione segue l\'orologio dell\'host', (tester) async {
    final base = active(host: false);
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    // The host clock is far from the device's: only jamNowMs() gives 0:40.
    final fake = _FakeJam(JamUiState(
      phase: base.phase,
      role: base.role,
      peerName: base.peerName,
      peerId: base.peerId,
      jam: base.jam!.copyWith(playing: true, positionMs: 30000, positionAt: 5000000),
    ))
      ..clockMs = 5010000;
    await h.pump(tester, const JamScreen(), extraOverrides: [jamProvider.overrideWith(() => fake)]);
    expect(find.text('0:40'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await h.dispose(tester);
  });

  testWidgets('la posizione mostrata non torna indietro all\'avvio sincronizzato, il seek sì subito',
      (tester) async {
    final base = active(host: false);
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    JamUiState at(int posMs, int posAt) => JamUiState(
          phase: base.phase,
          role: base.role,
          peerName: base.peerName,
          peerId: base.peerId,
          jam: base.jam!.copyWith(playing: true, positionMs: posMs, positionAt: posAt),
        );
    final fake = _FakeJam(at(0, 998700))..clockMs = 1000000;
    await h.pump(tester, const JamScreen(), extraOverrides: [jamProvider.overrideWith(() => fake)]);
    expect(find.text('0:01'), findsOneWidget);
    // The start is moved ahead by the lead: the shown position must not fall to 0:00.
    fake.setState(at(0, 1001500));
    await tester.pump();
    expect(find.text('0:01'), findsOneWidget);
    // A seek moves it at once.
    fake.setState(at(60000, 1000000));
    await tester.pump();
    expect(find.text('1:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await h.dispose(tester);
  });

  testWidgets('desktop: la Jam non mostra il volume locale', (tester) async {
    final (_, h) = await openJam(tester, size: const Size(1280, 900));
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
    expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('posizione della Jam ferma in pausa', (tester) async {
    final base = active(host: true);
    final (fake, h) = await openJam(
      tester,
      state: JamUiState(
        phase: base.phase,
        role: base.role,
        peerName: base.peerName,
        peerId: base.peerId,
        jam: base.jam!.copyWith(
          playing: false,
          positionMs: 30000,
          positionAt: 0,
        ),
      ),
    );
    expect(fake.sent, isEmpty);
    expect(find.text('0:30'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('0:30'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('precedente e successivo per tutti, play e pausa dalla Jam', (tester) async {
    final (fake, h) = await openJam(tester, host: false);
    await tester.tap(find.byTooltip('Brano successivo'));
    await tester.tap(find.byTooltip('Pausa'));
    await tester.pump();
    expect(fake.sent.map((c) => c.type), [JamCommandType.next, JamCommandType.pause]);
    await h.dispose(tester);
  });

  testWidgets('riga con ⋮ + ≡ nel foglio «Coda», senza ✕', (tester) async {
    final (fake, h) = await openJam(tester, host: true);
    await tester.tap(find.text('Coda'));
    await tester.pumpAndSettle();
    expect(find.text('Seconda'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    // ⋮ of the second row: «Salta qui» and «Rimuovi» (host: any item).
    await tester.tap(find.byIcon(Icons.more_vert_rounded).last);
    await tester.pumpAndSettle();
    expect(find.text('Rimuovi'), findsOneWidget);
    await tester.tap(find.text('Salta qui'));
    await tester.pumpAndSettle();
    expect(fake.sent.single.type, JamCommandType.jump);
    expect(fake.sent.single.itemId, 2);
    await h.dispose(tester);
  });

  testWidgets('un ospite rimuove solo i propri brani non in riproduzione', (tester) async {
    final (_, h) = await openJam(tester, host: false);
    await tester.tap(find.text('Coda'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('Salta qui'), findsOneWidget);
    expect(find.text('Rimuovi'), findsNothing);
    await h.dispose(tester);
  });

  JamUiState withPeople(bool host, int n) {
    final base = active(host: host);
    return JamUiState(
      phase: base.phase,
      role: base.role,
      peerName: base.peerName,
      peerId: base.peerId,
      jam: base.jam!.copyWith(participants: [
        const JamParticipant(id: 'host', name: 'Emanuele'),
        for (var i = 1; i < n; i++) JamParticipant(id: 'p$i', name: 'Ospite$i'),
      ]),
    );
  }

  testWidgets('Annulla non chiude la Jam', (tester) async {
    final (fake, h) = await openJam(tester, state: withPeople(true, 3));
    await tester.tap(find.text('Termina Jam'));
    await tester.pumpAndSettle();
    expect(find.text('Terminare la Jam per tutti?'), findsOneWidget);
    expect(find.text('I 2 ospiti verranno disconnessi e la coda condivisa verrà chiusa.'),
        findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
    expect(find.text('Terminare la Jam per tutti?'), findsNothing);
    expect(fake.ended, 0);
    await h.dispose(tester);
  });

  testWidgets('toccare fuori o il tasto indietro chiudono il dialogo senza terminare', (tester) async {
    final (fake, h) = await openJam(tester, state: withPeople(true, 3));
    await tester.tap(find.text('Termina Jam'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Terminare la Jam per tutti?'), findsNothing);
    await tester.tap(find.text('Termina Jam'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Terminare la Jam per tutti?'), findsNothing);
    expect(find.text('Termina Jam'), findsOneWidget);
    expect(fake.ended, 0);
    await h.dispose(tester);
  });

  testWidgets('senza brano corrente precedente, play e successivo sono spenti', (tester) async {
    final base = active(host: true);
    final (_, h) = await openJam(
      tester,
      state: JamUiState(
        phase: base.phase,
        role: base.role,
        peerName: base.peerName,
        peerId: base.peerId,
        jam: base.jam!.copyWith(currentIndex: -1, playing: false),
      ),
    );
    IconButton btn(IconData i) => tester.widget<IconButton>(
        find.ancestor(of: find.byIcon(i), matching: find.byType(IconButton)).first);
    expect(btn(Icons.skip_previous_rounded).onPressed, isNull);
    expect(btn(Icons.skip_next_rounded).onPressed, isNull);
    expect(tester.widget<PlayCircleButton>(find.byType(PlayCircleButton)).onPressed, isNull);
    await h.dispose(tester);
  });

  testWidgets('un seek rifiutato riporta la barra alla posizione della Jam', (tester) async {
    final base = active(host: false);
    final (fake, h) = await openJam(
      tester,
      host: false,
      sendResult: JamError.invalid,
      state: JamUiState(
        phase: base.phase,
        role: base.role,
        peerName: base.peerName,
        peerId: base.peerId,
        jam: base.jam!.copyWith(playing: false, positionMs: 30000, positionAt: 0),
      ),
    );
    final slider = find.descendant(of: find.byType(SeekBar), matching: find.byType(Slider));
    final r = tester.getRect(slider);
    final g = await tester.startGesture(r.center);
    await g.moveTo(Offset(r.right - 2, r.center.dy));
    await g.up();
    await tester.pump();
    await tester.pump();
    expect(fake.sent.single.type, JamCommandType.seek);
    expect(find.text('0:30'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('Termina con conferma chiama end', (tester) async {
    final (fake, h) = await openJam(tester, state: withPeople(true, 3));
    await tester.tap(find.text('Termina Jam'));
    await tester.pumpAndSettle();
    expect(fake.ended, 0);
    final ok = find.widgetWithText(TextButton, 'Termina');
    expect(tester.getSize(ok).height, greaterThanOrEqualTo(48));
    await tester.tap(ok);
    await tester.pumpAndSettle();
    expect(fake.ended, 1);
    await h.dispose(tester);
  });

  testWidgets('Esci dalla Jam (ospite) esce subito, senza conferma', (tester) async {
    final (fake, h) = await openJam(tester, host: false);
    expect(find.text('Termina Jam'), findsNothing);
    await tester.tap(find.text('Esci dalla Jam'));
    await tester.pumpAndSettle();
    expect(find.text('Terminare la Jam per tutti?'), findsNothing);
    expect(fake.ended, 1);
    await h.dispose(tester);
  });

  testWidgets('+N con semantica: 6 partecipanti, +2 e una sola etichetta', (tester) async {
    final handle = tester.ensureSemantics();
    final (_, h) = await openJam(tester, state: withPeople(true, 6));
    expect(find.textContaining('Emanuele (host), Ospite1, Ospite2, Ospite3 +2'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^6 partecipanti: Emanuele \(host\), Ospite1, .*Ospite5$')),
      findsOneWidget,
    );
    handle.dispose();
    await h.dispose(tester);
  });

  testWidgets('intestazione a textScaler 2.0 senza tagli', (tester) async {
    final (_, h) = await openJam(
      tester,
      state: withPeople(true, 6),
      size: const Size(360, 780),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final b = tester.getRect(find.text('Termina Jam'));
    expect(b.left, greaterThanOrEqualTo(0));
    expect(b.right, lessThanOrEqualTo(360));
    expect(tester.getRect(find.text('Jam').first).right, lessThanOrEqualTo(360));
    await h.dispose(tester);
  });

  testWidgets('desktop: coda nel pannello di destra, sul telefono solo nel foglio', (tester) async {
    final (_, h) = await openJam(tester, size: const Size(1280, 800));
    expect(find.text('Coda condivisa'), findsOneWidget);
    expect(find.text('Seconda'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    await h.dispose(tester);
    final (_, h2) = await openJam(tester, size: const Size(500, 1000));
    expect(find.text('Coda condivisa'), findsNothing);
    await h2.dispose(tester);
  }
  );

  for (final left in [true, false]) {
    testWidgets('a guest that ${left ? 'left' : 'was ended by the host'} reads the right message', (tester) async {
      final h = await Harness.create(tester);
      final fake = _FakeJam(active(host: false));
      await h.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const JamScreen())),
              child: const Text('apri'),
            ),
          ),
        ),
        extraOverrides: [jamProvider.overrideWith(() => fake)],
      );
      await tester.tap(find.text('apri'));
      await tester.pump(const Duration(milliseconds: 400));
      fake.setState(fake.state.copyWith(phase: JamPhase.ended, left: left));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(left ? 'Sei uscito dalla Jam' : 'La Jam è terminata'), findsOneWidget);
      await tester.pumpAndSettle();
      await h.dispose(tester);
    });
  }

  const JamAddResult? none = null;
  for (final (added, text) in [
    ((added: 0, full: true), 'La Jam è piena'),
    ((added: 0, full: false), 'Non aggiunto alla Jam'),
    ((added: 3, full: false), 'Aggiunti alla Jam: 3'),
    (none, 'Aggiunto in coda'),
  ]) {
    testWidgets('queue add confirmation: $text', (tester) async {
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(onPressed: () => showQueued(c, added, wanted: 5), child: const Text('aggiungi')),
          ),
        ),
      );
      await tester.tap(find.text('aggiungi'));
      await tester.pump();
      expect(find.text(text), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await h.dispose(tester);
    });
  }
}

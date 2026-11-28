import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/services/share/discovery.dart';
import 'package:codecore/ui/screens/devices/devices_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const peer = Peer(id: 'p', name: 'Pc', host: '10.0.0.2', port: 1, platform: 'linux');

class FakeHub extends ShareHubNotifier {
  FakeHub(this.outcome);
  SendOutcome outcome;
  List<Track>? sentTracks;
  @override
  ShareHubState build() => const ShareHubState(active: true, peers: [peer]);
  @override
  Future<void> enter() async {}
  @override
  Future<void> leave() async {}
  @override
  Future<SendOutcome> sendOffer(Peer peer, List<Track> tracks) async {
    sentTracks = tracks;
    return outcome;
  }
}

void main() {
  Future<void> send(WidgetTester t, SendOutcome o, String text) async {
    t.view.physicalSize = const Size(600, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: 2);
    final hub = FakeHub(o);
    await h.pump(
      t,
      Scaffold(body: Builder(builder: (c) => TextButton(onPressed: () => DevicesSheet.show(c, trackIds: [1, 2]), child: const Text('open')))),
      extraOverrides: [shareHubProvider.overrideWith(() => hub)],
    );
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Invia'));
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump();
    expect(hub.sentTracks!.map((e) => e.id), [1, 2]);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text(text), findsOneWidget);
    await t.pumpAndSettle(const Duration(seconds: 10));
    await h.dispose(t);
  }

  testWidgets('all sent: Inviato a X', (t) => send(t, const SendOutcome(SendStatus.sent, total: 2, sent: 2), 'Richiesta inviata a Pc'));
  testWidgets('some dropped: N of M plus the reason',
      (t) => send(t, const SendOutcome(SendStatus.sent, total: 2, sent: 1, shadow: 1), 'Inviato 1 brano su 2 a Pc: 1 non disponibile su questo dispositivo'));
  testWidgets('none can be sent', (t) => send(t, const SendOutcome(SendStatus.nothingToSend, total: 2, missing: 2), 'Nessuno di questi brani si può inviare'));
  testWidgets('unreachable: as today', (t) => send(t, const SendOutcome.unreachable(2), 'Dispositivo non raggiungibile: controlla indirizzo e Wi‑Fi'));
}

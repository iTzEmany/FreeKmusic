import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/jam_remote_providers.dart';
import 'package:codecore/services/jam/jam_guest.dart' show JamJoinOutcome;
import 'package:codecore/services/jam/jam_guest_link.dart' show JamLinkState;
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/jam_bridge.dart' show JamBridgeStatus;
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/ui/screens/jam/jam_header.dart';
import 'package:codecore/ui/widgets/bulk_actions.dart';
import 'package:codecore/ui/screens/jam/jam_remote_sheets.dart';
import 'package:codecore/ui/screens/jam/jam_screen.dart';
import 'package:codecore/ui/screens/jam/speaker_notices.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../support/app_harness.dart';

class _FakeBridge extends JamBridgeNotifier {
  _FakeBridge(this.initial);
  final JamBridgeState initial;
  int started = 0, stopped = 0;

  @override
  JamBridgeState build() => initial;
  void set(JamBridgeState s) => state = s;
  @override
  String? currentQr() => 'CCJ1:test';
  @override
  String? get code => 'ABCD-EFGH';
  @override
  DateTime? get codeExpiresAt => DateTime.now().add(const Duration(seconds: 25));
  @override
  Future<void> startCode() async => started++;
  @override
  void stopCode() => stopped++;
}

class _FakeJam extends JamController {
  _FakeJam([this.initial = const JamUiState()]);
  final JamUiState initial;
  final requested = <JamInvite?>[];
  void set(JamUiState s) => state = s;

  @override
  JamUiState build() => initial;
  @override
  Future<void> invite() async {}
  @override
  Future<void> stopInviting() async {}
  @override
  Future<void> requestRemote(JamInvite? invite) async => requested.add(invite);
}

void main() {
  Future<Harness> open(WidgetTester t, Widget child, List<Override> overrides, {int tracks = 0}) async {
    t.view.physicalSize = const Size(500, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t, tracks: tracks);
    await h.pump(t, Scaffold(body: child), extraOverrides: overrides);
    return h;
  }

  testWidgets('the invite sheet shows the QR and the code, starts it and stops it on close', (t) async {
    final bridge = _FakeBridge(const JamBridgeState(on: true, status: JamBridgeStatus.up));
    final h = await open(t, const JamInviteSheet(), [
      jamProvider.overrideWith(_FakeJam.new),
      jamBridgeProvider.overrideWith(() => bridge),
    ]);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('ABCD-EFGH'), findsOneWidget);
    expect(find.textContaining('Scade tra'), findsOneWidget);
    expect(bridge.started, 1);
    await t.pumpWidget(const SizedBox());
    expect(bridge.stopped, 1);
    await h.dispose(t);
  });

  testWidgets('an unreachable broker is told, with a link to its settings', (t) async {
    final h = await open(t, const JamInviteSheet(), [
      jamProvider.overrideWith(_FakeJam.new),
      jamBridgeProvider.overrideWith(() => _FakeBridge(const JamBridgeState(on: true, status: JamBridgeStatus.unreachable))),
    ]);
    expect(find.text('Broker irraggiungibile'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Jam a distanza'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    await h.dispose(t);
  });

  testWidgets('a retrying bridge says so', (t) async {
    final h = await open(t, const JamInviteSheet(), [
      jamProvider.overrideWith(_FakeJam.new),
      jamBridgeProvider.overrideWith(() => _FakeBridge(const JamBridgeState(on: true, status: JamBridgeStatus.retrying))),
    ]);
    expect(find.text('Ponte interrotto, riprovo…'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a wrong code says «Codice non valido» and asks nothing', (t) async {
    final fake = _FakeJam();
    final h = await open(t, const JamJoinSheet(), [jamProvider.overrideWith(() => fake)]);
    await t.enterText(find.byType(TextField), 'abc');
    await t.tap(find.text('Entra'));
    await t.pump();
    expect(find.text('Codice non valido'), findsOneWidget);
    expect(fake.requested, isEmpty);
    await h.dispose(t);
  });

  testWidgets('a good code is requested', (t) async {
    final fake = _FakeJam();
    final h = await open(t, const JamJoinSheet(), [jamProvider.overrideWith(() => fake)]);
    await t.enterText(find.byType(TextField), 'abcd-2345');
    await t.tap(find.text('Entra'));
    await t.pump();
    expect(fake.requested.single?.code, 'ABCD2345');
    await t.pump(const Duration(milliseconds: 600));
    await h.dispose(t);
  });

  testWidgets('an expired code shows its message and leaves the Jam screen', (t) async {
    final h = await open(
        t,
        Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const JamScreen())),
                child: const Text('apri'))),
        [jamProvider.overrideWith(() => _FakeJam(const JamUiState(outcome: JamJoinOutcome.codeExpired)))]);
    await t.tap(find.text('apri'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Codice scaduto, chiedi quello nuovo'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('waiting for a remote host without a name gets the generic text', (t) async {
    final h = await open(
        t,
        Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const JamScreen())),
                child: const Text('apri'))),
        [jamProvider.overrideWith(() => _FakeJam(const JamUiState(phase: JamPhase.requesting, remote: true)))]);
    await t.tap(find.text('apri'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('In attesa che l’host accetti…'), findsOneWidget);
    await h.dispose(t);
  });

  testWidgets('a busy remote host without a name gets the generic message', (t) async {
    final h = await open(
        t,
        Builder(
            builder: (c) => TextButton(
                onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => const JamScreen())),
                child: const Text('apri'))),
        [jamProvider.overrideWith(() => _FakeJam(const JamUiState(outcome: JamJoinOutcome.busy)))]);
    await t.tap(find.text('apri'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('L’host ha già una Jam in corso'), findsOneWidget);
    await h.dispose(t);
  });

  for (final (link, text) in [
    (JamLinkState.reconnecting, 'Connessione persa, riprovo…'),
    (JamLinkState.hostSilent, 'Host non raggiungibile, riprovo…'),
  ]) {
    testWidgets('a remote guest with link $link sees «$text»', (t) async {
      final h = await open(t, const JamLinkNotice(), [
        jamProvider.overrideWith(() => _FakeJam(JamUiState(remote: true, link: link))),
      ]);
      expect(find.text(text), findsOneWidget);
      await h.dispose(t);
    });
  }

  testWidgets('the roster marks an unreachable remote guest', (t) async {
    final h = await open(
      t,
      JamHeader(
        isHost: true,
        onEnd: () {},
        unreachable: const ['peer'],
        jam: const JamState(
          version: 1,
          hostDeviceId: 'host',
          outputDeviceId: 'host',
          participants: [JamParticipant(id: 'host', name: 'PC'), JamParticipant(id: 'peer', name: 'Telefono')],
        ),
      ),
      [],
    );
    expect(find.textContaining('Telefono (non raggiungibile)'), findsOneWidget);
    await h.dispose(t);
  });

  for (final remote in [false, true]) {
    testWidgets('«Aggiungi alla Jam» is offered for a ${remote ? 'remote' : 'LAN'} guest', (t) async {
      late BuildContext ctx;
      late WidgetRef ref;
      final h = await open(
          t,
          Consumer(builder: (c, r, _) {
            ctx = c;
            ref = r;
            return const SizedBox();
          }),
          [jamProvider.overrideWith(() => _FakeJam(JamUiState(phase: JamPhase.active, remote: remote)))],
          tracks: 2);
      final rows = await t.runAsync(() => (h.db.select(h.db.tracks)).get());
      final groups = bulkActions(ctx, ref, rows!, const BulkContext(), done: () {});
      final labels = [for (final g in groups) for (final a in g.actions) a.label];
      expect(labels.contains('Aggiungi alla Jam'), true);
      await h.dispose(t);
    });
  }

  for (final jamStarts in [true, false]) {
    testWidgets(jamStarts ? 'the invite sheet closes when the Jam becomes active' : 'the invite sheet closes when the bridge goes off', (t) async {
      final fake = _FakeJam();
      final bridge = _FakeBridge(const JamBridgeState(on: true, status: JamBridgeStatus.up));
      final h = await open(
          t,
          Builder(builder: (c) => TextButton(onPressed: () => JamInviteSheet.show(c), child: const Text('apri'))),
          [jamProvider.overrideWith(() => fake), jamBridgeProvider.overrideWith(() => bridge)]);
      await t.tap(find.text('apri'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(JamInviteSheet), findsOneWidget);
      if (jamStarts) {
        fake.set(const JamUiState(phase: JamPhase.active));
      } else {
        bridge.set(const JamBridgeState());
      }
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byType(JamInviteSheet), findsNothing);
      expect(find.text('Mi collego…'), findsNothing);
      await h.dispose(t);
    });
  }

  testWidgets('opening and closing the invite sheet may change the Jam state (as the real controller does)', (t) async {
    final fake = _StateChangingJam();
    final shown = ValueNotifier(true);
    final h = await open(t, ValueListenableBuilder(valueListenable: shown, builder: (_, on, _) => on ? const JamInviteSheet() : const SizedBox()), [
      jamProvider.overrideWith(() => fake),
      jamBridgeProvider.overrideWith(() => _FakeBridge(const JamBridgeState(on: true, status: JamBridgeStatus.up))),
    ]);
    await t.pump();
    expect(fake.state.inviting, isTrue);
    shown.value = false;
    await t.pump();
    await t.pump();
    expect(fake.state.inviting, isFalse);
    expect(t.takeException(), isNull);
    await h.dispose(t);
  });
}

/// Like the real controller: invite() and stopInviting() assign the state at once.
class _StateChangingJam extends _FakeJam {
  @override
  Future<void> invite() async => state = state.copyWith(inviting: true);
  @override
  Future<void> stopInviting() async => state = state.copyWith(inviting: false);
}

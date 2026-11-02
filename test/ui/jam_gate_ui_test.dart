import 'package:codecore/data/settings/jam_secret_store.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/jam_gate_providers.dart';
import 'package:codecore/services/jam/jam_gate.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/ui/screens/jam/jam_request_dialog.dart';
import 'package:codecore/ui/screens/settings/settings_screen.dart';
import 'package:codecore/ui/widgets/duration_choice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Records the declined requests; [initial] decides whether a Jam is running.
class _DialogJam extends JamController {
  _DialogJam(this.initial);
  final JamUiState initial;
  final declined = <String>[];
  @override
  JamUiState build() => initial;
  @override
  void decline(JamRequest req) => declined.add(req.id);
}

void main() {
  final now = DateTime(2026, 1, 1, 12);
  JamGate newGate() => JamGate(MemoryJamSecretStore(), now: () => now);

  Future<void> openDialog(WidgetTester t, JamGate gate, _DialogJam jam) async {
    final h = await Harness.create(t);
    final req = JamRequest(
        id: 'r', fromId: 'x', fromName: 'Telefono', fromHost: '10.0.0.2',
        fromPort: 1, token: 'tttttttt', receivedAt: now);
    await h.pump(
        t,
        Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(context: c, builder: (_) => JamRequestDialog(request: req)),
                    child: const Text('apri')))),
        extraOverrides: [jamGateProvider.overrideWithValue(gate), jamProvider.overrideWith(() => jam)]);
    await t.tap(find.text('apri'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
  }

  testWidgets('dialog: Sospendi asks for a duration and suspends the sender', (t) async {
    final gate = newGate();
    final jam = _DialogJam(const JamUiState());
    await openDialog(t, gate, jam);
    for (final a in ['Accetta', 'Rifiuta', 'Sospendi', 'Blocca']) {
      expect(find.text(a), findsOneWidget);
    }
    await t.tap(find.text('Sospendi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('15 minuti'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(gate.suspended.single.id, 'x');
    expect(gate.suspended.single.when, now.add(const Duration(minutes: 15)));
    expect(jam.declined, ['r']);
    expect(find.text('Telefono vuole avviare una Jam'), findsNothing);
  });

  testWidgets('dialog: Blocca blocks the sender', (t) async {
    final gate = newGate();
    final jam = _DialogJam(const JamUiState());
    await openDialog(t, gate, jam);
    await t.tap(find.text('Blocca'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(gate.blocked.single.name, 'Telefono');
    expect(jam.declined, ['r']);
    expect(find.text('Telefono vuole avviare una Jam'), findsNothing);
  });

  testWidgets('dialog: «until the Jam ends» is offered only with a Jam running, and suspends with no expiry', (t) async {
    var gate = newGate();
    await openDialog(t, gate, _DialogJam(const JamUiState()));
    await t.tap(find.text('Sospendi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Fino alla fine della Jam'), findsNothing);

    gate = newGate();
    await t.pumpWidget(const SizedBox());
    await openDialog(t, gate, _DialogJam(const JamUiState(phase: JamPhase.active, role: JamRole.host)));
    await t.tap(find.text('Sospendi'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.text('Fino alla fine della Jam'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(gate.suspended.single.when, isNull);
  });

  testWidgets('settings lists show blocked and suspended senders and Sblocca removes them', (t) async {
    final gate = newGate();
    await gate.ready; // loading drops the «until the Jam ends» suspensions
    gate
      ..block('a', 'Tablet')
      ..suspend('b', 'Telefono', null);
    t.view.physicalSize = const Size(400, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final h = await Harness.create(t);
    await h.pump(t, const Scaffold(body: SettingsScreen(initial: SettingsPage.network)),
        extraOverrides: [jamGateProvider.overrideWithValue(gate)]);
    expect(find.text('Tablet'), findsOneWidget);
    expect(find.text('Fino alla fine della Jam'), findsOneWidget);
    await t.tap(find.text('Sblocca').first);
    await t.pump();
    expect(gate.blocked, isEmpty);
    expect(find.text('Tablet'), findsNothing);
    await t.tap(find.text('Sblocca'));
    await t.pump();
    expect(gate.suspended, isEmpty);
    expect(find.text('Telefono'), findsNothing);
  });

  testWidgets('duration sheet: cancel chip only when asked, minutes and end pop their value', (t) async {
    final h = await Harness.create(t);
    int? got;
    Future<void> open(String? cancel) async {
      await h.pump(
        t,
        Builder(
          builder: (c) => Scaffold(
            body: TextButton(
              onPressed: () async => got = await showDurationChoiceSheet(c,
                  title: 'T', endLabel: 'Fine', cancelLabel: cancel),
              child: const Text('apri'),
            ),
          ),
        ),
      );
      await t.tap(find.text('apri'));
      await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    }

    await open(null);
    expect(find.text('Annulla'), findsNothing);
    await t.tap(find.text('45 minuti'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(got, 45);
    await open('Annulla');
    await t.tap(find.text('Annulla'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(got, 0);
    await open(null);
    await t.tap(find.text('Fine'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(got, -1);
  });
}

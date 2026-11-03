import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/ui/screens/jam/jam_queue_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeJam extends JamController {
  _FakeJam(this.initial);
  final JamUiState initial;
  @override
  JamUiState build() => initial;
  void set(JamUiState s) => state = s;
}

JamUiState _state({required List<JamParticipant> people}) => JamUiState(
      phase: JamPhase.active,
      role: JamRole.host,
      jam: JamState(
        version: 3,
        items: const [
          JamItem(id: 2, ownerDeviceId: 'peer', title: 'Seconda', ext: 'mp3', durationMs: 1000),
        ],
        participants: people,
        currentIndex: 0,
        hostDeviceId: 'host',
        outputDeviceId: 'host',
      ),
    );

Future<(_FakeJam, Harness)> _open(WidgetTester tester, JamUiState s) async {
  final h = await Harness.create(tester);
  final fake = _FakeJam(s);
  await h.pump(
    tester,
    Scaffold(body: CustomScrollView(slivers: const [JamQueueSliver()])),
    extraOverrides: [jamProvider.overrideWith(() => fake)],
  );
  return (fake, h);
}

void main() {
  testWidgets('chi è uscito resta col nome visto prima', (tester) async {
    const host = JamParticipant(id: 'host', name: 'PC');
    final (fake, h) = await _open(tester, _state(people: [host, const JamParticipant(id: 'peer', name: 'Mi A3')]));
    expect(find.textContaining('Mi A3'), findsOneWidget);
    fake.set(_state(people: [host]));
    await tester.pump();
    expect(find.textContaining('Mi A3'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('chi è uscito e non si è mai visto: «Ospite»', (tester) async {
    final (_, h) = await _open(tester, _state(people: [const JamParticipant(id: 'host', name: 'PC')]));
    expect(find.textContaining('Ospite'), findsOneWidget);
    await h.dispose(tester);
  });
}

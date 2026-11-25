import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/ui/screens/online/online_song_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _r = YtResult(
  id: 'v1',
  title: 'Online song',
  channel: 'Chan',
  duration: Duration(seconds: 90),
  artists: ['Ann'],
  artistIds: ['UC1'],
);

class _Jam extends JamController {
  final online = <String>[];
  @override
  JamUiState build() => const JamUiState(phase: JamPhase.active, role: JamRole.guest);
  @override
  bool addOnline(YtResult r) {
    online.add(r.id);
    return true;
  }
}

// The real PlayerController (no fake): R-89, a guest's online queueing reaches addOnline.
void main() {
  late _Jam jam;
  Future<Harness> pumpRow(WidgetTester tester) async {
    jam = _Jam();
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const Scaffold(body: OnlineSongTile(result: _r, index: 0, selectionKey: 'k')),
      extraOverrides: [jamProvider.overrideWith(() => jam)],
    );
    return h;
  }

  testWidgets('guest: swipe on an online row queues in the Jam', (tester) async {
    final h = await pumpRow(tester);
    await tester.dragFrom(const Offset(120, 36), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(jam.online, ['v1']);
    await h.dispose(tester);
  });

  testWidgets('guest: ⋮ → «Aggiungi in coda» on an online row queues in the Jam', (tester) async {
    final h = await pumpRow(tester);
    await tester.tap(find.byTooltip('Altre azioni').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aggiungi in coda'));
    await tester.pumpAndSettle();
    expect(jam.online, ['v1']);
    await h.dispose(tester);
  });
}

import 'package:codecore/data/repositories/backup_merge.dart';
import 'package:codecore/providers/app_restart_provider.dart';
import 'package:codecore/services/restart/app_restart.dart';
import 'package:codecore/ui/screens/settings/merge_report_dialog.dart';
import 'package:codecore/ui/screens/settings/restore_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeRestart implements AppRestart {
  _FakeRestart(this.result);
  final bool result;
  int calls = 0;
  @override
  Future<bool> restart() async {
    calls++;
    return result;
  }
}

Future<void> _open(WidgetTester tester, Harness h, void Function(BuildContext, WidgetRef) go,
    List<Override> extra) async {
  await h.pump(
    tester,
    Consumer(builder: (c, ref, _) => TextButton(onPressed: () => go(c, ref), child: const Text('open'))),
    extraOverrides: extra,
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('restart started: the app is restarted, no «close and reopen» text', (tester) async {
    final h = await Harness.create(tester);
    final fake = _FakeRestart(true);
    await _open(tester, h, showRestartDialog, [appRestartProvider.overrideWithValue(fake)]);
    expect(fake.calls, 1);
    expect(find.textContaining('si riavvia'), findsOneWidget);
    expect(find.textContaining('chiudi l’app'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('restart not possible: the fallback text and a button that closes only the dialog', (tester) async {
    final h = await Harness.create(tester);
    await _open(tester, h, showRestartDialog, [appRestartProvider.overrideWithValue(_FakeRestart(false))]);
    expect(find.textContaining('chiudi l’app'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chiudi l’app'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('not found: one row each, «Salva in streaming» only with a stream key', (tester) async {
    final h = await Harness.create(tester);
    final r = MergeReport()
      ..notFound.addAll(const [
        MissingTrack(title: 'Uno', artist: 'A', streamKey: 'youtube:abc'),
        MissingTrack(title: 'Due'),
        MissingTrack(title: 'Tre', artist: 'C'),
      ]);
    await _open(tester, h, (c, _) => showMergeReport(c, r), const []);
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('Salva in streaming'), findsOneWidget);
    expect(find.text('Cerca online'), findsNWidgets(2));
    expect(find.text('Salva tutti'), findsOneWidget);
    expect(find.text('Copia elenco'), findsOneWidget);
    await h.dispose(tester);
  });
}

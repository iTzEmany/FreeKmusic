import 'package:codecore/data/repositories/backup_merge.dart';
import 'package:codecore/providers/app_restart_provider.dart';
import 'package:codecore/services/restart/app_restart.dart';
import 'package:codecore/providers/ui_providers.dart';
import 'package:codecore/ui/screens/playlists/export_dialog.dart';
import 'package:codecore/ui/screens/settings/backup_section.dart';
import 'package:codecore/ui/screens/settings/merge_report_dialog.dart';
import 'package:codecore/ui/screens/settings/restore_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeRestart implements AppRestart {
  _FakeRestart(this.result, {this.throws = false});
  final bool result;
  final bool throws;
  int calls = 0;
  int quits = 0;
  @override
  Future<void> quit() async => quits++;
  @override
  Future<bool> restart() async {
    calls++;
    if (throws) throw StateError('no channel');
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
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('restart not possible: the fallback text and a button that quits the app', (tester) async {
    final h = await Harness.create(tester);
    final fake = _FakeRestart(false);
    await _open(tester, h, showRestartDialog, [appRestartProvider.overrideWithValue(fake)]);
    expect(find.textContaining('chiudi l’app'), findsOneWidget);
    await tester.tap(find.text('Chiudi'));
    await tester.pump();
    expect(fake.quits, 1);
    await h.dispose(tester);
  });

  testWidgets('restart started but the process lives on after 5 s: the fallback', (tester) async {
    final h = await Harness.create(tester);
    await _open(tester, h, showRestartDialog, [appRestartProvider.overrideWithValue(_FakeRestart(true))]);
    expect(find.textContaining('chiudi l’app'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('chiudi l’app'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('restart that throws: the fallback text', (tester) async {
    final h = await Harness.create(tester);
    await _open(tester, h, showRestartDialog, [appRestartProvider.overrideWithValue(_FakeRestart(false, throws: true))]);
    expect(find.textContaining('chiudi l’app'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a tap outside does not close the restart dialog', (tester) async {
    final h = await Harness.create(tester);
    await _open(tester, h, showRestartDialog, [appRestartProvider.overrideWithValue(_FakeRestart(true))]);
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.textContaining('si riavvia'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await h.dispose(tester);
  });

  testWidgets('backup tiles: what it holds, export opens its dialog', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(tester, Scaffold(body: Consumer(builder: (c, ref, _) => ListView(children: backupTiles(c, ref)))));
    expect(find.textContaining('Il backup contiene'), findsOneWidget);
    expect(find.text('Importa playlist'), findsOneWidget);
    await tester.tap(find.text('Esporta playlist'));
    await tester.pumpAndSettle();
    expect(find.byType(ExportDialog), findsOneWidget);
    await h.dispose(tester);
  });

  group('not found', () {
    String? clip;
    setUp(() {
      clip = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
        if (c.method == 'Clipboard.setData') clip = (c.arguments as Map)['text'] as String?;
        return null;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    final report = MergeReport()
      ..notFound.addAll(const [
        MissingTrack(title: 'Uno', artist: 'A'),
        MissingTrack(title: 'Due', artist: ''),
        MissingTrack(title: 'Tre'),
      ]);

    testWidgets('one row each with «Cerca online»; no artist: the title alone', (tester) async {
      final sem = tester.ensureSemantics();
      final h = await Harness.create(tester);
      await _open(tester, h, (c, _) => showMergeReport(c, report), const []);
      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('Cerca online'), findsNWidgets(3));
      expect(find.text('Uno'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Cerca online: Uno')), findsOneWidget);
      sem.dispose();
      await h.dispose(tester);
    });

    testWidgets('«Copia elenco» copies every row', (tester) async {
      final h = await Harness.create(tester);
      await _open(tester, h, (c, _) => showMergeReport(c, report), const []);
      await tester.tap(find.text('Copia elenco'));
      await tester.pump();
      expect(clip, 'Uno - A\nDue\nTre');
      await h.dispose(tester);
    });

    testWidgets('«Cerca online» copies the list, closes, tells and prefills «artista titolo»', (tester) async {
      final h = await Harness.create(tester);
      await h.pump(
        tester,
        Scaffold(body: Consumer(builder: (c, ref, _) => TextButton(onPressed: () => showMergeReport(c, report), child: const Text('open')))),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerca online').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(clip, 'Uno - A\nDue\nTre');
      expect(find.text('Elenco copiato negli appunti'), findsOneWidget);
      expect(ProviderScope.containerOf(tester.element(find.text('open'))).read(searchPrefillProvider), 'A Uno');
      await h.dispose(tester);
    });
  });
}

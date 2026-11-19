import 'package:codecore/providers/update_providers.dart';
import 'package:codecore/services/online/update_checker.dart';
import 'package:codecore/services/update/update_installer.dart';
import 'package:codecore/services/update/update_target.dart';
import 'package:codecore/ui/screens/settings/update_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _apk = 'freekmusic-full-arm64-v8a-release.apk';
const _mb = 1048576;

final _info = UpdateInfo(version: '9.9.9', url: 'https://x/rel', assets: [
  UpdateAsset(name: _apk, url: Uri.parse('https://x/$_apk'), size: 84 * _mb, sha256: 'ab'),
  UpdateAsset(name: 'freekmusic_9.9.9_amd64.deb', url: Uri.parse('https://x/d.deb'), size: 31 * _mb, sha256: 'ab'),
]);

class _Flow extends UpdateDownloadNotifier {
  _Flow(this.initial);
  final UpdateDownloadState initial;
  final calls = <String>[];
  @override
  UpdateDownloadState build() => initial;
  @override
  Future<void> start(UpdateInfo info) async => calls.add('start');
  @override
  Future<void> confirm() async => calls.add('confirm');
  @override
  void cancel() => calls.add('cancel');
  @override
  Future<void> retry() async => calls.add('retry');
}

void main() {
  late _Flow flow;

  Future<Harness> open(
    WidgetTester tester,
    UpdateDownloadState state, {
    UpdateKind kind = UpdateKind.androidFull,
  }) async {
    flow = _Flow(state);
    final h = await Harness.create(tester);
    await h.pump(tester, UpdateDialog(info: _info), extraOverrides: [
      updateTargetProvider.overrideWith((_) => UpdateTarget(kind: kind, abi: 'arm64-v8a')),
      updateDownloadProvider.overrideWith(() => flow),
    ]);
    return h;
  }

  final apk = _info.assets.first;
  const idle = UpdateDownloadState(UpdatePhase.idle);

  testWidgets('newer: «Aggiorna» with the file and its size, no link to copy', (tester) async {
    final h = await open(tester, idle);
    expect(find.text('Disponibile la versione 9.9.9'), findsOneWidget);
    expect(find.text('File: $_apk, 84 MB'), findsOneWidget);
    expect(find.text('Copia indirizzo'), findsNothing);
    await tester.tap(find.text('Aggiorna'));
    expect(flow.calls, ['start']);
    await h.dispose(tester);
  });

  testWidgets('a file that does not install itself: «Scarica dal browser»', (tester) async {
    final h = await open(tester, idle, kind: UpdateKind.deb);
    expect(find.text('Scarica dal browser'), findsOneWidget);
    expect(find.text('Aggiorna'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('downloading: «35 di 84 MB» and «Annulla»', (tester) async {
    final h = await open(tester, UpdateDownloadState(UpdatePhase.downloading, asset: apk, received: 35 * _mb));
    expect(find.text('35 di 84 MB'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    expect(flow.calls, ['cancel']);
    await h.dispose(tester);
  });

  testWidgets('metered network: asks with the size, «Scarica» goes on', (tester) async {
    final h = await open(tester, UpdateDownloadState(UpdatePhase.confirmSize, asset: apk));
    expect(find.text('Sei su una rete a consumo. Il file pesa 84 MB: scaricarlo?'), findsOneWidget);
    await tester.tap(find.text('Scarica'));
    expect(flow.calls, ['confirm']);
    await h.dispose(tester);
  });

  for (final (failure, title) in [
    (UpdateFailure.interrupted, 'Download interrotto'),
    (UpdateFailure.corrupt, 'File danneggiato'),
  ]) {
    testWidgets('$title: «Riprova»', (tester) async {
      final h = await open(tester, UpdateDownloadState(UpdatePhase.error, asset: apk, failure: failure));
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text('Riprova'));
      expect(flow.calls, ['retry']);
      await h.dispose(tester);
    });
  }

  testWidgets('different signer: says so, nothing to retry', (tester) async {
    final h = await open(tester, UpdateDownloadState(UpdatePhase.differentSigner, asset: apk));
    expect(find.text('Firma diversa'), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('missing unknown-sources permission: says what to allow', (tester) async {
    final h = await open(tester, UpdateDownloadState(UpdatePhase.needsPermission, asset: apk));
    expect(find.textContaining('Consenti a FreeKmusic di installare app'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the start-up notice has «Aggiorna», which opens the update dialog', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(tester, Scaffold(body: Builder(builder: (c) => TextButton(
      onPressed: () => ScaffoldMessenger.of(c).showSnackBar(updateSnackBar(c, _info, const Duration(seconds: 8))),
      child: const Text('go'),
    ))), extraOverrides: [
      updateTargetProvider.overrideWith((_) => const UpdateTarget(kind: UpdateKind.androidFull, abi: 'arm64-v8a')),
    ]);
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Disponibile la versione 9.9.9'), findsOneWidget);
    await tester.tap(find.text('Aggiorna'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('File: $_apk, 84 MB'), findsOneWidget);
    await h.dispose(tester);
  });
}

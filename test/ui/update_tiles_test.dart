import 'package:codecore/providers/update_providers.dart';
import 'package:codecore/services/online/update_checker.dart';
import 'package:codecore/services/update/update_installer.dart';
import 'package:codecore/services/update/update_target.dart';
import 'package:codecore/ui/screens/settings/update_page.dart';
import 'package:codecore/ui/screens/settings/update_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _apk = 'freekmusic-full-arm64-v8a-release.apk';
const _mb = 1048576;

const _block = '''
## Novità
- evidenza | mic | Video karaoke nella Jam | Metti un video karaoke.
- play | Ascolta subito | I brani partono in streaming.
## Correzioni
- La musica riparte
- Il karaoke riprende
## What's Changed
* feat(136): arricchimento unico by @x in https://x/pull/208
''';

final _info = UpdateInfo(
  version: '9.9.9',
  url: 'https://x/rel',
  notes: _block,
  assets: [
    UpdateAsset(name: _apk, url: Uri.parse('https://x/$_apk'), size: 84 * _mb, sha256: 'ab'),
    UpdateAsset(name: 'freekmusic_9.9.9_amd64.deb', url: Uri.parse('https://x/d.deb'), size: 31 * _mb, sha256: 'ab'),
  ],
);

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
  Future<void> resumeInstall() async => calls.add('resume');
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
    await h.pump(
      tester,
      UpdatePage(info: _info, wide: tester.view.physicalSize.width / tester.view.devicePixelRatio >= 840),
      extraOverrides: [
        updateTargetProvider.overrideWith((_) => UpdateTarget(kind: kind, abi: 'arm64-v8a')),
        updateDownloadProvider.overrideWith(() => flow),
      ],
    );
    return h;
  }

  final apk = _info.assets.first;
  const idle = UpdateDownloadState(UpdatePhase.idle);

  testWidgets('newer: the button says «Aggiorna (84 MB)», which TalkBack reads too', (tester) async {
    final h = await open(tester, idle);
    expect(find.text('È arrivata la 9.9.9'), findsOneWidget);
    expect(find.text('Copia indirizzo'), findsNothing);
    expect(tester.getSemantics(find.widgetWithText(FilledButton, 'Aggiorna (84 MB)')).label, contains('84 MB'));
    await tester.tap(find.text('Aggiorna (84 MB)'));
    expect(flow.calls, ['start']);
    await h.dispose(tester);
  });

  testWidgets('with the block: highlight, news and «Correzioni (2)» closed; no GitHub «feat(» line', (tester) async {
    final h = await open(tester, idle);
    expect(find.text('Video karaoke nella Jam'), findsOneWidget);
    expect(find.text('Ascolta subito'), findsOneWidget);
    expect(find.text('Correzioni (2)'), findsOneWidget);
    expect(find.text('La musica riparte'), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.text('Correzioni (2)'));
    await tester.pumpAndSettle();
    expect(find.text('La musica riparte'), findsOneWidget);
    expect(find.textContaining('feat('), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('without the block (raw GitHub notes): «Correzioni e miglioramenti» and the link only', (tester) async {
    final h = await Harness.create(tester);
    final raw = UpdateInfo(version: '9.9.9', url: 'https://x/rel', notes: "## What's Changed\n* feat(1): x by @y");
    await h.pump(
      tester,
      UpdatePage(info: raw, wide: false),
      extraOverrides: [
        updateTargetProvider.overrideWith((_) => const UpdateTarget(kind: UpdateKind.androidFull, abi: 'arm64-v8a')),
      ],
    );
    expect(find.text('Correzioni e miglioramenti'), findsOneWidget);
    expect(find.text('Tutte le modifiche su GitHub'), findsOneWidget);
    expect(find.textContaining('feat('), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('wide: a two-column dialog; narrow: a full-screen page', (tester) async {
    final h = await open(tester, idle);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(Scaffold), findsWidgets);
    await h.dispose(tester);
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = await open(tester, idle);
    expect(find.byType(Dialog), findsOneWidget);
    await w.dispose(tester);
  });

  testWidgets('a file that does not install itself: «Scarica dal browser»', (tester) async {
    final h = await open(tester, idle, kind: UpdateKind.deb);
    expect(find.text('Scarica dal browser'), findsOneWidget);
    expect(find.textContaining('Aggiorna ·'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('flatpak, ready: shows the install command with the file path and «Copia» copies it', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (c) async {
      if (c.method == 'Clipboard.setData') copied = (c.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final h = await open(
      tester,
      const UpdateDownloadState(UpdatePhase.ready, path: '/home/u/updates/freekmusic-9.9.9.flatpak'),
      kind: UpdateKind.flatpak,
    );
    const cmd = 'flatpak install --user /home/u/updates/freekmusic-9.9.9.flatpak';
    expect(find.text(cmd), findsOneWidget);
    expect(find.textContaining('incolla il comando'), findsOneWidget);
    await tester.tap(find.text('Copia'));
    await tester.pump();
    expect(copied, cmd);
    await h.dispose(tester);
  });

  testWidgets('other formats, ready: no install command, no «Copia»', (tester) async {
    final h = await open(tester, UpdateDownloadState(UpdatePhase.ready, asset: apk));
    expect(find.textContaining('flatpak install'), findsNothing);
    expect(find.text('Copia'), findsNothing);
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

  testWidgets('back in the foreground: the install goes on with the downloaded file', (tester) async {
    final h = await open(tester, UpdateDownloadState(UpdatePhase.needsPermission, asset: apk));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(flow.calls, ['resume']);
    await h.dispose(tester);
  });

  for (final phase in [UpdatePhase.ready, UpdatePhase.needsPermission]) {
    testWidgets('$phase: «Aggiorna» starts again', (tester) async {
      final h = await open(tester, UpdateDownloadState(phase, asset: apk));
      await tester.tap(find.text('Aggiorna'));
      expect(flow.calls, ['retry']);
      await h.dispose(tester);
    });
  }

  testWidgets('the progress bar reads out the same text', (tester) async {
    final h = await open(tester, UpdateDownloadState(UpdatePhase.downloading, asset: apk, received: 35 * _mb));
    expect(tester.getSemantics(find.byType(LinearProgressIndicator)).label, '35 di 84 MB');
    await h.dispose(tester);
  });

  testWidgets('the start-up notice has «Aggiorna», which opens the update page', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(updateSnackBar(c, _info, const Duration(seconds: 8))),
            child: const Text('go'),
          ),
        ),
      ),
      extraOverrides: [
        updateTargetProvider.overrideWith((_) => const UpdateTarget(kind: UpdateKind.androidFull, abi: 'arm64-v8a')),
      ],
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Disponibile la versione 9.9.9'), findsOneWidget);
    await tester.tap(find.text('Aggiorna'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('È arrivata la 9.9.9'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a tap on the text of the start-up notice opens the page too', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(updateSnackBar(c, _info, const Duration(seconds: 8))),
            child: const Text('go'),
          ),
        ),
      ),
      extraOverrides: [
        updateTargetProvider.overrideWith((_) => const UpdateTarget(kind: UpdateKind.androidFull, abi: 'arm64-v8a')),
      ],
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Disponibile la versione 9.9.9'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('È arrivata la 9.9.9'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1)); // the snack bar's exit animation
    expect(find.byType(SnackBar), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the start-up notice times out', (tester) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      Scaffold(
        body: Builder(
          builder: (c) => TextButton(
            onPressed: () => ScaffoldMessenger.of(c).showSnackBar(updateSnackBar(c, _info, const Duration(seconds: 8))),
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Disponibile la versione 9.9.9'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Disponibile la versione 9.9.9'), findsNothing);
    await h.dispose(tester);
  });
}

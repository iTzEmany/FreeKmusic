import 'dart:async';

import 'package:codecore/core/issue_report.dart';
import 'package:codecore/providers/issue_providers.dart';
import 'package:codecore/services/issue/issue_sender.dart';
import 'package:codecore/services/issue/link_opener.dart';
import 'package:codecore/ui/screens/settings/report_issue_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

class _FakeOpener extends LinkOpener {
  final opened = <String>[];
  bool ok = true;

  @override
  Future<bool> open(String url) async {
    opened.add(url);
    return ok;
  }
}

class _FakeSender implements IssueSender {
  _FakeSender(this.result);
  final IssueSendResult result;
  final sent = <String>[];

  @override
  Future<IssueSendResult> send({required String title, required String body, required String version}) async {
    sent.add('$title|$body');
    return result;
  }
}

const _info = TechInfo(
  appVersion: '1.2.0',
  buildNumber: '6053',
  platform: 'android',
  osVersion: '14',
  deviceModel: 'Mi A3',
  flavor: 'completa',
  transition: 'normal',
  shufflePlus: false,
  language: 'it',
  logLines: ['2026 [W] qualcosa'],
);

void main() {
  testWidgets('validation, preview toggle, open and copy', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opener = _FakeOpener();
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (c) async {
        if (c.method == 'Clipboard.setData') {
          clip = (c.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final h = await Harness.create(tester);
    await h.pump(
      tester,
      const ReportIssueScreen(),
      extraOverrides: [
        linkOpenerProvider.overrideWithValue(opener),
        issueTechInfoProvider.overrideWith((ref) async => _info),
      ],
    );

    TextButton openBtn() =>
        tester.widget(find.byKey(const ValueKey('report-open')));
    expect(openBtn().onPressed, isNull, reason: 'empty fields');
    expect(find.byKey(const ValueKey('report-preview')), findsOneWidget);
    expect(find.textContaining('Mi A3'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('report-title')),
      'Si ferma',
    );
    await tester.enterText(
      find.byKey(const ValueKey('report-description')),
      'corta',
    );
    await tester.pump();
    expect(openBtn().onPressed, isNull, reason: 'description too short');

    await tester.enterText(
      find.byKey(const ValueKey('report-description')),
      'La musica si ferma dopo dieci minuti',
    );
    await tester.pump();
    expect(openBtn().onPressed, isNotNull);

    await tester.tap(find.byKey(const ValueKey('report-open')));
    await tester.pump();
    expect(opener.opened.single, contains('issues/new?title=Si%20ferma'));
    expect(opener.opened.single, contains('Mi%20A3'));

    await tester.tap(find.byKey(const ValueKey('report-copy')));
    await tester.pump();
    expect(clip, startsWith('Si ferma\n\nTipo: Bug\n\nLa musica si ferma'));
    expect(clip, contains('Mi A3'));

    await tester.tap(find.byKey(const ValueKey('report-attach')));
    await tester.pump();
    expect(find.byKey(const ValueKey('report-preview')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('report-copy')));
    await tester.pump();
    expect(clip, isNot(contains('Mi A3')));

    opener.ok = false;
    clip = null;
    await tester.tap(find.byKey(const ValueKey('report-open')));
    await tester.pump();
    expect(clip, isNotNull, reason: 'browser failure falls back to copying');
    await h.dispose(tester);
  });

  Future<Harness> pumpScreen(
    WidgetTester tester, {
    Widget screen = const ReportIssueScreen(),
    String endpoint = '',
    IssueSender? sender,
  }) async {
    final h = await Harness.create(tester);
    await h.pump(
      tester,
      screen,
      extraOverrides: [
        issueEndpointProvider.overrideWithValue(endpoint),
        if (sender != null) issueSenderProvider.overrideWithValue(sender),
        issueTechInfoProvider.overrideWith((ref) async => _info),
      ],
    );
    return h;
  }

  testWidgets('opens pre-filled and explains the disabled buttons', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await pumpScreen(
      tester,
      screen: const ReportIssueScreen(title: 'Download non riuscito', details: 'HTTP Error 403'),
    );
    expect(find.text('Download non riuscito'), findsOneWidget);
    expect(find.text('HTTP Error 403'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-why-disabled')), findsOneWidget);
    await h.dispose(tester);
  });

  for (final size in const [Size(320, 640), Size(1280, 800)]) {
    testWidgets('no overflow at ${size.width.toInt()} dp', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await pumpScreen(tester, endpoint: 'https://w.example/');
      await tester.enterText(find.byKey(const ValueKey('report-title')), 'Titolo');
      await tester.enterText(
        find.byKey(const ValueKey('report-description')),
        'Una descrizione abbastanza lunga',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('report-send')), findsOneWidget);
      await h.dispose(tester);
    });
  }

  Future<void> fill(WidgetTester tester) async {
    await tester.enterText(find.byKey(const ValueKey('report-title')), 'Si ferma');
    await tester.enterText(
      find.byKey(const ValueKey('report-description')),
      'La musica si ferma dopo dieci minuti',
    );
    await tester.pump();
  }

  testWidgets('send: success shows the link', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sender = _FakeSender(const IssueSendResult(IssueSendStatus.sent, 'https://github.com/o/r/issues/7'));
    final h = await pumpScreen(tester, endpoint: 'https://w.example/', sender: sender);
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('report-send')));
    await tester.pump();
    await tester.pump();
    expect(sender.sent.single, startsWith('Si ferma|Tipo: Bug\n\nLa musica'));
    expect(find.text('https://github.com/o/r/issues/7'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-copy')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('send: failure leaves Copia testo and says so', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await pumpScreen(tester, endpoint: 'https://w.example/', sender: _FakeSender(const IssueSendResult(IssueSendStatus.rejected)));
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('report-send')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('report-send-failed')), findsOneWidget);
    expect(find.byKey(const ValueKey('report-copy')), findsOneWidget);
    await h.dispose(tester);
  });

  for (final st in [IssueSendStatus.rateLimited, IssueSendStatus.unsure]) {
    testWidgets('send: $st shows its own message', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final h = await pumpScreen(tester, endpoint: 'https://w.example/', sender: _FakeSender(IssueSendResult(st)));
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pump();
      await tester.pump();
      final shown = (tester.widget(find.byKey(const ValueKey('report-send-failed'))) as Text).data!;
      expect(shown, st == IssueSendStatus.rateLimited ? contains('Troppi invii') : contains('GitHub prima di riprovare'));
      await h.dispose(tester);
    });
  }

  testWidgets('send waits for the technical info still loading', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gate = Completer<TechInfo>();
    final sender = _FakeSender(const IssueSendResult(IssueSendStatus.sent, 'https://github.com/o/r/issues/7'));
    final h = await Harness.create(tester);
    await h.pump(tester, const ReportIssueScreen(), extraOverrides: [
      issueEndpointProvider.overrideWithValue('https://w.example/'),
      issueSenderProvider.overrideWithValue(sender),
      issueTechInfoProvider.overrideWith((ref) => gate.future),
    ]);
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('report-send')));
    await tester.pump();
    expect(sender.sent, isEmpty);
    gate.complete(_info);
    await tester.pump();
    await tester.pump();
    expect(sender.sent.single, contains('Mi A3'));
    await h.dispose(tester);
  });

  testWidgets('empty address: no «Invia», only copy and GitHub', (tester) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await pumpScreen(tester);
    expect(find.byKey(const ValueKey('report-send')), findsNothing);
    expect(find.byKey(const ValueKey('report-copy')), findsOneWidget);
    await h.dispose(tester);
  });
}

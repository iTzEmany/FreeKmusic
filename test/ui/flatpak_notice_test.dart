import 'package:codecore/services/platform/flatpak_data_notice.dart';
import 'package:codecore/ui/screens/onboarding/onboarding_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _flatpak = {'FLATPAK_ID': 'com.freekmusic.player'};

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _open(WidgetTester tester, Harness h, Map<String, String> env) async {
  await h.pump(tester, OnboardingGate(env: env, child: const Scaffold(body: Text('APP'))));
  await _settle(tester);
}

void main() {
  test('due only inside a flatpak, with an empty library and the notice not shown', () {
    bool due(Map<String, String> env, {bool empty = true, bool shown = false}) =>
        flatpakNoticeDue(env: env, libraryEmpty: empty, shown: shown);
    expect(due(_flatpak), isTrue);
    expect(due(const {}), isFalse);
    expect(due(const {'FLATPAK_ID': ''}), isFalse);
    expect(due(_flatpak, empty: false), isFalse);
    expect(due(_flatpak, shown: true), isFalse);
  });

  test('the copy command sets the empty new folder aside before copying', () {
    expect(flatpakCopyCommand.indexOf('mv '), lessThan(flatpakCopyCommand.indexOf('cp -a')));
    expect(flatpakCopyCommand, contains('.vuota'));
  });

  testWidgets('shown the first time with a flatpak and an empty library, not the second', (tester) async {
    final h = await Harness.create(tester);
    await _open(tester, h, _flatpak);
    expect(find.text('Copia comando'), findsOneWidget);
    expect(h.store.flatpakNoticeShown, isTrue);
    await h.dispose(tester);

    final h2 = await Harness.create(tester);
    await h2.store.markFlatpakNoticeShown();
    await _open(tester, h2, _flatpak);
    expect(find.text('Copia comando'), findsNothing);
    await h2.dispose(tester);
  });

  testWidgets('not outside a flatpak, not with a full library', (tester) async {
    final h = await Harness.create(tester);
    await _open(tester, h, const {});
    expect(find.text('Copia comando'), findsNothing);
    await h.dispose(tester);

    final h2 = await Harness.create(tester, tracks: 2);
    await _open(tester, h2, _flatpak);
    expect(find.text('Copia comando'), findsNothing);
    expect(h2.store.flatpakNoticeShown, isFalse);
    await h2.dispose(tester);
  });
}

// Characterization: the «add folder» flow is one (D-12, addFolderAndScan): a
// folder added in the onboarding is scanned straight away, like in the sheet.
//
// The system picker is replaced by a fake that answers with a fixed path.
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/ui/screens/library/folders_sheet.dart';
import 'package:codecore/ui/screens/onboarding/onboarding_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

const _gone = '/nonexistent/codecore-folders-test';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

ScanState _scan(WidgetTester tester) => ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
    .read(scanStateProvider);

class _FakePicker extends FilePickerPlatform {
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    String? initialDirectory,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async => _gone;
}

void main() {
  setUp(() => FilePickerPlatform.instance = _FakePicker());

  group('onboarding', () {
    testWidgets('a folder added on the folders page is scanned straight away', (tester) async {
      final h = await Harness.create(tester);
      await h.pump(tester, const OnboardingScreen(askAudioPermission: false));
      await tester.tap(find.text('Avanti'));
      await _settle(tester);
      await tester.tap(find.text('Aggiungi cartella'));
      await _settle(tester);
      expect(find.text('1 cartella aggiunta'), findsOneWidget);
      expect(_scan(tester).error, contains(_gone), reason: 'the unreachable folder was visited');
      await h.dispose(tester);
    });
  });

  group('folders sheet', () {
    Future<Harness> open(WidgetTester tester) async {
      final h = await Harness.create(tester);
      await tester.runAsync(() => h.db.transaction(() => FolderRepository(h.db).add(_gone)));
      await h.pump(tester, const Scaffold(body: FoldersSheet()));
      await _settle(tester);
      return h;
    }

    testWidgets('lists the folders by path', (tester) async {
      final h = await open(tester);
      expect(find.text(_gone), findsOneWidget);
      await h.dispose(tester);
    });

    testWidgets('the refresh button scans straight away', (tester) async {
      final h = await open(tester);
      await tester.tap(find.byTooltip('Aggiorna libreria'));
      await _settle(tester);
      expect(_scan(tester).error, contains(_gone));
      await h.dispose(tester);
    });

    testWidgets('removing a folder asks first: cancel keeps it, confirm drops it', (tester) async {
      final h = await open(tester);
      await tester.tap(find.byTooltip('Rimuovi cartella'));
      await _settle(tester);
      await tester.tap(find.text('Annulla'));
      await _settle(tester);
      expect(find.text(_gone), findsOneWidget);
      await tester.tap(find.byTooltip('Rimuovi cartella'));
      await _settle(tester);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      await _settle(tester);
      expect(find.text(_gone), findsNothing);
      await h.dispose(tester);
    });
  });
}

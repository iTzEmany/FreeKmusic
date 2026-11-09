import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/services/library/duplicate_finder.dart';
import 'package:codecore/ui/screens/cleanup/duplicate_member_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Folder _root(int id, String path) => Folder(id: id, path: path, addedAt: 0);

DupEntry _entry(String path) => DupEntry(
  id: 1,
  path: path,
  title: 't',
  artist: null,
  durationMs: 200000,
  format: 'flac',
  sizeBytes: 1000000,
);

void main() {
  group('dupFolderLabel', () {
    test('is relative to the root and keeps the nested folders', () {
      final roots = [_root(1, '/storage/emulated/0/Music')];
      expect(
        dupFolderLabel(
          '/storage/emulated/0/Music/Pink Floyd/The Wall/a.mp3',
          roots,
        ),
        'Music › Pink Floyd › The Wall',
      );
    });

    test('same-named roots are told apart like Memoria does', () {
      final roots = [
        _root(1, '/storage/emulated/0/Music'),
        _root(2, '/storage/emulated/0/Android/data/x/files/Music'),
      ];
      expect(
        dupFolderLabel('/storage/emulated/0/Music/A/a.mp3', roots),
        'Music › A',
      );
      expect(
        dupFolderLabel(
          '/storage/emulated/0/Android/data/x/files/Music/a.mp3',
          roots,
        ),
        'x/Music',
      );
    });

    test('without a matching root the absolute folder is shown', () {
      expect(dupFolderLabel('/mnt/x/y/a.mp3', const []), '/mnt/x/y');
    });
  });

  testWidgets(
    'long name and deep folder are fully readable; dialog copies the path',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      const name =
          'A very long file name for the remastered deluxe edition (2011) - final mix v2.flac';
      const path =
          '/storage/emulated/0/Music/Pink Floyd/The Wall/Disc 2/Bonus/$name';
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            foldersProvider.overrideWith(
              (ref) => Stream.value([_root(1, '/storage/emulated/0/Music')]),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('it'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: DuplicateMemberRow(
                entry: _entry(path),
                keep: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final nameText = tester.widget<Text>(
        find.byKey(const ValueKey('dup-name-1')),
      );
      expect(nameText.data, name);
      expect(nameText.overflow, isNot(TextOverflow.ellipsis));
      expect(nameText.maxLines, isNull);
      expect(
        find.text('Music › Pink Floyd › The Wall › Disc 2 › Bonus'),
        findsOneWidget,
      );
      expect(find.text('Da tenere'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('dup-info-1')));
      await tester.pumpAndSettle();
      expect(find.text('Dettagli'), findsOneWidget);
      expect(find.byKey(const ValueKey('dup-full-path')), findsOneWidget);
      expect(find.text(path), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dup-copy-path')));
      await tester.pump();
      expect(copied, path);
    },
  );
}

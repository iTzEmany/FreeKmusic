import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart' show LastPlay;
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/radio_providers.dart';
import 'package:codecore/providers/releases_providers.dart';
import 'package:codecore/ui/screens/home/home_blocks.dart'
    show NewReleasesBlock;
import 'package:codecore/providers/resume_providers.dart';
import 'package:codecore/ui/screens/home/resume_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';

class _Spy implements PlayerController {
  final played = <List<int>>[];
  @override
  Future<void> playFromList(
    List<Track> snapshot,
    int index, {
    PlayContext? context,
  }) async => played.add([for (final t in snapshot) t.id]);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets(
    'an episode row names the podcast, where it was left and plays it',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final episode = Track(
        saved: false,
        coverSource: 0,
        id: 7,
        path: '/e/7.mp3',
        title: 'Seconda parte',
        artist: 'Tienimi Bordone',
        albumKey: 'k',
        durationMs: 42 * 60000,
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        hasCover: false,
        isFavorite: false,
        enrichStatus: 0,
        userEdited: false,
        missing: false,
        ignored: false,
        kind: 1,
        addedAt: 1,
        playCount: 0,
        resumePositionMs: (23 * 60 + 41) * 1000,
      );
      final spy = _Spy();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumableTracksProvider.overrideWith(
              (ref) => Stream.value([episode]),
            ),
            currentTrackProvider.overrideWith((ref) => Stream.value(null)),
            queueProvider.overrideWith((ref) => Stream.value(const <Track>[])),
            playContextProvider.overrideWithValue(null),
            lastPlaysProvider.overrideWith((ref) => Stream.value(const [])),
            savedRadiosProvider.overrideWith((ref) => Stream.value(const [])),
            isPlayingProvider.overrideWith((ref) => Stream.value(false)),
            recentEntriesProvider.overrideWithValue(const []),
            playerControllerProvider.overrideWithValue(spy),
          ],
          child: MaterialApp(
            locale: const Locale('it'),
            theme: buildThemeFromColors(CcColors.notte, false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ResumeList()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.text('Tienimi Bordone, riprendi da 23:41, mancano 19 min'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(const ValueKey('resume-podcast'))).label,
        allOf(
          contains('Seconda parte'),
          contains('riprendi da 23:41'),
          contains('mancano 19 min'),
        ),
        reason: 'TalkBack reads where it was left and what is left',
      );
      await tester.tap(find.text('Seconda parte'));
      expect(spy.played, [
        [7],
      ]);
      semantics.dispose();
    },
  );

  testWidgets(
    'a song with a bookmark keeps its usual subtitle (no podcast wording)',
    (tester) async {
      final song = Track(
        saved: false,
        coverSource: 0,
        id: 8,
        path: '/m/8.mp3',
        title: 'Lunga suite',
        artist: 'Band',
        album: 'Live',
        albumKey: 'k',
        durationMs: 60 * 60000,
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        hasCover: false,
        isFavorite: false,
        enrichStatus: 0,
        userEdited: false,
        missing: false,
        ignored: false,
        kind: 0,
        addedAt: 1,
        playCount: 0,
        resumePositionMs: 20 * 60 * 1000,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumableTracksProvider.overrideWith((ref) => Stream.value([song])),
            currentTrackProvider.overrideWith((ref) => Stream.value(null)),
            queueProvider.overrideWith((ref) => Stream.value(const <Track>[])),
            playContextProvider.overrideWithValue(null),
            lastPlaysProvider.overrideWith((ref) => Stream.value(const [])),
            savedRadiosProvider.overrideWith((ref) => Stream.value(const [])),
            isPlayingProvider.overrideWith((ref) => Stream.value(false)),
            recentEntriesProvider.overrideWithValue(const []),
            playerControllerProvider.overrideWithValue(_Spy()),
          ],
          child: MaterialApp(
            locale: const Locale('it'),
            theme: buildThemeFromColors(CcColors.notte, false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ResumeList()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Lunga suite'), findsOneWidget);
      expect(
        find.text('Mancano 40 minuti'),
        findsOneWidget,
        reason: 'only what is left, no artist, no place',
      );
      expect(find.textContaining('riprendi da'), findsNothing);
    },
  );

  for (final (width, columns) in [(400.0, 2), (1200.0, 3)]) {
    testWidgets('the grid has $columns columns at $width dp, tiles of 48 dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Track t(int id, int kind) => Track(
        saved: false,
        coverSource: 0,
        id: id,
        path: '/m/$id.mp3',
        title: 'T$id',
        albumKey: 'k',
        durationMs: 60000,
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        hasCover: false,
        isFavorite: false,
        enrichStatus: 0,
        userEdited: false,
        missing: false,
        ignored: false,
        kind: kind,
        addedAt: 1,
        playCount: 0,
        lastPlayedAt: 10,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            resumableTracksProvider.overrideWith(
              (ref) => Stream.value([t(1, 0), t(2, 1)]),
            ),
            lastPlaysProvider.overrideWith(
              (ref) => Stream.value([LastPlay(8, t(3, 0), 5)]),
            ),
            savedRadiosProvider.overrideWith((ref) => Stream.value(const [])),
            isPlayingProvider.overrideWith((ref) => Stream.value(false)),
            currentTrackProvider.overrideWith((ref) => Stream.value(null)),
            queueProvider.overrideWith((ref) => Stream.value(const <Track>[])),
            playContextProvider.overrideWithValue(null),
            recentEntriesProvider.overrideWithValue(const []),
            playerControllerProvider.overrideWithValue(_Spy()),
          ],
          child: MaterialApp(
            locale: const Locale('it'),
            theme: buildThemeFromColors(CcColors.notte, false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SingleChildScrollView(child: ResumeList()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      final tops = {
        for (final k in ['track', 'podcast', 'daylist'])
          tester.getTopLeft(find.byKey(ValueKey('resume-$k'))).dy,
      };
      expect(tops, hasLength(columns == 2 ? 2 : 1));
      expect(
        tester.getSize(find.byKey(const ValueKey('resume-track'))).height,
        greaterThanOrEqualTo(48),
      );
    });
  }

  for (final n in [0, 3]) {
    testWidgets('«Nuove uscite» block shows only with releases ($n)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newReleasesCountProvider.overrideWith((ref) => Stream.value(n)),
          ],
          child: MaterialApp(
            locale: const Locale('it'),
            theme: buildThemeFromColors(CcColors.notte, false),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: NewReleasesBlock()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Nuove uscite'), n == 0 ? findsNothing : findsOneWidget);
    });
  }
}

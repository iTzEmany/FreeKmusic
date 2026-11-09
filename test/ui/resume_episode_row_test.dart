import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/l10n/app_localizations.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/releases_providers.dart';
import 'package:codecore/ui/screens/home/resume_rows.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codecore/ui/theme/app_theme.dart';
import 'package:codecore/ui/theme/tokens.dart';

class _Spy implements PlayerController {
  final played = <List<int>>[];
  @override
  Future<void> playFromList(List<Track> snapshot, int index, {PlayContext? context}) async =>
      played.add([for (final t in snapshot) t.id]);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  testWidgets('an episode row names the podcast, where it was left and plays it', (tester) async {
    final semantics = tester.ensureSemantics();
    final episode = Track(
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
    await tester.pumpWidget(ProviderScope(
      overrides: [
        resumableTracksProvider.overrideWith((ref) => Stream.value([episode])),
        currentTrackProvider.overrideWith((ref) => Stream.value(null)),
        queueProvider.overrideWith((ref) => Stream.value(const <Track>[])),
        playContextProvider.overrideWithValue(null),
        newReleasesCountProvider.overrideWith((ref) => Stream.value(0)),
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
    ));
    await tester.pump();
    expect(find.text('Tienimi Bordone, riprendi da 23:41, mancano 19 min'), findsOneWidget);
    expect(tester.getSemantics(find.byKey(const ValueKey('resume-track-7'))).label,
        allOf(contains('Seconda parte'), contains('riprendi da 23:41'), contains('mancano 19 min')),
        reason: 'TalkBack reads where it was left and what is left');
    await tester.tap(find.text('Seconda parte'));
    expect(spy.played, [
      [7],
    ]);
    semantics.dispose();
  });

  testWidgets('a song with a bookmark keeps its usual subtitle (no podcast wording)', (tester) async {
    final song = Track(
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
    await tester.pumpWidget(ProviderScope(
      overrides: [
        resumableTracksProvider.overrideWith((ref) => Stream.value([song])),
        currentTrackProvider.overrideWith((ref) => Stream.value(null)),
        queueProvider.overrideWith((ref) => Stream.value(const <Track>[])),
        playContextProvider.overrideWithValue(null),
        newReleasesCountProvider.overrideWith((ref) => Stream.value(0)),
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
    ));
    await tester.pump();
    expect(find.text('Lunga suite'), findsOneWidget);
    expect(find.text('Mancano 40 minuti'), findsOneWidget, reason: 'only what is left, no artist, no place');
    expect(find.textContaining('riprendi da'), findsNothing);
  });
}

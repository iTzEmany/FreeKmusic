import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/library_queries.dart' show LastPlay;
import 'package:codecore/data/repositories/release_repository.dart' show RecentRelease;
import 'package:codecore/providers/daylist_providers.dart'
    show DaylistActions, daylistActionsProvider;
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
  int toggles = 0;
  @override
  Future<void> togglePlayPause() async => toggles++;
  @override
  Future<void> playFromList(
    List<Track> snapshot,
    int index, {
    PlayContext? context,
    Object? listKey,
  }) async => played.add([for (final t in snapshot) t.id]);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DaylistSpy implements DaylistActions {
  int plays = 0;
  @override
  Future<void> play({int? startIndex}) async => plays++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Track _song(int id) => Track(
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
  kind: 0,
  addedAt: 1,
  playCount: 0,
);

/// The block alone, inside a box of [blockWidth] dp when given.
Future<_DaylistSpy> _pumpResume(
  WidgetTester tester, {
  PlayContext? source,
  List<Track> queue = const [],
  Track? current,
  List<LastPlay> plays = const [],
  List<LibraryEntry> entries = const [],
  List<SavedRadio> radios = const [],
  double? blockWidth,
  _Spy? spy,
}) async {
  final daylist = _DaylistSpy();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        resumableTracksProvider.overrideWith(
          (ref) => Stream.value(const <Track>[]),
        ),
        lastPlaysProvider.overrideWith((ref) => Stream.value(plays)),
        savedRadiosProvider.overrideWith((ref) => Stream.value(radios)),
        isPlayingProvider.overrideWith((ref) => Stream.value(true)),
        currentTrackProvider.overrideWith((ref) => Stream.value(current)),
        queueProvider.overrideWith((ref) => Stream.value(queue)),
        playContextProvider.overrideWithValue(source),
        recentEntriesProvider.overrideWithValue(entries),
        playerControllerProvider.overrideWithValue(spy ?? _Spy()),
        daylistActionsProvider.overrideWithValue(daylist),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        theme: buildThemeFromColors(CcColors.notte, false),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: blockWidth, child: const ResumeList()),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  return daylist;
}

void main() {
  for (final (kind, key, title) in [
    (PlayContextKind.album, 'album', 'Disco'),
    (PlayContextKind.playlist, 'playlist', 'Mix'),
    (PlayContextKind.radio, 'radio', 'Radio X'),
  ]) {
    testWidgets(
      'a queue playing from $kind: no error, the tile of the area shows its own $title',
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpResume(
          tester,
          source: PlayContext(kind, title),
          current: _song(1),
          queue: [_song(1)],
          entries: [
            const LibraryEntry(
              kind: LibraryKind.album,
              id: 'a',
              title: 'Disco',
              count: 1,
              lastPlayedAt: 5,
            ),
            const LibraryEntry(
              kind: LibraryKind.playlist,
              id: 'p',
              title: 'Mix',
              count: 1,
              lastPlayedAt: 5,
            ),
          ],
          radios: [
            SavedRadio(
              stationId: 's',
              name: 'Radio X',
              streamUrl: 'u',
              homepage: '',
              faviconUrl: '',
              countryCode: '',
              state: '',
              tags: '',
              codec: '',
              bitrate: 0,
              hls: false,
              position: 0,
              addedAt: 1,
              lastPlayedAt: 5,
              unreachable: false,
            ),
          ],
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSemantics(find.byKey(ValueKey('resume-$key'))).label,
          contains(title),
        );
        semantics.dispose();
      },
    );
  }

  testWidgets(
    'the tile of what plays pauses/resumes it on tap, one semantics node each tile',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final spy = _Spy();
      await _pumpResume(
        tester,
        spy: spy,
        source: const PlayContext(PlayContextKind.library),
        current: _song(1),
        queue: [_song(1)],
        plays: [LastPlay(8, _song(2), 5)],
      );
      final now = find.byKey(const ValueKey('resume-track'));
      expect(tester.getSemantics(now).label, contains('T1'));
      expect(
        tester.getSemantics(find.byKey(const ValueKey('resume-daylist'))).label,
        contains('Daylist'),
      );
      await tester.tap(now);
      expect(spy.toggles, 1);
      expect(spy.played, isEmpty);
      semantics.dispose();
    },
  );

  testWidgets('an album or playlist with a blank title shows the fallback', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpResume(
      tester,
      plays: [
        LastPlay(0, _song(1), 5, contextName: ''),
        LastPlay(2, _song(2), 4, contextName: ' '),
      ],
      entries: [
        const LibraryEntry(
          kind: LibraryKind.album,
          id: 'k',
          title: '',
          count: 1,
          lastPlayedAt: 5,
        ),
        const LibraryEntry(
          kind: LibraryKind.playlist,
          id: 'p',
          title: ' ',
          count: 1,
          lastPlayedAt: 4,
        ),
      ],
    );
    final l = AppLocalizations.of(tester.element(find.byType(ResumeList)));
    expect(
      tester.getSemantics(find.byKey(const ValueKey('resume-album'))).label,
      contains(l.unknownAlbum),
    );
    semantics.dispose();
  });

  testWidgets('a daylist from the plays starts it on tap', (tester) async {
    final daylist = await _pumpResume(
      tester,
      plays: [LastPlay(8, _song(1), 5)],
    );
    await tester.tap(find.byKey(const ValueKey('resume-daylist')));
    expect(daylist.plays, 1);
  });

  testWidgets('the daylist that is playing is not started again by a tap', (
    tester,
  ) async {
    final daylist = await _pumpResume(
      tester,
      source: const PlayContext(PlayContextKind.daylist),
      current: _song(1),
      queue: [_song(1)],
    );
    expect(find.byKey(const ValueKey('resume-daylist')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('resume-daylist')));
    expect(daylist.plays, 0);
  });

  for (final n in [0, 1, 3, 8]) {
    testWidgets(
      '$n listens: the ring has the middle and ${n < 2 ? 0 : n - 1} on the arc, no gaps',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final spy = _Spy();
        await _pumpResume(
          tester,
          spy: spy,
          plays: [
            for (var i = 1; i <= n; i++) LastPlay(null, _song(i), 100 - i),
          ],
        );
        final slots = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('resume-'),
        );
        expect(slots, findsNWidgets(n));
        if (n == 0) {
          semantics.dispose();
          return;
        }
        expect(find.byIcon(Icons.play_circle_outline_rounded), findsOneWidget);
        for (final e in slots.evaluate()) {
          final r = tester.getRect(find.byElementPredicate((x) => x == e));
          expect(r.width, greaterThanOrEqualTo(48));
          expect(r.height, greaterThanOrEqualTo(48));
          expect(
            tester.getSemantics(find.byElementPredicate((x) => x == e)).label,
            isNotEmpty,
          );
        }
        // The most recent is in the middle; a tap on the last one resumes that listen.
        final core = tester.getCenter(
          find.byKey(const ValueKey('resume-track')),
        );
        if (n > 1) {
          final end = find.byKey(ValueKey('resume-track-${n - 1}'));
          expect(tester.getCenter(end).dy, isNot(core.dy));
          await tester.tap(end);
          expect(spy.played.last, [n]);
        }
        semantics.dispose();
      },
    );
  }

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
      await tester.tap(find.byKey(const ValueKey('resume-podcast')));
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

  for (final n in [0, 3]) {
    testWidgets('«Nuove uscite» block shows only with releases ($n)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            newReleasesCountProvider.overrideWith((ref) => Stream.value(n)),
            recentReleasesProvider(30).overrideWith(
              (ref) => Stream.value([
                if (n > 0)
                  const RecentRelease(
                    ArtistRelease(
                      browseId: 'B1',
                      artistId: 'UC1',
                      title: 'Disco',
                      kind: 0,
                      firstSeenAt: 1,
                      isNew: true,
                      groupKey: 'disco',
                    ),
                    'Artista',
                    false,
                    0,
                  ),
              ]),
            ),
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

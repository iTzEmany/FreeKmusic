import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/home_sections.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/library_queries.dart' show LastPlay;
import 'package:drift/drift.dart' show Value;
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/radio_providers.dart';
import 'package:codecore/providers/resume_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Track track(int id) => Track(
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

void main() {
  test(
    'every play context kind has its area (radio comes from the stations)',
    () {
      final expected = {
        PlayContextKind.album: ResumeArea.album,
        PlayContextKind.playlist: ResumeArea.playlist,
        PlayContextKind.radio: null,
        PlayContextKind.podcast: ResumeArea.podcast,
        PlayContextKind.daylist: ResumeArea.daylist,
        PlayContextKind.artist: ResumeArea.track,
        PlayContextKind.favorites: ResumeArea.track,
        PlayContextKind.library: ResumeArea.track,
        PlayContextKind.search: ResumeArea.track,
      };
      expect(
        expected.keys.toSet(),
        PlayContextKind.values.toSet(),
        reason: 'a new kind needs a line here',
      );
      for (final e in expected.entries) {
        expect(resumeAreaOf(e.key), e.value, reason: '${e.key}');
      }
    },
  );

  // The raw `plays.context` column: null, odd or from a newer version reads as the library.
  for (final (raw, area) in <(int?, ResumeArea?)>[
    (null, ResumeArea.track),
    (-1, ResumeArea.track),
    (0, null), // an album play with no entry in the library: no tile
    (7, null),
    (8, ResumeArea.daylist),
    (9, ResumeArea.track),
    (1 << 40, ResumeArea.track),
  ]) {
    test('a play with context $raw gives ${area ?? 'no item'}', () async {
      final c = ProviderContainer(
        overrides: [
          lastPlaysProvider.overrideWith(
            (ref) => Stream.value([LastPlay(raw, track(1), 5)]),
          ),
          resumableTracksProvider.overrideWith(
            (ref) => Stream.value(const <Track>[]),
          ),
          savedRadiosProvider.overrideWith((ref) => Stream.value(const [])),
          currentTrackProvider.overrideWith((ref) => Stream.value(null)),
          queueProvider.overrideWith((ref) => Stream.value(const <Track>[])),
          playContextProvider.overrideWithValue(null),
          recentEntriesProvider.overrideWithValue(const []),
        ],
      );
      addTearDown(c.dispose);
      c.listen(resumeItemsProvider, (_, _) {});
      await c.read(lastPlaysProvider.future);
      await c.read(resumableTracksProvider.future);
      await c.read(savedRadiosProvider.future);
      await c.read(currentTrackProvider.future);
      await c.read(queueProvider.future);
      expect(c.read(resumeItemsProvider).map((i) => i.area), [?area]);
    });
  }

  test('listens of different kinds give distinct items in order, the most recent first', () async {
    ProviderContainer make() {
      final c = ProviderContainer(
        overrides: [
          lastPlaysProvider.overrideWith(
            (ref) => Stream.value([
              LastPlay(null, track(1), 90),
              LastPlay(8, track(2), 80),
              LastPlay(0, track(3), 70, contextName: 'X'),
              LastPlay(2, track(4), 60, contextName: 'P'),
            ]),
          ),
          resumableTracksProvider.overrideWith(
            (ref) => Stream.value([
              track(5).copyWith(lastPlayedAt: const Value(50)),
            ]),
          ),
          savedRadiosProvider.overrideWith(
            (ref) => Stream.value([
              SavedRadio(
                stationId: 's',
                name: 'R',
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
                lastPlayedAt: 85,
                unreachable: false,
              ),
            ]),
          ),
          currentTrackProvider.overrideWith((ref) => Stream.value(null)),
          queueProvider.overrideWith((ref) => Stream.value(const <Track>[])),
          playContextProvider.overrideWithValue(null),
          recentEntriesProvider.overrideWithValue(const [
            LibraryEntry(
              kind: LibraryKind.album,
              id: 'k',
              title: 'X',
              count: 1,
              lastPlayedAt: 70,
            ),
            LibraryEntry(
              kind: LibraryKind.playlist,
              id: 'p',
              title: 'P',
              count: 1,
              lastPlayedAt: 60,
            ),
            LibraryEntry(
              kind: LibraryKind.album,
              id: 'z',
              title: 'Z',
              count: 1,
              lastPlayedAt: 40,
            ),
          ]),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    final c = make();
    c.listen(resumeItemsProvider, (_, _) {});
    await c.read(lastPlaysProvider.future);
    await c.read(resumableTracksProvider.future);
    await c.read(savedRadiosProvider.future);
    await c.read(currentTrackProvider.future);
    await c.read(queueProvider.future);
    final items = c.read(resumeItemsProvider);
    expect(items.map((i) => i.area), [
      ResumeArea.track,
      ResumeArea.radio,
      ResumeArea.daylist,
      ResumeArea.album,
      ResumeArea.playlist,
      ResumeArea.track,
      ResumeArea.album,
    ]);
    expect(items.map((i) => i.at), [90, 85, 80, 70, 60, 50, 40]);
  });
}

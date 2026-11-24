import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/home_sections.dart';
import 'package:codecore/data/play_context_kind.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:flutter_test/flutter_test.dart';

Track track(int id, {int kind = 0, int? lastPlayedAt}) => Track(
  saved: false,
  coverSource: 0,
  id: id,
  path: '/m/$id.mp3',
  title: 'Song $id',
  albumKey: 'k',
  durationMs: 180000,
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
  lastPlayedAt: lastPlayedAt,
);

LibraryEntry entry(
  String id,
  int played, [
  LibraryKind k = LibraryKind.album,
]) => LibraryEntry(kind: k, id: id, title: id, count: 1, lastPlayedAt: played);

SavedRadio radio(int? played) => SavedRadio(
  stationId: 's', name: 'R', streamUrl: 'u', homepage: '', faviconUrl: '', countryCode: '',
  state: '', tags: '', codec: '', bitrate: 0, hls: false, position: 0, addedAt: 1,
  lastPlayedAt: played, unreachable: false,
);

void main() {
  test('a stored index is decoded in one place: null or unknown reads as the library', () {
    expect(PlayContextKind.fromIndex(PlayContextKind.radio.index), PlayContextKind.radio);
    expect(PlayContextKind.fromIndex(PlayContextKind.values.length - 1), PlayContextKind.daylist);
    for (final raw in [null, -1, PlayContextKind.values.length, 9999]) {
      expect(PlayContextKind.fromIndex(raw), PlayContextKind.library, reason: '$raw');
    }
  });

  test('a radio listen makes no tile of its own: the stations give the radio tile', () {
    final items = lastPerArea(plays: [(kind: PlayContextKind.radio, track: track(1), at: 50, name: 'R')]);
    expect(items, isEmpty);
  });

  test('one item per area, the latest of each, most recent first', () {
    final items = lastPerArea(
      plays: [
        (kind: PlayContextKind.library, track: track(1), at: 50, name: null),
        (kind: PlayContextKind.daylist, track: track(2), at: 40, name: null),
      ],
      resumable: [
        track(5, lastPlayedAt: 10),
        track(6, kind: 1, lastPlayedAt: 60),
      ],
      entries: [
        entry('a', 30),
        entry('b', 20),
        entry('p', 5, LibraryKind.playlist),
      ],
    );
    expect(items.map((i) => i.area), [
      ResumeArea.podcast,
      ResumeArea.track,
      ResumeArea.daylist,
      ResumeArea.album,
      ResumeArea.playlist,
    ]);
    expect(items.firstWhere((i) => i.area == ResumeArea.track).track!.id, 1);
    expect(items.firstWhere((i) => i.area == ResumeArea.album).entry!.id, 'a');
  });

  test('the playing queue wins its area and carries its place', () {
    final items = lastPerArea(
      current: track(1),
      queue: [track(0), track(1), track(2)],
      plays: [(kind: PlayContextKind.library, track: track(9), at: 99, name: null)],
      resumable: [track(1, lastPlayedAt: 3)],
    );
    expect(items, hasLength(1));
    expect((items.single.queueIndex, items.single.queueLength), (1, 3));
    expect(items.single.track!.id, 1);
  });

  test('nothing played: no items', () {
    expect(lastPerArea(), isEmpty);
  });

  for (final queueKind in [PlayContextKind.album, PlayContextKind.playlist, PlayContextKind.radio]) {
    test('a queue playing $queueKind does not make an item without its entry', () {
      final items = lastPerArea(
        current: track(1),
        queue: [track(1)],
        queueKind: queueKind,
      );
      expect(items, isEmpty, reason: 'album, playlist and radio tiles need their entry or station');
    });
  }

  test('an album in the queue takes its tile from the entries', () {
    final items = lastPerArea(
      current: track(1),
      queue: [track(1)],
      queueKind: PlayContextKind.album,
      entries: [entry('a', 30)],
    );
    expect(items.single.area, ResumeArea.album);
    expect(items.single.entry!.id, 'a');
    expect(items.single.queueIndex, isNull);
  });

  test('a daylist in the queue carries its place', () {
    final items = lastPerArea(
      current: track(1),
      queue: [track(1), track(2)],
      queueKind: PlayContextKind.daylist,
    );
    expect(items.single.area, ResumeArea.daylist);
    expect(items.single.queueIndex, 0);
  });

  test('entries without a last play are skipped, artists never show', () {
    final items = lastPerArea(
      entries: [
        const LibraryEntry(kind: LibraryKind.album, id: 'none', title: 'none', count: 1),
        entry('ok', 5),
        entry('artist', 99, LibraryKind.artist),
      ],
    );
    expect(items.map((i) => i.entry!.id), ['ok']);
  });

  test('a radio played shows, the latest of the plays wins', () {
    final items = lastPerArea(radios: [radio(5)]);
    expect(items.single.radio!.name, 'R');
  });

  test('a podcast play gives the track tile, a radio never played (no last play) is absent', () {
    final items = lastPerArea(
      plays: [(kind: PlayContextKind.podcast, track: track(3, kind: 1), at: 7, name: null)],
      radios: [radio(null)],
    );
    expect(items.single.area, ResumeArea.podcast);
    expect(items.single.track!.id, 3);
  });

  LibraryEntry album(String key, String title, int played) => LibraryEntry(
    kind: LibraryKind.album, id: key, title: title, count: 1, lastPlayedAt: played);
  Track inAlbum(int id, String key) => track(id).copyWith(albumKey: key);

  test('an album played as an album shows; a daylist that plays its tracks does not move the tiles', () {
    final items = lastPerArea(
      plays: [
        (kind: PlayContextKind.album, track: inAlbum(1, 'x'), at: 10, name: 'X'),
        (kind: PlayContextKind.daylist, track: inAlbum(2, 'y'), at: 90, name: null),
      ],
      // The daylist track bumped album y (MAX of the tracks' last play).
      entries: [album('x', 'X', 10), album('y', 'Y', 90)],
    );
    expect(items.firstWhere((i) => i.area == ResumeArea.album).entry!.id, 'x');
  });

  test('a playlist play finds its playlist by name; without a play the entries decide', () {
    final withPlay = lastPerArea(
      plays: [(kind: PlayContextKind.playlist, track: track(1), at: 10, name: 'A')],
      entries: [entry('A', 10, LibraryKind.playlist), entry('B', 90, LibraryKind.playlist)],
    );
    expect(withPlay.single.entry!.id, 'A');
    final without = lastPerArea(entries: [entry('B', 90, LibraryKind.playlist)]);
    expect(without.single.entry!.id, 'B');
  });

  test('the song that plays is not offered again by the daylist or the resumable ones', () {
    final items = lastPerArea(
      current: track(1),
      queue: [track(1)],
      queueKind: PlayContextKind.daylist,
      plays: [(kind: PlayContextKind.library, track: track(1), at: 99, name: null)],
      resumable: [track(1, lastPlayedAt: 98)],
    );
    expect(items.map((i) => i.area), [ResumeArea.daylist]);
  });
}

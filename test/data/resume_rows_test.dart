import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/home_sections.dart';
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

void main() {
  test('one item per area, the latest of each, most recent first', () {
    final items = lastPerArea(
      plays: [
        (area: ResumeArea.track, track: track(1), at: 50),
        (area: ResumeArea.daylist, track: track(2), at: 40),
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
      plays: [(area: ResumeArea.track, track: track(9), at: 99)],
      resumable: [track(1, lastPlayedAt: 3)],
    );
    expect(items, hasLength(1));
    expect((items.single.queueIndex, items.single.queueLength), (1, 3));
    expect(items.single.track!.id, 1);
  });

  test('nothing played: no items', () {
    expect(lastPerArea(), isEmpty);
  });
}

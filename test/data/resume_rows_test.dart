import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/ui/screens/home/resume_rows.dart';
import 'package:flutter_test/flutter_test.dart';

Track track(int id) => Track(saved: false, coverSource: 0, 
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
  kind: 0,
  addedAt: 1,
  playCount: 0,
);

LibraryEntry entry(String id, int played) => LibraryEntry(
  kind: LibraryKind.album,
  id: id,
  title: id,
  count: 1,
  lastPlayedAt: played,
);

void main() {
  test('order is releases, queue, resumable, recent entries; max 4', () {
    final rows = buildResumeRows(
      current: track(1),
      queue: [track(0), track(1), track(2)],
      resumable: [track(5), track(6)],
      entries: [entry('a', 3), entry('b', 2), entry('c', 1)],
      hasNewReleases: true,
    );
    expect(rows.map((r) => r.runtimeType), [
      ReleasesResume,
      QueueResume,
      TrackResume,
      TrackResume,
    ]);
    final q = rows[1] as QueueResume;
    expect((q.index, q.length), (1, 3));
  });

  test('the current track is not repeated as a resumable row', () {
    final rows = buildResumeRows(
      current: track(1),
      queue: [track(1), track(2)],
      resumable: [track(1), track(7)],
    );
    expect(rows.whereType<TrackResume>().map((r) => r.track.id), [7]);
  });

  test('nothing played: no rows', () {
    expect(
      buildResumeRows(
        queue: const [],
        resumable: const [],
        entries: const [],
        hasNewReleases: false,
      ),
      isEmpty,
    );
  });
}

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/services/online/library_overlap.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

Track _track(String title, {int? durationMs}) => Track(coverSource: 0, 
      id: 1,
      path: '/m/$title.mp3',
      title: title,
      albumKey: 'k',
      durationMs: durationMs ?? 0,
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

YtResult _song(String title, {int? seconds}) => YtResult(
    id: 'x',
    title: title,
    channel: 'c',
    duration: seconds == null ? null : Duration(seconds: seconds));

ArtistSummary _artist(String? name, int tracks) =>
    ArtistSummary(key: (name ?? '').toLowerCase(), name: name, trackCount: tracks, albumCount: 1);

void main() {
  group('localArtistFor', () {
    test('case, accents and «feat.» do not matter', () {
      final pink = _artist('PINK FLOYD', 12);
      expect(localArtistFor('Pink Floyd', [_artist('Queen', 5), pink]), pink);
      final bjork = _artist('Björk feat. Thom Yorke', 3);
      expect(localArtistFor('Bjork', [bjork]), bjork);
    });

    test('with several spellings the one with most songs wins; none when absent', () {
      final small = _artist('Pink Floyd', 2);
      final big = _artist('PINK FLOYD', 40);
      expect(localArtistFor('Pink Floyd', [small, big]), big);
      expect(localArtistFor('Genesis', [small, big]), isNull);
      expect(localArtistFor('', [_artist(null, 4)]), isNull);
    });
  });

  group('LibraryOverlap', () {
    final mine = [_track('Time', durationMs: 413000), _track('Money (2011 Remaster)', durationMs: 382000)];

    test('same title is a song you have, case ignored', () {
      expect(ownedIn(mine, _song('Time', seconds: 416)), isTrue);
      expect(ownedIn(mine, _song('time', seconds: 410)), isTrue);
    });

    test('a different length is still the song you have (D-389)', () {
      expect(ownedIn(mine, _song('Time', seconds: 300)), isTrue);
    });

    test('another title is not owned; remaster tags do not count', () {
      expect(ownedIn(mine, _song('Us and Them', seconds: 413)), isFalse);
      expect(ownedIn(mine, _song('Money', seconds: 382)), isTrue);
    });

    test('an unknown length (top songs have none) matches on the title alone', () {
      expect(ownedIn(mine, _song('Time')), isTrue);
      expect(ownedIn([_track('Time')], _song('Time', seconds: 413)), isTrue);
    });
  });
}

import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/track_matcher.dart' show LibraryIndex;
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_intent.dart' show SearchIntent;
import 'package:codecore/services/online/query_match.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'smart_cases.dart';

YtResult song(String id, String title, {int? secs, String artist = 'Lucio Corsi'}) => YtResult(
    id: id,
    title: title,
    channel: artist,
    duration: secs == null ? null : Duration(seconds: secs),
    artists: [artist]);

YtResult video(String id, String title,
        {int? secs, String channel = 'Lucio Corsi'}) =>
    YtResult(
        id: id,
        title: title,
        channel: channel,
        duration: secs == null ? null : Duration(seconds: secs));

ScoredResult s(YtResult r, double c, MediaKind k, int pos) => ScoredResult(r, c, k, pos);
ScoredResult ytm(YtResult r, [double c = 0.9, int pos = 0]) => s(r, c, MediaKind.ytmSong, pos);
ScoredResult yt(YtResult r, [double c = 0.9, int pos = 0]) => s(r, c, MediaKind.ytVideo, pos);

void main() {
  test('the same video id in both sources is one row with two sources', () {
    final c = smartCase('lucio corsi sigarette');
    final rows = mergeResults(c.scored());
    final row = rows.singleWhere((r) => r.ids.contains('InRdKLk1BTU'));
    expect(row.sources, {MediaKind.ytmSong, MediaKind.ytVideo});
    expect(row.primary.artists, ['Lucio Corsi']);
    expect(row.hasVideo, isFalse);
    expect(rows.expand((r) => r.ids).toSet().length, rows.expand((r) => r.ids).length,
        reason: 'no result in two rows');
  });

  test('a video of the song merges into the catalog song, which is shown', () {
    final rows = mergeResults([
      yt(video('v1', 'Lucio Corsi - Sigarette (Official Video)', secs: 183), 0.95),
      ytm(song('s1', 'Sigarette', secs: 180), 0.9),
    ]);
    expect(rows, hasLength(1));
    expect(rows.single.primary.id, 's1');
    expect(rows.single.alternatives.map((r) => r.id), ['v1']);
    expect(rows.single.hasVideo, isTrue);
    expect(rows.single.confidence, 0.95);
  });

  test('the same song live (other length, «live» in the title) is another row', () {
    final rows = mergeResults([
      ytm(song('s1', 'Sigarette', secs: 180)),
      yt(video('v2', 'Lucio Corsi - Sigarette (Live)', secs: 240), 0.5),
    ]);
    expect(rows, hasLength(2));
  });

  test('without a length on one side, title and artist alone merge', () {
    final rows = mergeResults([
      ytm(song('s1', 'Sigarette', secs: 180)),
      yt(video('v1', 'Lucio Corsi - Sigarette', secs: null)),
    ]);
    expect(rows, hasLength(1));
    // …but another title does not.
    expect(
        mergeResults([
          ytm(song('s1', 'Sigarette', secs: 180)),
          yt(video('v3', 'Lucio Corsi - Altro', secs: null)),
        ]),
        hasLength(2));
  });

  test('two entries of the same source stay two rows', () {
    final rows = mergeResults([
      ytm(song('s1', 'Blowin in the Wind', secs: 166, artist: 'Bob Dylan')),
      ytm(song('s2', 'Blowin in the Wind', secs: 167, artist: 'Bob Dylan'), 0.9, 1),
    ]);
    expect(rows, hasLength(2));
  });

  test('a video of any channel named «Artist - Title» merges with the song', () {
    final rows = mergeResults([
      yt(video('a', 'Lucio Corsi - Sigarette', secs: 180, channel: 'Someone'), 0.9),
      ytm(song('s1', 'Sigarette', secs: 181), 0.5),
    ]);
    expect(rows, hasLength(1));
    expect(rows.single.primary.id, 's1');
  });

  test('rows are ordered by confidence, then source, then position, and ties keep the order', () {
    final rows = mergeResults([
      yt(video('v1', 'Alpha one', secs: 100, channel: 'A'), 0.8, 0),
      ytm(song('s1', 'Beta two', secs: 100, artist: 'B'), 0.8, 3),
      yt(video('v2', 'Gamma three', secs: 100, channel: 'C'), 0.8, 1),
      ytm(song('s2', 'Delta four', secs: 100, artist: 'D'), 0.95, 5),
    ]);
    expect(rows.map((r) => r.primary.id), ['s2', 's1', 'v1', 'v2']);
  });

  test('the split takes the rows over the threshold as best, at most the limit', () {
    final rows = mergeResults([
      for (var i = 0; i < 20; i++)
        ytm(song('s$i', 'Title $i', secs: 100 + 20 * i, artist: 'Artist $i'),
            i < 18 ? 0.9 : 0.3, i),
    ]);
    final split = splitBest(rows, kBestThreshold);
    expect(split.best, hasLength(15));
    expect(split.others, hasLength(5));
    expect(split.noneSure, isFalse);
    expect(split.best.first.primary.id, 's0');
    expect(splitBest(rows, kBestThreshold, maxBest: 3).best, hasLength(3));
  });

  test('when no row is sure the first five are shown and flagged', () {
    final rows = mergeResults([
      for (var i = 0; i < 8; i++)
        ytm(song('s$i', 'Title $i', secs: 100 + 20 * i, artist: 'Artist $i'), 0.3, i),
    ]);
    final split = splitBest(rows, kBestThreshold);
    expect(split.noneSure, isTrue);
    expect(split.best, hasLength(5));
    expect(split.others, hasLength(3));
    expect(splitBest(const [], kBestThreshold).noneSure, isFalse);
  });

  group('library songs (D-389, D-399, D-400)', () {
    final library = LibraryIndex(const [
      LibraryEntryLite(id: 1, title: 'Born On The Bayou', artist: 'Creedence Clearwater Revival', durationMs: 315222),
    ]);
    SmartResult row(YtResult r, [MediaKind k = MediaKind.ytmSong]) => mergeResults([s(r, 0.9, k, 0)]).single;

    test('same title and artist is owned whatever the length, and leaves the rows', () {
      final owned = row(song('a', 'Born on the Bayou', secs: 231, artist: 'Creedence Clearwater Revival'));
      final other = row(song('b', 'Proud Mary', secs: 187, artist: 'Creedence Clearwater Revival'));
      final r = withoutOwned([owned, other], library);
      expect(r.kept, [other]);
      expect(r.hiddenRows, [owned]);
    });

    test('another recording or another artist stays', () {
      final live = row(song('a', 'Born On The Bayou (Live)', artist: 'Creedence Clearwater Revival'));
      final cover = row(song('b', 'Born On The Bayou', artist: 'Dr. John'));
      expect(withoutOwned([live, cover], library).hiddenRows, isEmpty);
    });

    test('an upload «Artist - Title» from any channel is owned too', () {
      final up = row(video('v', 'Creedence Clearwater Revival - Born On The Bayou', channel: 'Some Channel'),
          MediaKind.ytVideo);
      expect(ownedByLibrary(up, library), isTrue);
    });

    test('the video already downloaded is owned: its file is the library track, else it stands alone', () {
      final dl = row(song('dl', 'Some Other Title', artist: 'Someone Else'));
      final file = LibraryEntryLite(id: 7, title: 'Whatever', artist: 'X', durationMs: 1, path: '/m/dl.m4a');
      final withFile = LibraryIndex([file]);
      String? path(YtResult r) => r.id == 'dl' ? '/m/dl.m4a' : null;
      expect(ownedMatch(dl, withFile), isNull);
      expect(ownedMatch(dl, withFile, downloadPath: path)?.track, file);
      // The library has not read the file yet: still owned, no track to show.
      final hit = ownedMatch(dl, LibraryIndex(const []), downloadPath: path);
      expect(hit, isNotNull);
      expect(hit!.track, isNull);
      final r = withoutOwned([dl], LibraryIndex(const []), downloadPath: path);
      expect(r.hiddenRows, [dl]);
      expect(r.matches, isEmpty);
    });

    test('an empty library hides nothing', () {
      final r = row(song('a', 'Born On The Bayou', artist: 'Creedence Clearwater Revival'));
      expect(withoutOwned([r], LibraryIndex(const [])).kept, [r]);
    });

    test('only a song search looks at the library', () {
      expect({for (final i in SearchIntent.values) if (libraryAppliesTo(i)) i},
          {SearchIntent.song, SearchIntent.songs, SearchIntent.artistAndSongs});
    });
  });
}

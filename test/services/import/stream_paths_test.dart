import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/csv_profiles.dart';
import 'package:codecore/services/import/playlist_paths.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('streamPathOfWatchUrl takes only a YouTube watch page with a well-formed id', () {
    const id = 'abcdefghi12';
    for (final ok in [
      'https://music.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&list=x',
      '  https://www.youtube.com/watch?v=$id  ',
    ]) {
      expect(streamPathOfWatchUrl(ok), 'stream:youtube:$id', reason: ok);
    }
    expect(streamPathOfWatchUrl('https://youtube.com/watch?v=$id&v=zzzzzzzzzzz'), 'stream:youtube:$id', reason: 'first v wins');
    for (final bad in [
      'https://notyoutube.com/watch?v=$id',
      'https://youtube.com.evil.com/watch?v=$id',
      'https://evil.com/watch?v=$id',
      'https://youtube.com/embed?v=$id',
      'https://youtube.com/watch',
      'https://youtube.com/watch?v=',
      'https://youtube.com/watch?v=abc',
      'https://youtube.com/watch?v=../../x1234',
      'https://youtube.com/watch?v=${id}a',
      'https://youtube.com/watch?v=$id%26x',
      'https://youtu.be/$id',
      '',
    ]) {
      expect(streamPathOfWatchUrl(bad), isNull, reason: bad);
    }
  });

  test('pathKey keeps the case of a stream: path, lowers any other', () {
    expect(pathKey('stream:youtube:AbCdEfGhIjK'), 'stream:youtube:AbCdEfGhIjK');
    expect(pathKey(r'C:\Music\X.MP3'), 'c:/music/x.mp3');
  });

  test('findByPath tells two YouTube ids apart by case', () {
    final idx = LibraryIndex([
      const LibraryEntryLite(id: 1, title: 'a', artist: null, durationMs: 0, path: 'stream:youtube:AAAAAAAAAAa'),
      const LibraryEntryLite(id: 2, title: 'b', artist: null, durationMs: 0, path: 'stream:youtube:aaaaaaaaaaA'),
    ]);
    expect(idx.findByPath('stream:youtube:aaaaaaaaaaA')?.id, 2);
    expect(idx.findByPath('stream:youtube:AAAAAAAAAAa')?.id, 1);
    expect(idx.findByPath('stream:youtube:AAAAAAAAAAA'), isNull);
  });

  test('a CSV with a URI column that is a YouTube address gets the stream location', () {
    final p = readCsvPlaylist('l.csv', 'Track URI,Track Name,Artist Name(s)\n'
        'https://music.youtube.com/watch?v=abcdefghi12,Song,X\n'
        'spotify:track:1,Other,Y\n');
    expect(p.rows.map((r) => r.location), ['stream:youtube:abcdefghi12', isNull]);
  });
}

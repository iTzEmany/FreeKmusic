import 'dart:io';
import 'dart:typed_data';

import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/m3u_reader.dart';
import 'package:codecore/services/import/playlist_paths.dart';
import 'package:codecore/services/import/playlist_reader.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/import/xspf_reader.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String n) => File('test/fixtures/$n').readAsStringSync();

LibraryEntryLite entry(int id, String path, {String title = 't', String? artist}) =>
    LibraryEntryLite(id: id, title: title, artist: artist, durationMs: 0, path: path);

void main() {
  test('a YouTube Music page address becomes the streamed row path (export -> import)', () {
    final p = readM3u('a.m3u8',
        '#EXTINF:100,Pink Floyd - Hey You\nhttps://music.youtube.com/watch?v=abcdefghi12&list=x\n#EXTINF:1,A - B\nhttps://example.com/watch?v=zzz\n');
    expect(p.rows[0].location, 'stream:youtube:abcdefghi12');
    expect(p.rows[1].location, isNull);
    final idx = LibraryIndex([entry(7, 'stream:youtube:abcdefghi12', title: 'Hey You', artist: 'Pink Floyd')]);
    expect(idx.find(p.rows[0])?.id, 7);
  });

  group('M3U (synthetic VLC file)', () {
    final p = readM3u('Sera_in_casa.m3u8', fixture('synthetic_vlc.m3u8'));

    test('titles, artists, lengths and locations', () {
      expect(p.kind, 'm3u');
      expect(p.name, 'Sera in casa', reason: 'no #PLAYLIST: file name is used');
      expect(p.rows.map((r) => r.title),
          ['Imagine', 'Wish You Were Here', 'Radio Capital', 'Sigarette', 'Senza titolo']);
      expect(p.rows[0].artists, ['John Lennon']);
      expect(p.rows[0].durationMs, 187000);
      expect(p.rows[0].location, '/home/user/Music/Beatles/John Lennon/Imagine.mp3');
    });

    test('a web stream keeps only its label', () {
      final radio = p.rows[2];
      expect(radio.location, isNull);
      expect(radio.durationMs, isNull, reason: 'length -1');
    });

    test('a relative path is kept as written', () {
      expect(p.rows[3].location, '../Lucio Corsi/Volevo essere un duro/02 Sigarette.mp3');
    });

    test('an entry without #EXTINF is named after its file', () {
      expect(p.rows[4].artists, isEmpty);
      expect(p.rows[4].location, '/home/user/Music/untagged/Senza titolo.ogg');
    });
  });

  group('M3U (synthetic Poweramp file, Latin-1, Windows path)', () {
    final bytes = Uint8List.fromList(File('test/fixtures/synthetic_poweramp.m3u').readAsBytesSync());

    test('Latin-1 is used when the bytes are not UTF-8', () {
      final text = decodePlaylistBytes('Sera.m3u', bytes);
      final p = readPlaylistFile('Sera.m3u', text);
      expect(p.name, 'Sera');
      expect(p.rows.single.title, 'Halo');
      expect(p.rows.single.artists, ['Beyoncé']);
      expect(p.rows.single.location, 'C:/Music/Beyoncé/Halo.mp3');
    });
  });

  test('M3U: lines that cannot be named are counted, never fatal', () {
    final p = readM3u('x.m3u', '#EXTM3U\nhttp://a/b\n#EXTINF:100,A - B\n/x/y.mp3\n');
    expect(p.rows.single.title, 'B');
    expect(p.skipped, 1);
  });

  group('XSPF (synthetic VLC file)', () {
    final p = readXspf('lista.xspf', fixture('synthetic_vlc.xspf'));

    test('name with entities, kind and track count', () {
      expect(p.kind, 'xspf');
      expect(p.name, 'Playlist & Co');
      expect(p.rows, hasLength(3));
      expect(p.skipped, 1, reason: 'the http entry has no title');
    });

    test('location is decoded; duration is in milliseconds', () {
      final first = p.rows.first;
      expect(first.location, '/home/user/Music/Pink Floyd/Wish You Were Here.mp3');
      expect(first.durationMs, 334000);
      expect(first.album, 'Wish You Were Here');
      expect(first.artists, ['Pink Floyd']);
    });

    test('Windows file URL, CDATA and &amp; in the creator', () {
      final second = p.rows[1];
      expect(second.location, 'C:/Music/Simon & Garfunkel/The Boxer.mp3');
      expect(second.title, 'The Boxer & Co');
      expect(second.artists, ['Simon & Garfunkel']);
      expect(second.durationMs, isNull, reason: 'duration 0');
    });

    test('numeric entities and a broken %-escape do not fail', () {
      final third = p.rows[2];
      expect(third.title, "It's été");
      expect(third.location, contains('Bad%ZZ'));
    });

    test('a file with no track list is not XSPF', () {
      expect(() => readXspf('x.xspf', '<playlist></playlist>'), throwsFormatException);
    });
  });

  test('the registry routes each extension to its reader', () {
    expect(readPlaylistFile('a.m3u8', '#EXTM3U\n#EXTINF:1,X - Y\n/a.mp3\n').kind, 'm3u');
    expect(readPlaylistFile('a.M3U', '#EXTM3U\n#EXTINF:1,X - Y\n/a.mp3\n').kind, 'm3u');
    expect(readPlaylistFile('a.xspf', fixture('synthetic_vlc.xspf')).kind, 'xspf');
    expect(supportedPlaylistExtensions, containsAll(['csv', 'm3u', 'm3u8', 'xspf']));
  });

  group('path helpers', () {
    test('local paths from file URLs and plain paths', () {
      expect(localPathFromLocation('file:///home/a%20b/c.mp3'), '/home/a b/c.mp3');
      expect(localPathFromLocation('file:///C:/Music/x.mp3'), 'C:/Music/x.mp3');
      expect(localPathFromLocation(r'C:\Music\x.mp3'), 'C:/Music/x.mp3');
      expect(localPathFromLocation('http://a/b.mp3'), isNull);
      expect(localPathFromLocation('smb://nas/x.mp3'), isNull);
      expect(localPathFromLocation('  '), isNull);
    });

    test('absolute detection and label splitting', () {
      expect(isAbsoluteLocalPath('/a'), isTrue);
      expect(isAbsoluteLocalPath('C:/a'), isTrue);
      expect(isAbsoluteLocalPath('a/b'), isFalse);
      expect(splitLabel('A - B - C').artist, 'A');
      expect(splitLabel('A - B - C').title, 'B - C');
      expect(splitLabel('Only title').artist, isNull);
    });
  });

  group('LibraryIndex.findByPath', () {
    final lib = LibraryIndex([
      entry(1, '/home/me/Music/Pink Floyd/Wish You Were Here.mp3'),
      entry(2, '/home/me/Music/Lucio Corsi/Volevo essere un duro/02 Sigarette.mp3'),
      entry(3, '/home/me/Music/A/01.mp3'),
      entry(4, '/home/me/Music/B/01.mp3'),
      entry(5, '/home/me/Music/List/solo.mp3'),
    ]);

    test('an absolute path matches exactly, ignoring case', () {
      expect(lib.findByPath('/home/me/music/pink floyd/wish you were here.mp3')!.id, 1);
    });

    test('the same file on another device or root matches by its folders', () {
      expect(lib.findByPath('/storage/emulated/0/Music/Pink Floyd/Wish You Were Here.mp3')!.id, 1);
      expect(lib.findByPath(r'C:\Music\Pink Floyd\Wish You Were Here.mp3')!.id, 1);
    });

    test('a file URL works too', () {
      expect(lib.findByPath('file:///x/Pink%20Floyd/Wish%20You%20Were%20Here.mp3')!.id, 1);
    });

    test('a relative path is resolved against the playlist folder', () {
      expect(
          lib.findByPath('../Lucio Corsi/Volevo essere un duro/02 Sigarette.mp3',
              baseDir: '/home/me/Music/List')!.id,
          2);
      expect(lib.findByPath('solo.mp3', baseDir: '/home/me/Music/List')!.id, 5);
    });

    test('a relative path with no base still matches by its trailing folders', () {
      expect(lib.findByPath('Lucio Corsi/Volevo essere un duro/02 Sigarette.mp3')!.id, 2);
      expect(lib.findByPath('../Lucio Corsi/Volevo essere un duro/02 Sigarette.mp3')!.id, 2);
    });

    test('ambiguous names give nothing rather than a wrong track', () {
      expect(lib.findByPath('01.mp3'), isNull);
      expect(lib.findByPath('A/01.mp3')!.id, 3);
    });

    test('unknown files and web addresses give nothing', () {
      expect(lib.findByPath('/home/me/Music/Nope/Nothing.mp3'), isNull);
      expect(lib.findByPath('http://a/b.mp3'), isNull);
    });

    test('find() tries the location first, then title and artist', () {
      final both = LibraryIndex([
        entry(1, '/m/a.mp3', title: 'Other'),
        entry(2, '/m/b.mp3', title: 'Imagine', artist: 'John Lennon'),
      ]);
      const byPath = ImportRow(
          index: 0, title: 'Whatever', artists: [], location: '/m/a.mp3');
      expect(both.find(byPath)!.id, 1);
      const byMeta = ImportRow(
          index: 0,
          title: 'Imagine',
          artists: ['John Lennon'],
          location: '/elsewhere/missing.mp3');
      expect(both.find(byMeta)!.id, 2);
    });
  });

  test('5,000 local entries are read and looked up in well under 2 seconds', () {
    final b = StringBuffer('#EXTM3U\n');
    final entries = <LibraryEntryLite>[];
    for (var i = 0; i < 5000; i++) {
      b.write('#EXTINF:200,Artist $i - Song $i\n/home/me/Music/Artist $i/Song $i.mp3\n');
      entries.add(entry(i, '/home/me/Music/Artist $i/Song $i.mp3'));
    }
    final clock = Stopwatch()..start();
    final p = readM3u('big.m3u8', b.toString());
    final lib = LibraryIndex(entries);
    final found = p.rows.where((r) => lib.find(r) != null).length;
    expect(found, 5000);
    expect(clock.elapsedMilliseconds, lessThan(2000));
  });
}

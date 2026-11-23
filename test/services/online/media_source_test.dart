import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/yt_dlp_process_service.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  group('parseYtDlpJson with SoundCloud', () {
    test('the real flat search: source, page, uploader as channel; null entries skipped', () {
      final res = parseYtDlpJson(fixture('scsearch.json'));
      // Five entries in the fixture, one of them null (a DRM track).
      expect(res, hasLength(4));
      final r = res.firstWhere((x) => x.id == '2158904142');
      expect(r.source, MediaSource.soundcloud);
      expect(r.channel, 'HOUZ');
      expect(r.webpageUrl, 'https://soundcloud.com/houzmusicblog/daft-punk-one-more-time-valmer-edit-hzrx');
      expect(r.downloadUrl, r.webpageUrl, reason: 'the page, not the api.soundcloud.com address');
      expect(r.duration, const Duration(seconds: 314));
      expect(r.indexKey, 'soundcloud:2158904142');
    });

    test('an entry without a page cannot be downloaded and is left out', () {
      final raw = jsonEncode({
        'entries': [
          {'id': '1', 'title': 'No page', 'ie_key': 'Soundcloud', 'uploader': 'x'},
          {'id': '2', 'title': 'Has page', 'ie_key': 'Soundcloud', 'uploader': 'x', 'webpage_url': 'https://soundcloud.com/x/y'},
        ],
      });
      expect(parseYtDlpJson(raw).map((r) => r.id), ['2']);
    });

    test('full metadata says it with extractor_key', () {
      final raw = jsonEncode({
        'id': '9',
        'title': 'T',
        'uploader': 'U',
        'extractor_key': 'Soundcloud',
        'webpage_url': 'https://soundcloud.com/u/t',
      });
      expect(parseYtDlpJson(raw).single.source, MediaSource.soundcloud);
    });
  });

  group('parseYtDlpJson with YouTube is as before', () {
    test('a YouTube entry keeps the id as its address and has no page', () {
      final res = parseYtDlpJson(fixture('yt_playlist_flat.json'));
      expect(res, hasLength(6));
      final r = res.first;
      expect(r.source, MediaSource.youtube);
      expect(r.webpageUrl, isNull);
      expect(r.downloadUrl, 'https://www.youtube.com/watch?v=${r.id}');
      expect(r.indexKey, 'youtube:${r.id}');
    });

    test('a full-metadata YouTube result is still addressed by its id (not music.youtube.com)', () {
      final raw = jsonEncode({
        'entries': [
          {
            'id': 'abc',
            'title': 'Song',
            'channel': 'Band',
            'extractor_key': 'Youtube',
            'webpage_url': 'https://music.youtube.com/watch?v=abc',
          },
        ],
      });
      final r = parseYtDlpJson(raw).single;
      expect(r.downloadUrl, 'https://www.youtube.com/watch?v=abc');
    });
  });

  group('DownloadIndex', () {
    late Directory dir;
    late File file;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('dlidx');
      file = File(p.join(dir.path, 'downloads.json'));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    File music(String name) => File(p.join(dir.path, name))..writeAsBytesSync([1]);

    test('the old format (bare YouTube ids) is read as youtube:', () async {
      final f = music('old.mp3');
      file.writeAsStringSync(jsonEncode({'abc': f.path}));
      final idx = DownloadIndex(file);
      await idx.load();
      expect(idx.contains('abc'), isTrue);
      expect(idx.pathFor('abc'), f.path);
      expect(idx.contains('abc', source: MediaSource.soundcloud), isFalse, reason: 'a bare key is never SoundCloud');
    });

    test('new entries are written with the source prefix and read back', () async {
      final yt = music('yt.mp3');
      final sc = music('sc.m4a');
      final idx = DownloadIndex(file);
      await idx.add('abc', yt.path);
      await idx.add('123', sc.path, source: MediaSource.soundcloud);

      final saved = jsonDecode(file.readAsStringSync()) as Map;
      expect(saved.keys, unorderedEquals(['youtube:abc', 'soundcloud:123']));

      final again = DownloadIndex(file);
      await again.load();
      expect(again.pathFor('abc'), yt.path);
      expect(again.pathFor('123', source: MediaSource.soundcloud), sc.path);
      expect(again.pathFor('123'), isNull, reason: 'the same id on another source is another track');
    });

    test('a file that is gone does not count', () async {
      final f = music('gone.mp3');
      final idx = DownloadIndex(file);
      await idx.add('abc', f.path);
      f.deleteSync();
      // contains() reads memory only (no sync I/O on the UI thread); the disk check is async.
      expect(await idx.existingPathFor('abc'), isNull);
      expect(await idx.containsOnDisk('abc'), isFalse);
    });
  });
}

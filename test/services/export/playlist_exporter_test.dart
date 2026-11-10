import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/services/export/playlist_exporter.dart';
import 'package:codecore/services/import/csv_parser.dart';
import 'package:codecore/services/import/csv_profiles.dart';
import 'package:flutter_test/flutter_test.dart';

Track t(int id, String path, String title, String? artist, int ms,
        {String? album, int? folderId}) =>
    Track(coverSource: 0, 
      id: id,
      path: path,
      folderId: folderId,
      title: title,
      artist: artist,
      album: album,
      albumKey: 'k',
      durationMs: ms,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false, kind: 0,
      addedAt: 1,
      playCount: 0,
    );

void main() {
  renderTests();
  final tracks = [
    t(1, '/music/a/one.mp3', 'One', 'Band', 180400, album: 'Alb'),
    t(2, '/music/b/two.mp3', 'Two, "the" sequel', null, 0),
  ];

  group('writeCsv', () {
    test('quotes only when needed and round trips', () {
      final rows = [
        ['a', 'b,c', 'say "hi"', 'two\nlines', ''],
        ['x', 'y', 'z', '', ''],
      ];
      final text = writeCsv(rows);
      expect(text, startsWith('a,"b,c","say ""hi""","two\nlines",\r\n'));
      expect(parseCsv(text), rows);
    });
  });

  group('M3U8', () {
    test('absolute paths', () {
      final m = toM3u8('Mix', tracks);
      expect(m.split('\n'), [
        '#EXTM3U',
        '#PLAYLIST:Mix',
        '#EXTINF:180,Band - One',
        '/music/a/one.mp3',
        '#EXTINF:-1,Two, "the" sequel',
        '/music/b/two.mp3',
        '',
      ]);
    });

    test('a shadow row (kind 2) has no file: left out of both renderings', () {
      final all = [...tracks, t(3, 'stream:youtube:v1', 'Streamed', 'Band', 1000).copyWith(kind: 2)];
      final abs = toM3u8('Mix', all);
      expect(abs, isNot(contains('Streamed')));
      expect(abs, isNot(contains('stream:')));
      final rel = renderPlaylist(ExportFormat.m3u8, name: 'Mix', createdAt: 1, tracks: all, relativePaths: true);
      expect(rel, isNot(contains('stream:')));
      expect(rel, contains('one.mp3'));
    });

    test('paths relative to the playlist folder', () {
      final m = toM3u8('Mix', tracks, relativeTo: '/music/lists');
      expect(m, contains('\n../a/one.mp3\n'));
      expect(m, contains('\n../b/two.mp3\n'));
    });
  });

  test('Exportify CSV is read back by the importer, row by row', () {
    final csv = toExportifyCsv(tracks, {1: 'GBAAA0000001'});
    final back = readCsvPlaylist('Mix.csv', csv);
    expect(back.rows, hasLength(2));
    expect(back.rows[0].title, 'One');
    expect(back.rows[0].artists, ['Band']);
    expect(back.rows[0].album, 'Alb');
    expect(back.rows[0].durationMs, 180400);
    expect(back.rows[0].isrc, 'GBAAA0000001');
    expect(back.rows[1].title, 'Two, "the" sequel');
    expect(back.rows[1].durationMs, isNull);
    expect(back.rows[1].isrc, isNull);
  });
}

void renderTests() {
  final tracks = [
    t(1, '/music/a/x/one.mp3', 'One', 'Band', 1000),
    t(2, '/music/a/y/two.mp3', 'Two', 'Band', 2000),
  ];

  group('renderPlaylist', () {
    test('common directory and relative M3U8', () {
      expect(commonDirectory(tracks), p.join('/music', 'a'));
      final m = renderPlaylist(ExportFormat.m3u8,
          name: 'Mix', createdAt: 1, tracks: tracks, relativePaths: true);
      expect(m, contains('\nx/one.mp3\n'));
      expect(m, contains('\ny/two.mp3\n'));
      expect(commonDirectory(const []), '');
    });

    test('JSON keeps the folder and relative path of each track', () {
      final j = renderPlaylist(ExportFormat.json,
          name: 'Mix',
          createdAt: 1,
          tracks: [t(1, '/music/a/x/one.mp3', 'One', 'Band', 1000, folderId: 1)],
          folders: {1: '/music'});
      final d = UserData.fromJson({
        ...jsonDecode(j) as Map<String, dynamic>,
        'createdAt': 0,
      });
      final ref = d.playlists.single.items.single;
      expect((ref.title, ref.artist, ref.durationMs), ('One', 'Band', 1000));
      expect((ref.folder, ref.relPath), ('/music', 'a/x/one.mp3'));
    });

    test('file names are safe and carry the extension', () {
      expect(exportFileName('AC/DC: Live?', ExportFormat.m3u8), 'ACDC Live.m3u8');
      expect(exportFileName('Mix', ExportFormat.csv), 'Mix.csv');
    });
  });
}

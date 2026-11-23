import 'dart:io';
import 'dart:ui' show Rect;

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/external_share_actions.dart';
import 'package:codecore/services/share/external_share.dart';
import 'package:codecore/services/share/external_share_text.dart';
import 'package:codecore/services/share/share_fragment.dart';
import 'package:flutter_test/flutter_test.dart';

Track _t(int i, {bool stream = true, String? album}) => Track(
  saved: false, coverSource: 0, id: i,
  path: stream ? 'stream:youtube:abcdefgh${(i ~/ 10) % 10}_${i % 10}' : '/m/$i.mp3',
  title: 'Song $i', artist: 'Band', album: album, albumKey: 'k', durationMs: 1000,
  format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false,
  enrichStatus: 0, userEdited: false, missing: false, ignored: false,
  kind: stream ? 2 : 0, addedAt: 1, playCount: 0,
  albumBrowseId: album == null ? null : 'MPREb_x',
);

class FakeShare implements ExternalShare {
  final texts = <String>[];
  final files = <String>[];
  final origins = <Rect?>[];
  String? fileBody;

  @override
  Future<void> shareText(String text, {String? subject, Rect? origin}) async {
    texts.add(text);
    origins.add(origin);
  }

  @override
  Future<void> shareFile(String path, {String? text, Rect? origin}) async {
    files.add(path);
    fileBody = File(path).readAsStringSync();
    origins.add(origin);
  }
}

void main() {
  test('track: label, YouTube Music link and page link with the id in the fragment', () {
    final text = buildShareText(SharedKind.track, 'Song 1', [_t(1)]);
    final lines = text.split('\n');
    expect(lines[0], 'Band - Song 1');
    expect(lines[1], 'https://music.youtube.com/watch?v=abcdefgh0_1');
    expect(lines[2], startsWith('$kSharePageUrl#'));
    final f = decodeShareFragment(lines[2].substring(kSharePageUrl.length + 1));
    expect(f.ids, ['abcdefgh0_1']);
  });

  test('album: numbered list, album link, local rows are text only and not in the fragment', () {
    final text = buildShareText(SharedKind.album, 'Alb', [_t(1, album: 'Alb'), _t(2, stream: false)], subtitle: 'Band');
    expect(text, contains('Alb - Band\n1. Band - Song 1\n2. Band - Song 2'));
    expect(text, contains('https://music.youtube.com/browse/MPREb_x'));
    final frag = text.split('#').last;
    expect(decodeShareFragment(frag).ids, ['abcdefgh0_1']);
  });

  test('only local tracks: text without any link', () {
    final text = buildShareText(SharedKind.playlist, 'Mix', [_t(1, stream: false)]);
    expect(text, isNot(contains('http')));
  });

  group('limit', () {
    late Directory tmp;
    late FakeShare fake;
    late ExternalShareActions actions;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('share_test');
      fake = FakeShare();
      actions = ExternalShareActions(fake, () async => tmp);
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    for (final (n, asFile) in [(kMaxSharedTracks - 1, false), (kMaxSharedTracks, false), (kMaxSharedTracks + 1, true)]) {
      test('$n tracks -> ${asFile ? 'm3u8 file' : 'link'}', () async {
        await actions.share(SharedKind.playlist, 'Mix', [for (var i = 0; i < n; i++) _t(i)], origin: const Rect.fromLTWH(1, 2, 3, 4));
        expect(fake.texts.length, asFile ? 0 : 1);
        expect(fake.files.length, asFile ? 1 : 0);
        expect(fake.origins.single, const Rect.fromLTWH(1, 2, 3, 4));
      });
    }

    test('file: streamed rows only with their links; an older share file is deleted', () async {
      final old = File('${tmp.path}/share/old.m3u8')..createSync(recursive: true);
      final tracks = [for (var i = 0; i < 51; i++) _t(i), _t(99, stream: false)];
      await actions.share(SharedKind.playlist, 'Mix', tracks);
      expect(old.existsSync(), isFalse);
      expect(fake.files.single, endsWith('Mix.m3u8'));
      expect(fake.fileBody, contains('https://music.youtube.com/watch?v=abcdefgh0_1'));
      expect(fake.fileBody, isNot(contains('/m/99.mp3')));
    });
  });
}

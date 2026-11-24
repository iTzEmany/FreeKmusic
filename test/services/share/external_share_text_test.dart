import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/external_share_actions.dart';
import 'package:codecore/services/share/external_share_text.dart';
import 'package:codecore/services/share/share_fragment.dart';
import 'package:codecore/services/share/share_m3u8.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_share.dart';

Track _t(int i, {bool stream = true, String? album}) => Track(
  saved: false, coverSource: 0, id: i,
  path: stream ? 'stream:youtube:abcdefgh${(i ~/ 10) % 10}_${i % 10}' : '/m/$i.mp3',
  title: 'Song $i', artist: 'Band', album: album, albumKey: 'k', durationMs: 1000,
  format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false,
  enrichStatus: 0, userEdited: false, missing: false, ignored: false,
  kind: stream ? 2 : 0, addedAt: 1, playCount: 0,
  albumBrowseId: album == null ? null : 'MPREb_x',
);

void main() {
  test('a blank title falls back to the fragment one, not an empty line', () {
    final lines = buildShareText(SharedKind.playlist, '  ', [_t(1)]).split('\n');
    expect(lines[0], untitledShare);
  });

  test('isVideoId accepts 11 url-safe chars only', () {
    expect(isVideoId('abcdefgh0_1'), isTrue);
    expect(isVideoId('short'), isFalse);
    expect(isVideoId('abcdefgh0_1x'), isFalse);
  });

  test('track: label, YouTube Music link and page link with the id in the fragment', () {
    final text = buildShareText(SharedKind.track, 'Song 1', [_t(1)]);
    final lines = text.split('\n');
    expect(lines[0], 'Band - Song 1');
    expect(lines[1], 'https://music.youtube.com/watch?v=abcdefgh0_1');
    expect(lines[2], startsWith('$kSharePageUrl#'));
    final f = decodeShareFragment(lines[2].substring(kSharePageUrl.length + 1));
    expect(f.rows, [const SharedRow.id('abcdefgh0_1')]);
  });

  test('album: numbered list, album link; a local row without id is a search row in the fragment', () {
    final text = buildShareText(SharedKind.album, 'Alb', [_t(1, album: 'Alb'), _t(2, stream: false)], subtitle: 'Band');
    expect(text, contains('Alb - Band\n1. Band - Song 1\n2. Band - Song 2'));
    expect(text, contains('https://music.youtube.com/browse/MPREb_x'));
    final frag = text.split('#').last;
    expect(decodeShareFragment(frag).rows, [const SharedRow.id('abcdefgh0_1'), const SharedRow.search('Band', 'Song 2')]);
  });

  test('a local row with the video id kept at download is an id row', () {
    expect(shareRowOf(_t(1, stream: false).copyWith(videoId: const Value('dQw4w9WgXcQ'))), const SharedRow.id('dQw4w9WgXcQ'));
  });

  test('a v= of 12 characters is not an id: the row is a search', () {
    final long = _t(1).copyWith(path: 'stream:youtube:abcdefgh0_1x');
    expect(shareRowOf(long), const SharedRow.search('Band', 'Song 1'));
  });

  test('numbered list: 10 and 11 tracks, the ellipsis only above the limit', () {
    List<Track> n(int c) => [for (var i = 1; i <= c; i++) _t(i)];
    final ten = buildShareText(SharedKind.playlist, 'Mix', n(10)).split('\n');
    expect(ten, contains('10. Band - Song 10'));
    expect(ten, isNot(contains('…')));
    final eleven = buildShareText(SharedKind.playlist, 'Mix', n(11)).split('\n');
    expect(eleven, isNot(contains('11. Band - Song 11')));
    expect(eleven, contains('…'));
  });

  test('album browse link only for an album; empty track list gives no page line', () {
    final pl = buildShareText(SharedKind.playlist, 'Mix', [_t(1, album: 'Alb')]);
    expect(pl, isNot(contains('/browse/')));
    final noBrowse = buildShareText(SharedKind.album, 'Alb', [_t(1)]);
    expect(noBrowse, isNot(contains('/browse/')));
    expect(buildShareText(SharedKind.track, 'x', []), isNot(contains(kSharePageUrl)));
  });

  test('only local tracks: no YouTube Music link, but the page link with search rows', () {
    final text = buildShareText(SharedKind.playlist, 'Mix', [_t(1, stream: false)]);
    expect(text, isNot(contains('music.youtube.com')));
    expect(decodeShareFragment(text.split('#').last).rows, [const SharedRow.search('Band', 'Song 1')]);
  });

  test('shareLinkFitsQr: 666 characters fit, one more does not', () {
    expect(shareLinkFitsQr('x' * 666), isTrue);
    expect(shareLinkFitsQr('x' * 667), isFalse);
  });

  test('exceedsShareLimit: more than 50 tracks even if local; 50 fit; a link that is too long does not', () {
    expect(exceedsShareLimit([for (var i = 0; i < 51; i++) _t(i, stream: false)]), isTrue);
    expect(exceedsShareLimit([for (var i = 0; i < 50; i++) _t(i)]), isFalse);
    final r = Random(3); // random text does not compress, repetitive text does
    String word(int n) => String.fromCharCodes([for (var j = 0; j < n; j++) 97 + r.nextInt(26)]);
    final wordy = [for (var i = 0; i < 50; i++) _t(i, stream: false).copyWith(title: word(80), artist: Value(word(60)))];
    expect(exceedsShareLimit(wordy), isTrue);
  });

  test('a file name from a title with / and .. stays inside the folder', () async {
    final dir = Directory.systemTemp.createTempSync('share_name');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final name in ['a/../../b', '..', '../x/..', '/']) {
      final f = await writeShareM3u8(Directory('${dir.path}/own'), name, [_t(1)]);
      expect(f.parent.path, '${dir.path}/own', reason: name);
      expect(f.path, endsWith('.m3u8'));
    }
  });

  group('limit', () {
    late Directory tmp;
    late FakeShare fake;
    late ExternalShareActions actions;
    setUp(() {
      tmp = Directory.systemTemp.createTempSync('share_test');
      fake = FakeShare();
      actions = ExternalShareActions(fake, () async => tmp, canShareFiles: true);
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
      final old = File('${tmp.path}/freekmusic_share/old.m3u8')..createSync(recursive: true);
      final tracks = [for (var i = 0; i < 51; i++) _t(i), _t(99, stream: false)];
      await actions.share(SharedKind.playlist, 'Mix', tracks);
      expect(old.existsSync(), isFalse);
      expect(fake.files.single, endsWith('Mix.m3u8'));
      expect(fake.fileBody, contains('https://music.youtube.com/watch?v=abcdefgh0_1'));
      expect(fake.fileBody, isNot(contains('/m/99.mp3')));
    });

    test('only the folder of its own is emptied: a sibling of the temp folder is kept', () async {
      final other = File('${tmp.path}/share/other.txt')..createSync(recursive: true);
      await actions.share(SharedKind.playlist, 'Mix', [for (var i = 0; i < 51; i++) _t(i)]);
      expect(other.existsSync(), isTrue);
      expect(fake.files.single, contains('freekmusic_share'));
    });

    test('51 rows, only 30 streamed: still a file (every track counts)', () async {
      await actions.share(SharedKind.playlist, 'Mix', [for (var i = 0; i < 51; i++) _t(i, stream: i < 30)]);
      expect(fake.texts, isEmpty);
      expect(fake.files.length, 1);
    });

    group('clipboard', () {
      final copied = <String>[];
      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
        copied.clear();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
          return null;
        });
      });
      tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      test('the sheet fails: the text is copied and the caller is told', () async {
        fake.error = StateError('no mail client');
        expect(await actions.share(SharedKind.playlist, 'Mix', [_t(1)]), isTrue);
        expect(copied.single, startsWith('Mix'));
      });

      test('the sheet works: nothing is copied', () async {
        expect(await actions.share(SharedKind.playlist, 'Mix', [_t(1)]), isFalse);
        expect(copied, isEmpty);
      });

      test('no file sheet (Linux, Windows): the m3u8 text is copied, no file is written', () async {
        final desktop = ExternalShareActions(fake, () async => tmp, canShareFiles: false);
        expect(await desktop.share(SharedKind.playlist, 'Mix', [for (var i = 0; i < 51; i++) _t(i)]), isTrue);
        expect(copied.single, startsWith('#EXTM3U'));
        expect(fake.files, isEmpty);
        expect(Directory('${tmp.path}/freekmusic_share').existsSync(), isFalse);
      });

      test('a share in progress: the second call does nothing', () async {
        fake.gate = Completer<void>();
        final first = actions.share(SharedKind.playlist, 'Mix', [_t(1)]);
        expect(await actions.share(SharedKind.playlist, 'Mix', [_t(2)]), isFalse);
        fake.gate!.complete();
        await first;
        expect(fake.texts.length, 1);
        await actions.share(SharedKind.playlist, 'Mix', [_t(3)]);
        expect(fake.texts.length, 2);
      });
    });
  });
}

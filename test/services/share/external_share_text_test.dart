import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/external_share_actions.dart';
import 'package:codecore/services/share/external_share.dart';
import 'package:codecore/services/share/external_share_text.dart';
import 'package:codecore/services/share/share_fragment.dart';
import 'package:codecore/services/share/share_m3u8.dart';
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

  test('an id that is not 11 valid characters is left out: text without the page line', () {
    final short = _t(1).copyWith(path: 'stream:youtube:abc');
    final text = buildShareText(SharedKind.track, 'Song 1', [short]);
    expect(text, isNot(contains(kSharePageUrl)));
    expect(sharedIds([short, _t(2)]), ['abcdefgh0_2']);
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

    test('51 rows but fewer than 51 streamed: text, not a file', () async {
      await actions.share(SharedKind.playlist, 'Mix', [for (var i = 0; i < 51; i++) _t(i, stream: i < 30)]);
      expect(fake.texts.length, 1);
      expect(fake.files, isEmpty);
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
        fake.error = const ExternalShareUnavailable('no mail client');
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

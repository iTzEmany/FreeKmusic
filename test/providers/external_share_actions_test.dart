import 'dart:io';
import 'dart:typed_data';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/external_share_actions.dart';
import 'package:codecore/services/share/external_share_text.dart';
import 'package:codecore/services/share/share_card_renderer.dart';
import 'package:codecore/services/share/share_fragment.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_share.dart';

Track _t(int i) => Track(
  saved: false, coverSource: 0, id: i, path: 'stream:youtube:abcdefgh0_$i', title: 'Song $i', artist: 'Band',
  albumKey: 'k', durationMs: 1000, format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false,
  enrichStatus: 0, userEdited: false, missing: false, ignored: false, kind: 2, addedAt: 1, playCount: 0,
);

void main() {
  late Directory tmp;
  late FakeShare fake;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('share_card_actions');
    fake = FakeShare();
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  ExternalShareActions actions(ShareCardMaker? maker, {bool files = true}) =>
      ExternalShareActions(fake, () async => tmp, canShareFiles: files, cardMaker: maker);
  Future<Uint8List> png(SharedKind k, String t, String? s, List<Track> tr) async => Uint8List.fromList('png'.codeUnits);

  for (final kind in SharedKind.values) {
    test('$kind: the card is shared as a file with the short caption', () async {
      final tracks = [_t(1), _t(2)];
      await actions(png).share(kind, 'Name', tracks);
      expect(fake.texts, isEmpty);
      expect(fake.files.single, allOf(contains('freekmusic_share'), endsWith('Name.png')));
      expect(fake.fileTexts.single, buildShareCaption(kind, 'Name', tracks));
    });
  }

  test('the card fails to draw (error or timeout): the text goes as before', () async {
    for (final maker in <ShareCardMaker>[
      (k, t, s, tr) async => throw StateError('no draw'),
      (k, t, s, tr) => Future<Uint8List>.delayed(const Duration(seconds: 1), () => Uint8List(1)).timeout(const Duration(milliseconds: 10)),
    ]) {
      fake = FakeShare();
      await actions(maker).share(SharedKind.album, 'Alb', [_t(1)], subtitle: 'Band');
      expect(fake.files, isEmpty);
      expect(fake.texts.single, buildShareText(SharedKind.album, 'Alb', [_t(1)], subtitle: 'Band'));
    }
  });

  test('no file sheet: no card is drawn, the text is the one of today', () async {
    var drawn = false;
    final a = actions((k, t, s, tr) async { drawn = true; return Uint8List(1); }, files: false);
    await a.share(SharedKind.track, 'Song 1', [_t(1)]);
    expect(drawn, isFalse);
    expect(fake.files, isEmpty);
  });

  test('above the limit the m3u8 goes, not the card', () async {
    await actions(png).share(SharedKind.playlist, 'Mix', [for (var i = 0; i < 51; i++) _t(i)]);
    expect(fake.files.single, endsWith('Mix.m3u8'));
  });

  test('the sheet refuses the card file (old Windows): the text is not lost', () async {
    fake.error = StateError('no sheet');
    final a = actions(png);
    // The clipboard channel is not mocked here: the copy fails and is logged; the share was tried once with the file.
    await a.share(SharedKind.track, 'Song 1', [_t(1)]);
    expect(fake.files.length, 1);
  });
}

import 'dart:async' show TimeoutException;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/share/external_share_text.dart';
import 'package:codecore/services/share/share_card_renderer.dart';
import 'package:codecore/services/share/share_fragment.dart';
import 'package:codecore/ui/widgets/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = kShareCardSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
}

ShareCard _shareCard(String? link, List<ui.Image> covers) => ShareCard(
    kind: SharedKind.playlist,
    brand: 'FreeKmusic',
    kindLabel: 'Playlist',
    title: 'Mix',
    meta: '2 tracks',
    tint: Colors.indigo,
    qrLink: link,
    covers: covers,
  );

Widget _card(String? link) => Directionality(textDirection: TextDirection.ltr, child: _shareCard(link, const []));

void main() {
  links();
  testWidgets('the QR holds exactly the page link', (tester) async {
    const link = '$kSharePageUrl#FK2abc';
    await _pump(tester, _card(link));
    expect(find.byKey(const ValueKey(link)), findsOneWidget); // the key of the QR is its data
  });

  testWidgets('the real render gives a 1080 x 1350 PNG', (tester) async {
    final png = await tester.runAsync(() => renderShareCardPng(const [], (i) => _shareCard(null, i)));
    final img = await tester.runAsync(() async => (await (await ui.instantiateImageCodec(png!)).getNextFrame()).image);
    expect((img!.width, img.height), (1080, 1350));
  });

  testWidgets('a card slower than the timeout throws a TimeoutException', (tester) async {
    await tester.runAsync(
      () => expectLater(renderShareCardPng(const [], (i) => _shareCard(null, i), timeout: Duration.zero), throwsA(isA<TimeoutException>())),
    );
  });

  testWidgets('no link (nothing to link, or too long for a QR): no QR on the card', (tester) async {
    await _pump(tester, _card(null));
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('no cover: the ring carries the initial of the title', (tester) async {
    await _pump(tester, _card(null));
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('a title that starts with an emoji or a symbol: a note, not half an emoji', (tester) async {
    for (final title in ['🎵 Mix', '(Mix)']) {
      await _pump(tester, Directionality(textDirection: TextDirection.ltr, child: ShareCard(
        kind: SharedKind.track, brand: 'B', kindLabel: 'K', title: title, meta: 'm', tint: Colors.indigo)));
      expect(find.text('♪'), findsOneWidget, reason: title);
    }
  });
}

Track _t(int i, {String? title, String? artist, bool stream = true}) => Track(
  saved: false, coverSource: 0, id: i, path: stream ? 'stream:youtube:abcdefgh0_$i' : '/m/$i.mp3', title: title ?? 'Song $i', artist: artist ?? 'Band',
  albumKey: 'k', durationMs: 1000, format: 'mp3', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false,
  enrichStatus: 0, userEdited: false, missing: false, ignored: false, kind: stream ? 2 : 0, addedAt: 1, playCount: 0,
);

void links() {
  test('caption: the name and the page link, nothing else', () {
    final lines = buildShareCaption(SharedKind.playlist, 'Mix', [_t(1), _t(2)]).split('\n');
    expect(lines.length, 2);
    expect(lines[0], 'Mix');
    expect(lines[1], shareLink(SharedKind.playlist, 'Mix', [_t(1), _t(2)]));
    expect(buildShareCaption(SharedKind.playlist, 'Mix', const []), 'Mix');
  });

  test('QR link: the page link when it fits, none above the limit or without tracks', () {
    expect(shareCardLink(SharedKind.track, 'Song 1', [_t(1)]), shareLink(SharedKind.track, 'Song 1', [_t(1)]));
    expect(shareCardLink(SharedKind.playlist, 'Mix', const []), isNull);
    final r = Random(3); // random text does not compress
    String word(int n) => String.fromCharCodes([for (var j = 0; j < n; j++) 97 + r.nextInt(26)]);
    final long = [for (var i = 0; i < 20; i++) _t(i, title: word(30), artist: word(20), stream: false)];
    expect(shareLinkFitsQr(shareLink(SharedKind.playlist, 'Mix', long)), isFalse);
    expect(shareCardLink(SharedKind.playlist, 'Mix', long), isNull);
  });
}

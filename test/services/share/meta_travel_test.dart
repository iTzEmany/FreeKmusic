import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/share/lan_client.dart';
import 'package:codecore/services/share/lan_server.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:codecore/services/share/track_meta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

const _png =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
const _meta = TrackMeta(
  title: 'T',
  artist: 'A',
  album: 'Al',
  year: 1999,
  trackNumber: 3,
  isrc: 'GBAYE0601498',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // the test binding fakes HTTP with 400s
  late Directory tmp;
  late OfferNode senderNode;
  late OfferService sender;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('metatravel');
    sender = OfferService(deviceId: 'a', deviceName: 'S', allowLoopback: true);
    senderNode = OfferNode(sender, allowLoopback: true);
    await senderNode.start();
  });
  tearDown(() async {
    await senderNode.stop();
    tmp.deleteSync(recursive: true);
  });

  ShareEntry entry(
    int id, {
    TrackMeta? meta,
    List<int>? cover,
    String coverExt = 'png',
  }) {
    final f = File(p.join(tmp.path, '$id.mp3'))..writeAsBytesSync([1, 2, 3]);
    String? cp;
    if (cover != null) {
      cp = (File(
        p.join(tmp.path, '$id.$coverExt'),
      )..writeAsBytesSync(cover)).path;
    }
    return ShareEntry(
      id: id,
      path: f.path,
      title: 'S$id',
      sizeBytes: 3,
      durationMs: 1,
      ext: 'mp3',
      coverPath: cp,
      meta: meta,
    );
  }

  Future<OutgoingOffer> accepted(List<ShareEntry> es) async {
    final o = sender.createOutgoing(toId: 'b', toName: 'R', entries: es);
    o.status = OfferStatus.accepted;
    return o;
  }

  test('meta arrives intact in the PIN list', () async {
    final server = LanServer();
    final info = await server.start(
      entries: [entry(1, meta: _meta)],
      host: '127.0.0.1',
      deviceName: 'PC',
    );
    addTearDown(server.stop);
    final list = await LanClient().manifest('127.0.0.1', info.port, info.pin);
    expect(list.single.meta!.toJson(), _meta.toJson());
  });

  test('meta and hasCover arrive intact in an offer', () async {
    final o = await accepted([
      entry(1, meta: _meta, cover: base64Decode(_png)),
    ]);
    final item = OfferItem.tryParse(
      (sender.offerPayload(o, 1)['items'] as List).single,
    )!;
    expect(item.meta!.toJson(), _meta.toJson());
    expect(item.hasCover, true);
  });

  test('entry without meta (old sender) parses as today', () {
    final item = OfferItem.tryParse({
      'id': 1,
      'title': 'x',
      'sizeBytes': 1,
      'ext': 'mp3',
    })!;
    expect(item.meta, isNull);
    expect(item.hasCover, false);
    expect(RemoteTrack.fromJson({'id': 1}).meta, isNull);
  });

  test('meta with bad fields keeps the entry, fields are null', () {
    final item = OfferItem.tryParse({
      'id': 1,
      'title': 'x',
      'sizeBytes': 1,
      'ext': 'mp3',
      'meta': {'title': 5, 'year': 'abc', 'isrc': 'nope', 'artist': 'Ok'},
    })!;
    expect(item.meta!.title, isNull);
    expect(item.meta!.year, isNull);
    expect(item.meta!.isrc, isNull);
    expect(item.meta!.artist, 'Ok');
  });

  test('the old fields of the offer are unchanged by the new ones', () async {
    final o = await accepted([
      entry(1, meta: _meta, cover: base64Decode(_png)),
    ]);
    final json = (sender.offerPayload(o, 1)['items'] as List).single as Map;
    expect(
      {
        for (final k in ['id', 'title', 'artist', 'album', 'sizeBytes', 'ext'])
          k: json[k],
      },
      {
        'id': 1,
        'title': 'S1',
        'artist': null,
        'album': null,
        'sizeBytes': 3,
        'ext': 'mp3',
      },
    );
    final o2 = await accepted([entry(2)]);
    // Without a playlist the offer has exactly the fields of before (D-760).
    expect(sender.offerPayload(o2, 1).keys.toSet(), {'offerId', 'fromId', 'fromName', 'port', 'token', 'items'});
    final plain = (sender.offerPayload(o2, 1)['items'] as List).single as Map;
    expect(plain.keys.toSet(), {
      'id',
      'title',
      'artist',
      'album',
      'sizeBytes',
      'ext',
    });
  });

  group('cover route', () {
    Future<Response> get(OfferService s, String path, String? token) =>
        Future.value(
          s.buildRouter().call(
            Request(
              'GET',
              Uri.parse('http://x$path'),
              headers: {'X-Token': ?token},
            ),
          ),
        );

    test('rejects a caller without the token', () async {
      final o = await accepted([entry(1, cover: base64Decode(_png))]);
      expect(
        (await get(sender, '/${o.offerId}/cover/1', 'wrong')).statusCode,
        401,
      );
      expect(
        (await get(sender, '/${o.offerId}/cover/1', null)).statusCode,
        401,
      );
    });

    test('rejects an n out of range or without cover', () async {
      final o = await accepted([entry(1, cover: base64Decode(_png)), entry(2)]);
      for (final n in ['9', 'x', '2']) {
        expect(
          (await get(sender, '/${o.offerId}/cover/$n', o.token)).statusCode,
          404,
          reason: n,
        );
      }
      expect(
        (await get(sender, '/${o.offerId}/cover/1', o.token)).statusCode,
        200,
      );
    });
  });

  group('downloadOfferCover', () {
    Future<({List<int> bytes, String mime})?> fetch(ShareEntry e) async {
      final o = await accepted([e]);
      return LanClient().downloadOfferCover(
        '127.0.0.1',
        senderNode.port!,
        o.offerId,
        o.token,
        e.id,
      );
    }

    test('returns a valid image', () async {
      final r = await fetch(entry(1, cover: base64Decode(_png)));
      expect(r!.mime, 'image/png');
      expect(r.bytes, base64Decode(_png));
    });

    test('discards a cover over 5 MB', () async {
      expect(
        await fetch(entry(1, cover: List.filled(maxOfferCoverBytes + 1, 0))),
        isNull,
      );
    });

    test('discards bytes that are not an image', () async {
      expect(
        await fetch(
          entry(1, cover: utf8.encode('not an image'), coverExt: 'jpg'),
        ),
        isNull,
      );
    });
  });

  group('downloadCover (PIN)', () {
    Future<({int port, String pin})> serve(List<ShareEntry> es) async {
      final server = LanServer();
      final info = await server.start(
          entries: es, host: '127.0.0.1', deviceName: 'PC');
      addTearDown(server.stop);
      return (port: info.port, pin: info.pin);
    }

    test('returns the image, and null without a cover', () async {
      final s = await serve([entry(1, cover: base64Decode(_png)), entry(2)]);
      final c = LanClient();
      final ok = await c.downloadCover('127.0.0.1', s.port, s.pin, 1);
      expect(ok!.bytes, base64Decode(_png));
      expect(await c.downloadCover('127.0.0.1', s.port, s.pin, 2), isNull);
    });
  });
}

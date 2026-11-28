import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/hidden_playlists.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:codecore/services/share/playlist_parts.dart';
import 'package:codecore/services/share/received_playlist.dart';
import 'package:codecore/services/stream/stream_key.dart' show streamResultOf;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

String ykey(int i) => 'youtube:${i.toString().padLeft(11, 'a')}';

OfferItem item(int id) => OfferItem(id: id, title: 'Song $id', sizeBytes: 1, ext: 'mp3');
StreamOffer stream(String key, {bool shadow = false}) => StreamOffer(key: key, title: 'T $key', shadow: shadow);
OfferRef it(int id) => (item: id, stream: null);
OfferRef st(String key) => (item: null, stream: key);

void main() {
  late AppDatabase db;
  late TrackRepository tracks;
  late PlaylistRepository playlists;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    playlists = PlaylistRepository(db);
  });
  tearDown(() => db.close());

  Future<int> addFile(String path, {String? title}) => db.into(db.tracks).insert(TracksCompanion.insert(
      path: path, title: title ?? path, albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));

  Future<int?> write(OfferPlaylist pl, {List<OfferItem> items = const [], List<StreamOffer> streams = const [], Map<int, String> paths = const {}, int? appendTo}) async =>
      writeReceivedPlaylist(
        playlist: pl,
        items: items,
        streams: streams,
        pathOfItem: paths,
        tracks: tracks,
        playlists: playlists,
        resolver: await PlaylistSyncRepository(db).resolver(),
        appendTo: appendTo,
      );

  Future<List<String>> pathsOf(int id) async => [for (final t in await playlists.watchTracks(id).first) t.path];

  OfferPlaylist plOf(List<OfferRef> order, {String name = 'Mix', String key = 'k', int part = 1, int parts = 1}) =>
      OfferPlaylist(key: key, name: name, part: part, parts: parts, order: order);

  test('playlist in the sender order with files, saved streams and shadow rows; shadow rows stay out of the library', () async {
    await addFile('/r/a.mp3');
    await addFile('/r/b.mp3');
    await tracks.ingestStream(streamResultOf(ykey(1), title: 'T'), at: 1, hasFile: (_) => false);
    final id = await write(
      plOf([it(2), st(ykey(1)), st(ykey(2)), it(1)]),
      items: [item(1), item(2)],
      streams: [stream(ykey(1)), stream(ykey(2), shadow: true)],
      paths: {1: '/r/a.mp3', 2: '/r/b.mp3'},
    );
    expect(await pathsOf(id!), ['/r/b.mp3', 'stream:${ykey(1)}', 'stream:${ykey(2)}', '/r/a.mp3']);
    final shadow = await tracks.streamRow(ykey(2));
    expect((shadow!.kind, shadow.saved), (kStreamKind, false));
    expect((await tracks.streamRow(ykey(1)))!.saved, true);
  });

  test('a taken name becomes «Nome (2)», then «Nome (3)»', () async {
    await addFile('/r/a.mp3');
    final pl = plOf([it(1)]);
    Future<String> go() async {
      final id = await write(pl, items: [item(1)], paths: {1: '/r/a.mp3'});
      return (await db.visiblePlaylists()).firstWhere((p) => p.id == id).name;
    }
    expect(await go(), 'Mix');
    expect(await go(), 'Mix (2)');
    expect(await go(), 'Mix (3)');
    expect((await db.visiblePlaylists()).length, 3);
  });

  test('a file that did not arrive does not block the playlist; a track already here is found', () async {
    await addFile('/r/a.mp3');
    await addFile('/lib/Song 2.mp3', title: 'Song 2');
    final id = await write(
      plOf([it(1), it(2), it(3)]),
      items: [item(1), item(2), item(3)],
      paths: {1: '/r/a.mp3'},
    );
    expect(await pathsOf(id!), ['/r/a.mp3', '/lib/Song 2.mp3']);
    expect(await write(plOf([it(3)]), items: [item(3)]), isNull);
  });

  test('an offer without playlist writes nothing (no playlist object, as today)', () async {
    expect(IncomingOffer(offerId: 'o', fromId: 'f', fromName: 'n', fromHost: 'h', fromPort: 1, token: 't', items: [item(1)]).playlist, isNull);
    expect(await db.visiblePlaylists(), isEmpty);
  });

  group('parts over 500 (D-762)', () {
    IncomingOffer part(int n, int of, {String from = 'dev-a', String host = '10.0.0.2', String? fp, String key = 'big', List<OfferRef>? order, List<StreamOffer>? streams}) =>
        IncomingOffer(
          offerId: 'o$n$from$host$key',
          fromId: from,
          fromName: 'A',
          fromHost: host,
          fromPort: 1,
          callerFingerprint: fp,
          token: 'tok',
          items: const [],
          streams: streams ?? [stream(ykey(n), shadow: true)],
          playlist: plOf(order ?? [st(ykey(n))], key: key, part: n, parts: of),
        );

    late List<String> log;
    late PlaylistParts parts;
    late int? written;
    setUp(() {
      log = [];
      written = null;
      parts = PlaylistParts(
        accept: (o) async {
          o.status = OfferStatus.done;
          log.add('accept ${o.playlist!.part}');
          final pl = o.playlist!;
          written = await write(pl, streams: o.streams, appendTo: parts.playlistFor(o));
          if (written != null) parts.wrote(o, written!);
          parts.firstDone(o, ok: true);
        },
        decline: (o) async {
          o.status = OfferStatus.declined;
          log.add('decline ${o.playlist!.part}');
          parts.firstDone(o, ok: false);
        },
      );
    });
    tearDown(() => parts.dispose());

    test('1200 tracks: 500/500/200 parts become one playlist, in order, one question only', () async {
      final all = [for (var i = 0; i < 1200; i++) ykey(i)];
      final chunks = splitParts(all);
      expect(chunks.map((c) => c.length), [500, 500, 200]);
      final offers = [
        for (var i = 0; i < 3; i++)
          part(i + 1, 3, order: [for (final k in chunks[i]) st(k)], streams: [for (final k in chunks[i]) stream(k, shadow: true)]),
      ];
      expect(parts.handle(offers[0]), false); // asks the user
      expect(parts.handle(offers[1]), true);
      expect(parts.handle(offers[2]), true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(log, isEmpty); // nothing before part 1 is confirmed
      await parts.accept(offers[0]);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(log, ['accept 1', 'accept 2', 'accept 3']);
      final lists = await db.visiblePlaylists();
      expect(lists.length, 1);
      expect(await pathsOf(written!), [for (final k in all) 'stream:$k']);
    });

    test('another sender, another address or another fingerprint with the same key is not accepted by itself', () async {
      parts.handle(part(1, 2));
      expect(parts.handle(part(2, 2, from: 'dev-x')), false);
      expect(parts.handle(part(2, 2, host: '10.0.0.9')), false);
      expect(parts.handle(part(2, 2, fp: 'abc')), false);
      expect(parts.handle(part(2, 2)), true);
    });

    test('first part refused: no playlist and the others are refused', () async {
      final p1 = part(1, 3), p2 = part(2, 3), p3 = part(3, 3);
      parts.handle(p1);
      parts.handle(p2);
      parts.handle(p3);
      p1.status = OfferStatus.declined;
      parts.firstDone(p1, ok: false);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(log, ['decline 2', 'decline 3']);
      expect(await db.visiblePlaylists(), isEmpty);
    });
  });
}

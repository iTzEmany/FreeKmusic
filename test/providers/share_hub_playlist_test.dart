import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart' show coversDirProvider;
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/share_providers.dart' show lanClientProvider;
import 'package:codecore/providers/youtube_providers.dart' show downloadIndexProvider;
import 'package:codecore/services/share/lan_client.dart';
import 'package:codecore/services/online/download_index.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codecore/data/repositories/hidden_playlists.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:codecore/services/share/playlist_parts.dart';
import 'package:codecore/services/share/received_playlist.dart';
import 'package:codecore/services/stream/stream_key.dart' show streamResultOf;
import 'package:codecore/services/share/discovery.dart' show Peer;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

String ykey(int i) => 'youtube:${i.toString().padLeft(11, 'a')}';

OfferItem item(int id) => OfferItem(id: id, title: 'Song $id', sizeBytes: 1, ext: 'mp3');
StreamOffer stream(String key, {bool shadow = false}) => StreamOffer(key: key, title: 'T $key', shadow: shadow);
OfferRef it(int id) => (item: id, stream: null);
OfferRef st(String key) => (item: null, stream: key);

class _NoNetClient extends LanClient {
  @override
  Future<void> offerAction(String host, int port, String offerId, String action, String token, {int? tlsPort, String? pin}) async {}
}

/// An old receiver: a part with nothing it can read (no files, no streams[]) is a 400.
class _OldReceiverClient extends LanClient {
  final sentParts = <int>[];

  @override
  Future<void> sendOffer(String host, int port, Map<String, Object?> payload, {int? tlsPort, String? pin}) async {
    final part = (payload['playlist']! as Map)['part']! as int;
    if ((payload['items']! as List).isEmpty && !payload.containsKey('streams')) throw const LanException(LanError.failed);
    sentParts.add(part);
  }
}

IncomingOffer _offer(String id, {List<StreamOffer> streams = const [], OfferPlaylist? playlist}) => IncomingOffer(
    offerId: id, fromId: 'f', fromName: 'n', fromHost: '10.0.0.2', fromPort: 1, token: 'tok12345', items: const [], streams: streams, playlist: playlist);

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
  test('a saved stream already downloaded here, and a file with no row, are found by title instead of vanishing', () async {
    await addFile('/lib/Song 2.mp3', title: 'Song 2');
    await addFile('/lib/Live.mp3', title: 'T ${ykey(5)}');
    final id = await write(
      plOf([it(1), st(ykey(5)), st(ykey(6))]),
      items: [item(1)],
      streams: [stream(ykey(5)), stream(ykey(6), shadow: true)],
      paths: {1: '/r/not-in-db.mp3'},
    );
    // item 1: path without row -> looked up by title ("Song 1" is not here); ykey(5): file here; ykey(6): new shadow row.
    expect(await pathsOf(id!), ['/lib/Live.mp3', 'stream:${ykey(6)}']);
  });

  test('a part appended to a playlist the user deleted starts a new one', () async {
    await addFile('/r/a.mp3');
    final first = await write(plOf([it(1)]), items: [item(1)], paths: {1: '/r/a.mp3'});
    await playlists.delete(first!);
    final next = await write(plOf([it(1)], part: 2, parts: 2), items: [item(1)], paths: {1: '/r/a.mp3'}, appendTo: first);
    expect(next, isNot(first));
    expect(await pathsOf(next!), ['/r/a.mp3']);
  });

  group('hub accept', () {
    late ProviderContainer c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final tmp = await Directory.systemTemp.createTemp('hubpl');
      addTearDown(() => tmp.delete(recursive: true));
      c = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(await SharedPreferences.getInstance())),
        databaseProvider.overrideWithValue(db),
        lanClientProvider.overrideWithValue(_NoNetClient()),
        downloadIndexProvider.overrideWith((ref) => DownloadIndex(File('${tmp.path}/idx.json'))),
      ]);
      addTearDown(c.dispose);
    });

    test('sender: a part refused with 400 (shadow rows only, old receiver) does not stop the next parts; it counts as unsupported', () async {
      final client = _OldReceiverClient();
      final c2 = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore(await SharedPreferences.getInstance())),
        databaseProvider.overrideWithValue(db),
        lanClientProvider.overrideWithValue(client),
        coversDirProvider.overrideWithValue(Directory.systemTemp),
      ]);
      addTearDown(c2.dispose);
      final rows = <Track>[];
      for (var i = 0; i < 501; i++) {
        final id = await tracks.ensureStreamRow(streamResultOf(ykey(i), title: 'T$i', artist: 'A', album: '', durationMs: 1000));
        if (i == 500) await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(saved: Value(true)));
        rows.add(await (db.select(db.tracks)..where((t) => t.id.equals(id))).getSingle());
      }
      final out = await c2.read(shareHubProvider.notifier).sendOffer(
          const Peer(id: 'p', name: 'P', host: '127.0.0.1', port: 9, platform: 'linux'), rows, playlistName: 'Mix');
      expect(client.sentParts, [2]);
      expect((out.status, out.sent, out.unsupported, out.total), (SendStatus.sent, 1, 500, 501));
    });

    test('shadow stream without a valid playlist is never saved to the library', () async {
      final o = _offer('o1', streams: [stream(ykey(1), shadow: true), stream(ykey(2))]);
      await c.read(shareHubProvider.notifier).accept(o);
      expect(await tracks.streamRow(ykey(1)), isNull);
      expect((await tracks.streamRow(ykey(2)))!.saved, true);
      expect(await db.visiblePlaylists(), isEmpty);
    });

    test('with a playlist: it is created in order, shadow rows only inside it', () async {
      final o = _offer('o2',
          streams: [stream(ykey(1)), stream(ykey(2), shadow: true)], playlist: plOf([st(ykey(2)), st(ykey(1))], name: 'Mix'));
      await c.read(shareHubProvider.notifier).accept(o);
      final lists = await db.visiblePlaylists();
      expect(lists.single.name, 'Mix');
      expect(await pathsOf(lists.single.id), ['stream:${ykey(2)}', 'stream:${ykey(1)}']);
      expect((await tracks.streamRow(ykey(2)))!.saved, false);
      expect((await tracks.streamRow(ykey(1)))!.saved, true);
    });
  });

  group('PlaylistParts rules', () {
    IncomingOffer p(int n, int of, {String id = '', String host = '10.0.0.2'}) => IncomingOffer(
        offerId: id.isEmpty ? 'p$n' : id, fromId: 'f', fromName: 'n', fromHost: host, fromPort: 1, token: 'tok12345', items: const [],
        streams: [stream(ykey(n))], playlist: plOf([st(ykey(n))], key: 'k', part: n, parts: of));

    void run(String name, void Function(FakeAsync fa, List<String> log, PlaylistParts parts) body, {bool throwOn2 = false}) {
      test(name, () {
        fakeAsync((fa) {
          final log = <String>[];
          final parts = PlaylistParts(
            accept: (o) async {
              log.add('accept ${o.playlist!.part}');
              if (throwOn2 && o.playlist!.part == 2) throw StateError('disk full');
            },
            decline: (o) async => log.add('decline ${o.playlist!.part}'),
          );
          body(fa, log, parts);
          parts.dispose();
        });
      });
    }

    run('part 1 accepted but downloading for 15 minutes: the waiting parts are not declined', (fa, log, parts) {
      final p1 = p(1, 3);
      parts.handle(p1);
      fa.elapse(const Duration(minutes: 1));
      expect(parts.handle(p(2, 3)), true);
      parts.answered(p1);
      fa.elapse(const Duration(minutes: 15));
      expect(log, isEmpty);
      parts.firstDone(p1, ok: true);
      fa.flushMicrotasks();
      expect(log, ['accept 2']);
    });

    run('part 1 never answered: at the end of offerTtl the pending parts are refused', (fa, log, parts) {
      parts.handle(p(1, 3));
      parts.handle(p(2, 3));
      fa.elapse(offerTtl + const Duration(seconds: 1));
      expect(log, ['decline 2']);
      expect(parts.accepts('f', '10.0.0.2', null, 'k', 3, 3), false);
    });

    run('an accept that throws does not block the next part', (fa, log, parts) {
      final p1 = p(1, 3);
      parts.handle(p1);
      parts.handle(p(2, 3));
      parts.handle(p(3, 3));
      parts.firstDone(p1, ok: true);
      fa.flushMicrotasks();
      expect(log, ['accept 2', 'accept 3']);
    }, throwOn2: true);

    run('only the next part of the declared parts is taken: no duplicate, jump, other total or repeated part 1', (fa, log, parts) {
      final p1 = p(1, 3);
      parts.handle(p1);
      expect(parts.handle(p(1, 3, id: 'again')), false);
      expect(parts.handle(p(3, 3)), false); // jump
      expect(parts.handle(p(2, 5)), false); // another `parts`
      expect(parts.handle(p(2, 3)), true);
      expect(parts.handle(p(2, 3, id: 'dup')), false);
      expect(parts.handle(p(4, 3)), false); // beyond the declared
      expect(parts.accepts('f', '10.0.0.2', null, 'k', 3, 3), true);
      expect(parts.accepts('f', '10.0.0.9', null, 'k', 3, 3), false);
      // The repeated part 1 did not replace the group: the real one still leads.
      parts.firstDone(p1, ok: true);
      fa.flushMicrotasks();
      expect(log, ['accept 2']);
    });

    run('the group closes after the last part; a single part makes no group', (fa, log, parts) {
      final p1 = p(1, 2);
      parts.handle(p1);
      parts.handle(p(2, 2));
      parts.firstDone(p1, ok: true);
      fa.flushMicrotasks();
      expect(log, ['accept 2']);
      expect(parts.handle(p(2, 2, id: 'late')), false);
      expect(parts.handle(p(1, 1, id: 'solo')), false);
      expect(parts.accepts('f', '10.0.0.2', null, 'k', 2, 2), false);
    });

    run('an idle group ends offerTtl after its last activity', (fa, log, parts) {
      final p1 = p(1, 3);
      parts.handle(p1);
      parts.firstDone(p1, ok: true);
      fa.elapse(offerTtl - const Duration(seconds: 1));
      expect(parts.accepts('f', '10.0.0.2', null, 'k', 2, 3), true);
      fa.elapse(const Duration(seconds: 2));
      expect(parts.accepts('f', '10.0.0.2', null, 'k', 2, 3), false);
    });

    run('part 2 appends to the playlist of part 1, and only for offers of the group', (fa, log, parts) {
      final p1 = p(1, 2), p2 = p(2, 2);
      parts.handle(p1);
      parts.handle(p2);
      expect(parts.playlistFor(p1), isNull);
      parts.wrote(p1, 7);
      expect(parts.playlistFor(p2), 7);
      expect(parts.playlistFor(p(2, 2, id: 'stranger')), isNull);
      parts.wrote(p(1, 2, id: 'stranger1'), 99);
      expect(parts.playlistFor(p2), 7);
    });
  });
}

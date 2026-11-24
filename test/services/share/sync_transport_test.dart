import 'dart:io';

import 'package:codecore/core/clock.dart';
import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/share/device_identity.dart';
import 'package:codecore/services/share/lan_client.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:codecore/services/share/sync_client.dart';
import 'package:codecore/services/share/sync_routes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late DeviceIdentity idA, idB, idC, idD;
  late OfferNode nodeB;
  late Set<String> trusted, mine;
  late List<TombstoneData> tombstones;
  int? lastSince;
  late List<(String, TrackRequest)> wanted;

  // Making a key pair is the slow part: once for the whole file.
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('sync-ids');
    addTearDown(() => dir.deleteSync(recursive: true));
    Future<DeviceIdentity> make(String n) => DeviceIdentity.loadOrCreate(Directory(p.join(dir.path, n)));
    idA = await make('a');
    idB = await make('b');
    idC = await make('c');
    idD = await make('d');
  });

  setUp(() async {
    trusted = {idA.fingerprint, idD.fingerprint};
    mine = {idA.fingerprint};
    tombstones = [];
    lastSince = null;
    wanted = [];
    nodeB = OfferNode(OfferService(deviceId: 'b', deviceName: 'B', allowLoopback: true),
        allowLoopback: true,
        identity: idB,
        secureRoutes: {
          '/sync': buildSyncRouter(
            export: () async => [
              const RemotePlaylist(uuid: 'u1', name: 'Mix', createdAt: 1, updatedAt: 5, items: [TrackRef(title: 'x', relPath: 'x.mp3')]),
            ],
            exportFavorites: () async => [const FavoriteCollectionData(kind: 'album', key: 'artist|album', addedAt: 7)],
            exportStreams: () async => [const StreamEntry(key: 'youtube:dQw4w9WgXcQ', title: 'T', saved: true, addedAt: 9)],
            exportTombstones: (since) async {
              lastSince = since;
              return tombstones;
            },
            isTrusted: trusted.contains,
            isMine: mine.contains,
            onWant: (host, fp, req) async {
              wanted.add((host, req));
              return req.refs.length;
            },
          ).call,
        });
    await nodeB.start();
  });
  tearDown(() => nodeB.stop());

  SyncClient client(DeviceIdentity id) => SyncClient(LanClient(identity: id));

  test('a trusted device reads the playlists in the portable format', () async {
    final list = await client(idA).playlists('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint);
    expect(list.single.uuid, 'u1');
    expect(list.single.updatedAt, 5);
    expect(list.single.items.single.relPath, 'x.mp3');
  });

  test('an untrusted device, or an unsigned one, is refused', () async {
    await expectLater(client(idC).playlists('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint),
        throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.notTrusted)));
    await expectLater(SyncClient(LanClient()).playlists('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint),
        throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.notTrusted)));
  });

  test('a changed identity is reported, not followed', () async {
    await expectLater(client(idA).playlists('127.0.0.1', nodeB.tlsPort!, pin: idC.fingerprint),
        throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.identityChanged)));
  });

  test('«want» reaches the other device with the caller\'s address and ports', () async {
    final n = await client(idA).want('127.0.0.1', nodeB.tlsPort!, [const TrackRef(title: 'a'), const TrackRef(title: 'b')],
        pin: idB.fingerprint, port: 4001, tlsPortHere: 4002);
    expect(n, 2);
    final (host, req) = wanted.single;
    expect(host, '127.0.0.1');
    expect((req.port, req.tlsPort), (4001, 4002));
    expect([for (final r in req.refs) r.title], ['a', 'b']);
    await expectLater(client(idC).want('127.0.0.1', nodeB.tlsPort!, [const TrackRef(title: 'a')], pin: idB.fingerprint, port: 1),
        throwsA(isA<SyncException>()));
    expect(wanted, hasLength(1));
  });

  group('favourites, streamed tracks and tombstones', () {
    const uuid = '00000000-0000-4000-8000-000000000001';

    test('a trusted device reads favourites and streamed tracks with their dates', () async {
      final side = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: false);
      expect((side.favorites.single.key, side.favorites.single.addedAt), ('artist|album', 7));
      expect((side.streams.single.key, side.streams.single.saved, side.streams.single.addedAt), ('youtube:dQw4w9WgXcQ', true, 9));
    });

    test('tombstones go only to an own device, and only when asked: a device not «mine» gets none', () async {
      tombstones = [const TombstoneData(kind: 'playlist', key: uuid, deletedAt: 50)];
      final mineSide = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true, since: 40);
      expect(mineSide.tombstones.single.key, uuid);
      expect(lastSince, 40);
      // The caller asks (it thinks the server is its own) but the server does not think so of it.
      final other = await client(idD).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect(other.tombstones, isEmpty);
      // Not asked at all when the caller does not think the server is its own.
      lastSince = -1;
      final none = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: false);
      expect(none.tombstones, isEmpty);
      expect(lastSince, -1);
    });

    test('unsigned, untrusted or with a changed identity: refused on every new route', () async {
      for (final c in [client(idC), SyncClient(LanClient())]) {
        for (final mineFlag in [false, true]) {
          await expectLater(c.collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: mineFlag),
              throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.notTrusted)));
        }
      }
      await expectLater(client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idC.fingerprint, mine: true),
          throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.identityChanged)));
    });

    test('hostile input is dropped: bad kinds, future or past dates, long keys, malformed entries', () async {
      final future = nowMs() + const Duration(days: 3).inMilliseconds;
      final hostile = StreamEntry.tryParse({'key': 'youtube:dQw4w9WgXcQ', 'title': 'T', 'saved': true, 'addedAt': future});
      expect(hostile!.addedAt, isNull, reason: 'a date from the future is not trusted');
      expect(StreamEntry.tryParse({'key': 'youtube:../../x', 'title': 'T', 'saved': true}), isNull);
      expect(StreamEntry.tryParse({'key': 'youtube:dQw4w9WgXcQ', 'title': 'x' * 600, 'saved': true}), isNull);
      expect(StreamEntry.tryParse({'key': 'youtube:dQw4w9WgXcQ', 'title': 'T'}), isNull, reason: 'neither saved nor hearted');
      expect(StreamEntry.tryParse({'key': 'youtube:dQw4w9WgXcQ', 'title': 'T', 'saved': true, 'addedAt': -5})!.addedAt, isNull);
      expect(FavoriteCollectionData.tryParse({'kind': 'album', 'key': 'k' * 600}), isNull);
      expect(FavoriteCollectionData.tryParse({'kind': 'album', 'key': 'k', 'addedAt': future})!.addedAt, isNull);
      for (final bad in [
        {'kind': 'nope', 'key': uuid, 'deletedAt': 5},
        {'kind': 'playlist', 'key': uuid, 'deletedAt': future},
        {'kind': 'playlist', 'key': uuid, 'deletedAt': 0},
        {'kind': 'playlist', 'key': 'x' * 600, 'deletedAt': 5},
        {'kind': 'savedStream', 'key': 'youtube:../x', 'deletedAt': 5},
      ]) {
        expect(TombstoneData.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('too many entries: only the first kMaxSyncItems are read', () async {
      tombstones = [
        for (var i = 0; i < kMaxSyncItems + 50; i++)
          TombstoneData(kind: 'favoriteAlbum', key: 'a|$i', deletedAt: 10 + i),
      ];
      final side = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect(side.tombstones, hasLength(kMaxSyncItems));
    });
  });
}

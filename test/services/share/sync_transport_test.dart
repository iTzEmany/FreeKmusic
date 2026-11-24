import 'dart:convert';
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
import 'package:shelf/shelf.dart';

void main() {
  late DeviceIdentity idA, idB, idC, idD;
  late OfferNode nodeB;
  late Set<String> trusted, mine;
  late List<TombstoneData> tombstones;
  int? lastSince;
  late int favoritesCalls, streamsCalls;
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
    favoritesCalls = streamsCalls = 0;
    wanted = [];
    nodeB = OfferNode(
      OfferService(deviceId: 'b', deviceName: 'B', allowLoopback: true),
      allowLoopback: true,
      identity: idB,
      secureRoutes: {
        '/sync': buildSyncRouter(
          export: () async => [
            const RemotePlaylist(
              uuid: '00000000-0000-4000-8000-0000000000a1',
              name: 'Mix',
              createdAt: 1,
              updatedAt: 5,
              items: [TrackRef(title: 'x', relPath: 'x.mp3')],
            ),
          ],
          exportFavorites: () async {
            favoritesCalls++;
            return [
              const FavoriteCollectionData(
                kind: 'album',
                key: 'artist|album',
                addedAt: 7,
              ),
            ];
          },
          exportStreams: () async {
            streamsCalls++;
            return [
              const StreamEntry(
                key: 'youtube:dQw4w9WgXcQ',
                title: 'T',
                saved: true,
                addedAt: 9,
              ),
            ];
          },
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
      },
    );
    await nodeB.start();
  });
  tearDown(() => nodeB.stop());

  SyncClient client(DeviceIdentity id) => SyncClient(LanClient(identity: id));

  test('a trusted device reads the playlists in the portable format', () async {
    final list = await client(idA)
        .playlists('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint);
    expect(list.single.uuid, '00000000-0000-4000-8000-0000000000a1');
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

    test(
      'an own device reads favourites and streamed tracks with their dates',
      () async {
        final side = await client(idA).collections(
          '127.0.0.1',
          nodeB.tlsPort!,
          pin: idB.fingerprint,
          mine: true,
        );
        expect(
          (side.favorites.single.key, side.favorites.single.addedAt),
          ('artist|album', 7),
        );
        expect(
          (
            side.streams.single.key,
            side.streams.single.saved,
            side.streams.single.addedAt,
          ),
          ('youtube:dQw4w9WgXcQ', true, 9),
        );
      },
    );

    test('a trusted device that is not «mine» is served only the playlists: an empty answer on the other routes, and none is asked for', () async {
      final asked = await client(idD).collections(
        '127.0.0.1',
        nodeB.tlsPort!,
        pin: idB.fingerprint,
        mine: true,
      );
      expect([
        asked.favorites,
        asked.streams,
        asked.tombstones,
      ], everyElement(isEmpty));
      expect(
        (favoritesCalls, streamsCalls),
        (0, 0),
        reason: 'the server does not even read them for it',
      );
      expect(
        (await client(idD)
            .playlists('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint)),
        hasLength(1),
      );

      final none = await client(idA).collections(
        '127.0.0.1',
        nodeB.tlsPort!,
        pin: idB.fingerprint,
        mine: false,
      );
      expect([
        none.favorites,
        none.streams,
        none.tombstones,
      ], everyElement(isEmpty));
      expect(
        (favoritesCalls, streamsCalls),
        (0, 0),
        reason: 'the client does not ask when it does not think the server is its own',
      );
    });

    test('tombstones go only to an own device, and only when asked: a device not «mine» gets none', () async {
      tombstones = [
        const TombstoneData(kind: 'playlist', key: uuid, deletedAt: 50),
      ];
      final mineSide = await client(idA).collections(
        '127.0.0.1',
        nodeB.tlsPort!,
        pin: idB.fingerprint,
        mine: true,
      );
      expect(mineSide.tombstones.single.key, uuid);
      expect(lastSince, isNull);
      final reply = await LanClient(identity: idA).securePost(
        '127.0.0.1',
        nodeB.tlsPort!,
        '/sync/tombstones',
        {'since': 40},
        pin: idB.fingerprint,
      );
      expect(reply.status, 200);
      expect(
        lastSince,
        40,
        reason: 'the route keeps `since`, in the signed body',
      );
      // The caller asks (it thinks the server is its own) but the server does not think so of it.
      final other = await client(idD).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect(other.tombstones, isEmpty);
      // Not asked at all when the caller does not think the server is its own.
      lastSince = -1;
      final none = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: false);
      expect(none.tombstones, isEmpty);
      expect(lastSince, -1);
    });

    test('an untrusted or unsigned caller is refused (403) on every route by itself, tombstones included', () async {
      for (final lan in [LanClient(identity: idC), LanClient()]) {
        for (final path in [
          '/sync/playlists',
          '/sync/favorites',
          '/sync/streams',
        ]) {
          final r = await lan.secureGet(
            '127.0.0.1',
            nodeB.tlsPort!,
            path,
            pin: idB.fingerprint,
          );
          expect(r.status, 403, reason: path);
        }
        final t = await lan.securePost(
          '127.0.0.1',
          nodeB.tlsPort!,
          '/sync/tombstones',
          {},
          pin: idB.fingerprint,
        );
        expect(t.status, 403);
      }
      expect((favoritesCalls, streamsCalls), (0, 0));
      for (final c in [client(idC), SyncClient(LanClient())]) {
        await expectLater(
          c.collections(
            '127.0.0.1',
            nodeB.tlsPort!,
            pin: idB.fingerprint,
            mine: true,
          ),
          throwsA(
            isA<SyncException>().having(
              (e) => e.error,
              'error',
              SyncError.notTrusted,
            ),
          ),
        );
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

  group('what the other device answers is not trusted', () {
    late OfferNode raw;
    late int status;
    late Object body;

    setUp(() async {
      status = 200;
      body = {};
      raw = OfferNode(
        OfferService(deviceId: 'r', deviceName: 'R', allowLoopback: true),
        allowLoopback: true,
        identity: idB,
        secureRoutes: {
          '/sync': (Request r) async => Response(
            status,
            body: jsonEncode(body),
            headers: {'content-type': 'application/json'},
          ),
        },
      );
      await raw.start();
    });
    tearDown(() => raw.stop());

    Matcher failed() => throwsA(
      isA<SyncException>().having((e) => e.error, 'error', SyncError.failed),
    );
    Map<String, Object?> playlist([Map<String, Object?> over = const {}]) => {
      'uuid': '00000000-0000-4000-8000-000000000001',
      'name': 'Mix',
      'createdAt': 1,
      'updatedAt': 5,
      'items': [],
      ...over,
    };

    test('a status other than 200 is a failure, on every route', () async {
      status = 500;
      body = {
        'playlists': [],
        'favorites': [],
        'streams': [],
        'tombstones': [],
      };
      await expectLater(
        client(idA).playlists('127.0.0.1', raw.tlsPort!, pin: idB.fingerprint),
        failed(),
      );
      await expectLater(
        client(idA).collections(
          '127.0.0.1',
          raw.tlsPort!,
          pin: idB.fingerprint,
          mine: true,
        ),
        failed(),
      );
    });

    test('a malformed playlist is a SyncError, never a TypeError; a good one is read', () async {
      body = {
        'playlists': [playlist()],
      };
      expect(
        await client(idA)
            .playlists('127.0.0.1', raw.tlsPort!, pin: idB.fingerprint),
        hasLength(1),
      );
      for (final bad in <Object?>[
        5,
        playlist({'uuid': 'nope'}),
        playlist({
          'items': [5],
        }),
        playlist({
          'items': [
            {'title': 'x' * 513},
          ],
        }),
        playlist({'createdAt': 'soon'}),
      ]) {
        body = {
          'playlists': [bad],
        };
        await expectLater(
          client(idA)
              .playlists('127.0.0.1', raw.tlsPort!, pin: idB.fingerprint),
          failed(),
          reason: '$bad',
        );
      }
      body = {'playlists': 'x'};
      await expectLater(
        client(idA).playlists('127.0.0.1', raw.tlsPort!, pin: idB.fingerprint),
        failed(),
      );
    });

    test('no more than kMaxSyncItems playlists are read', () async {
      body = {
        'playlists': [
          for (var i = 0; i < kMaxSyncItems + 5; i++)
            playlist({
              'uuid':
                  '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
            }),
        ],
      };
      expect(
        await client(idA)
            .playlists('127.0.0.1', raw.tlsPort!, pin: idB.fingerprint),
        hasLength(kMaxSyncItems),
      );
    });

    test('tombstones of a repeated key: the latest date, even when the list is not in order', () async {
      const uuid = '00000000-0000-4000-8000-000000000001';
      body = {
        'favorites': [],
        'streams': [],
        'tombstones': [
          {'kind': 'playlist', 'key': uuid, 'deletedAt': 30},
          {'kind': 'playlist', 'key': uuid, 'deletedAt': 20},
        ],
      };
      final side = await client(idA).collections(
        '127.0.0.1',
        raw.tlsPort!,
        pin: idB.fingerprint,
        mine: true,
      );
      expect(side.tombstones.single.deletedAt, 30);
    });
  });
}

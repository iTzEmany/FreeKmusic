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
import 'package:codecore/services/share/tables_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

void main() {
  late DeviceIdentity idA, idB, idC, idD;
  late OfferNode nodeB;
  late Set<String> trusted, mine;
  late List<TombstoneData> tombstones;
  late int favoritesCalls, streamsCalls, tombstoneCalls, settingsCalls;
  late Future<({List<TextEntry> texts, int? next})> Function(int after) textsOf;
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
    favoritesCalls = streamsCalls = tombstoneCalls = settingsCalls = 0;
    textsOf = (after) async => (texts: <TextEntry>[], next: null);
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
          exportTombstones: () async {
            tombstoneCalls++;
            return tombstones;
          },
          exportSettings: () async {
            settingsCalls++;
            return {'theme': 'oled', 'fontScale': 1.15};
          },
          exportPlays: () async => [
            const PlayEntry(ref: TrackRef(title: 'x', relPath: 'x.mp3'), playedAt: 1000, msPlayed: 5, context: 2, contextName: 'Mix'),
          ],
          exportTags: () async => (
            tags: [const TagEntry(name: 'rock', color: 3)],
            tagged: [const TaggedTrack(ref: TrackRef(title: 'x', relPath: 'x.mp3'), tags: ['rock'])],
          ),
          exportTexts: (after) => textsOf(after),
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

  group('collections: favourites, streamed tracks and tombstones', () {
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

    test('a trusted device that is not «mine» is served only the playlists: empty lists and settings, no tombstones, empty texts, and the server reads nothing for it', () async {
      tombstones = [const TombstoneData(kind: 'playlist', key: uuid, deletedAt: 50)];
      textsOf = (after) async => (texts: [const TextEntry(ref: TrackRef(title: 't', relPath: 't.mp3'), plain: 'w')], next: null);
      // The caller asks (it thinks the server is its own) but the server does not think so of it.
      final asked = await client(idD).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect([asked.favorites, asked.streams, asked.tombstones, asked.settings, asked.tables.plays, asked.tables.tags, asked.tables.texts],
          everyElement(isEmpty));
      expect((favoritesCalls, streamsCalls, tombstoneCalls, settingsCalls), (0, 0, 0, 0));
      expect(await client(idD).playlists('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint), hasLength(1));

      // Not asked at all when the caller does not think the server is its own.
      final none = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: false);
      expect([none.favorites, none.streams, none.tombstones, none.settings], everyElement(isEmpty));
      expect((favoritesCalls, streamsCalls, tombstoneCalls, settingsCalls), (0, 0, 0, 0));

      // An own device does get the tombstones.
      final mineSide = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect(mineSide.tombstones.single.key, uuid);
    });

    test('an untrusted or unsigned caller is refused (403) on every route by itself', () async {
      for (final lan in [LanClient(identity: idC), LanClient()]) {
        for (final path in ['/sync/playlists', '/sync/collections']) {
          final r = await lan.secureGet('127.0.0.1', nodeB.tlsPort!, path, pin: idB.fingerprint);
          expect(r.status, 403, reason: path);
        }
        for (final path in ['/sync/texts', '/sync/want']) {
          final r = await lan.securePost('127.0.0.1', nodeB.tlsPort!, path, {'after': 0}, pin: idB.fingerprint);
          expect(r.status, 403, reason: path);
        }
      }
      expect((favoritesCalls, streamsCalls, tombstoneCalls, settingsCalls), (0, 0, 0, 0));
      for (final c in [client(idC), SyncClient(LanClient())]) {
        await expectLater(
          c.collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true),
          throwsA(isA<SyncException>().having((e) => e.error, 'error', SyncError.notTrusted)),
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

  group('collections: settings, listens, tags and texts', () {
    TextEntry text(int i) => TextEntry(ref: TrackRef(title: 't$i', relPath: 't$i.mp3'), plain: 'words $i');

    test('an own device reads them; the settings are only the allowed ones', () async {
      final side = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect(side.settings, {'theme': 'oled', 'fontScale': 1.15});
      expect(side.tables.plays.single.playedAt, 1000);
      expect(side.tables.plays.single.context, 2);
      expect((side.tables.tags.single.name, side.tables.tags.single.color), ('rock', 3));
      expect(side.tables.tagged.single.tags, ['rock']);
    });

    test('texts come page by page; a page that does not move forward ends the reading', () async {
      final asked = <int>[];
      textsOf = (after) async {
        asked.add(after);
        return switch (after) {
          0 => (texts: [text(1), text(2)], next: 7),
          7 => (texts: [text(3)], next: 7), // not forward: the end
          _ => (texts: <TextEntry>[], next: null),
        };
      };
      final side = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect([for (final t in side.tables.texts) t.plain], ['words 1', 'words 2', 'words 3']);
      expect(asked, [0, 7]);
    });

    test('empty pages that always name a further id do not make the reading endless: the rows read are bounded', () async {
      var asked = 0;
      textsOf = (after) async {
        asked++;
        return (texts: <TextEntry>[], next: after + 1);
      };
      final side = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true);
      expect(side.tables.texts, isEmpty);
      expect(asked, kMaxSyncItems ~/ kTextsPerPage);
    });

    test('each page is filtered as it arrives and the characters kept are bounded', () async {
      textsOf = (after) async => switch (after) {
        0 => (texts: [for (var i = 1; i <= 4; i++) text(i)], next: 10),
        _ => (texts: [for (var i = 5; i <= 8; i++) text(i)], next: null),
      };
      final pages = <int>[];
      final side = await client(idA).collections(
        '127.0.0.1',
        nodeB.tlsPort!,
        pin: idB.fingerprint,
        mine: true,
        keepTexts: (page) async {
          pages.add(page.length);
          return [for (final t in page) if (t.ref.title != 't2') t];
        },
      );
      expect(pages, [4, 4]);
      expect([for (final t in side.tables.texts) t.ref.title], ['t1', 't3', 't4', 't5', 't6', 't7', 't8']);
      final capped = await client(idA).collections('127.0.0.1', nodeB.tlsPort!, pin: idB.fingerprint, mine: true, maxTextChars: 15);
      expect(capped.tables.texts, hasLength(3), reason: 'the reading stops at the text that reaches 15 characters (7 each)');
    });

    test('hostile input is dropped: a streamed track with a text, huge texts, impossible dates, bad names', () {
      final ref = {'title': 'x', 'relPath': 'x.mp3'};
      expect(TextEntry.tryParse({'ref': {'title': 'x', 'streamKey': 'youtube:dQw4w9WgXcQ'}, 'plain': 'a'}), isNull);
      expect(TextEntry.tryParse({'ref': ref, 'plain': 'a' * (kMaxTextLength + 1)}), isNull);
      expect(TextEntry.tryParse({'ref': ref, 'plain': '  '}), isNull, reason: 'blank is no text');
      expect(TextEntry.tryParse({'ref': ref, 'plain': 'a', 'synced': 'b' * (kMaxTextLength + 1)})!.synced, isNull);
      final future = nowMs() + const Duration(days: 3).inMilliseconds;
      for (final at in [future, 0, -4, 'x', double.nan, null]) {
        expect(PlayEntry.tryParse({'ref': ref, 'playedAt': at}), isNull, reason: '$at');
      }
      expect(PlayEntry.tryParse({'ref': {'title': 'x', 'streamKey': '../x'}, 'playedAt': 5}), isNull);
      final p = PlayEntry.tryParse({'ref': ref, 'playedAt': 5, 'msPlayed': -1, 'context': 99999, 'contextName': 'n' * 600})!;
      expect((p.msPlayed, p.context, p.contextName), (0, null, null));
      expect(PlayEntry.tryParse({'ref': ref, 'playedAt': 5, 'context': 77})!.context, 77, reason: 'unknown kinds are kept, read as the library');
      expect(TagEntry.tryParse({'name': 'x' * 600}), isNull);
      expect(TagEntry.tryParse({'name': ' '}), isNull);
      expect(TagEntry.tryParse({'name': ' rock ', 'color': 9})!.name, 'rock');
      expect(TagEntry.tryParse({'name': 'rock', 'color': 9})!.color, isNull);
      expect(TaggedTrack.tryParse({'ref': ref, 'tags': [for (var i = 0; i < 500; i++) 't$i']})!.tags, hasLength(kMaxTagsPerTrack));
      expect(TaggedTrack.tryParse({'ref': ref, 'tags': [1, '']}), isNull);
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

    test('a peer without /sync/collections (404, as a version up to 1.6 answers) syncs the playlists only', () async {
      // A router with only the routes a 1.6 device has: the others are a 404 of the router itself.
      final old = OfferNode(
        OfferService(deviceId: 'o', deviceName: 'O', allowLoopback: true),
        allowLoopback: true,
        identity: idB,
        secureRoutes: {
          '/sync': (Router()
                ..get('/playlists', (Request r) async => Response.ok(jsonEncode({'playlists': [playlist()]}), headers: {'content-type': 'application/json'})))
              .call,
        },
      );
      await old.start();
      addTearDown(old.stop);
      expect(await client(idA).playlists('127.0.0.1', old.tlsPort!, pin: idB.fingerprint), hasLength(1));
      final side = await client(idA).collections('127.0.0.1', old.tlsPort!, pin: idB.fingerprint, mine: true);
      expect([side.favorites, side.streams, side.tombstones, side.settings], everyElement(isEmpty));
      expect(side.tables.isEmpty, isTrue);
    });

    test('a collections answer whose list is not a list is a failure', () async {
      body = {'favorites': 'x', 'streams': [], 'tombstones': [], 'plays': [], 'tags': [], 'tagged': []};
      await expectLater(client(idA).collections('127.0.0.1', raw.tlsPort!, pin: idB.fingerprint, mine: true), failed());
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
            {'title': 'x' * 4097},
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
        'plays': [],
        'tags': [],
        'tagged': [],
        'texts': [],
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

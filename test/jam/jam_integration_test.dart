import 'dart:async';
import 'dart:io';

import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/services/jam/jam_cache.dart';
import 'package:codecore/services/jam/jam_guest.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/jam_online_adder.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:path/path.dart' as p;
import 'package:codecore/services/share/offers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;

/// The first state of [g] that passes [test], the one it already has included:
/// a state that arrived before the wait would otherwise cost a whole long poll.
Future<JamState> reach(JamGuest g, bool Function(JamState) test) {
  final now = g.state;
  if (now != null && test(now)) return Future.value(now);
  return g.states.firstWhere(test).timeout(const Duration(seconds: 5));
}

void main() {
  late JamHost hostJam, guestJam;
  late OfferNode hostNode, guestNode;
  late int hostPort, guestPort;
  late JamGuest guest;
  late Directory dir;
  var noSpeaker = false;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('jam_int');
    hostJam = JamHost(
        deviceId: 'host', deviceName: 'PC', allowLoopback: true,
        pollWait: const Duration(seconds: 2));
    guestJam = JamHost(
        deviceId: 'guest', deviceName: 'Phone', allowLoopback: true,
        pollWait: const Duration(seconds: 2));
    hostNode = OfferNode(
        OfferService(deviceId: 'host', deviceName: 'PC', allowLoopback: true),
        allowLoopback: true,
        extraRoutes: {
          '/jam': (r) async {
            // Stands in for a host whose speaker is away (JamHost answers so).
            if (noSpeaker && r.method == 'POST' && r.url.path.endsWith('/cmd')) {
              return shelf.Response(409, body: 'no speaker');
            }
            return hostJam.buildRouter().call(r);
          }
        });
    guestNode = OfferNode(
        OfferService(deviceId: 'guest', deviceName: 'Phone', allowLoopback: true),
        allowLoopback: true,
        extraRoutes: {'/jam': guestJam.buildRouter().call});
    hostPort = await hostNode.start();
    guestPort = await guestNode.start();
    guest = JamGuest(
        local: guestJam,
        requestPoll: const Duration(milliseconds: 50),
        backoff: const Duration(milliseconds: 20),
        maxFailures: 3);
    hostJam.onRequest = (r) => hostJam.accept(r.id);
  });

  tearDown(() async {
    await guest.dispose();
    await hostNode.stop();
    await guestNode.stop();
    dir.deleteSync(recursive: true);
  });

  Future<void> join() async {
    final o = await guest.join(
        host: '127.0.0.1',
        port: hostPort,
        ownDeviceId: 'guest',
        ownName: 'Phone',
        ownPort: guestPort);
    expect(o, JamJoinOutcome.accepted);
  }

  test('guest and host edit the same queue, guest can jump', () async {
    await join();
    expect(guest.state!.hostDeviceId, 'host');

    final r = await guest.send(const JamCommand.add(JamItem(
        id: 0, ownerDeviceId: 'guest', title: 'G', ext: 'mp3', ref: '1')));
    expect(r.isOk, true);
    expect(hostJam.state!.items.single.title, 'G');

    hostJam.apply(const JamCommand.add(
        JamItem(id: 0, ownerDeviceId: 'host', title: 'H', ext: 'flac')));
    await guest.states
        .firstWhere((s) => s.items.length == 2)
        .timeout(const Duration(seconds: 5));
    expect(guest.state!.items.map((i) => i.title), ['G', 'H']);

    final j = await guest.send(const JamCommand.jump(2));
    expect(j.isOk, true);
    final rm = await guest.send(const JamCommand.remove(2));
    expect(rm.error, JamError.forbidden);
    final mv = await guest.send(const JamCommand.move(2, 0));
    expect(mv.isOk, true);
    expect(hostJam.state!.items.first.title, 'H');
  });

  test('a 409 «no speaker» reaches the guest as noSpeaker, not full', () async {
    await join();
    noSpeaker = true;
    expect((await guest.send(const JamCommand.play())).error, JamError.noSpeaker);
    noSpeaker = false;
  });

  test('an unknown command reaches the guest as invalid (old host)', () async {
    final odd = JamGuest(
        local: guestJam,
        dio: Dio(BaseOptions(validateStatus: (_) => true))
          ..interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
            if (o.path.endsWith('/cmd')) o.data = {'cmd': 'bogus'};
            h.next(o);
          })),
        requestPoll: const Duration(milliseconds: 50),
        backoff: const Duration(milliseconds: 20),
        maxFailures: 3);
    addTearDown(odd.dispose);
    final o = await odd.join(
        host: '127.0.0.1', port: hostPort, ownDeviceId: 'guest',
        ownName: 'Phone', ownPort: guestPort);
    expect(o, JamJoinOutcome.accepted);
    expect((await odd.send(const JamCommand.previous())).error, JamError.invalid);
  });

  test('declined and ended', () async {
    hostJam.onRequest = (r) => hostJam.decline(r.id);
    final o = await guest.join(
        host: '127.0.0.1', port: hostPort, ownDeviceId: 'guest',
        ownName: 'Phone', ownPort: guestPort);
    expect(o, JamJoinOutcome.declined);

    hostJam.onRequest = (r) => hostJam.accept(r.id);
    await join();
    final ended = guest.states.firstWhere((s) => s.ended);
    hostJam.endSession();
    expect((await ended.timeout(const Duration(seconds: 5))).ended, true);
    // The client stops before it announces the ended state.
    expect(guest.active, false);
  });

  test('host disappearing marks the session lost', () async {
    await join();
    final lost = guest.lost.first;
    await hostNode.stop();
    await lost.timeout(const Duration(seconds: 15));
    expect(guest.active, false);
  });

  test('three devices: a guest accepts a newcomer on behalf of the host',
      () async {
    await join();
    final jamB = JamHost(
        deviceId: 'guestB', deviceName: 'Tablet', allowLoopback: true,
        pollWait: const Duration(seconds: 2));
    final nodeB = OfferNode(
        OfferService(deviceId: 'guestB', deviceName: 'Tablet', allowLoopback: true),
        allowLoopback: true,
        extraRoutes: {'/jam': jamB.buildRouter().call});
    final portB = await nodeB.start();
    final guestB = JamGuest(
        local: jamB,
        requestPoll: const Duration(milliseconds: 50),
        backoff: const Duration(milliseconds: 20),
        maxFailures: 3);
    addTearDown(() async {
      await guestB.dispose();
      await nodeB.stop();
    });
    // The first guest answers for the host.
    guestJam.onRequest = (r) => guest.invite(r);

    final o = await guestB.join(
        host: '127.0.0.1',
        port: guestPort, // asks the guest, not the host
        ownDeviceId: 'guestB',
        ownName: 'Tablet',
        ownPort: portB);
    expect(o, JamJoinOutcome.accepted);
    expect(hostJam.memberIds, containsAll(['guest', 'guestB']));
    expect(guestB.files!.hostBase, 'http://127.0.0.1:$hostPort/jam');

    // everyone sees the same roster
    await reach(guestB, (s) => s.participants.length == 3);
    expect(guestB.state!.participants.map((p) => p.name),
        containsAll(['PC', 'Phone', 'Tablet']));

    // B adds a track it owns; the original guest can fetch it from B
    final gf = File('${dir.path}/b.mp3')..writeAsBytesSync([5, 6, 7]);
    jamB.resolveFile = (i) async => gf.path;
    final r = await guestB.send(const JamCommand.add(JamItem(
        id: 0, ownerDeviceId: 'guestB', title: 'B', ext: 'mp3', ref: '1')));
    expect(r.isOk, true);
    await reach(guest, (s) => s.items.length == 1);
    final owner = guest.state!.participant('guestB')!;
    final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
    final got = await dio.get<List<int>>(
        'http://${owner.host}:${owner.port}/jam/${guest.files!.sessionId}/file/1',
        options: Options(headers: {'x-jam-file': guest.files!.fileToken}));
    expect(got.data, [5, 6, 7]);

    // B leaves: its track vanishes, the others stay
    await guestB.leave();
    await reach(guest, (s) => s.items.isEmpty && s.participants.length == 2);
    expect(hostJam.state!.ended, false);
  });

  group('online tracks from a guest (47.2)', () {
    late StreamCache cache;
    late Map<String, Completer<File>> downloads;
    late List<YtResult> failed;
    late JamOnlineAdder adder;

    YtResult yt(String id) =>
        YtResult(id: id, title: 'T$id', channel: 'C', duration: const Duration(seconds: 3));

    setUp(() async {
      cache = StreamCache(Directory(p.join(dir.path, 'cache')), freeSpace: () async => null);
      await cache.open();
      downloads = {};
      failed = [];
      await join();
      guestJam.resolveFile = (i) async => (await cache.fileFor(jamCacheKey(i)!))?.path;
      adder = JamOnlineAdder(
        ownId: 'guest',
        cache: cache,
        ready: (key, r) => (downloads[r.id] = Completer<File>()).future,
        send: (c) async => (await guest.send(c)).error,
        onFailed: failed.add,
      );
    });

    Future<File> finish(String id, List<int> bytes) async {
      final part = File(p.join(cache.dir.path, 'x.mp3.part'))..writeAsBytesSync(bytes);
      final f = await cache.put('youtube:$id', part);
      downloads[id]!.complete(f);
      return f;
    }

    test('items appear in order of addition and the host reads the guest cache', () async {
      adder.add(yt('a'));
      adder.add(yt('b'));
      await finish('b', [2]); // the second is ready first
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(hostJam.state!.items, isEmpty);
      await finish('a', [1]);
      await reach(guest, (s) => s.items.length == 2);
      final items = hostJam.state!.items;
      expect(items.map((i) => i.title), ['Ta', 'Tb']);
      expect(items.first.ref, 'yt:youtube:a');
      expect(items.first.videoId, 'a');

      // The host fetches it from the owner like `_resolve` does.
      final hostCache = JamCache(Directory(p.join(dir.path, 'jc')));
      final got = await hostCache.fetch(
          items.first,
          Uri.parse('http://127.0.0.1:$guestPort/jam/${guest.files!.sessionId}/file/${items.first.id}'),
          {'x-jam-file': hostJam.fileToken!});
      expect(got!.readAsBytesSync(), [1]);
    });

    test('a failed download adds nothing and does not block the next', () async {
      adder.add(yt('a'));
      adder.add(yt('b'));
      downloads['a']!.completeError(StateError('offline'));
      await finish('b', [2]);
      await reach(guest, (s) => s.items.length == 1);
      expect(hostJam.state!.items.single.title, 'Tb');
      expect(failed.map((r) => r.id), ['a']);
    });

    test('a throwing send or a vanished file does not block the next add', () async {
      var calls = 0;
      final sent = <String>[];
      final ok = File(p.join(dir.path, 'ok.m4a'))..writeAsBytesSync([1]);
      final a2 = JamOnlineAdder(
        ownId: 'guest',
        cache: cache,
        ready: (k, r) async => r.id == 'v' ? File(p.join(dir.path, 'gone.m4a')) : ok,
        send: (c) async {
          if (calls++ == 0) throw StateError('network blip');
          sent.add(c.item!.title);
          return null;
        },
        onFailed: failed.add,
      );
      a2.add(yt('t')); // send throws
      a2.add(yt('v')); // file vanished
      a2.add(yt('w'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(failed.map((r) => r.id), ['t', 'v']);
      expect(sent, ['Tw']);
    });

    test('the same track added twice leaves no pin behind', () async {
      final part = File(p.join(cache.dir.path, 'x.m4a.part'))..writeAsBytesSync([1, 2, 3]);
      final f = await cache.put('youtube:a', part);
      final a2 = JamOnlineAdder(
          ownId: 'guest', cache: cache, ready: (k, r) async => f, send: (c) async => null, onFailed: (_) {});
      a2.add(yt('a'));
      a2.add(yt('a'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      a2.seen([_own('guest', 'a')]);
      a2.dispose();
      cache.limitBytes = 0;
      await cache.evict();
      expect(await cache.fileFor('youtube:a'), isNull);
    });

    test("someone else's item with the same key does not release our pin", () async {
      final part = File(p.join(cache.dir.path, 'x.m4a.part'))..writeAsBytesSync([1, 2, 3]);
      final f = await cache.put('youtube:a', part);
      final a2 = JamOnlineAdder(
          ownId: 'guest', cache: cache, ready: (k, r) async => f, send: (c) async => null, onFailed: (_) {});
      a2.add(yt('a'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      a2.seen([_own('host', 'a')]);
      cache.limitBytes = 0;
      await cache.evict();
      expect(await cache.fileFor('youtube:a'), isNotNull);
      a2.dispose();
    });

    test('a file waiting for its turn is not evicted until it is queued', () async {
      adder.add(yt('a'));
      adder.add(yt('b'));
      await finish('b', [2]); // waits for 'a'
      cache.limitBytes = 0;
      await cache.evict();
      expect(await cache.fileFor('youtube:b'), isNotNull);
      adder.dispose(); // the Jam ends: pins are let go
      await cache.evict();
      expect(await cache.fileFor('youtube:b'), isNull);
    });
  });
}

JamItem _own(String owner, String id) => JamItem(
    id: 0, ownerDeviceId: owner, title: 'T', ext: 'm4a', ref: 'yt:youtube:$id', videoId: id);

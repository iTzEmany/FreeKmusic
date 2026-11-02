import 'dart:async';
import 'dart:io';

import 'package:codecore/services/jam/jam_guest.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/jam_part_feeder.dart';
import 'package:codecore/services/jam/jam_state.dart';
import 'package:codecore/services/share/offers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';

/// One simulated device: its own HTTP node, Jam routes and guest client.
class Dev {
  Dev(String id, {DateTime Function()? now})
      : id = id,
        jam = JamHost(
            deviceId: id,
            deviceName: id,
            allowLoopback: true,
            now: now,
            pollWait: const Duration(seconds: 1)) {
    final routes = jam.buildRouter();
    node = OfferNode(
        OfferService(deviceId: id, deviceName: id, allowLoopback: true),
        allowLoopback: true,
        extraRoutes: {
          '/jam': (Request r) {
            // The route reads the caller's token synchronously: once a poll
            // is announced here, the host has already seen its sender.
            final res = routes.call(r);
            if (r.url.path.endsWith('/state')) _polls.add(r.headers[jamTokenHeader]);
            return res;
          },
        });
    guest = JamGuest(
        local: jam,
        requestPoll: const Duration(milliseconds: 30),
        backoff: const Duration(milliseconds: 20),
        maxFailures: 3,
        lostAfter: const Duration(seconds: 2));
  }

  final String id;
  final JamHost jam;
  late final OfferNode node;
  late final JamGuest guest;
  late final int port;
  final _polls = StreamController<String?>.broadcast();

  /// The identity token of every state poll this device receives as host.
  Stream<String?> get statePolls => _polls.stream;

  Future<void> start() async => port = await node.start();

  Future<JamJoinOutcome> joinThrough(Dev other) => guest.join(
      host: '127.0.0.1',
      port: other.port,
      ownDeviceId: id,
      ownName: id,
      ownPort: port,
      timeout: const Duration(seconds: 5));

  Future<void> stop() async {
    await guest.dispose();
    await node.stop();
  }
}

/// The first state of [g] that passes [test], the one it already has included.
Future<JamState> reach(JamGuest g, bool Function(JamState) test) {
  final now = g.state;
  if (now != null && test(now)) return Future.value(now);
  return g.states
      .firstWhere(test)
      .timeout(const Duration(seconds: 5), onTimeout: () => g.state!);
}

void main() {
  feederTests();
  late List<Dev> devs;
  late Directory dir;

  Future<Dev> make(String id, {DateTime Function()? now}) async {
    final d = Dev(id, now: now);
    await d.start();
    devs.add(d);
    return d;
  }

  setUp(() {
    devs = [];
    dir = Directory.systemTemp.createTempSync('jamsim');
  });

  tearDown(() async {
    for (final d in devs) {
      await d.stop();
    }
    dir.deleteSync(recursive: true);
  });

  /// A guest accepts on behalf of its host, a host accepts itself.
  void autoAccept(Dev d) {
    d.jam.onRequest = (r) {
      if (d.jam.isGuest) {
        unawaited(d.guest.invite(r));
      } else {
        d.jam.accept(r.id);
      }
    };
  }

  test('five devices fill the session, a sixth is turned away', () async {
    final host = await make('host');
    autoAccept(host);
    final guests = [for (var i = 1; i <= 4; i++) await make('g$i')];
    for (final g in guests) {
      expect(await g.joinThrough(host), JamJoinOutcome.accepted, reason: g.id);
    }
    expect(host.jam.state!.participants.length, 5);

    final late = await make('late');
    expect(await late.joinThrough(host), JamJoinOutcome.busy);

    // every guest converges on the same roster
    for (final g in guests) {
      final s = await reach(g.guest, (s) => s.participants.length == 5);
      expect(s.participants.length, 5, reason: g.id);
    }
  });

  test('items from every guest are served by their owners to each other',
      () async {
    final host = await make('host');
    autoAccept(host);
    final a = await make('a');
    final b = await make('b');
    final c = await make('c');
    for (final g in [a, b, c]) {
      expect(await g.joinThrough(host), JamJoinOutcome.accepted);
    }
    final files = <String, File>{};
    for (final d in [host, a, b, c]) {
      final f = File('${dir.path}/${d.id}.mp3')
        ..writeAsBytesSync(d.id.codeUnits);
      files[d.id] = f;
      d.jam.resolveFile = (_) async => f.path;
    }
    // everybody queues one track
    host.jam.apply(const JamCommand.add(
        JamItem(id: 0, ownerDeviceId: 'host', title: 'h', ext: 'mp3')));
    for (final g in [a, b, c]) {
      final r = await g.guest.send(JamCommand.add(JamItem(
          id: 0, ownerDeviceId: g.id, title: g.id, ext: 'mp3', ref: g.id)));
      expect(r.isOk, true);
    }
    final s = host.jam.state!;
    expect(s.items.length, 4);

    // device c downloads every item from its owner, as a real output would
    final dio = Dio(BaseOptions(responseType: ResponseType.bytes));
    final sid = c.guest.files!.sessionId;
    for (final it in s.items) {
      final owner = s.participant(it.ownerDeviceId)!;
      final port = owner.id == 'host' ? host.port : owner.port;
      final r = await dio.get<List<int>>(
          'http://127.0.0.1:$port/jam/$sid/file/${it.id}',
          options: Options(headers: {jamFileHeader: c.guest.files!.fileToken}));
      expect(String.fromCharCodes(r.data!), owner.id, reason: it.title);
    }
    // the identity token must not open somebody else's files
    expect(
        () => dio.get<List<int>>(
            'http://127.0.0.1:${a.port}/jam/$sid/file/2',
            options: Options(headers: {jamFileHeader: c.guest.sessionToken})),
        throwsA(isA<DioException>()));
  });

  test('the guest that invited another one can drop without ending it',
      () async {
    var clock = DateTime(2026, 1, 1);
    final host = await make('host', now: () => clock);
    autoAccept(host);
    final a = await make('a');
    autoAccept(a);
    final b = await make('b');
    expect(await a.joinThrough(host), JamJoinOutcome.accepted);
    // b is let in by a, on behalf of the host
    expect(await b.joinThrough(a), JamJoinOutcome.accepted);
    expect(host.jam.memberIds, ['a', 'b']);
    expect(b.guest.files!.hostBase, 'http://127.0.0.1:${host.port}/jam');

    // a vanishes (process killed): the host keeps b and the session
    await a.stop();
    // Time passes on the host; b keeps polling, a does not: only a goes stale.
    clock = clock.add(const Duration(seconds: 80));
    final heard = host.statePolls.firstWhere((t) => t == b.guest.sessionToken);
    host.jam.apply(const JamCommand.volume(0.3)); // b's long poll returns, b polls again
    await heard.timeout(const Duration(seconds: 5));
    expect(host.jam.dropStale(const Duration(seconds: 75)), ['a']);
    expect(host.jam.state!.ended, false);
    expect(host.jam.memberIds, ['b']);

    // b still works against the host
    final r = await b.guest.send(const JamCommand.volume(0.4));
    expect(r.isOk, true);
    expect(host.jam.state!.volume, 0.4);
  });

  test('host ending reaches every guest; token reuse is rejected', () async {
    final host = await make('host');
    autoAccept(host);
    final a = await make('a');
    final b = await make('b');
    await a.joinThrough(host);
    await b.joinThrough(host);
    final ended = [
      for (final g in [a, b])
        g.guest.states.firstWhere((s) => s.ended).timeout(const Duration(seconds: 5))
    ];
    // a cannot act as b: commands are attributed by token, not by claim
    final r = await a.guest.send(JamCommand.add(const JamItem(
        id: 0, ownerDeviceId: 'b', title: 'x', ext: 'mp3')));
    expect(r.error, JamError.forbidden);

    host.jam.endSession();
    await Future.wait(ended);
    expect(host.jam.state!.ended, true);
  });
}

/// Host and guests in memory: the reducer plus one feeder per device (66.4, 66.5).
class _Sim {
  _Sim(List<String> ids, {Map<String, int> parts = const {}, this.suggested = const {}}) {
    s = JamState(
      hostDeviceId: ids.first,
      outputDeviceId: ids.first,
      mode: JamMode.together,
      participants: [for (final i in ids) JamParticipant(id: i, name: i)],
    );
    for (final id in ids) {
      feeders[id] = JamPartFeeder(
        ownId: id,
        part: [for (var n = 0; n < (parts[id] ?? 0); n++) '$id$n'],
        send: (c) async => send(id, c),
        itemOf: (k) async =>
            JamItem(id: 0, ownerDeviceId: id, title: k, ext: 'mp3', partKey: k),
        suggest: (_) async => suggested.contains(id)
            ? JamItem(
                id: 0,
                ownerDeviceId: id,
                title: 'sug${++_n}',
                ext: 'mp3',
                suggested: true)
            : null,
      );
    }
  }

  late JamState s;
  final Set<String> suggested;
  final feeders = <String, JamPartFeeder>{};
  var _n = 0;

  JamResult send(String from, JamCommand c) {
    final r = applyCommand(s, c, from: from, nowMs: 0);
    if (r.isOk) {
      s = r.state!;
      for (final f in feeders.values) {
        unawaited(f.update(s));
      }
    }
    return r;
  }

  /// Until no feeder has anything left to send.
  Future<void> settle() async {
    for (var v = -1; v != s.version;) {
      v = s.version;
      await Future.wait([for (final f in feeders.values) f.update(s)]);
    }
  }
}

void feederTests() {
  group('part feeder', () {
    test('host and two guests with 300 tracks each: 500 played, none lost, none twice, at most 200', () async {
      final sim = _Sim(['h', 'a', 'b'], parts: {'h': 300, 'a': 300, 'b': 300});
      await sim.settle();
      expect(sim.s.items.length, lessThanOrEqualTo(maxJamItems));
      final played = <String>[];
      for (var n = 0; n < 500; n++) {
        played.add(sim.s.current!.partKey!);
        sim.send('h', JamCommand.trackEnded(sim.s.current!.id));
        await sim.settle();
        expect(sim.s.items.length, lessThanOrEqualTo(maxJamItems), reason: 'step $n');
      }
      expect(played.toSet().length, 500);
      for (final id in ['h', 'a', 'b']) {
        // Each part plays in its own order.
        final mine = [for (final k in played) if (k.startsWith(id)) int.parse(k.substring(1))];
        expect(mine, [...mine]..sort(), reason: id);
      }
      final inJam = [for (final i in sim.s.items) i.partKey!];
      final left = [for (final f in sim.feeders.values) ...f.unsent];
      final all = [...played, sim.s.current!.partKey!, ...inJam, ...left];
      // current is also in inJam: every key of the 900 appears, and only the ones in the Jam twice.
      expect(all.toSet().length, 900);
      expect(inJam.toSet().length, inJam.length);
      expect(left.toSet().intersection({...played, ...inJam}), isEmpty);
    });

    test('the fill stops 20 seats short of the limit; the keys stay in the part and enter as tracks are played', () async {
      final sim = _Sim(['h', 'a', 'b'], parts: {'h': 100, 'a': 100, 'b': 100});
      await sim.settle();
      int total() => sim.s.items.length + [for (final f in sim.feeders.values) ...f.unsent].length;
      const free = maxJamItems - jamManualSeats;
      expect(sim.s.items.length, free);
      expect(total(), 300);
      sim.send('h', JamCommand.trackEnded(sim.s.current!.id));
      await sim.settle();
      expect(sim.s.items.length, greaterThan(free)); // a seat opened: they are counted from the current track
      expect(sim.s.items.length, lessThan(maxJamItems));
      expect(total(), 300); // nothing lost
    });

    test('a track removed from the Jam unplayed stays removed, by the host or by its owner', () async {
      final sim = _Sim(['h', 'a'], parts: {'h': 3, 'a': 5});
      await sim.settle();
      final gone = sim.s.items.lastWhere((i) => i.partKey == 'a3');
      sim.send('h', JamCommand.remove(gone.id)); // the host removes a guest track
      await sim.settle();
      expect(sim.s.items.where((i) => i.partKey == 'a3'), isEmpty);
      final mine = sim.s.items.lastWhere((i) => i.partKey == 'a2');
      sim.feeders['a']!.forget('a2'); // before the state change reaches the feeder
      sim.send('a', JamCommand.remove(mine.id));
      await sim.settle();
      expect(sim.s.items.where((i) => i.partKey == 'a2'), isEmpty);
    });

    test('an empty part gets one suggestion at its turn, never two while waiting', () async {
      final sim = _Sim(['h', 'a'], parts: {'h': 4}, suggested: {'a'});
      await sim.settle();
      List<JamItem> mineA() => [
            for (final (n, i) in sim.s.items.indexed)
              if (n > sim.s.currentIndex && i.ownerDeviceId == 'a') i,
          ];
      expect(mineA().length, 1);
      expect(mineA().single.suggested, true);
      for (var n = 0; n < 3; n++) {
        sim.send('h', JamCommand.trackEnded(sim.s.current!.id));
        await sim.settle();
        expect(mineA().length, lessThanOrEqualTo(1));
      }
      expect(sim.s.items.where((i) => i.suggested).length, greaterThan(1));
    });

    test('stops in host mode and resumes in together mode', () async {
      final sim = _Sim(['h', 'a'], parts: {'a': 3});
      sim.s = sim.s.copyWith(mode: JamMode.host);
      await sim.settle();
      expect(sim.s.items, isEmpty);
      sim.send('h', const JamCommand.setMode(JamMode.together));
      await sim.settle();
      expect(sim.s.items.length, 3);
    });
  });
}

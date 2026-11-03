import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/settings/jam_secret_store.dart';
import 'package:codecore/services/jam/jam_gate.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

void main() {
  late DateTime now;
  late Map<String, String> data;
  late JamGate gate;

  // "Restart": a new gate over the same map.
  Future<JamGate> open() async {
    final g = JamGate(MemoryJamSecretStore(data), now: () => now);
    await g.ready;
    return g;
  }

  setUp(() async {
    now = DateTime(2026, 1, 1, 12);
    data = {};
    gate = await open();
  });

  test('2 per minute per id, sliding window', () {
    expect(gate.allow('a'), isTrue);
    now = now.add(const Duration(seconds: 10));
    expect(gate.allow('a'), isTrue);
    expect(gate.allow('a'), isFalse);
    expect(gate.allow('b'), isTrue);
    now = now.add(const Duration(seconds: 50));
    expect(gate.allow('a'), isTrue); // the first one left the window
  });

  test('suspend 15 min survives a restart and expires', () async {
    gate.suspend('a', 'Phone', const Duration(minutes: 15));
    expect(gate.isMuted('a'), isTrue);
    gate = await open();
    now = now.add(const Duration(minutes: 15));
    expect(gate.isMuted('a'), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(gate.isMuted('a'), isFalse);
    expect(gate.suspended, isEmpty);
  });

  test('suspension until the end of the Jam is dropped at the end and at start', () async {
    gate.suspend('a', 'A', null);
    gate.suspend('b', 'B', null);
    gate.clearEndOfJam();
    expect(gate.isMuted('a'), isFalse);
    gate.suspend('c', 'C', null);
    gate = await open();
    expect(gate.isMuted('c'), isFalse);
  });

  test('block and unblock persist across restarts', () async {
    gate.block('a', 'Phone');
    gate = await open();
    expect(gate.isMuted('a'), isTrue);
    expect(gate.blocked.single.name, 'Phone');
    gate.unblock('a');
    gate = await open();
    expect(gate.isMuted('a'), isFalse);
  });

  test('listeners are told when the saved lists finish loading', () async {
    gate.block('a', 'Phone');
    final g = JamGate(MemoryJamSecretStore(data), now: () => now);
    var calls = 0;
    g.addListener(() => calls++);
    await g.ready;
    expect(calls, 1);
    expect(g.blocked.single.id, 'a');
  });

  test('invite of a muted id is refused with 409 and adds nobody', () async {
    final h = JamHost(deviceId: 'h', deviceName: 'PC', now: () => now, gate: gate);
    final a = h.addMember(id: 'a', name: 'A', host: '192.168.1.6', port: 1000)!;
    gate.block('x', 'X');
    final r = await h.buildRouter(clientIp: (_) => '192.168.1.5').call(Request(
        'POST', Uri.parse('http://x/${a.sid}/invite'),
        body: jsonEncode({'id': 'x', 'name': 'X', 'host': '192.168.1.7', 'port': 1001}),
        headers: {'x-jam-token': a.token}));
    expect(r.statusCode, 409);
    expect(h.memberIds, ['a']);
  });

  group('admitRequest', () {
    late JamHost h;
    final seen = <String>[];
    JamAdmission adm(String id) =>
        h.admitRequest(id: id, name: 'P', port: 4000, token: 'tok-12345');
    int code(JamAdmission a) => switch (a.status) {
          JamAdmitStatus.accepted => 202,
          JamAdmitStatus.full || JamAdmitStatus.busy => 409,
          JamAdmitStatus.tooMany => 429,
          JamAdmitStatus.bad => 400,
        };

    setUp(() {
      seen.clear();
      h = JamHost(deviceId: 'h', deviceName: 'PC', now: () => now, gate: gate)
        ..onRequest = (r) => seen.add(r.fromId);
    });

    test('silent request: 202, not shown, not busy, expires', () async {
      gate.suspend('s', 'S', null);
      final r = adm('s');
      expect(code(r), 202);
      expect(r.request!.id, isNotEmpty);
      expect(seen, isEmpty);
      expect(code(adm('ok')), 202); // not busy
      expect(seen, ['ok']);
      final silent = h.requests.values.firstWhere((q) => q.silent);
      now = now.add(jamRequestTtl + const Duration(seconds: 1));
      h.expire();
      expect(silent.status, JamRequestStatus.expired);
    });

    test('a blocked id is rate-limited like anyone', () {
      gate.block('x', 'X');
      for (var i = 0; i < 2; i++) {
        expect(code(adm('x')), 202);
        h.decline(h.requests.values.last.id);
      }
      expect(code(adm('x')), 429);
    });

    test('a blocked id and a normal id get the same statuses, also after expiry', () async {
      gate.block('x', 'X');
      Future<List<int>> run(String id) async {
        final out = <int>[];
        String? rid;
        for (var i = 0; i < 2; i++) {
          final r = adm(id);
          out.add(code(r));
          if (r.request != null) rid = r.request!.id;
        }
        now = now.add(jamRequestTtl * 2 + const Duration(seconds: 1));
        h.expire();
        out.add(h.requests.containsKey(rid) ? 200 : 401);
        h.requests.clear();
        now = now.add(const Duration(minutes: 2));
        return out;
      }

      expect(await run('x'), await run('ok'));
    });

    test('clearSession drops end-of-Jam suspensions', () {
      gate.suspend('a', 'A', null);
      h.clearSession();
      expect(gate.isMuted('a'), isFalse);
    });

    test('third request in a minute from the same id is 429', () {
      for (var i = 0; i < 2; i++) {
        expect(code(adm('a')), 202);
        h.decline(h.requests.values.last.id);
      }
      expect(code(adm('a')), 429);
    });
  });

  test('suspend then block: the id is only in blocked', () {
    gate.suspend('a', 'A', null);
    gate.block('a', 'A');
    expect(gate.suspended, isEmpty);
    expect(gate.blocked.map((e) => e.id), ['a']);
  });

  test('a clock moved back by an hour does not freeze the window', () {
    expect(gate.allow('a'), isTrue);
    expect(gate.allow('a'), isTrue);
    expect(gate.allow('a'), isFalse);
    now = now.subtract(const Duration(hours: 1));
    expect(gate.allow('a'), isTrue);
  });

  test('a bad element drops only itself, a broken list not the other, end-of-Jam is cleared', () async {
    data[jamBlockedKey] = '[{"id":"b1","name":"B"},5,{"id":"b2","name":"B2","at":"2026-01-01T10:00:00.000"}]';
    data[jamSuspendedKey] = 'not json';
    gate = await open();
    expect(gate.blocked.map((e) => e.id), ['b1', 'b2']);
    data[jamBlockedKey] = 'broken';
    data[jamSuspendedKey] =
        '[{"id":"e","name":"E","until":null},{"name":"no id"},{"id":"s","name":"S","until":"2026-01-01T13:00:00.000"}]';
    gate = await open();
    expect(gate.blocked, isEmpty);
    expect(gate.suspended.map((e) => e.id), ['s']);
  });

  group('FileJamSecretStore', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('jamsecrets');
      addTearDown(() => dir.delete(recursive: true));
    });

    for (final junk in ['', '{"jamBlo', 'not json']) {
      test('an unreadable file ("$junk") starts empty', () async {
        File('${dir.path}/jam_secrets.json').writeAsStringSync(junk);
        final g = JamGate(FileJamSecretStore(dir.path), now: () => now);
        await g.ready;
        expect(g.blocked, isEmpty);
        expect(g.suspended, isEmpty);
      });
    }

    test('concurrent writes do not fail, the last wins, no .tmp is left', () async {
      final s = FileJamSecretStore(dir.path);
      await Future.wait([for (var i = 0; i < 5; i++) s.write('k', 'v$i')]);
      expect(await FileJamSecretStore(dir.path).read('k'), 'v4');
      expect(dir.listSync().map((e) => p.basename(e.path)), ['jam_secrets.json']);
    });
  });

  test('file store round trip, own file', () async {
    final dir = await Directory.systemTemp.createTemp('jamsecrets');
    addTearDown(() => dir.delete(recursive: true));
    await FileJamSecretStore(dir.path).write('k', 'v');
    expect(await FileJamSecretStore(dir.path).read('k'), 'v');
    expect(File('${dir.path}/jam_secrets.json').existsSync(), isTrue);
    expect(File('${dir.path}/shared_preferences.json').existsSync(), isFalse);
  });
}

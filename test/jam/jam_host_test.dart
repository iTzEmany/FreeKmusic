import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/settings/jam_secret_store.dart';
import 'package:codecore/services/jam/jam_gate.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/share/track_meta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

void main() {
  late JamHost host;
  late Handler h;
  var now = DateTime(2026, 1, 1, 12);
  final seen = <JamRequest>[];

  Future<Response> call(String method, String path,
      {Object? body, Map<String, String>? headers}) {
    return Future.sync(() => h(Request(
          method,
          Uri.parse('http://localhost/$path'),
          body: body == null ? null : jsonEncode(body),
          headers: headers,
        )));
  }

  Future<Map<String, dynamic>> json(Response r) async =>
      jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  Map<String, Object?> reqBody({String id = 'guest'}) => {
        'fromId': id,
        'fromName': 'Phone',
        'port': 4000,
        'token': 'reqtoken-123',
      };

  Future<({String sid, String token})> startSession() async {
    final r = await call('POST', 'request', body: reqBody());
    final rid = (await json(r))['requestId'] as String;
    expect(host.accept(rid), isNotNull);
    final st = await json(await call('GET', 'request/$rid',
        headers: {'x-token': 'reqtoken-123'}));
    expect(st['status'], 'accepted');
    return (sid: st['sessionId'] as String, token: st['token'] as String);
  }

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    seen.clear();
    host = JamHost(
        deviceId: 'host',
        deviceName: 'PC',
        now: () => now,
        pollWait: const Duration(milliseconds: 100))
      ..onRequest = seen.add;
    final router = host.buildRouter(clientIp: (_) => '192.168.1.50');
    h = router.call;
  });

  test('request is pending until the user accepts', () async {
    final r = await call('POST', 'request', body: reqBody());
    expect(r.statusCode, 202);
    expect(seen, hasLength(1));
    final rid = seen.single.id;
    var st = await json(await call('GET', 'request/$rid',
        headers: {'x-token': 'reqtoken-123'}));
    expect(st['status'], 'pending');
    expect(st.containsKey('token'), false);
    expect((await call('GET', 'request/$rid', headers: {'x-token': 'nope'}))
        .statusCode, 401);
    // a second request while one is pending
    expect((await call('POST', 'request', body: reqBody(id: 'other')))
        .statusCode, 409);
    host.decline(rid);
    st = await json(await call('GET', 'request/$rid',
        headers: {'x-token': 'reqtoken-123'}));
    expect(st['status'], 'declined');
  });

  test('open() starts the session without guests, idempotent; addMember after it does not reopen', () {
    host.open();
    expect(host.hosting, true);
    expect(host.state!.participants.map((p) => p.id), ['host']);
    final sid = host.sessionId;
    host.open();
    expect(host.sessionId, sid);
    final c = host.addMember(id: 'g', name: 'G', host: '1.2.3.4', port: 1);
    expect(c!.sid, sid);
    expect(host.state!.participants, hasLength(2));
  });

  test('request expires and refuses non-local', () async {
    await call('POST', 'request', body: reqBody());
    now = now.add(const Duration(minutes: 6));
    expect(host.accept(seen.single.id), isNull);
    final public = JamHost(deviceId: 'h', deviceName: 'h')
        .buildRouter(clientIp: (_) => '8.8.8.8');
    final r = await public.call(Request('POST', Uri.parse('http://x/request'),
        body: jsonEncode(reqBody())));
    expect(r.statusCode, 403);
  });

  test('state, commands, permissions and auth', () async {
    final s = await startSession();
    final auth = {'x-jam-token': s.token};
    expect((await call('GET', '${s.sid}/state')).statusCode, 401);
    expect((await call('GET', '${s.sid}/state',
            headers: {'x-jam-token': 'x' * 32}))
        .statusCode, 401);

    var st = await json(await call('GET', '${s.sid}/state?since=-1',
        headers: auth));
    final v0 = st['version'] as int;
    expect(v0, greaterThan(0));

    final add = JamCommand.add(const JamItem(
        id: 0, ownerDeviceId: 'guest', title: 'Song', ext: 'mp3', ref: '7'));
    final res = await call('POST', '${s.sid}/cmd', body: add.toJson(), headers: auth);
    expect(res.statusCode, 200);
    st = await json(res);
    expect(st['version'], v0 + 1);
    expect(host.state!.items.single.ownerDeviceId, 'guest');

    // guest can jump (D-160) but cannot end
    final jr = await call('POST', '${s.sid}/cmd',
        body: const JamCommand.jump(1).toJson(), headers: auth);
    expect(jr.statusCode, 200);
    final er = await call('POST', '${s.sid}/cmd',
        body: const JamCommand.end().toJson(), headers: auth);
    expect(er.statusCode, 403);
    // garbage
    expect((await call('POST', '${s.sid}/cmd', body: {'cmd': 'x'}, headers: auth))
        .statusCode, 400);
    // a second guest can join the running session
    expect((await call('POST', 'request', body: reqBody(id: 'g2'))).statusCode,
        202);
    expect(host.accept(seen.last.id), isNotNull);
    expect(host.memberIds, ['guest', 'g2']);
  });

  test('a leaving guest keeps its upcoming online items, loses the rest (D-93)', () async {
    await startSession();
    expect((await call('POST', 'request', body: reqBody(id: 'g2'))).statusCode, 202);
    host.accept(seen.last.id);
    JamItem item(String t, {String? ref, String? vid}) => JamItem(
        id: 0, ownerDeviceId: 'guest', title: t, ext: 'm4a', ref: ref, videoId: vid);
    host.apply(const JamCommand.add(JamItem(id: 0, ownerDeviceId: 'host', title: 'H', ext: 'mp3')),
        from: 'host');
    host.apply(JamCommand.add(item('lib', ref: '7')), from: 'guest');
    host.apply(JamCommand.add(item('yt', ref: 'yt:youtube:abc', vid: 'abc')), from: 'guest');
    host.apply(JamCommand.add(item('sc', ref: 'yt:soundcloud:9', vid: '9')), from: 'guest');

    host.removeMember('guest');

    // SoundCloud cannot be fetched again by the host: it goes.
    expect(host.state!.items.map((i) => i.title), ['H', 'yt']);
    expect(host.state!.items.last.ownerDeviceId, 'guest');
  });

  test('a leaving guest loses its fed part even when online: it takes it back by part key', () async {
    await startSession();
    expect((await call('POST', 'request', body: reqBody(id: 'g2'))).statusCode, 202);
    host.accept(seen.last.id);
    host.apply(const JamCommand.add(JamItem(id: 0, ownerDeviceId: 'host', title: 'H', ext: 'mp3')),
        from: 'host');
    JamItem yt(String t, {String? pk}) => JamItem(
        id: 0, ownerDeviceId: 'guest', title: t, ext: 'webm', ref: 'yt:youtube:$t', videoId: t, partKey: pk);
    host.apply(JamCommand.add(yt('fed', pk: '1')), from: 'guest');
    host.apply(JamCommand.add(yt('manual')), from: 'guest');

    host.removeMember('guest');

    expect(host.state!.items.map((i) => i.title), ['H', 'manual']);
  });

  test('a leaving guest keeps its online item when it is the current one', () async {
    await startSession();
    expect((await call('POST', 'request', body: reqBody(id: 'g2'))).statusCode, 202);
    host.accept(seen.last.id);
    host.apply(
        const JamCommand.add(JamItem(
            id: 0, ownerDeviceId: 'guest', title: 'cur', ext: 'm4a', ref: 'yt:youtube:abc', videoId: 'abc')),
        from: 'guest');
    expect(host.state!.currentIndex, 0);

    host.removeMember('guest');

    expect(host.state!.items.map((i) => i.title), ['cur']);
  });

  test('the only guest leaves with an online track: the Jam stays on the host (D-221)', () async {
    await startSession();
    host.apply(
      const JamCommand.add(
        JamItem(id: 0, ownerDeviceId: 'host', title: 'H', ext: 'mp3'),
      ),
      from: 'host',
    );
    host.apply(
      const JamCommand.add(
        JamItem(
          id: 0,
          ownerDeviceId: 'guest',
          title: 'yt',
          ext: 'm4a',
          ref: 'yt:youtube:abc',
          videoId: 'abc',
        ),
      ),
      from: 'guest',
    );

    host.removeMember('guest');

    expect(host.memberIds, isEmpty);
    expect(host.state!.ended, false);
    expect(host.state!.items.map((i) => i.title), ['H', 'yt']);
  });

  test('long poll wakes up on change and times out otherwise', () async {
    final s = await startSession();
    final auth = {'x-jam-token': s.token};
    final v0 = host.state!.version;
    final timeout = await call('GET', '${s.sid}/state?since=$v0', headers: auth);
    expect((await json(timeout))['version'], v0);

    final pending = call('GET', '${s.sid}/state?since=$v0', headers: auth);
    host.apply(const JamCommand.volume(0.5));
    expect((await json(await pending))['version'], v0 + 1);
  });

  test('end is visible to the guest and then clears', () async {
    final s = await startSession();
    host.endSession();
    final st = await json(await call('GET', '${s.sid}/state?since=0',
        headers: {'x-jam-token': s.token}));
    expect(st['ended'], true);
    host.clearSession();
    expect((await call('GET', '${s.sid}/state',
            headers: {'x-jam-token': s.token}))
        .statusCode, 401);
  });

  test('serves only queued items it owns, with Range', () async {
    final dir = Directory.systemTemp.createTempSync('jam');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File(p.join(dir.path, 'a.mp3'))..writeAsBytesSync(List.generate(100, (i) => i));
    host.resolveFile = (item) async => item.ref == 'mine' ? f.path : null;
    final s = await startSession();
    final auth = {'x-jam-file': host.fileToken!};
    host.apply(const JamCommand.add(
        JamItem(id: 0, ownerDeviceId: 'host', title: 'A', ext: 'mp3', ref: 'mine')));
    host.apply(const JamCommand.add(
        JamItem(id: 0, ownerDeviceId: 'host', title: 'B', ext: 'mp3', ref: 'secret')));

    final full = await call('GET', '${s.sid}/file/1', headers: auth);
    expect(full.statusCode, 200);
    expect((await full.read().expand((b) => b).toList()).length, 100);
    final part = await call('GET', '${s.sid}/file/1',
        headers: {...auth, 'range': 'bytes=10-19'});
    expect(part.statusCode, 206);
    // not in queue, unresolvable, no token
    expect((await call('GET', '${s.sid}/file/99', headers: auth)).statusCode, 404);
    expect((await call('GET', '${s.sid}/file/2', headers: auth)).statusCode, 404);
    expect((await call('GET', '${s.sid}/file/1')).statusCode, 401);
    // item owned by the guest is not served by the host
    host.apply(
        const JamCommand.add(
            JamItem(id: 0, ownerDeviceId: 'guest', title: 'C', ext: 'mp3', ref: 'mine')),
        from: 'guest');
    expect((await call('GET', '${s.sid}/file/3', headers: auth)).statusCode, 404);
  });

  test('serves the TrackMeta of queued owned items, library and cached', () async {
    host.resolveMeta = (item) async => switch (item.ref) {
          'lib' => const TrackMeta(title: 'Lib', isrc: 'USRC17607839'),
          'yt:abcdefghijk' => const TrackMeta(title: 'Cached', youtubeId: 'abcdefghijk'),
          _ => null,
        };
    final s = await startSession();
    final auth = {'x-jam-file': host.fileToken!};
    for (final ref in ['lib', 'yt:abcdefghijk', 'none']) {
      host.apply(JamCommand.add(
          JamItem(id: 0, ownerDeviceId: 'host', title: ref, ext: 'mp3', ref: ref)));
    }
    expect((await json(await call('GET', '${s.sid}/meta/1', headers: auth)))['isrc'],
        'USRC17607839');
    expect((await json(await call('GET', '${s.sid}/meta/2', headers: auth)))['youtubeId'],
        'abcdefghijk');
    // callback says unknown, not in queue, wrong sid, no token
    expect((await call('GET', '${s.sid}/meta/3', headers: auth)).statusCode, 404);
    expect((await call('GET', '${s.sid}/meta/99', headers: auth)).statusCode, 404);
    expect((await call('GET', 'wrong/meta/1', headers: auth)).statusCode, 401);
    expect((await call('GET', '${s.sid}/meta/1')).statusCode, 401);
  });

  test('serves the cover of queued owned items', () async {
    final img = File(p.join(Directory.systemTemp.createTempSync('jc').path, 'c.jpg'))
      ..writeAsBytesSync([1, 2, 3]);
    host.resolveCover = (item) async => item.ref == 'lib' ? img.path : null;
    final s = await startSession();
    final auth = {'x-jam-file': host.fileToken!};
    for (final ref in ['lib', 'none']) {
      host.apply(JamCommand.add(
          JamItem(id: 0, ownerDeviceId: 'host', title: ref, ext: 'mp3', ref: ref)));
    }
    final ok = await call('GET', '${s.sid}/cover/1', headers: auth);
    expect(ok.statusCode, 200);
    expect(await ok.read().expand((c) => c).toList(), [1, 2, 3]);
    expect((await call('GET', '${s.sid}/cover/2', headers: auth)).statusCode, 404);
    expect((await call('GET', 'wrong/cover/1', headers: auth)).statusCode, 401);
  });

  test('the guest that plays for the speaker leaves: speakerAway, the host takes over (D-220)', () {
    host.open();
    host.makeSpeaker();
    host.addMember(id: 'g', name: 'Phone', host: '192.168.1.50', port: 4000);
    host.apply(const JamCommand.speakerAway());
    expect(host.apply(const JamCommand.offerSpeaker(), from: 'g').isOk, isTrue);
    expect(host.state!.outputs, ['g']);
    host.removeMember('g');
    final s = host.state!;
    expect(s.speaker, isTrue);
    expect(s.speakerAwaySince, isNotNull);
    expect(s.outputs, ['host']);
    expect(s.playing, isFalse);
  });

  test('makeSpeaker turns a running Jam into the speaker one', () {
    host.addMember(id: 'g', name: 'Phone', host: '192.168.1.50', port: 4000);
    host.makeSpeaker();
    expect(host.state!.speaker, isTrue);
    expect(host.state!.outputs, ['host']);
  });

  test('makeSpeaker on a Jam playing on a guest or on several outputs: only the host', () {
    host.addMember(id: 'g', name: 'Phone', host: '192.168.1.50', port: 4000);
    host.apply(const JamCommand.setOutput('g'));
    expect(host.state!.outputs, ['g']);
    host.makeSpeaker();
    expect(host.state!.outputs, ['host']);

    final other = JamHost(deviceId: 'host', deviceName: 'PC', now: () => now);
    other.addMember(id: 'g', name: 'Phone', host: '192.168.1.50', port: 4000);
    other.apply(const JamCommand.setOutputs(['host', 'g']));
    expect(other.state!.outputs, hasLength(2));
    other.makeSpeaker();
    expect(other.state!.outputs, ['host']);
  });

  test('a playback command with the speaker away is a 409 "no speaker"', () async {
    final s = await startSession();
    host.makeSpeaker();
    host.apply(const JamCommand.speakerAway());
    final r = await call('POST', '${s.sid}/cmd',
        body: const JamCommand.play().toJson(), headers: {'x-jam-token': s.token});
    expect(r.statusCode, 409);
    expect(await r.readAsString(), 'no speaker');
  });

  group('remote guests', () {
    String join(String id, {bool remote = true}) {
      final a = host.admitRequest(
          id: id, name: id, remote: remote, ttl: jamRemoteRequestTtl,
          port: remote ? null : 4000, token: remote ? null : 'reqtoken-123');
      expect(a.status, JamAdmitStatus.accepted);
      expect(host.accept(a.request!.id), isNotNull);
      return id;
    }

    test('a friend goes ahead of a stranger, but a second friend does not jump the first', () {
      JamAdmission adm(String id, {bool friend = false}) =>
          host.admitRequest(id: id, name: id, remote: true, friend: friend);
      final stranger = adm('s').request!;
      final f1 = adm('f1', friend: true);
      expect(stranger.status, JamRequestStatus.expired);
      expect(f1.status, JamAdmitStatus.accepted);
      final f2 = adm('f2', friend: true);
      expect(f2.status, JamAdmitStatus.busy);
      expect(f1.request!.status, JamRequestStatus.pending);
    });

    test('autoAccept without friend goes to the sheet, not to the automatic acceptance', () {
      final asked = <String>[], auto = <String>[];
      host.onRequest = (r) => asked.add(r.fromId);
      host.onAutoAccept = (r) {
        auto.add(r.fromId);
      };
      host.admitRequest(id: 'x', name: 'X', remote: true, autoAccept: true);
      expect(asked, ['x']);
      expect(auto, isEmpty);
    });

    test('a remote request needs no port or token; a LAN one does', () {
      expect(host.admitRequest(id: 'r', name: 'R', remote: true).status, JamAdmitStatus.accepted);
      expect(host.admitRequest(id: 'l', name: 'L').status, JamAdmitStatus.bad);
    });

    test('accept makes a remote participant, rem in the JSON only when true', () {
      join('r');
      final p = host.state!.participant('r')!;
      expect(p.remote, isTrue);
      expect(p.toJson()['rem'], true);
      expect(host.state!.participant('host')!.toJson().containsKey('rem'), isFalse);
      expect(JamParticipant.tryParse({'id': 'a', 'name': 'A', 'host': '', 'port': 0})!.remote, isFalse);
      expect(JamState.tryParse(host.state!.toJson())!.participant('r')!.remote, isTrue);
    });

    test('a remote request ends after 60 s, a LAN one keeps jamRequestTtl', () {
      final r = host.admitRequest(id: 'r', name: 'R', remote: true).request!;
      now = now.add(const Duration(seconds: 61));
      host.expire();
      expect(r.status, JamRequestStatus.expired);
      final l = host.admitRequest(id: 'l', name: 'L', port: 4000, token: 'reqtoken-123').request!;
      now = now.add(const Duration(minutes: 4));
      host.expire();
      expect(l.status, JamRequestStatus.pending);
    });

    test('expire notifies when a request expires', () async {
      host.admitRequest(id: 'r', name: 'R', remote: true);
      var n = 0;
      final sub = host.changes.listen((_) => n++);
      host.expire();
      await Future<void>.delayed(Duration.zero);
      expect(n, 0);
      now = now.add(const Duration(seconds: 61));
      host.expire();
      await Future<void>.delayed(Duration.zero);
      expect(n, 1);
      await sub.cancel();
    });

    test('a guest rejoining with the other transport gets a new token and flag', () {
      join('g', remote: false);
      final t = host.addMember(id: 'g', name: 'g', remote: true)!.token;
      expect(host.state!.participant('g')!.remote, isTrue);
      expect(host.addMember(id: 'g', name: 'g', remote: true)!.token, t);
    });

    test('a remote request id with an empty x-token does not leak tokens', () async {
      final r = host.admitRequest(id: 'r', name: 'R', remote: true).request!;
      host.accept(r.id);
      final res = await call('GET', 'request/${r.id}', headers: {'x-token': ''});
      expect(res.statusCode, 401);
    });

    test('unreachable after 60 s, touch clears it, removed after 10 min', () {
      join('r');
      join('lan', remote: false);
      now = now.add(const Duration(seconds: 61));
      expect(host.unreachableIds(), ['r']); // a LAN guest is never flagged
      host.touch('r');
      expect(host.unreachableIds(), isEmpty);
      now = now.add(const Duration(minutes: 9, seconds: 59));
      expect(host.dropStale(const Duration(seconds: 75)), ['lan']);
      now = now.add(const Duration(seconds: 2));
      expect(host.dropStale(const Duration(seconds: 75)), ['r']);
      expect(host.memberIds, isEmpty);
    });

    test('a remote cannot be an output, nor offer the speaker', () {
      join('r');
      join('lan', remote: false);
      expect(host.apply(const JamCommand.setOutput('r')).error, JamError.forbidden);
      expect(host.apply(const JamCommand.setOutputs(['lan', 'r'])).error, JamError.forbidden);
      expect(host.apply(const JamCommand.setOutput('lan')).isOk, isTrue);
      host.makeSpeaker();
      host.apply(const JamCommand.speakerAway());
      expect(host.apply(const JamCommand.offerSpeaker(), from: 'r').error, JamError.forbidden);
    });

    test('the sixth participant is full, LAN and remote together', () {
      for (var i = 0; i < 4; i++) {
        join('r$i', remote: i.isEven);
      }
      expect(host.admitRequest(id: 'x', name: 'X', remote: true).status, JamAdmitStatus.full);
    });

    test('gate.allow is checked before full and busy', () {
      final g = JamGate(MemoryJamSecretStore({}), now: () => now);
      final h2 = JamHost(deviceId: 'h', deviceName: 'H', now: () => now, gate: g);
      for (var i = 0; i < 2; i++) {
        h2.admitRequest(id: 'a', name: 'A', remote: true);
      }
      // 'a' is pending (busy for anybody else), yet a third try says tooMany, not busy.
      expect(h2.admitRequest(id: 'a', name: 'A', remote: true).status, JamAdmitStatus.tooMany);
      expect(h2.admitRequest(id: 'b', name: 'B', remote: true).status, JamAdmitStatus.busy);
    });
  });
}

import 'dart:math';

import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/jam_online_adder.dart';
import 'package:codecore/services/jam/jam_state.dart';
import 'package:flutter_test/flutter_test.dart';

const host = 'host', guest = 'guest';

JamItem item(String owner,
        {String title = 't', int dur = 100000, bool inherited = false}) =>
    JamItem(
        id: 0,
        ownerDeviceId: owner,
        title: title,
        ext: 'mp3',
        durationMs: dur,
        inherited: inherited);

/// Host queue: current track 'cur' followed by [n] inherited tracks.
JamState seeded(int n) {
  var s = ok(start(), JamCommand.add(item(host, title: 'cur')), host);
  for (var i = 0; i < n; i++) {
    s = ok(s, JamCommand.add(item(host, title: 'i$i', inherited: true)), host);
  }
  return s;
}

JamState start() => const JamState(hostDeviceId: host, outputDeviceId: host);

JamState ok(JamState s, JamCommand c, String from, {int now = 1000}) {
  final r = applyCommand(s, c, from: from, nowMs: now);
  expect(r.isOk, true, reason: '${r.error}');
  return r.state!;
}

JamError? err(JamState s, JamCommand c, String from) =>
    applyCommand(s, c, from: from, nowMs: 1000).error;

void main() {
  remoteTests();
  speakerTests();
  videoIdTests();
  togetherTests();
  unsafeIdsTests();
  test('add assigns ids, selects first, bumps version', () {
    var s = ok(start(), JamCommand.add(item(host)), host);
    s = ok(s, JamCommand.add(item(guest)), guest);
    expect(s.items.map((i) => i.id), [1, 2]);
    expect(s.currentIndex, 0);
    expect(s.version, 2);
  });

  test('host next and jump move the index, start playing and bump version', () {
    var s = ok(start(), JamCommand.add(item(host)), host);
    s = ok(s, JamCommand.add(item(host)), host);
    s = ok(s, JamCommand.add(item(host)), host);
    final v = s.version;
    s = ok(s, const JamCommand.jump(2), host);
    expect(s.currentIndex, 1);
    expect(s.playing, true);
    expect(s.version, v + 1);
    s = ok(s, const JamCommand.next(), host);
    expect(s.currentIndex, 2);
    expect(s.playing, true);
    expect(s.version, v + 2);
  });

  test('ospite può next/jump (D-160)', () {
    var s = ok(start(), JamCommand.add(item(host)), host);
    s = ok(s, JamCommand.add(item(host)), host);
    s = ok(s, JamCommand.add(item(host)), host);
    s = ok(s, const JamCommand.jump(2), guest);
    expect(s.currentIndex, 1);
    expect(s.playing, true);
    s = ok(s, const JamCommand.next(), guest);
    expect(s.currentIndex, 2);
    expect(err(s, const JamCommand.jump(99), guest), JamError.notFound);
  });

  group('jamPreviousCommand', () {
    JamState at(int index, int posMs) => seeded(2).copyWith(
        currentIndex: index, positionMs: posMs, positionAt: 1000, playing: true);

    test('precedente > 3 s → seek(0)', () {
      final c = jamPreviousCommand(at(1, 0), 1000 + 3001);
      expect(c.type, JamCommandType.seek);
      expect(c.positionMs, 0);
    });

    test('≤ 3 s → jump al precedente', () {
      final s = at(1, 0);
      final c = jamPreviousCommand(s, 1000 + 3000);
      expect(c.type, JamCommandType.jump);
      expect(c.itemId, s.items[0].id);
    });

    test('primo brano → seek(0)', () {
      expect(jamPreviousCommand(at(0, 0), 1000).type, JamCommandType.seek);
    });
  });

  group('previous decided by the host (R-95)', () {
    JamState host2() => seeded(2).copyWith(playing: true, positionAt: 1000);

    test('next then previous within 3 s: the host state plays the item before from 0', () {
      var s = ok(host2(), const JamCommand.next(), guest, now: 1000);
      s = ok(s, const JamCommand.previous(), guest, now: 2000);
      expect(s.currentIndex, 0);
      expect(s.positionMs, 0);
      expect(s.playing, true);
    });

    test('after 3 s it restarts the current item', () {
      var s = ok(host2(), const JamCommand.next(), host, now: 1000);
      s = ok(s, const JamCommand.previous(), guest, now: 1000 + 3500);
      expect(s.currentIndex, 1);
      expect(s.positionMs, 0);
    });

    test('on the first item it restarts it; with no item it changes nothing', () {
      final s = ok(host2(), const JamCommand.previous(), guest);
      expect(s.currentIndex, 0);
      expect(s.positionMs, 0);
      final empty = ok(start(), const JamCommand.previous(), guest);
      expect(empty.version, start().version);
      expect(empty.items, isEmpty);
    });

    test('previous JSON round trip', () {
      expect(const JamCommand.previous().toJson(), {'cmd': 'previous'});
      expect(JamCommand.tryParse({'cmd': 'previous'})!.type, JamCommandType.previous);
    });
  });

  test('next and jump messages keep their exact JSON', () {
    expect(const JamCommand.next().toJson(), {'cmd': 'next'});
    expect(const JamCommand.jump(7).toJson(), {'cmd': 'jump', 'itemId': 7});
    expect(JamCommand.tryParse({'cmd': 'jump', 'itemId': 7})!.itemId, 7);
    expect(JamCommand.tryParse({'cmd': 'next'})!.type, JamCommandType.next);
  });

  test('remove keeps current index coherent', () {
    var s = start();
    for (var i = 0; i < 3; i++) {
      s = ok(s, JamCommand.add(item(host)), host);
    }
    s = ok(s, const JamCommand.jump(3), host);
    s = ok(s, const JamCommand.remove(1), host);
    expect(s.currentIndex, 1);
    expect(s.current!.id, 3);
    s = ok(s, const JamCommand.remove(3), host);
    expect(s.currentIndex, 0);
    expect(s.current!.id, 2);
  });

  test('guest removes only own, not the current one', () {
    var s = ok(start(), JamCommand.add(item(host)), host);
    s = ok(s, JamCommand.add(item(guest)), guest);
    s = ok(s, JamCommand.add(item(guest)), guest);
    expect(err(s, const JamCommand.remove(1), guest), JamError.forbidden);
    s = ok(s, const JamCommand.remove(2), guest);
    expect(s.items.length, 2);
    s = ok(s, const JamCommand.jump(3), host);
    expect(err(s, const JamCommand.remove(3), guest), JamError.forbidden);
  });

  test('move preserves the playing item', () {
    var s = start();
    for (var i = 0; i < 3; i++) {
      s = ok(s, JamCommand.add(item(host)), host);
    }
    s = ok(s, const JamCommand.move(3, 0), guest);
    expect(s.items.map((i) => i.id), [3, 1, 2]);
    expect(s.current!.id, 1);
    expect(err(s, const JamCommand.move(1, 9), guest), JamError.invalid);
  });

  test('position math across play/pause', () {
    var s = ok(start(), JamCommand.add(item(host)), host, now: 0);
    s = ok(s, const JamCommand.play(), host, now: 0);
    expect(s.positionAtTime(5000), 5000);
    s = ok(s, const JamCommand.pause(), guest, now: 5000);
    expect(s.positionAtTime(9000), 5000);
    expect(err(s, const JamCommand.seek(999999), guest), JamError.invalid);
    s = ok(s, const JamCommand.seek(20000), guest, now: 9000);
    expect(s.positionMs, 20000);
  });

  test('setOutput only host or requester; version monotonic', () {
    var s = ok(start(), JamCommand.add(item(host)), host);
    final v = s.version;
    s = ok(s, const JamCommand.setOutput(guest), guest);
    expect(s.outputDeviceId, guest);
    expect(s.version, greaterThan(v));
    expect(err(s, const JamCommand.setOutput('stranger'), guest),
        JamError.invalid);
  });

  test('trackEnded advances once; stale id ignored', () {
    var s = start();
    s = ok(s, JamCommand.add(item(host)), host);
    s = ok(s, JamCommand.add(item(host)), host);
    s = ok(s, const JamCommand.trackEnded(1), guest);
    expect(s.currentIndex, 1);
    final again = ok(s, const JamCommand.trackEnded(1), guest);
    expect(again.currentIndex, 1);
    s = ok(s, const JamCommand.trackEnded(2), guest);
    expect(s.playing, false);
  });

  test('limit and end', () {
    var s = start();
    for (var i = 0; i < maxJamItems; i++) {
      s = ok(s, JamCommand.add(item(host)), host);
    }
    expect(err(s, JamCommand.add(item(host)), host), JamError.full);
    expect(err(s, const JamCommand.end(), guest), JamError.forbidden);
    s = ok(s, const JamCommand.end(), host);
    expect(err(s, const JamCommand.play(), host), JamError.ended);
  });

  test('json round trip and strict parsing', () {
    var s = ok(start(), JamCommand.add(item(host, title: 'A')), host);
    s = ok(s, const JamCommand.play(), host);
    final back = JamState.tryParse(s.toJson())!;
    expect(back.items.single.title, 'A');
    expect(back.version, s.version);
    expect(JamState.tryParse({'version': 'x'}), isNull);
    expect(JamCommand.tryParse({'cmd': 'nope'}), isNull);
    expect(
        JamItem.tryParse({'id': 1, 'owner': 'a', 'title': 'x', 'ext': 'exe'}),
        isNull);
    final c = JamCommand.tryParse(JamCommand.add(item(guest)).toJson())!;
    expect(c.type, JamCommandType.add);
  });

  test('guest add lands right after current, before inherited items', () {
    final s = ok(seeded(2), JamCommand.add(item(guest, title: 'g')), guest);
    expect(s.items.map((i) => i.title), ['cur', 'g', 'i0', 'i1']);
    expect(s.currentIndex, 0);
  });

  test('second add lands after the first add', () {
    var s = ok(seeded(2), JamCommand.add(item(guest, title: 'g1')), guest);
    s = ok(s, JamCommand.add(item(host, title: 'h2')), host);
    expect(s.items.map((i) => i.title), ['cur', 'g1', 'h2', 'i0', 'i1']);
  });

  test('move: inherited track dragged into the added block becomes added', () {
    var s = ok(seeded(2), JamCommand.add(item(guest, title: 'a1')), guest);
    s = ok(s, JamCommand.add(item(guest, title: 'a2')), guest);
    s = ok(s, JamCommand.move(s.items[3].id, 1), host);
    expect(s.items[1].title, 'i0');
    expect(s.items[1].inherited, false);
    s = ok(s, JamCommand.add(item(guest, title: 'b')), guest);
    expect(s.items.map((i) => i.title), ['cur', 'i0', 'a1', 'a2', 'b', 'i1']);
  });

  test('move: added track dragged to the end becomes inherited', () {
    var s = ok(seeded(1), JamCommand.add(item(guest, title: 'a')), guest);
    s = ok(s, JamCommand.move(s.items[1].id, 2), host);
    expect(s.items.last.title, 'a');
    expect(s.items.last.inherited, true);
  });

  test('add after next lands right after the new current', () {
    var s = ok(seeded(2), const JamCommand.next(), host);
    s = ok(s, JamCommand.add(item(guest, title: 'g')), guest);
    expect(s.items.map((i) => i.title), ['cur', 'i0', 'g', 'i1']);
  });

  test('add when current is the last item goes to the end', () {
    var s = ok(seeded(1), const JamCommand.next(), host);
    s = ok(s, JamCommand.add(item(guest, title: 'g')), guest);
    expect(s.items.map((i) => i.title), ['cur', 'i0', 'g']);
  });

  test('full queue: add evicts the last inherited item', () {
    final s0 = seeded(maxJamItems - 1);
    expect(s0.items.length, maxJamItems);
    final s = ok(s0, JamCommand.add(item(guest, title: 'g')), guest);
    expect(s.items.length, maxJamItems);
    expect(s.items[1].title, 'g');
    expect(s.items.last.title, 'i${maxJamItems - 3}');
  });

  test('full queue without inherited items after current fails', () {
    var s = start();
    for (var i = 0; i < maxJamItems; i++) {
      s = ok(s, JamCommand.add(item(host)), host);
    }
    expect(err(s, JamCommand.add(item(guest)), guest), JamError.full);
  });

  test('guest cannot send an inherited add', () {
    final s = ok(seeded(1), JamCommand.add(item(guest, title: 'g', inherited: true)), guest);
    expect(s.items.map((i) => i.title), ['cur', 'g', 'i0']);
    expect(s.items[1].inherited, false);
  });

  test('R-88: three guest adds in a row keep arrival order before the inherited', () {
    var s = seeded(2);
    for (final n in ['g1', 'g2', 'g3']) {
      s = ok(s, JamCommand.add(item(guest, title: n)), guest);
    }
    expect(s.items.map((i) => i.title),
        ['cur', 'g1', 'g2', 'g3', 'i0', 'i1']);
    expect(s.items.map((i) => i.inherited), [false, false, false, false, true, true]);
  });

  test('host inherited add goes to the end and keeps the flag', () {
    final s = ok(seeded(1), JamCommand.add(item(host, title: 'h', inherited: true)), host);
    expect(s.items.map((i) => i.title), ['cur', 'i0', 'h']);
    expect(s.items.last.inherited, true);
  });

  test('host remove of the current: next slides in, rewound; last falls back; empty stops', () {
    var s = ok(seeded(1), const JamCommand.play(), host);
    s = ok(s, JamCommand.remove(s.current!.id), host);
    expect(s.current!.title, 'i0');
    expect(s.currentIndex, 0);
    expect(s.positionMs, 0);
    expect(s.playing, true);
    s = ok(s, JamCommand.remove(s.current!.id), host);
    expect(s.items, isEmpty);
    expect(s.currentIndex, -1);
    expect(s.playing, false);
    var t = ok(seeded(1), const JamCommand.next(), host);
    t = ok(t, JamCommand.remove(t.current!.id), host);
    expect(t.items.map((i) => i.title), ['cur']);
    expect(t.currentIndex, 0);
  });

  test('next on the last item stops, rewound, without moving the index', () {
    var s = ok(seeded(1), const JamCommand.next(), host);
    s = ok(s, const JamCommand.play(), host);
    s = ok(s, const JamCommand.next(), host, now: 5000);
    expect(s.currentIndex, 1);
    expect(s.playing, false);
    expect(s.positionMs, 0);
  });

  test('trackEnded on the last item stops; on an earlier one advances rewound', () {
    var s = seeded(1);
    s = ok(s, JamCommand.trackEnded(s.current!.id), guest);
    expect(s.currentIndex, 1);
    expect(s.positionMs, 0);
    s = ok(s, JamCommand.trackEnded(s.current!.id), host);
    expect(s.currentIndex, 1);
    expect(s.playing, false);
  });

  test('jump to an item starts it playing from 0', () {
    var s = ok(seeded(2), const JamCommand.seek(500), host);
    s = ok(s, JamCommand.jump(s.items[2].id), guest);
    expect(s.currentIndex, 2);
    expect(s.positionMs, 0);
    expect(s.playing, true);
  });

  test('move to the head adopts the neighbour flag and keeps the current item', () {
    var s = ok(seeded(2), JamCommand.add(item(guest, title: 'g')), guest);
    s = ok(s, JamCommand.move(s.items[2].id, 0), host);
    expect(s.items.map((i) => i.title), ['i0', 'cur', 'g', 'i1']);
    expect(s.items[0].inherited, false); // adopts the flag of 'cur' next to it
    expect(s.current!.title, 'cur');
    expect(s.currentIndex, 1);
  });

  test('JamItem json keeps inherited', () {
    expect(JamItem.tryParse(item(host, inherited: true).toJson())!.inherited, true);
    expect(JamItem.tryParse(item(host).toJson())!.inherited, false);
  });
}

void videoIdTests() {
  test('videoId round-trips JSON; JSON without it reads null', () {
    final i = JamItem(
        id: 1, ownerDeviceId: 'a', title: 't', ext: 'm4a', ref: 'yt:youtube:abc', videoId: 'abc');
    final back = JamItem.tryParse(i.toJson()..['extra'] = 1)!;
    expect(back.videoId, 'abc');
    expect(back.ref, 'yt:youtube:abc');
    expect(i.copyWith(id: 2).videoId, 'abc');
    expect((i.toJson()..remove('vid')).let(JamItem.tryParse)!.videoId, isNull);
  });
}

void unsafeIdsTests() {
  JamItem? parse(String ref, String vid) => JamItem.tryParse({
        'id': 1, 'owner': 'o', 'title': 't', 'ext': 'm4a', 'ref': ref, 'vid': vid});

  test('a guest ref or vid that is not a plain id is dropped', () {
    final good = parse('yt:soundcloud:123-a_B', 'abc_-1')!;
    expect([good.ref, good.videoId], ['yt:soundcloud:123-a_B', 'abc_-1']);
    expect(parse('7', 'x')!.ref, '7');
    for (final bad in ['yt:youtube:../../../evil', 'yt:other:abc', 'yt:youtube:', 'x/7']) {
      expect(parse(bad, 'a')!.ref, isNull, reason: bad);
    }
    expect(parse('7', 'a&list=PLx')!.videoId, isNull);
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

const g2 = 'g2';

JamState startTogether() => const JamState(
  hostDeviceId: host,
  outputDeviceId: host,
  participants: [
    JamParticipant(id: host, name: 'H'),
    JamParticipant(id: guest, name: 'G'),
    JamParticipant(id: g2, name: 'G2'),
  ],
);

/// Owners after the current item, as a compact string.
String after(JamState s) =>
    s.items.skip(s.currentIndex + 1).map((i) => i.title).join(' ');

JamState addAll(JamState s, List<(String, String)> l) {
  for (final (o, t) in l) {
    s = ok(s, JamCommand.add(item(o, title: t)), o);
  }
  return s;
}

void togetherTests() {
  group('together mode', () {
    test(
      'JSON: mode, sug and pk round-trip; absent or unknown = host (R-106)',
      () {
        final s = startTogether().copyWith(mode: JamMode.together);
        expect(JamState.tryParse(s.toJson())!.mode, JamMode.together);
        expect(
          s.copyWith(mode: JamMode.host).toJson().containsKey('mode'),
          false,
        );
        expect(JamState.tryParse(startTogether().toJson())!.mode, JamMode.host);
        expect(
          (JamState.tryParse({...s.toJson(), 'mode': 'zzz', 'extra': 1}))!.mode,
          JamMode.host,
        );
        final it = JamItem.tryParse({
          ...const JamItem(
            id: 1,
            ownerDeviceId: 'a',
            title: 't',
            ext: 'mp3',
          ).toJson(),
          'sug': true,
          'pk': 'k1',
          'zzz': 1,
        })!;
        expect((it.suggested, it.partKey), (true, 'k1'));
        expect(
          JamItem.tryParse({...it.toJson(), 'pk': 'x' * 65})!.partKey,
          isNull,
        );
        final plain = JamItem.tryParse(
          const JamItem(
            id: 1,
            ownerDeviceId: 'a',
            title: 't',
            ext: 'mp3',
          ).toJson(),
        )!;
        expect((plain.suggested, plain.partKey), (false, null));
        final c = JamCommand.tryParse(
          const JamCommand.setMode(JamMode.together).toJson(),
        );
        expect(c!.mode, JamMode.together);
        expect(JamCommand.tryParse({'cmd': 'setMode', 'mode': 'zzz'}), isNull);
      },
    );

    test('setMode: host only, version + 1, same mode is a no-op', () {
      final s = addAll(startTogether(), [(host, 'cur')]);
      expect(
        err(s, const JamCommand.setMode(JamMode.together), guest),
        JamError.forbidden,
      );
      final t = ok(s, const JamCommand.setMode(JamMode.together), host);
      expect((t.mode, t.version), (JamMode.together, s.version + 1));
      expect(
        ok(t, const JamCommand.setMode(JamMode.together), host).version,
        t.version,
      );
    });

    test(
      'setMode(together) alternates; back to host keeps the order (R-104)',
      () {
        var s = addAll(startTogether(), [
          (host, 'h0'),
          (host, 'h1'),
          (host, 'h2'),
          (guest, 'g1'),
          (guest, 'g2'),
        ]);
        s = ok(s, const JamCommand.setMode(JamMode.together), host);
        expect(after(s), 'g1 h1 g2 h2');
        final back = ok(s, const JamCommand.setMode(JamMode.host), host);
        expect(back.items.map((i) => i.id), s.items.map((i) => i.id));
      },
    );

    test('add goes to the head of the sender part (D-179 examples)', () {
      // Host track playing, host has h1 queued, guest has g1.
      var s = ok(
        startTogether(),
        JamCommand.add(item(host, title: 'cur')),
        host,
      );
      s = addAll(s, [(host, 'h1'), (guest, 'g1')]);
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      expect(after(s), 'g1 h1');
      // Guest adds while the host's track plays: right after the current one.
      s = ok(s, JamCommand.add(item(guest, title: 'g0')), guest);
      expect(after(s), 'g0 h1 g1');
      // A track of the guest plays: the host's next one goes first.
      s = ok(s, const JamCommand.next(), host);
      s = ok(s, JamCommand.add(item(guest, title: 'gx')), guest);
      expect(after(s), 'h1 gx g1');
    });

    test('add with an empty part and with a third participant', () {
      var s = ok(
        startTogether(),
        JamCommand.add(item(host, title: 'cur')),
        host,
      );
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      s = addAll(s, [(g2, 'a'), (guest, 'b'), (g2, 'c')]);
      // After the host: guest, then g2.
      expect(after(s), 'b c a'); // c was added later: head of g2's part
    });

    test('move is refused in together mode (R-103), allowed in host mode', () {
      var s = addAll(startTogether(), [(host, 'a'), (host, 'b'), (host, 'c')]);
      expect(ok(s, const JamCommand.move(3, 1), host).items[1].id, 3);
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      expect(err(s, const JamCommand.move(3, 1), host), JamError.forbidden);
    });

    test('remove redoes the turns; inherited counts as the host part', () {
      var s = ok(
        startTogether(),
        JamCommand.add(item(host, title: 'cur')),
        host,
      );
      s = ok(s, JamCommand.add(item(host, title: 'i0', inherited: true)), host);
      s = addAll(s, [(guest, 'g1'), (guest, 'g2'), (host, 'h1')]);
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      expect(after(s), 'g1 h1 g2 i0');
      s = ok(
        s,
        JamCommand.remove(s.items.firstWhere((i) => i.title == 'g1').id),
        host,
      );
      expect(after(s), 'g2 h1 i0');
    });

    test('host inherited seed alternates with the guest adds (D-192)', () {
      var s = ok(startTogether(), JamCommand.add(item(host, title: 'cur')), host);
      for (final t in ['H1', 'H2', 'H3']) {
        s = ok(s, JamCommand.add(item(host, title: t, inherited: true)), host);
      }
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      s = addAll(s, [(guest, 'Y'), (guest, 'X')]);
      expect(after(s), 'X H1 Y H2 H3');
      expect(s.items.where((i) => i.inherited).length, 3);
    });

    test('jump redoes the turns after the new current', () {
      var s = addAll(startTogether(), [(host, 'a'), (host, 'b'), (host, 'c'), (guest, 'd'), (guest, 'e')]);
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      expect(s.items.map((i) => i.title).join(' '), 'a d b e c');
      s = ok(s, JamCommand.jump(s.items[3].id), host); // e, a guest track
      expect(s.items.map((i) => i.title).join(' '), 'a d b e c');
      s = ok(s, JamCommand.jump(s.items[1].id), host); // d
      expect(s.items.map((i) => i.title).join(' '), 'a d b e c');
      s = addAll(startTogether(), [(host, 'a'), (host, 'b'), (guest, 'c'), (guest, 'd'), (g2, 'e')]);
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      expect(s.items.map((i) => i.title).join(' '), 'a c e b d');
      // Jump to e (g2): after it the host goes first, then the guest.
      s = ok(s, JamCommand.jump(s.items[2].id), host);
      expect(after(s), 'b d');
    });

    test('invariant 2 on 200 random sequences', () {
      final rnd = Random(66);
      const who = [host, guest, g2];
      for (var n = 0; n < 200; n++) {
        var s = ok(
          startTogether(),
          JamCommand.add(item(host, title: 'cur')),
          host,
        );
        s = ok(s, const JamCommand.setMode(JamMode.together), host);
        for (var k = 0; k < 25; k++) {
          final o = who[rnd.nextInt(3)];
          final r = rnd.nextInt(10);
          if (r < 6) {
            s = ok(
              s,
              JamCommand.add(item(o, title: '$o$k', inherited: o == host && k.isOdd)),
              o,
            );
          } else if (r < 8 && s.items.length > s.currentIndex + 1) {
            s = ok(s, JamCommand.remove(s.items[s.currentIndex + 1].id), host);
          } else if (s.currentIndex + 1 < s.items.length) {
            s = ok(s, const JamCommand.next(), host);
          }
          // Two in a row of the same owner only if nobody else has any left.
          final tail = s.items.skip(s.currentIndex + 1).toList();
          for (var i = 1; i < tail.length; i++) {
            if (tail[i].ownerDeviceId != tail[i - 1].ownerDeviceId) continue;
            final o2 = tail[i].ownerDeviceId;
            expect(
              tail.skip(i).every((x) => x.ownerDeviceId == o2),
              true,
              reason: tail.map((x) => x.title).join(' '),
            );
          }
        }
      }
    });

    test('a full Jam slides in together mode: the oldest played track makes room (D-194)', () {
      JamState full(JamMode m, int cur) => startTogether().copyWith(
            mode: m,
            nextItemId: maxJamItems,
            currentIndex: cur,
            items: [
              for (var i = 0; i < maxJamItems; i++)
                JamItem(id: i, ownerDeviceId: i.isEven ? host : guest, title: 'p$i', ext: 'mp3'),
            ],
          );
      var s = ok(full(JamMode.together, 5), JamCommand.add(item(guest, title: 'new')), guest);
      expect(s.items.length, maxJamItems);
      expect((s.items.first.title, s.currentIndex, s.current!.title), ('p1', 4, 'p5'));
      expect(s.items.any((i) => i.title == 'new'), true);
      // Nothing played yet: refused, and together never drops an unplayed track.
      expect(err(full(JamMode.together, 0), JamCommand.add(item(guest)), guest), JamError.full);
      expect(err(full(JamMode.together, 0), JamCommand.add(item(host, inherited: true)), host), JamError.full);
      // «Coda dell'host»: no sliding.
      expect(err(full(JamMode.host, 5), JamCommand.add(item(guest)), guest), JamError.full);
    });

    test('a fed track (partKey) goes to the back of its owner part, an add to the head', () {
      JamItem fed(String o, String t) => JamItem(
          id: 0, ownerDeviceId: o, title: t, ext: 'mp3', partKey: t);
      var s = ok(startTogether(), JamCommand.add(item(host, title: 'cur')), host);
      s = ok(s, const JamCommand.setMode(JamMode.together), host);
      for (final t in ['a', 'b', 'c']) {
        s = ok(s, JamCommand.add(fed(guest, t)), guest);
      }
      expect(after(s), 'a b c');
      s = ok(s, JamCommand.add(item(guest, title: 'now')), guest);
      expect(after(s), 'now a b c');
    });
  });

    test('an add with a (owner, partKey) already in the Jam is a no-op, in both modes', () {
      JamItem fed(String o, String k) =>
          JamItem(id: 0, ownerDeviceId: o, title: k, ext: 'mp3', partKey: k);
      for (final m in [JamMode.host, JamMode.together]) {
        var s = ok(startTogether(), JamCommand.add(item(host, title: 'cur')), host);
        if (m == JamMode.together) s = ok(s, const JamCommand.setMode(JamMode.together), host);
        s = ok(s, JamCommand.add(fed(guest, 'k')), guest);
        final again = ok(s, JamCommand.add(fed(guest, 'k')), guest);
        expect((again.version, again.items.length), (s.version, s.items.length), reason: '$m');
        // Same key from someone else, or no key: a different track.
        expect(ok(s, JamCommand.add(fed(g2, 'k')), g2).items.length, s.items.length + 1);
      }
    });

    test('jump in together mode redoes the turns after the new current', () {
      var s = startTogether().copyWith(
        mode: JamMode.together,
        nextItemId: 4,
        items: [
          for (final (n, o) in [host, host, host, guest].indexed)
            JamItem(id: n, ownerDeviceId: o, title: '$o$n', ext: 'mp3'),
        ],
        currentIndex: 3,
      );
      s = ok(s, const JamCommand.jump(0), host);
      expect(after(s), 'guest3 host1 host2');
    });
}

const sg2 = 'guest2';

JamState speakerJam({int? away, List<String> outs = const [], String out = host}) =>
    ok(start(), JamCommand.add(item(host)), host).copyWith(
      speaker: true,
      speakerAwaySince: away,
      outputDeviceId: out,
      outputDeviceIds: outs,
      participants: const [
        JamParticipant(id: host, name: 'H'),
        JamParticipant(id: guest, name: 'G'),
        JamParticipant(id: sg2, name: 'G2'),
      ],
    );

void speakerTests() {
  group('speaker', () {
    test('JSON round trip, absent fields mean no speaker, junk is ignored', () {
      final s = speakerJam(away: 5000);
      final back = JamState.tryParse(s.toJson())!;
      expect(back.speaker, true);
      expect(back.speakerAwaySince, 5000);
      final plain = start().toJson();
      expect(plain.containsKey('spk'), false);
      expect(plain.containsKey('spkAway'), false);
      final p = JamState.tryParse(plain)!;
      expect(p.speaker, false);
      expect(p.speakerAwaySince, isNull);
      final junk = JamState.tryParse({...plain, 'spk': 'x', 'spkAway': 'y'})!;
      expect(junk.speaker, false);
      expect(junk.speakerAwaySince, isNull);
      expect(JamState.tryParse({...plain, 'spkAway': -3})!.speakerAwaySince, isNull);
      expect(s.copyWith(clearSpeakerAway: true).speakerAwaySince, isNull);
      // spkAway without spk would block play forever.
      expect(JamState.tryParse({...plain, 'spkAway': 5})!.speakerAwaySince, isNull);
    });

    test('new commands round trip', () {
      for (final c in [
        const JamCommand.speakerAway(),
        const JamCommand.speakerBack(),
        const JamCommand.offerSpeaker(),
        const JamCommand.continueOnPhone(),
      ]) {
        expect(JamCommand.tryParse(c.toJson())!.type, c.type);
      }
    });

    test('with the speaker away play, seek, next, jump, previous are refused', () {
      final s = speakerJam(away: 10);
      for (final c in [
        const JamCommand.play(),
        const JamCommand.seek(5),
        const JamCommand.next(),
        const JamCommand.jump(1),
        const JamCommand.previous(),
      ]) {
        expect(err(s, c, host), JamError.noSpeaker, reason: c.type.name);
      }
      expect(err(s, JamCommand.add(item(guest)), guest), isNull);
      expect(err(s, const JamCommand.setMode(JamMode.together), host), isNull);
      expect(err(s, const JamCommand.volume(0.5), guest), isNull);
      expect(err(s, const JamCommand.remove(1), host), isNull);
      // Present: all fine.
      expect(err(speakerJam(), const JamCommand.play(), host), isNull);
    });

    test('speakerAway from host freezes and pauses', () {
      final s = speakerJam().copyWith(playing: true, positionMs: 100, positionAt: 1000);
      final n = ok(s, const JamCommand.speakerAway(), host, now: 3000);
      expect(n.playing, false);
      expect(n.positionMs, 2100);
      expect(n.speakerAwaySince, 3000);
      expect(n.version, s.version + 1);
      // Already away: no-op.
      final again = ok(n, const JamCommand.speakerAway(), host, now: 9000);
      expect(again.speakerAwaySince, 3000);
      expect(again.version, n.version);
    });

    test('speakerAway from the only guest output resets outputs to the host', () {
      final s = speakerJam(out: guest).copyWith(playing: true);
      final n = ok(s, const JamCommand.speakerAway(), guest);
      expect(n.outputs, [host]);
      expect(n.speakerAwaySince, 1000);
      expect(err(s, const JamCommand.speakerAway(), sg2), JamError.forbidden);
    });

    test('a late trackEnded while the speaker is away changes nothing', () {
      final s = speakerJam(away: 10).copyWith(
          items: [item(host), item(host)].indexed.map((e) => e.$2.copyWith(id: e.$1 + 1)).toList());
      final r = applyCommand(s, const JamCommand.trackEnded(1), from: host, nowMs: 2000);
      expect(r.state!.currentIndex, s.currentIndex);
      expect(r.state!.version, s.version);
    });

    test('speakerAway without a speaker is invalid', () {
      expect(err(start(), const JamCommand.speakerAway(), host), JamError.invalid);
      expect(err(start(), const JamCommand.speakerBack(), host), JamError.invalid);
    });

    test('continueOnPhone: only the host, only while waiting, then play works', () {
      const c = JamCommand.continueOnPhone();
      final s = speakerJam(away: 10);
      expect(err(s, c, guest), JamError.forbidden);
      expect(err(speakerJam(), c, host), JamError.invalid);
      final n = ok(s, c, host);
      expect(n.speaker, false);
      expect(n.speakerAwaySince, isNull);
      expect(err(s, const JamCommand.play(), host), JamError.noSpeaker);
      expect(err(n, const JamCommand.play(), host), isNull);
    });

    test('speakerBack: host only, stays paused', () {
      final s = speakerJam(away: 10);
      expect(err(s, const JamCommand.speakerBack(), guest), JamError.forbidden);
      final n = ok(s, const JamCommand.speakerBack(), host);
      expect(n.speakerAwaySince, isNull);
      expect(n.playing, false);
      expect(ok(n, const JamCommand.speakerBack(), host).version, n.version);
    });

    test('offerSpeaker with the Jam stopped makes the guest the output', () {
      final s = speakerJam(away: 10);
      final n = ok(s, const JamCommand.offerSpeaker(), guest);
      expect(n.outputs, [guest]);
      expect(n.speakerAwaySince, isNull);
      expect(n.playing, false);
    });

    test('offerSpeaker is refused with the speaker present, from the host or unknown', () {
      expect(err(speakerJam(), const JamCommand.offerSpeaker(), guest), JamError.invalid);
      expect(err(start(), const JamCommand.offerSpeaker(), guest), JamError.invalid);
      final away = speakerJam(away: 10);
      expect(err(away, const JamCommand.offerSpeaker(), host), JamError.forbidden);
      expect(err(away, const JamCommand.offerSpeaker(), 'ghost'), JamError.invalid);
    });

    test('setOutput with a speaker accepts only the host', () {
      final s = speakerJam();
      expect(err(s, const JamCommand.setOutput(guest), host), JamError.forbidden);
      expect(err(s, const JamCommand.setOutput(guest), guest), JamError.forbidden);
      expect(err(s, const JamCommand.setOutputs([host, guest]), host), JamError.forbidden);
      expect(err(s, const JamCommand.setOutputs([guest]), host), JamError.forbidden);
      expect(err(s, const JamCommand.setOutput(host), host), isNull);
      // Normal Jam unchanged.
      final plain = speakerJam().copyWith(speaker: false);
      expect(ok(plain, const JamCommand.setOutput(guest), host).outputs, [guest]);
    });
  });
}

void remoteTests() {
  JamState withRemote() => const JamState(
        hostDeviceId: host,
        outputDeviceId: host,
        speaker: true,
        speakerAwaySince: 1,
        participants: [
          JamParticipant(id: host, name: 'H'),
          JamParticipant(id: 'lan', name: 'L', host: '1.2.3.4', port: 5),
          JamParticipant(id: 'rem', name: 'R', remote: true),
        ],
      );

  test('a remote cannot offer the speaker; a LAN guest can', () {
    expect(err(withRemote(), const JamCommand.offerSpeaker(), 'rem'), JamError.forbidden);
    expect(err(withRemote(), const JamCommand.offerSpeaker(), 'lan'), isNull);
  });

  test('setOutput and setOutputs toward a remote are forbidden', () {
    final s = withRemote().copyWith(speaker: false, clearSpeakerAway: true);
    expect(err(s, const JamCommand.setOutput('rem'), host), JamError.forbidden);
    expect(err(s, const JamCommand.setOutputs(['lan', 'rem']), host), JamError.forbidden);
    expect(err(s, const JamCommand.setOutput('lan'), host), isNull);
  });

  test('a remote online item is a self-fetch target; a LAN guest item is not', () {
    JamItem yt(String owner, int id) => JamItem(
        id: id, ownerDeviceId: owner, title: 't', ext: 'm4a', ref: 'yt:youtube:abc', videoId: 'abc');
    var s = withRemote().copyWith(speaker: false, clearSpeakerAway: true, items: [yt('rem', 1), yt('lan', 2)], currentIndex: 0);
    expect(jamSelfFetchTargets(s, host).map((i) => i.id), [1]);
    s = s.copyWith(currentIndex: 1);
    expect(jamSelfFetchTargets(s, host), isEmpty);
  });

  test('jamQueueFull: one rule for the reducer, the reserve and the in-flight adds', () {
    JamState filled(int n, int cur) => JamState(
        hostDeviceId: host,
        outputDeviceId: host,
        currentIndex: cur,
        items: [for (var i = 0; i < n; i++) item(host)]);
    expect(jamQueueFull(filled(maxJamItems, 0)), isTrue);
    expect(jamQueueFull(filled(maxJamItems, 3)), isFalse); // the window slides
    expect(jamQueueFull(filled(maxJamItems - jamManualSeats, 0)), isFalse);
    expect(jamQueueFull(filled(maxJamItems - jamManualSeats, 0), reserve: jamManualSeats), isTrue);
    expect(jamQueueFull(filled(10, 0), reserve: jamManualSeats, inFlight: maxJamItems - jamManualSeats - 10), isTrue);
  });
}

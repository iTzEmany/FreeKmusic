import 'dart:async';
import 'dart:math' as math;

import 'package:codecore/services/audio/crossfade_engine.dart';
import 'package:codecore/services/audio/equalizer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_equalizer.dart';

class _FakeTimer implements Timer {
  bool active = true;
  @override
  void cancel() => active = false;
  @override
  bool get isActive => active;
  @override
  int get tick => 0;
}

/// A ramp clock that only moves when the test says so.
class Ticks {
  final timers = <_FakeTimer>[];
  Duration? period;
  void Function()? _onTick;

  RampTicker get ticker => (p, cb) {
        period = p;
        _onTick = cb;
        final t = _FakeTimer();
        timers.add(t);
        return t;
      };

  bool get running => timers.isNotEmpty && timers.last.active;

  void tick([int n = 1]) {
    for (var i = 0; i < n; i++) {
      if (running) _onTick!();
    }
  }
}

Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 2));

const s6 = Duration(seconds: 6);

void main() {
  late List<FakeBackend> fakes;
  late Ticks ticks;
  late CrossfadeEngine engine;
  late List<Duration> positions;
  var advances = 0;

  setUp(() {
    fakes = [];
    ticks = Ticks();
    advances = 0;
    engine = CrossfadeEngine(() {
      final f = FakeBackend();
      fakes.add(f);
      return f;
    }, ticker: ticks.ticker)
      ..crossfade = s6;
    positions = [];
    engine.position.listen(positions.add);
    engine.advanced.listen((_) => advances++);
  });
  tearDown(() => engine.dispose());

  /// a (100 s) is playing, b (80 s, volume 0.5) is prepared on the other player.
  Future<void> aThenB({double volume = 1.0}) async {
    await engine.setVolume(volume);
    await engine.load('/m/a.mp3');
    fakes[0].durC.add(const Duration(seconds: 100));
    await pump();
    await engine.setNext('/m/b.mp3', volume: 0.5);
    fakes[1].durC.add(const Duration(seconds: 80));
    await pump();
    await engine.play();
  }

  Future<void> at(int seconds, {int player = 0}) async {
    fakes[player].posC.add(Duration(seconds: seconds));
    await pump();
  }

  test('the next track waits, silent, on the other player', () async {
    await aThenB();
    expect(fakes, hasLength(2));
    expect(fakes[1].loaded, ['/m/b.mp3']);
    expect(fakes[1].volumes.last, 0);
    expect(fakes[1].playing, isFalse);
    expect(fakes[0].playing, isTrue);
  });

  test('no fade before the last 6 s, then it starts exactly there', () async {
    await aThenB();
    await at(93);
    expect(fakes[1].playing, isFalse);
    expect(ticks.timers, isEmpty);
    await at(94);
    expect(fakes[1].playing, isTrue);
    expect(ticks.running, isTrue);
    expect(ticks.period, const Duration(milliseconds: 300));
  });

  test('at 1.5× the fade starts 9 s from the end and still lasts 6 s', () async {
    await engine.setSpeed(1.5);
    await aThenB();
    await at(90);
    expect(ticks.timers, isEmpty);
    await at(91);
    expect(ticks.running, isTrue);
    expect(ticks.period, const Duration(milliseconds: 300));
    expect(fakes[1].speedCalls, contains(1.5), reason: 'the second player has the speed too');
  });

  test('the ramp is equal-power and ends with only the new track', () async {
    await aThenB();
    await at(94);
    ticks.tick(10);
    final half = math.cos(math.pi / 4);
    expect(fakes[0].volumes.last, closeTo(half, 1e-9));
    expect(fakes[1].volumes.last, closeTo(half * 0.5, 1e-9));
    ticks.tick(10);
    await pump();
    expect(fakes[0].volumes.last, closeTo(0.0, 1e-9));
    expect(fakes[0].parkCalls, 1);
    expect(fakes[1].volumes.last, closeTo(0.5, 1e-9));
    expect(ticks.running, isFalse);
  });

  test('the join is announced halfway and the streams follow the new player', () async {
    await aThenB();
    await at(94);
    ticks.tick(9);
    await pump();
    expect(advances, 0);
    ticks.tick(1);
    await pump();
    expect(advances, 1);
    positions.clear();
    await at(97, player: 0); // the fading one: no longer heard
    await at(3, player: 1);
    expect(positions, [const Duration(seconds: 3)]);
    ticks.tick(10);
    await pump();
    expect(advances, 1, reason: 'announced once');
  });

  test('a pause in the middle of the fade pauses both and resuming goes on', () async {
    await aThenB();
    await at(94);
    ticks.tick(5);
    await engine.pause();
    expect(fakes[0].playing, isFalse);
    expect(fakes[1].playing, isFalse);
    expect(ticks.running, isFalse);
    final frozen = fakes[0].volumes.last;
    ticks.tick(5);
    expect(fakes[0].volumes.last, frozen, reason: 'nothing moves while paused');
    await engine.play();
    expect(fakes[0].playing, isTrue);
    expect(fakes[1].playing, isTrue);
    expect(ticks.running, isTrue);
    ticks.tick(15);
    await pump();
    expect(fakes[0].parkCalls, 1);
    expect(fakes[1].volumes.last, closeTo(0.5, 1e-9));
  });

  test('a seek before the halfway point cancels the fade and prepares b again', () async {
    await aThenB();
    await at(94);
    ticks.tick(3);
    await engine.seek(const Duration(seconds: 50));
    expect(fakes[1].parkCalls, 1);
    expect(fakes[0].volumes.last, 1.0);
    expect(fakes[0].seeks.last, const Duration(seconds: 50));
    expect(ticks.running, isFalse);
    expect(advances, 0);
    expect(fakes[1].loaded, ['/m/b.mp3', '/m/b.mp3'], reason: 'ready for the next approach');
    fakes[1].durC.add(const Duration(seconds: 80));
    await at(95);
    expect(ticks.running, isTrue, reason: 'and it fades again near the end');
  });

  test('a seek after the halfway point keeps the new track and drops the old', () async {
    await aThenB();
    await at(94);
    ticks.tick(12);
    await pump();
    expect(advances, 1);
    await engine.seek(const Duration(seconds: 20));
    expect(fakes[0].parkCalls, 1, reason: 'the old track stops at once');
    expect(fakes[1].volumes.last, closeTo(0.5, 1e-9));
    expect(fakes[1].seeks.last, const Duration(seconds: 20));
    expect(fakes[1].parkCalls, 0);
  });

  test('loading another track during the fade stops the one that was fading', () async {
    await aThenB();
    await at(94);
    ticks.tick(4);
    await engine.load('/m/z.mp3');
    expect(ticks.running, isFalse);
    expect(fakes[1].parkCalls, 1);
    expect(fakes[0].loaded.last, '/m/z.mp3');
    expect(fakes[0].volumes.last, 1.0);
  });

  test('a short track is never faded', () async {
    await engine.load('/m/a.mp3');
    fakes[0].durC.add(const Duration(seconds: 10)); // < 2 × 6 s
    await pump();
    await engine.setNext('/m/b.mp3');
    expect(fakes, hasLength(1), reason: 'no second player needed');
    expect(fakes[0].nextPath, '/m/b.mp3');
    expect(fakes[0].nextOverlap, isFalse);
  });

  test('a short incoming track is not faded in either', () async {
    await engine.load('/m/a.mp3');
    fakes[0].durC.add(const Duration(seconds: 100));
    await pump();
    await engine.setNext('/m/b.mp3');
    fakes[1].durC.add(const Duration(seconds: 8));
    await pump();
    await at(95);
    expect(ticks.timers, isEmpty);
    expect(fakes[1].playing, isFalse);
  });

  test('a join that may not overlap goes to the playing backend\'s own window', () async {
    await engine.load('/m/a.mp3');
    await engine.setNext('/m/b.mp3', overlap: false);
    expect(fakes, hasLength(1));
    expect(fakes[0].nextPath, '/m/b.mp3');
    fakes[0].advance();
    await pump();
    expect(advances, 1, reason: 'the backend\'s own join is passed on');
  });

  test('without a crossfade length the engine is a plain gapless pass-through', () async {
    engine.crossfade = null;
    await engine.load('/m/a.mp3');
    await engine.setNext('/m/b.mp3');
    expect(fakes, hasLength(1));
    expect(fakes[0].nextPath, '/m/b.mp3');
  });

  test('moving from a fade to a plain join clears the other player', () async {
    await aThenB();
    await engine.setNext('/m/c.mp3', overlap: false);
    expect(fakes[1].parkCalls, 1);
    expect(fakes[0].nextPath, '/m/c.mp3');
    await at(95);
    expect(ticks.timers, isEmpty, reason: 'no fade towards a track given for a plain join');
  });

  test('the user\'s volume reaches the playing side with its fade factor', () async {
    await aThenB();
    await at(94);
    ticks.tick(10);
    await engine.setVolume(0.6); // the incoming track is the main one now
    expect(fakes[1].volumes.last, closeTo(0.6 * math.sin(math.pi / 4), 1e-9));
    ticks.tick(10);
    await pump();
    expect(fakes[1].volumes.last, closeTo(0.6, 1e-9));
  });

  test('a track given during the fade is prepared once it is over', () async {
    await aThenB();
    await at(94);
    ticks.tick(5);
    await engine.setNext('/m/c.mp3');
    expect(fakes[0].loaded, ['/m/a.mp3'], reason: 'the fading player is not touched');
    ticks.tick(15);
    await pump();
    expect(fakes[0].loaded.last, '/m/c.mp3', reason: 'the idle player takes it');
  });

  test('a track that cannot be opened gives no fade and no crash', () async {
    const dead = '/m/dead.mp3';
    final own = <FakeBackend>[];
    final e = CrossfadeEngine(() {
      final f = FakeBackend();
      if (own.isNotEmpty) f.failing.add(dead); // the second player cannot open it
      own.add(f);
      return f;
    }, ticker: ticks.ticker)
      ..crossfade = s6;
    addTearDown(e.dispose);
    await e.load('/m/a.mp3');
    own[0].durC.add(const Duration(seconds: 100));
    await pump();
    await e.setNext(dead);
    expect(own, hasLength(2));
    expect(own[1].loaded, isEmpty);
    own[0].posC.add(const Duration(seconds: 95));
    await pump();
    expect(ticks.timers, isEmpty);
    expect(own[1].playing, isFalse);
  });

  test('the speed reaches the player created later', () async {
    await engine.setSpeed(1.25);
    await engine.load('/m/a.mp3');
    await engine.setNext('/m/b.mp3');
    expect(fakes[0].speedCalls, [1.25]);
    expect(fakes[1].speedCalls, [1.25]);
  });

  test('the equalizer settings go to both players', () async {
    final eqs = <FakeEq>[];
    final e = CrossfadeEngine(() {
      final f = FakeBackend()..equalizer = FakeEq();
      eqs.add(f.equalizer! as FakeEq);
      return f;
    }, ticker: ticks.ticker)
      ..crossfade = s6;
    addTearDown(e.dispose);
    await e.equalizer!.setEnabled(true);
    await e.equalizer!.setGains([1, 2, 3, 4, 5]);
    await e.load('/m/a.mp3');
    await e.setNext('/m/b.mp3'); // creates the second player
    await pump();
    expect(eqs, hasLength(2));
    expect(eqs[1].enabledCalls, [true], reason: 'the late player gets the settings');
    expect(eqs[1].gainCalls.last, [1, 2, 3, 4, 5]);
    await e.equalizer!.setGains([0, 0, 0, 0, 0]);
    expect(eqs[0].gainCalls.last, [0, 0, 0, 0, 0]);
    expect(eqs[1].gainCalls.last, [0, 0, 0, 0, 0]);
  });

  test('many track changes never stop the players nor create a third one', () async {
    // stop() rebuilds the native player (and its Android audio effect) at the
    // next load: at every change that exhausted the system's effects.
    await engine.load('/m/a.mp3');
    for (var i = 0; i < 6; i++) {
      fakes[i % 2].durC.add(const Duration(seconds: 100));
      await pump();
      await engine.setNext('/m/n$i.mp3');
      fakes[(i + 1) % 2].durC.add(const Duration(seconds: 80));
      await pump();
      await engine.play();
      await at(94, player: i % 2);
      ticks.tick(20);
      await pump();
    }
    expect(fakes, hasLength(2));
    expect(fakes.map((f) => f.stopCalls), everyElement(0));
    expect(fakes[0].parkCalls + fakes[1].parkCalls, 6);
  });

  test('without equalizers on the players, the engine has none', () async {
    expect(engine.equalizer, isNull);
  });

  test('stop leaves both players stopped and nothing prepared', () async {
    await aThenB();
    await engine.stop();
    expect(fakes[0].stopCalls, 1);
    expect(fakes[1].parkCalls, 1);
    await at(95);
    expect(ticks.timers, isEmpty);
  });

  test('the second player joining while the curve is being set gets it too, without an error', () async {
    final mirror = MirrorEqualizer();
    final first = _SlowEq()..hold = Completer<void>();
    final second = _SlowEq();
    mirror.add(first);
    final setting = mirror.setGains(const [1, 2, 3, 4, 5]);
    mirror.add(second); // while the first one is still busy
    first.hold!.complete();
    await setting;
    await mirror.setEnabled(true);
    expect(second.gains, [const [1.0, 2.0, 3.0, 4.0, 5.0]], reason: 'from add(), once');
    expect(first.enabled, [true]);
    expect(second.enabled, [true]);
  });
}

class _SlowEq implements Equalizer {
  final gains = <List<double>>[];
  final enabled = <bool>[];
  Completer<void>? hold;

  @override
  Future<EqBands> bands() async => const EqBands(centerHz: [60, 230, 910, 3600, 14000], minDb: -15, maxDb: 15);

  @override
  Future<void> setGains(List<double> gainsDb) async {
    gains.add(gainsDb);
    await hold?.future;
  }

  @override
  Future<void> setEnabled(bool on) async => enabled.add(on);
}

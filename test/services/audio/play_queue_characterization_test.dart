// Characterization of PlayQueue: a seeded random walk over its operations
// (no append, no insertNext), fingerprinting `items` + `currentIndex` after
// every step. The expected values below were generated once from the code as
// it was in phase 107 and must NOT change in phases 108-112: this file is the
// metric "queue behavior without additions, identical fingerprint" (D-499).
// «Svuota» + undo is covered in play_queue_test.dart, not repeated here.
//
// Representation: per seed, the readable fingerprints of the first 20 steps
// ("op:items|index") plus a cumulative FNV-1a hash every 10 steps, so a
// failure names the seed and the first step (or block of 10) that diverges.
import 'dart:math';

import 'package:codecore/services/audio/play_queue.dart';
import 'package:flutter_test/flutter_test.dart';

const _seeds = [1, 2, 3, 4, 5];
const _steps = 200;
const _block = 10;
const _readable = 20;
const _base = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

/// 32-bit FNV-1a over the code units of [s], continuing from [h].
int _fnv(int h, String s) {
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

class _Walk {
  final List<String> readable = [];
  final List<int> blocks = []; // cumulative hash after steps 10, 20, ...
}

_Walk _walk(int seed) {
  final r = Random(seed);
  final q = PlayQueue(random: Random(seed))..setItems(_base);
  final out = _Walk();
  var hash = 0x811C9DC5;
  var nextId = 100;
  for (var i = 0; i < _steps; i++) {
    final len = q.items.length;
    final String op;
    switch (r.nextInt(13)) {
      case 0:
      case 1:
        final auto = r.nextBool();
        op = 'next${auto ? 'A' : ''}=${q.next(auto: auto)}';
      case 2:
        op = 'prev=${q.previous()}';
      case 3:
        final k = r.nextInt(len + 2) - 1;
        q.jumpTo(k);
        op = 'jump$k';
      case 4:
        q.shuffle = true;
        op = 'shufOn';
      case 5:
        q.shuffle = false;
        op = 'shufOff';
      case 6:
      case 7:
        final from = r.nextInt(len + 1) - 1;
        final to = r.nextInt(len + 1) - 1;
        q.move(from, to);
        op = 'move$from>$to';
      case 8:
        final k = r.nextInt(len + 1) - 1;
        op = 'rm$k=${q.removeAt(k)}';
      case 9:
        final k = r.nextInt(len + 2) - 1;
        q.insertAt(k, nextId);
        op = 'ins$k#${nextId++}';
      case 10:
        q.rebuildUpcoming(_base);
        op = 'clear';
      default:
        q.repeat = PlayRepeat.values[r.nextInt(3)];
        op = 'rep${q.repeat.name}';
    }
    if (q.items.isEmpty) {
      // The op emptied the queue: reload the fixed list.
      q.setItems(_base);
    }
    final fp = '$op:${q.items.join(',')}|${q.currentIndex}';
    if (i < _readable) {
      out.readable.add(fp);
    }
    hash = _fnv(hash, fp);
    if ((i + 1) % _block == 0) {
      out.blocks.add(hash);
    }
  }
  return out;
}

/// Expected walks per seed: readable first steps and cumulative block hashes.
const _expected = <int, (List<String>, List<int>)>{
  1: (
    [
      'prev=1:1,2,3,4,5,6,7,8,9,10,11,12|0',
      'shufOn:1,12,6,2,3,7,11,8,5,10,9,4|0',
      'repoff:1,12,6,2,3,7,11,8,5,10,9,4|0',
      'move9>-1:1,12,6,2,3,7,11,8,5,10,9,4|0',
      'move3>4:1,12,6,3,2,7,11,8,5,10,9,4|0',
      'shufOff:1,2,3,4,5,6,7,8,9,10,11,12|0',
      'rm5=false:1,2,3,4,5,7,8,9,10,11,12|0',
      'move2>1:1,3,2,4,5,7,8,9,10,11,12|0',
      'move3>10:1,3,2,5,7,8,9,10,11,12,4|0',
      'move3>3:1,3,2,5,7,8,9,10,11,12,4|0',
      'nextA=3:1,3,2,5,7,8,9,10,11,12,4|1',
      'move5>1:1,8,3,2,5,7,9,10,11,12,4|2',
      'repall:1,8,3,2,5,7,9,10,11,12,4|2',
      'repall:1,8,3,2,5,7,9,10,11,12,4|2',
      'move5>2:1,8,7,3,2,5,9,10,11,12,4|3',
      'ins0#100:100,1,8,7,3,2,5,9,10,11,12,4|4',
      'nextA=2:100,1,8,7,3,2,5,9,10,11,12,4|5',
      'clear:1,2,3,4,5,6,7,8,9,10,11,12|1',
      'clear:1,2,3,4,5,6,7,8,9,10,11,12|1',
      'nextA=3:1,2,3,4,5,6,7,8,9,10,11,12|2',
    ],
    [
      1025205860,
      468987655,
      777881030,
      2038907985,
      1649315272,
      446833050,
      929740085,
      4221863875,
      50267901,
      1686651701,
      1100788798,
      109904079,
      903328412,
      3300315474,
      671400288,
      3282084065,
      1816605144,
      1511381240,
      3669164159,
      2648158808,
    ],
  ),
  2: (
    [
      'jump12:1,2,3,4,5,6,7,8,9,10,11,12|0',
      'nextA=2:1,2,3,4,5,6,7,8,9,10,11,12|1',
      'shufOn:2,8,3,9,5,7,4,1,10,12,11,6|0',
      'next=8:2,8,3,9,5,7,4,1,10,12,11,6|1',
      'ins9#100:2,8,3,9,5,7,4,1,10,100,12,11,6|1',
      'nextA=3:2,8,3,9,5,7,4,1,10,100,12,11,6|2',
      'ins6#101:2,8,3,9,5,7,101,4,1,10,100,12,11,6|2',
      'nextA=9:2,8,3,9,5,7,101,4,1,10,100,12,11,6|3',
      'jump5:2,8,3,9,5,7,101,4,1,10,100,12,11,6|5',
      'next=101:2,8,3,9,5,7,101,4,1,10,100,12,11,6|6',
      'repoff:2,8,3,9,5,7,101,4,1,10,100,12,11,6|6',
      'nextA=4:2,8,3,9,5,7,101,4,1,10,100,12,11,6|7',
      'move7>4:2,8,3,9,4,5,7,101,1,10,100,12,11,6|4',
      'jump8:2,8,3,9,4,5,7,101,1,10,100,12,11,6|8',
      'shufOff:1,2,3,4,5,6,7,101,8,9,10,100,11,12|0',
      'nextA=2:1,2,3,4,5,6,7,101,8,9,10,100,11,12|1',
      'nextA=3:1,2,3,4,5,6,7,101,8,9,10,100,11,12|2',
      'repone:1,2,3,4,5,6,7,101,8,9,10,100,11,12|2',
      'nextA=3:1,2,3,4,5,6,7,101,8,9,10,100,11,12|2',
      'clear:1,2,3,4,5,6,7,8,9,10,11,12|2',
    ],
    [
      412427442,
      3209250490,
      1498091745,
      3020590485,
      2873717368,
      2024306066,
      2131536793,
      3766064499,
      3630034610,
      3652395148,
      1073483578,
      3213799721,
      4279651728,
      3960841091,
      1147313460,
      1636894164,
      1447418718,
      836535774,
      407434720,
      670112090,
    ],
  ),
  3: (
    [
      'move9>3:1,2,3,10,4,5,6,7,8,9,11,12|0',
      'ins10#100:1,2,3,10,4,5,6,7,8,9,100,11,12|0',
      'rm4=false:1,2,3,10,5,6,7,8,9,100,11,12|0',
      'shufOn:1,10,11,5,2,7,8,100,9,6,3,12|0',
      'jump4:1,10,11,5,2,7,8,100,9,6,3,12|4',
      'rm6=false:1,10,11,5,2,7,100,9,6,3,12|4',
      'clear:2,11,5,4,8,9,3,10,12,6,7,1|0',
      'shufOff:1,2,3,4,5,6,7,8,9,10,11,12|1',
      'shufOff:1,2,3,4,5,6,7,8,9,10,11,12|1',
      'prev=1:1,2,3,4,5,6,7,8,9,10,11,12|0',
      'jump3:1,2,3,4,5,6,7,8,9,10,11,12|3',
      'shufOff:1,2,3,4,5,6,7,8,9,10,11,12|3',
      'clear:1,2,3,4,5,6,7,8,9,10,11,12|3',
      'prev=3:1,2,3,4,5,6,7,8,9,10,11,12|2',
      'move4>4:1,2,3,4,5,6,7,8,9,10,11,12|2',
      'shufOff:1,2,3,4,5,6,7,8,9,10,11,12|2',
      'move8>7:1,2,3,4,5,6,7,9,8,10,11,12|2',
      'repoff:1,2,3,4,5,6,7,9,8,10,11,12|2',
      'rm10=false:1,2,3,4,5,6,7,9,8,10,12|2',
      'nextA=4:1,2,3,4,5,6,7,9,8,10,12|3',
    ],
    [
      2014141299,
      4213484948,
      1653586144,
      3525639371,
      3276110679,
      936647366,
      4275881995,
      579229039,
      81133636,
      201601989,
      2673319604,
      2700356620,
      3510304443,
      2794100866,
      1899368232,
      3206003388,
      1309566207,
      1608725086,
      1768529223,
      3320383067,
    ],
  ),
  4: (
    [
      'repoff:1,2,3,4,5,6,7,8,9,10,11,12|0',
      'move6>4:1,2,3,4,7,5,6,8,9,10,11,12|0',
      'move2>-1:1,2,3,4,7,5,6,8,9,10,11,12|0',
      'repone:1,2,3,4,7,5,6,8,9,10,11,12|0',
      'shufOff:1,2,3,4,7,5,6,8,9,10,11,12|0',
      'jump1:1,2,3,4,7,5,6,8,9,10,11,12|1',
      'ins3#100:1,2,3,100,4,7,5,6,8,9,10,11,12|1',
      'move4>1:1,4,2,3,100,7,5,6,8,9,10,11,12|2',
      'shufOn:2,1,4,5,8,7,3,11,12,10,100,9,6|0',
      'repone:2,1,4,5,8,7,3,11,12,10,100,9,6|0',
      'shufOff:1,4,2,3,100,7,5,6,8,9,10,11,12|2',
      'move0>8:4,2,3,100,7,5,6,8,1,9,10,11,12|1',
      'jump1:4,2,3,100,7,5,6,8,1,9,10,11,12|1',
      'repone:4,2,3,100,7,5,6,8,1,9,10,11,12|1',
      'ins2#101:4,2,101,3,100,7,5,6,8,1,9,10,11,12|1',
      'move7>3:4,2,101,6,3,100,7,5,8,1,9,10,11,12|1',
      'nextA=2:4,2,101,6,3,100,7,5,8,1,9,10,11,12|1',
      'move1>3:4,101,6,2,3,100,7,5,8,1,9,10,11,12|3',
      'nextA=2:4,101,6,2,3,100,7,5,8,1,9,10,11,12|3',
      'clear:1,2,3,4,5,6,7,8,9,10,11,12|1',
    ],
    [
      1250445369,
      1311983457,
      3885032197,
      3322244884,
      2438613834,
      1426533055,
      209390406,
      1175817882,
      1436863693,
      2781289730,
      667909839,
      1771549723,
      149355311,
      428691648,
      4256963578,
      3740927847,
      3505341402,
      1798805917,
      3276820636,
      2800062568,
    ],
  ),
  5: (
    [
      'rm0=true:2,3,4,5,6,7,8,9,10,11,12|0',
      'shufOn:2,10,9,8,7,3,4,12,5,6,11|0',
      'shufOff:2,3,4,5,6,7,8,9,10,11,12|0',
      'next=3:2,3,4,5,6,7,8,9,10,11,12|1',
      'next=4:2,3,4,5,6,7,8,9,10,11,12|2',
      'move3>10:2,3,4,6,7,8,9,10,11,12,5|2',
      'prev=3:2,3,4,6,7,8,9,10,11,12,5|1',
      'clear:1,2,3,4,5,6,7,8,9,10,11,12|2',
      'ins9#100:1,2,3,4,5,6,7,8,9,100,10,11,12|2',
      'move4>8:1,2,3,4,6,7,8,9,5,100,10,11,12|2',
      'move6>2:1,2,8,3,4,6,7,9,5,100,10,11,12|3',
      'clear:1,2,3,4,5,6,7,8,9,10,11,12|2',
      'next=4:1,2,3,4,5,6,7,8,9,10,11,12|3',
      'ins0#101:101,1,2,3,4,5,6,7,8,9,10,11,12|4',
      'move7>2:101,1,7,2,3,4,5,6,8,9,10,11,12|5',
      'repoff:101,1,7,2,3,4,5,6,8,9,10,11,12|5',
      'move-1>-1:101,1,7,2,3,4,5,6,8,9,10,11,12|5',
      'shufOff:101,1,7,2,3,4,5,6,8,9,10,11,12|5',
      'prev=3:101,1,7,2,3,4,5,6,8,9,10,11,12|4',
      'ins13#102:101,1,7,2,3,4,5,6,8,9,10,11,12,102|4',
    ],
    [
      1293889364,
      260946256,
      3047321954,
      3069652233,
      3892791921,
      3082335595,
      3963673887,
      615939950,
      2216770099,
      544850718,
      1867714128,
      744394400,
      3135931002,
      3059710782,
      3792520724,
      1422033568,
      3031909113,
      1123432551,
      3933699143,
      691769264,
    ],
  ),
};

void main() {
  for (final seed in _seeds) {
    test('seed $seed walks exactly as in phase 107', () {
      final w = _walk(seed);
      final (readable, blocks) = _expected[seed]!;
      for (var i = 0; i < readable.length; i++) {
        expect(
          w.readable[i],
          readable[i],
          reason: 'seed $seed diverges at step $i',
        );
      }
      for (var b = 0; b < blocks.length; b++) {
        expect(
          w.blocks[b],
          blocks[b],
          reason:
              'seed $seed diverges within steps '
              '${b * _block}-${(b + 1) * _block - 1}',
        );
      }
    });
  }
}

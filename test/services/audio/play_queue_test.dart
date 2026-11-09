import 'dart:math';

import 'package:codecore/services/audio/play_queue.dart';
import 'package:flutter_test/flutter_test.dart';

PlayQueue make(List<int> ids, {int start = 0}) =>
    PlayQueue(random: Random(7))..setItems(ids, startIndex: start);

void main() {
  test('starts at requested index', () {
    final q = make([10, 20, 30], start: 1);
    expect(q.currentId, 20);
    expect(q.currentIndex, 1);
  });

  test('empty queue', () {
    final q = PlayQueue();
    expect(q.currentId, isNull);
    expect(q.currentIndex, -1);
    expect(q.next(), isNull);
    expect(q.previous(), isNull);
  });

  test('repeat off stops at the end (auto)', () {
    final q = make([1, 2]);
    expect(q.next(auto: true), 2);
    expect(q.next(auto: true), isNull);
    expect(q.currentId, 2);
  });

  test('hasNext: false on the last track unless repeating', () {
    final q = make([1, 2]);
    expect(q.hasNext, isTrue);
    q.next();
    expect(q.hasNext, isFalse);
    q.repeat = PlayRepeat.all;
    expect(q.hasNext, isTrue);
    expect(PlayQueue().hasNext, isFalse);
  });

  test('repeat all wraps', () {
    final q = make([1, 2])..repeat = PlayRepeat.all;
    q.next();
    expect(q.next(auto: true), 1);
  });

  test('repeat one: auto keeps, manual advances', () {
    final q = make([1, 2, 3])..repeat = PlayRepeat.one;
    expect(q.next(auto: true), 1);
    expect(q.next(), 2);
  });

  test('repeat one manual at the end wraps like all', () {
    final q = make([1, 2], start: 1)..repeat = PlayRepeat.one;
    expect(q.next(), 1);
  });

  test('shuffle keeps current first and has no repeats', () {
    final q = make(List.generate(20, (i) => i), start: 5);
    q.shuffle = true;
    expect(q.currentId, 5);
    final seen = <int>{q.currentId!};
    for (var i = 0; i < 19; i++) {
      expect(seen.add(q.next()!), isTrue);
    }
    expect(q.next(), isNull);
  });

  test('shuffle off keeps current and natural order', () {
    final q = make([1, 2, 3, 4], start: 0)..shuffle = true;
    q.next();
    final cur = q.currentId;
    q.shuffle = false;
    expect(q.currentId, cur);
    expect(q.currentIndex, [1, 2, 3, 4].indexOf(cur!));
    expect(q.playOrder, [1, 2, 3, 4]);
  });

  test('previous follows listening history', () {
    final q = make([1, 2, 3, 4]);
    q.next();
    q.jumpTo(3);
    expect(q.currentId, 4);
    expect(q.previous(), 2);
    expect(q.previous(), 1);
  });

  test('previous without history goes to previous item', () {
    final q = make([1, 2, 3], start: 2);
    expect(q.previous(), 2);
    expect(q.previous(), 1);
    expect(q.previous(), 1);
  });

  test('removeAt current reports and points to following', () {
    final q = make([1, 2, 3], start: 1);
    expect(q.removeAt(1), isTrue);
    expect(q.currentId, 3);
    expect(q.items, [1, 3]);
  });

  test('removeAt before current keeps current', () {
    final q = make([1, 2, 3], start: 2);
    expect(q.removeAt(0), isFalse);
    expect(q.currentId, 3);
    expect(q.currentIndex, 1);
  });

  test('removeAt last current clamps', () {
    final q = make([1, 2], start: 1);
    q.removeAt(1);
    expect(q.currentId, 1);
  });

  test('append goes to the end', () {
    final q = make([1, 2]);
    q.append(7);
    expect(q.items, [1, 2, 7]);
    q.next();
    expect(q.next(), 7);
  });

  test('move keeps current track', () {
    final q = make([1, 2, 3, 4], start: 1);
    q.move(0, 3);
    expect(q.items, [2, 3, 4, 1]);
    expect(q.currentId, 2);
    q.move(0, 2);
    expect(q.items, [3, 4, 2, 1]);
    expect(q.currentId, 2);
    expect(q.next(), 1);
  });

  group('shuffle shows the queue in the order it plays', () {
    test('items is the play order and next() walks it', () {
      final q = make(List.generate(12, (i) => i), start: 3)..shuffle = true;
      final listed = q.items;
      expect(listed[q.currentIndex], 3);
      for (var i = q.currentIndex + 1; i < listed.length; i++) {
        expect(q.next(), listed[i], reason: 'next is what the queue shows next');
      }
      expect(q.items, listed, reason: 'walking does not reshuffle');
    });

    test('shuffle off puts the natural order back, additions included', () {
      final q = make([1, 2, 3, 4, 5], start: 1)..shuffle = true;
      q.insertAt(q.currentIndex + 1, 99);
      q.append(7);
      q.next(); // 99
      q.shuffle = false;
      expect(q.currentId, 99);
      expect(q.items, [1, 2, 99, 3, 4, 5, 7]);
    });

    test('a restored session plays in the saved order even with shuffle on', () {
      final q = PlayQueue(random: Random(1))..shuffle = true;
      q.setItems([5, 3, 9, 1], startIndex: 1, alreadyShuffled: true);
      expect(q.items, [5, 3, 9, 1]);
      expect(q.next(), 9);
    });
  });

  group('peekNext / revision', () {
    test(
      'peekNext announces what next(auto: true) delivers, over random use',
      () {
        final ops = Random(2024);
        for (var seed = 0; seed < 200; seed++) {
          final q = PlayQueue(random: Random(seed));
          final ids = List.generate(1 + ops.nextInt(7), (i) => 100 + i);
          q.setItems(ids, startIndex: ops.nextInt(ids.length));
          var nextId = 500;
          for (var step = 0; step < 60; step++) {
            switch (ops.nextInt(11)) {
              case 0:
                q.shuffle = !q.shuffle;
              case 1:
                q.repeat = PlayRepeat.values[ops.nextInt(3)];
              case 2:
                if (q.items.length > 1) {
                  q.move(ops.nextInt(q.items.length), ops.nextInt(q.items.length));
                }
              case 3:
                if (q.items.length > 1) q.removeAt(ops.nextInt(q.items.length));
              case 4:
                q.insertAt(q.currentIndex + 1, nextId++);
              case 5:
                q.append(nextId++);
              case 6:
                if (q.items.isNotEmpty) q.jumpTo(ops.nextInt(q.items.length));
              case 7:
                q.previous();
              case 8:
                q.next();
              default:
                final announced = q.peekNext();
                final again = q.peekNext();
                expect(
                  again,
                  announced,
                  reason: 'peeking twice gives the same answer (seed $seed)',
                );
                expect(
                  q.next(auto: true),
                  announced,
                  reason: 'seed $seed step $step',
                );
            }
          }
        }
      },
    );

    test(
      'peekNext changes neither the position, the history nor the revision',
      () {
        final q = PlayQueue(random: Random(3))
          ..setItems([1, 2, 3], startIndex: 2)
          ..shuffle = true
          ..repeat = PlayRepeat.all;
        final before = [q.currentId, q.currentIndex, q.revision, ...q.playOrder];
        q.peekNext();
        q.peekNext(auto: false);
        expect([q.currentId, q.currentIndex, q.revision, ...q.playOrder], before);
        q.previous(); // the history was not touched by the peeks: nothing to go back to
        expect(q.currentId, isNotNull);
      },
    );

    test(
      'at the end of a shuffled lap the announced track is the one that comes',
      () {
        for (var seed = 0; seed < 50; seed++) {
          final q = PlayQueue(random: Random(seed))
            ..setItems([1, 2, 3, 4, 5])
            ..shuffle = true
            ..repeat = PlayRepeat.all;
          for (var i = 0; i < 4; i++) {
            q.next();
          }
          final last = q.currentId;
          final announced = q.peekNext();
          expect(q.next(auto: true), announced);
          expect(
            announced,
            isNot(last),
            reason: 'never the same track twice in a row',
          );
        }
      },
    );

    test('repeat one announces the same track only for automatic advances', () {
      final q = make([1, 2, 3])..repeat = PlayRepeat.one;
      expect(q.peekNext(), 1);
      expect(q.peekNext(auto: false), 2);
    });

    test('the end of the queue announces nothing', () {
      final q = make([1, 2], start: 1);
      expect(q.peekNext(), isNull);
      expect(PlayQueue().peekNext(), isNull);
    });

    test('every change moves the revision, a peek does not', () {
      final q = make([1, 2, 3]);
      var r = q.revision;
      void expectBump(String what) {
        expect(q.revision, greaterThan(r), reason: what);
        r = q.revision;
      }

      q.shuffle = true;
      expectBump('shuffle');
      q.shuffle = true;
      expect(q.revision, r, reason: 'same value, no change');
      q.repeat = PlayRepeat.all;
      expectBump('repeat');
      q.insertAt(q.currentIndex + 1, 9);
      expectBump('insertAt');
      q.append(8);
      expectBump('append');
      q.move(0, 1);
      expectBump('move');
      q.removeAt(0);
      expectBump('removeAt');
      q.jumpTo(1);
      expectBump('jumpTo');
      q.next();
      expectBump('next');
      q.previous();
      expectBump('previous');
      q.setItems([4, 5]);
      expectBump('setItems');
      q.peekNext();
      expect(q.revision, r);
    });
  });

  group('«Svuota» builds what follows again from the list playback came from', () {
    const source = [1, 2, 3, 4, 5];

    test('in order: from the current track on, manual additions gone', () {
      final q = make(source, start: 1)
        ..append(99)
        ..insertAt(1 + 1, 98);
      q.rebuildUpcoming(source);
      expect(q.currentId, 2);
      expect(q.items, source);
      expect([q.next(), q.next(), q.next(), q.next()], [3, 4, 5, null]);
    });

    test('shuffle: a new order of the whole list, shown as it will play', () {
      final q = make(List.generate(20, (i) => i), start: 2)..shuffle = true;
      final source = List.generate(20, (i) => i);
      final before = q.playOrder;
      q.rebuildUpcoming(source);
      expect(q.currentId, 2);
      expect(q.items, q.playOrder, reason: 'the queue lists what will play');
      expect(q.items.first, 2);
      expect(q.items.toSet(), source.toSet());
      expect(q.items, hasLength(20));
      expect(q.items, isNot(before), reason: 'a new shuffle');
    });

    test('a current track outside the list plays first, then the list', () {
      final q = make([42]);
      q.rebuildUpcoming(source);
      expect(q.items, [42, ...source]);
      expect(q.currentId, 42);
    });

    test('no list: just dropped; undo puts everything back', () {
      final q = make([7, 8, 9]);
      final saved = q.saveState();
      q.rebuildUpcoming(null);
      expect(q.items, [7]);
      expect(q.hasNext, isFalse);
      expect(q.restoreState(saved), isTrue);
      expect(q.items, [7, 8, 9]);
      expect(q.next(), 8);
      expect(q.restoreState(saved), isFalse, reason: 'another track plays now');
    });
  });

  group('insertAt / removeId', () {
    test('before, at and after the current track: the current one stays', () {
      for (final at in [0, 1, 2, 3, 99]) {
        final q = make([1, 2, 3], start: 1);
        q.insertAt(at, 9);
        expect(q.currentId, 2, reason: 'insertAt($at)');
        expect(q.items[at.clamp(0, 3)], 9);
        expect(q.items.length, 4);
      }
    });

    test(
      'shuffle off after an insert keeps the entry and the current track',
      () {
        final q = make([1, 2, 3, 4, 5], start: 2)..shuffle = true;
        final before = q.items[1];
        q.insertAt(2, 9);
        expect(q.items[2], 9);
        final current = q.currentId;
        q.shuffle = false;
        expect(q.items, containsAll([1, 2, 3, 4, 5, 9]));
        expect(q.items.length, 6);
        expect(q.currentId, current);
        // Right after the entry that preceded it in the shuffled order.
        expect(q.items.indexOf(9), q.items.indexOf(before) + 1);
      },
    );

    test('inserting at the start with shuffle off puts it first', () {
      final q = make([1, 2, 3])..shuffle = true;
      q.insertAt(0, 9);
      q.shuffle = false;
      expect(q.items.first, 9);
    });

    test('removeId drops the first occurrence and reports the current one', () {
      final q = make([1, 2, 3, 2], start: 1);
      expect(q.removeId(2), isTrue);
      expect(q.items, [1, 3, 2]);
      expect(q.currentId, 3);
      expect(q.removeId(42), isFalse);
      expect(q.items, [1, 3, 2]);
    });

    test('history and previous skip the removed entry', () {
      final q = make([1, 2, 3]);
      q.next();
      q.next();
      expect(q.currentId, 3);
      q.removeId(2);
      expect(q.previous(), 1);
    });

    test('revision grows', () {
      final q = make([1, 2]);
      var r = q.revision;
      q.insertAt(1, 9);
      expect(q.revision, greaterThan(r));
      r = q.revision;
      q.removeId(9);
      expect(q.revision, greaterThan(r));
    });
  });
}

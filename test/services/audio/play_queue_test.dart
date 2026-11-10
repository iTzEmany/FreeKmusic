import 'dart:math';

import 'package:codecore/services/audio/play_queue.dart';
import 'package:flutter_test/flutter_test.dart';

PlayQueue make(List<int> ids, {int start = 0}) =>
    PlayQueue(random: Random(7))..setItems(ids, startIndex: start);

void main() {
  test('putBack after the current moved on keeps the entry upcoming', () {
    final q = make([1, 2, 3, 4]);
    q.removeAt(1);
    q.next();
    q.putBack(1, 2, user: false);
    expect(q.items.sublist(q.currentIndex + 1), contains(2));
    expect(q.invariantError, isNull);
  });

  test('putBack of a user entry: head of the block, end of the block, empty queue', () {
    final q = make([1, 2, 3, 4])
      ..enqueue(7)
      ..enqueue(8);
    q.removeAt(1);
    q.next(); // the block is now empty
    final cur = q.currentIndex;
    q.putBack(0, 9, user: true); // index <= current: head of the block
    expect(q.items[cur + 1], 9);
    final ahead = q.userAhead;
    q.putBack(99, 10, user: true); // past the block: end of the block
    expect(q.userAhead, ahead + 1);
    expect(q.items[cur + q.userAhead], 10);
    expect(q.invariantError, isNull);
    final e = make([]);
    e.putBack(0, 5, user: true);
    expect(e.items, [5]);
    expect(e.invariantError, isNull);
  });

  test('putBack bumps revision and peekNext stays consistent (shuffle + repeat all)', () {
    final q = make([1, 2, 3, 4, 5])
      ..shuffle = true
      ..repeat = PlayRepeat.all;
    final id = q.items[q.currentIndex + 1];
    q.removeAt(q.currentIndex + 1);
    final rev = q.revision;
    q.putBack(q.currentIndex + 1, id, user: false);
    expect(q.revision, greaterThan(rev));
    final announced = q.peekNext();
    expect(q.peekNext(), announced);
    expect(q.next(auto: true), announced);
    expect(q.invariantError, isNull);
  });

  test('putBack deferred past interleaved ops: invariants hold, entry upcoming', () {
    final ops = Random(77);
    for (var seed = 0; seed < 200; seed++) {
      final q = make(List.generate(2 + ops.nextInt(8), (i) => 100 + i));
      q.shuffle = ops.nextBool();
      var nextId = 500;
      final pend = <(int, int, bool)>[];
      for (var s = 0; s < 40; s++) {
        switch (ops.nextInt(6)) {
          case 0:
            q.enqueue(nextId++);
          case 1:
            q.next();
          case 2:
            q.previous();
          case 3:
            q.repeat = PlayRepeat.values[ops.nextInt(3)];
          case 4:
            if (q.items.length > q.currentIndex + 1) {
              final i = q.currentIndex + 1 + ops.nextInt(q.items.length - q.currentIndex - 1);
              pend.add((i, q.items[i], i <= q.currentIndex + q.userAhead));
              q.removeAt(i);
            }
          default:
            if (pend.isNotEmpty) {
              final (i, id, user) = pend.removeAt(ops.nextInt(pend.length));
              final cur = q.currentId;
              q.putBack(i, id, user: user);
              expect(q.currentId, cur, reason: 'seed $seed step $s');
              expect(q.items.sublist(q.currentIndex + 1), contains(id), reason: 'seed $seed step $s');
            }
        }
        expect(q.invariantError, isNull, reason: 'seed $seed step $s');
      }
    }
  });

  test('putBack returns a removed entry to its slot, in or out of the block', () {
    final q = make([1, 2, 3, 4])
      ..enqueue(7)
      ..enqueue(8);
    q.removeAt(1);
    q.putBack(1, 7, user: true);
    expect(q.items, [1, 7, 8, 2, 3, 4]);
    expect(q.userAhead, 2);
    q.removeAt(4);
    q.putBack(4, 3, user: false);
    expect(q.items, [1, 7, 8, 2, 3, 4]);
    expect(q.userAhead, 2);
    expect(q.invariantError, isNull);
  });

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

  group('user block (enqueue)', () {
    test('FIFO: after the current track, behind earlier additions', () {
      final q = make([1, 2, 3]);
      q.enqueue(7);
      q.enqueue(8);
      expect(q.items, [1, 7, 8, 2, 3]);
      expect(q.userAhead, 2);
      expect(q.next(), 7);
      expect(q.currentFromUser, isTrue);
      expect(q.userAhead, 1);
      expect(q.next(), 8);
      expect(q.next(), 2);
      expect(q.currentFromUser, isFalse);
    });

    test('several tracks go in order to the end of the block', () {
      final q = make([1, 2]);
      q.enqueue(7);
      [8, 9].forEach(q.enqueue);
      expect(q.items, [1, 7, 8, 9, 2]);
    });

    test('empty queue: the track just plays', () {
      final q = PlayQueue()..enqueue(5);
      expect(q.items, [5]);
      expect(q.userAhead, 0);
    });

    test('shuffle on and off do not shuffle the block', () {
      final q = make(List.generate(10, (i) => i))
        ..enqueue(90)
        ..enqueue(91)
        ..shuffle = true;
      expect(q.items.sublist(1, 3), [90, 91]);
      expect(q.userAhead, 2);
      q.shuffle = false;
      expect(q.items.sublist(q.currentIndex + 1, q.currentIndex + 3), [90, 91]);
    });

    test('previous: the block stays right after the new current (D-493)', () {
      final q = make([1, 2, 3], start: 1);
      q.next(); // 3
      q.enqueue(7);
      expect(q.previous(), 2);
      expect(q.items, [1, 2, 7, 3]);
      expect(q.userAhead, 1);
      expect(q.next(), 7);
    });

    test(
      'jumpTo past the block: the block follows the touched track (D-494)',
      () {
        final q = make([1, 2, 3, 4])..enqueue(7);
        q.jumpTo(4); // 4
        expect(q.items, [1, 2, 3, 4, 7]);
        expect(q.userAhead, 1);
      },
    );

    test('jumpTo into the block takes that entry out of it', () {
      final q = make([1, 2])
        ..enqueue(7)
        ..enqueue(8);
      q.jumpTo(2); // 8
      expect(q.currentFromUser, isTrue);
      expect(q.items, [1, 8, 7, 2]);
      expect(q.userAhead, 1);
    });

    test(
      'move: landing in the block joins it, outside it is normal (D-487)',
      () {
        final q = make([1, 2, 3, 4])..enqueue(7);
        q.move(4, 1); // 4 lands right after the current track
        expect(q.items, [1, 4, 7, 2, 3]);
        expect(q.userAhead, 2);
        q.move(1, 4); // out of the block
        expect(q.items, [1, 7, 2, 3, 4]);
        expect(q.userAhead, 1);
        q.move(1, 4); // the block entry itself leaves it
        expect(q.userAhead, 0);
      },
    );

    test('removeAt takes the entry out of the block', () {
      final q = make([1, 2])
        ..enqueue(7)
        ..enqueue(8);
      q.removeAt(1);
      expect(q.items, [1, 8, 2]);
      expect(q.userAhead, 1);
    });

    test('insertAt inside the block goes right after it', () {
      final q = make([1, 2])
        ..enqueue(7)
        ..enqueue(8);
      q.insertAt(1, 9);
      expect(q.items, [1, 7, 8, 9, 2]);
      expect(q.userAhead, 2);
    });

    test('Svuota clears the block and Annulla puts it back', () {
      final q = make([1, 2, 3])..enqueue(7);
      final saved = q.saveState();
      q.rebuildUpcoming(const [1, 2, 3]);
      expect(q.userAhead, 0);
      expect(q.items, [1, 2, 3]);
      expect(q.restoreState(saved), isTrue);
      expect(q.userAhead, 1);
      expect(q.items, [1, 7, 2, 3]);
    });

    test(
      'Ripeti tutto: a played block entry comes back in the next lap (D-492)',
      () {
        final q = make([1, 2])
          ..repeat = PlayRepeat.all
          ..enqueue(7);
        expect([q.next(), q.next(), q.next(), q.next()], [7, 2, 1, 7]);
        expect(q.userAhead, 0);
      },
    );

    test(
      'setItems keepUser puts the block after the new current track (D-488)',
      () {
        final q = make([1, 2])..enqueue(7);
        q.setItems([5, 6, 8], startIndex: 1, keepUser: true);
        expect(q.items, [5, 6, 7, 8]);
        expect(q.userAhead, 1);
        q.setItems([5, 6]);
        expect(q.userAhead, 0);
      },
    );
  });

  group('currentFromUser survives and clears', () {
    PlayQueue onBlockEntry() {
      final q = make([1, 2, 3])..enqueue(9);
      q.next();
      expect(q.currentFromUser, isTrue);
      return q;
    }

    test('a shuffle toggle keeps it', () {
      final q = onBlockEntry()..shuffle = true;
      expect(q.currentFromUser, isTrue);
      q.shuffle = false;
      expect(q.currentFromUser, isTrue);
    });

    test('a move keeps it', () {
      final q = onBlockEntry();
      q.move(q.items.length - 1, q.currentIndex + 1);
      expect(q.currentFromUser, isTrue);
    });

    test('repeat-all wrap from a block entry clears it', () {
      final q = make([1])
        ..repeat = PlayRepeat.all
        ..enqueue(9);
      q.next();
      expect(q.currentFromUser, isTrue);
      q.next(auto: true);
      expect(q.currentFromUser, isFalse);
    });

    test('a new context clears it', () {
      final q = onBlockEntry()..setItems([4, 5]);
      expect(q.currentFromUser, isFalse);
    });

    test('Svuota keeps it and Annulla restores it', () {
      final q = onBlockEntry();
      final saved = q.saveState();
      q.rebuildUpcoming(null);
      expect(q.currentFromUser, isTrue);
      q.jumpTo(0); // here the block entry is the only one
      q.restoreState(saved);
      expect(q.currentFromUser, isTrue);
      expect(q.items, [1, 9, 2, 3]);
    });
  });

  test('move to pos+1+userAhead joins the block (D-487)', () {
    final q = make([1, 2, 3, 4])..enqueue(9);
    q.move(4, 2); // 4 right after the block
    expect(q.items, [1, 9, 4, 2, 3]);
    expect(q.userAhead, 2);
  });

  test('move from outside to between two block entries lands there (D-487)', () {
    final q = make([1, 2, 3, 4, 5])
      ..enqueue(7)
      ..enqueue(8);
    q.move(6, 2); // 5 between 7 and 8
    expect(q.items, [1, 7, 5, 8, 2, 3, 4]);
    expect(q.userAhead, 3);
  });

  test('jumpTo the current entry keeps currentFromUser', () {
    final q = make([1, 2, 3])..enqueue(9);
    q.next();
    expect(q.currentFromUser, isTrue);
    q.jumpTo(q.currentIndex);
    expect(q.currentFromUser, isTrue);
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
        expect(
          q.next(),
          listed[i],
          reason: 'next is what the queue shows next',
        );
      }
      expect(q.items, listed, reason: 'walking does not reshuffle');
    });

    test('shuffle off puts the natural order back, additions included', () {
      final q = make([1, 2, 3, 4, 5], start: 1)..shuffle = true;
      q.insertAt(q.currentIndex + 1, 99);
      q.enqueue(7);
      q.next(); // 7
      q.next(); // 99
      q.shuffle = false;
      expect(q.currentId, 99);
      expect(q.items, [1, 2, 7, 99, 3, 4, 5]); // 7 played: a normal entry now
    });

    test('shuffle off after a block entry keeps the queue playable', () {
      final q = make([1, 2, 3, 4, 5, 6], start: 1)..shuffle = true;
      q.enqueue(9);
      q.next(); // 9, now playing
      q.shuffle = false;
      expect(q.currentId, 9);
      expect(q.items.indexOf(9), lessThan(q.items.length - 1));
      expect(q.next(), isNotNull);
      expect(q.invariantError, isNull);
    });

    test(
      'a restored session plays in the saved order even with shuffle on',
      () {
        final q = PlayQueue(random: Random(1))..shuffle = true;
        q.setItems([5, 3, 9, 1], startIndex: 1, alreadyShuffled: true);
        expect(q.items, [5, 3, 9, 1]);
        expect(q.next(), 9);
      },
    );
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
            switch (ops.nextInt(16)) {
              case 0:
                q.shuffle = !q.shuffle;
              case 1:
                q.repeat = PlayRepeat.values[ops.nextInt(3)];
              case 2:
                if (q.items.length > 1) {
                  q.move(
                    ops.nextInt(q.items.length),
                    ops.nextInt(q.items.length),
                  );
                }
              case 3:
                if (q.items.length > 1) q.removeAt(ops.nextInt(q.items.length));
              case 4:
                q.insertAt(q.currentIndex + 1, nextId++);
              case 5:
                final id = nextId++;
                q.enqueue(id);
                if (q.items.length > 1) {
                  expect(q.items[q.currentIndex + q.userAhead], id);
                }
              case 6:
                if (q.items.isNotEmpty) q.jumpTo(ops.nextInt(q.items.length));
              case 7:
                q.previous();
              case 8:
                q.next();
              case 9:
                q.setItems(
                  List.generate(1 + ops.nextInt(5), (i) => nextId++),
                  keepUser: ops.nextBool(),
                  startIndex: ops.nextInt(3),
                  userAhead: ops.nextInt(3),
                );
              case 10:
                final saved = q.saveState();
                q.rebuildUpcoming(
                  ops.nextBool()
                      ? null
                      : [for (var i = 0; i < 4; i++) nextId++],
                );
                if (ops.nextBool()) q.restoreState(saved);
              case 11:
                if (q.items.isNotEmpty) {
                  q.removeId(q.items[ops.nextInt(q.items.length)]);
                }
              case 12:
                q.insertAt(ops.nextInt(q.items.length + 2), nextId++);
              case 14:
                if (q.items.length > q.currentIndex + 1) {
                  final i = q.currentIndex + 1 + ops.nextInt(q.items.length - q.currentIndex - 1);
                  final user = i <= q.currentIndex + q.userAhead;
                  final before = q.items;
                  final ahead = q.userAhead;
                  final id = q.items[i];
                  q.removeAt(i);
                  q.putBack(i, id, user: user);
                  expect(q.items, before, reason: 'seed $seed step $step');
                  expect(q.userAhead, ahead);
                }
              case 13:
                if (q.items.isNotEmpty) {
                  q.enqueue(q.items[ops.nextInt(q.items.length)]); // duplicate
                }
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
            expect(q.invariantError, isNull, reason: 'seed $seed step $step');
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
        final before = [
          q.currentId,
          q.currentIndex,
          q.revision,
          ...q.playOrder,
        ];
        q.peekNext();
        q.peekNext(auto: false);
        expect([
          q.currentId,
          q.currentIndex,
          q.revision,
          ...q.playOrder,
        ], before);
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
      q.enqueue(8);
      expectBump('enqueue');
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

  group(
    '«Svuota» builds what follows again from the list playback came from',
    () {
      const source = [1, 2, 3, 4, 5];

      test('in order: from the current track on, manual additions gone', () {
        final q = make(source, start: 1)
          ..enqueue(99)
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
        expect(
          q.restoreState(saved),
          isFalse,
          reason: 'another track plays now',
        );
      });
    },
  );

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

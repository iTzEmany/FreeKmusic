import 'package:codecore/services/shuffle_plus/insertion_plan.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> local(int n) => List.generate(n, (i) => i + 1);

void main() {
  test('20 songs, position 5, every 4: three slots, 8, 12 and 16', () {
    expect(plusPlan(local(20), 5, 4), [8, 12, 16]);
  });

  test('max limits the slots, and every 3 and 10 follow the same rule', () {
    expect(plusPlan(local(20), 5, 4, max: 2), [8, 12]);
    expect(plusPlan(local(30), 0, 3), [2, 5, 8]);
    expect(plusPlan(local(40), 0, 10), [9, 19, 29]);
  });

  test('a suggestion already waiting is a filled slot', () {
    final items = local(12)..insert(3, -1);
    expect(plusPlan(items, 0, 4), [7, 11]);
    expect(plusPlan(items, 0, 4, max: 1), isEmpty);
  });

  test('a suggestion behind the current song does not count', () {
    expect(plusPlan([-1, 1, 2, 3, 4], 1, 4), [4]);
  });

  test('no current song (-1) gives no slots', () {
    expect(plusPlan(local(6), -1, 4), isEmpty);
  });

  test('never a slot past the end of the queue', () {
    expect(plusPlan([1, 2, 3], 0, 4), isEmpty);
    expect(plusPlan([1, 2, 3, 4], 0, 4), [3], reason: 'one song still follows');
    expect(plusPlan([1], 0, 4), isEmpty);
    expect(plusPlan(const [], -1, 4), isEmpty);
  });

  test('a long run of songs heard: the first slot is right after the current song', () {
    expect(plusPlan([1, 2, 3, 4, 5, 6], 2, 4, playedSinceLast: 9), [3]);
  });

  test('skip passes over the queue block', () {
    expect(
      plusPlan([1, 2, 3, 4, 5, 6], 2, 4, playedSinceLast: 9, skip: 2),
      [5],
    );
  });
}

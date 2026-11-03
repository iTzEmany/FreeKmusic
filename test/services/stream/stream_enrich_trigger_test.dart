import 'dart:async';

import 'package:codecore/services/stream/stream_enrich_trigger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<int> calls;
  late Completer<void> gate;
  late StreamEnrichTrigger trigger;
  Duration s(int n) => Duration(seconds: n);

  setUp(() {
    calls = [];
    gate = Completer<void>()..complete();
    trigger = StreamEnrichTrigger((row) {
      calls.add(row);
      return gate.future;
    });
  });

  test('does not start before 5 s', () {
    trigger.tick(-1, 7, s(4));
    expect(calls, isEmpty);
  });

  test('starts at 5 s, once per listen', () {
    trigger.tick(-1, 7, s(5));
    trigger.tick(-1, 7, s(6));
    expect(calls, [7]);
  });

  test('changing track before 5 s cancels it', () {
    trigger.tick(-1, 7, s(4));
    trigger.tick(-2, 8, s(1));
    trigger.tick(-2, 8, s(4));
    expect(calls, isEmpty);
  });

  test('a row that arrives after 5 s starts as soon as it is there', () {
    trigger.tick(-1, null, s(8));
    expect(calls, isEmpty);
    trigger.tick(-1, 7, s(9));
    expect(calls, [7]);
  });

  test('no duplicate while one is running; a new listen retries', () async {
    gate = Completer<void>();
    trigger.tick(-1, 7, s(5));
    trigger.tick(-2, 8, s(0));
    trigger.tick(-1, 7, s(6)); // same row again, first still running
    expect(calls, [7]);
    gate.complete();
    await Future<void>.delayed(Duration.zero);
    trigger.tick(-3, 9, s(0));
    trigger.tick(-1, 7, s(6));
    expect(calls, [7, 7]);
  });

  test('an error does not escape', () async {
    trigger = StreamEnrichTrigger((row) async => throw StateError('down'));
    trigger.tick(-1, 7, s(5));
    await Future<void>.delayed(Duration.zero);
  });
}

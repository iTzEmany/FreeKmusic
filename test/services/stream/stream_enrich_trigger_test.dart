import 'dart:async';

import 'package:codecore/services/stream/stream_enrich_trigger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<int> calls;
  late Completer<void> gate;
  late StreamEnrichTrigger trigger;
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    calls = [];
    gate = Completer<void>()..complete();
    trigger = StreamEnrichTrigger((row) {
      calls.add(row);
      return gate.future;
    });
  });

  test('starts at once when the current track has its row', () {
    trigger.update(-1, 7);
    expect(calls, [7]);
  });

  test('does not start without a row, and starts as soon as it arrives', () {
    trigger.update(-1, null);
    expect(calls, isEmpty);
    trigger.update(-1, 7);
    expect(calls, [7]);
  });

  test('once per listen, even after the enrich completes', () async {
    trigger.update(-1, 7);
    await settle();
    trigger.update(-1, 7);
    await settle();
    trigger.update(-1, 7);
    expect(calls, [7]);
  });

  test('a new listen retries, also the same id after null', () async {
    trigger.update(-1, 7);
    await settle();
    trigger.update(null, null);
    trigger.update(-1, 7);
    await settle();
    trigger.update(-2, 8);
    trigger.update(-1, 7);
    expect(calls, [7, 7, 8, 7]);
  });

  test('a different row in the same listen is launched', () {
    trigger.update(-1, 7);
    trigger.update(-1, 8);
    expect(calls, [7, 8]);
  });

  test('no duplicate on the same row while one is running', () async {
    gate = Completer<void>();
    trigger.update(-1, 7);
    trigger.update(-2, 8);
    trigger.update(-1, 7); // new listen, first still running
    expect(calls, [7, 8]);
    gate.complete();
  });

  test('a synchronous throw is logged and the next listen retries', () async {
    var n = 0;
    trigger = StreamEnrichTrigger((row) {
      n++;
      throw StateError('down');
    });
    trigger.update(-1, 7);
    await settle();
    trigger.update(-2, 8);
    trigger.update(-1, 7);
    expect(n, 3);
  });

  test('an async error does not escape', () async {
    trigger = StreamEnrichTrigger((row) async => throw StateError('down'));
    trigger.update(-1, 7);
    await settle();
  });
}

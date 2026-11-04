import 'package:codecore/services/shuffle_plus/radio_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var now = DateTime(2026, 11, 4, 12);
  late RadioGate gate;

  setUp(() {
    now = DateTime(2026, 11, 4, 12);
    gate = RadioGate(now: () => now);
  });

  test('free before the first request; a minute apart after it', () {
    expect(gate.canAsk, isTrue);
    gate.asked();
    expect(gate.canAsk, isFalse);
    expect(gate.nextAsk, now.add(RadioGate.minGap));
    now = now.add(const Duration(seconds: 59));
    expect(gate.canAsk, isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(gate.canAsk, isTrue);
    expect(gate.nextAsk, isNull);
  });

  test('a 429 closes the gate for 15 minutes, then it reopens', () {
    gate.trip();
    expect(gate.rateLimited, isTrue);
    expect(gate.canAsk, isFalse);
    expect(gate.nextAsk, now.add(RadioGate.pause));
    now = now.add(RadioGate.pause);
    expect(gate.rateLimited, isFalse);
    expect(gate.canAsk, isTrue);
  });

  test('the later of the gap and the pause wins', () {
    gate.trip();
    now = now.add(const Duration(minutes: 14, seconds: 30));
    gate.asked();
    expect(gate.nextAsk, now.add(RadioGate.minGap));
  });
}

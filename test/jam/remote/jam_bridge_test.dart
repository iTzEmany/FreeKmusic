import 'dart:typed_data';

import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_bridge.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const a = BrokerEntry(host: 'a.net', port: 8883);
const b = BrokerEntry(host: 'b.net', port: 8883);

void main() {
  late FakeNet net;
  late FakeMqttLink link;
  late JamBridge bridge;
  late List<JamBridgeStatus> seen;

  void setUp_() {
    net = FakeNet([a, b]);
    link = FakeMqttLink(net);
    bridge = JamBridge(link, [a, b]);
    seen = [];
    bridge.statuses.listen(seen.add);
  }

  test('connects to the first broker and goes up', () {
    fakeAsync((t) {
      setUp_();
      bridge.start();
      t.flushMicrotasks();
      expect(bridge.status, JamBridgeStatus.up);
      expect(bridge.broker, a);
      expect(link.connectAttempts, [a]);
    });
  });

  test('first broker down: the second takes over after 1 s', () {
    fakeAsync((t) {
      setUp_();
      net[a].goDown();
      bridge.start();
      t.flushMicrotasks();
      expect(bridge.status, JamBridgeStatus.connecting);
      t.elapse(const Duration(seconds: 1));
      expect(bridge.broker, b);
    });
  });

  test(
    'no broker up: unreachable, attempts go on with waits 1,2,4,8,16,30,30 s',
    () {
      fakeAsync((t) {
        setUp_();
        net[a].goDown();
        net[b].goDown();
        bridge.start();
        t.flushMicrotasks();
        var total = 0;
        for (final w in [1, 2, 4, 8, 16, 30, 30]) {
          t.elapse(Duration(seconds: w - 1));
          expect(
            link.connectAttempts.length,
            lessThan(total + 2),
            reason: 'too early before ${w}s',
          );
          t.elapse(const Duration(seconds: 1));
          total++;
          expect(link.connectAttempts.length, total + 1, reason: 'wait $w');
        }
        expect(bridge.status, JamBridgeStatus.unreachable);
        expect(link.connectAttempts.take(4), [a, b, a, b]);
      });
    },
  );

  test('a loss retries the same broker at once, then the next after 1 s', () {
    fakeAsync((t) {
      setUp_();
      bridge.start();
      t.flushMicrotasks();
      net[a].goDown();
      t.flushMicrotasks();
      expect(link.connectAttempts, [a, a]);
      expect(bridge.status, JamBridgeStatus.retrying);
      t.elapse(const Duration(seconds: 1));
      expect(link.connectAttempts, [a, a, b]);
      expect(bridge.broker, b);
    });
  });

  test('when the broker comes back, the subscriptions are redone and retained messages arrive', () {
    fakeAsync((t) {
      setUp_();
      bridge.subscribe('t/x');
      bridge.start();
      t.flushMicrotasks();
      expect(link.subscribed, {'t/x'});
      net[a].goDown();
      net[b].goDown();
      t.elapse(const Duration(seconds: 40));
      expect(bridge.status, JamBridgeStatus.retrying);
      expect(link.subscribed, isEmpty);
      net[b].retained['t/x'] = Uint8List.fromList([1]);
      final got = <Uint8List>[];
      bridge.messages.listen((m) => got.add(m.payload));
      var reconnects = 0;
      bridge.connections.listen((_) => reconnects++);
      net[b].comeBack();
      t.elapse(
        const Duration(seconds: 60),
      ); // at most one wait of 30 s per broker
      expect(bridge.broker, b);
      expect(link.subscribed, {'t/x'});
      expect(reconnects, 1);
      expect(got.single, [1]);
      expect(seen.last, JamBridgeStatus.up);
    });
  });

  test('messages keep flowing on the same stream across a reconnection', () {
    fakeAsync((t) {
      setUp_();
      bridge.subscribe('t/y');
      bridge.start();
      t.flushMicrotasks();
      final got = <int>[];
      bridge.messages.listen((m) => got.add(m.payload.first));
      bridge.publish('t/y', Uint8List.fromList([1]));
      net[a].goDown();
      t.flushMicrotasks();
      expect(bridge.publish('t/y', Uint8List.fromList([9])), isFalse);
      t.elapse(const Duration(seconds: 1));
      bridge.publish('t/y', Uint8List.fromList([2]));
      t.flushMicrotasks();
      expect(got, [1, 2]);
    });
  });

  test('stop cancels the retries', () {
    fakeAsync((t) {
      setUp_();
      net[a].goDown();
      net[b].goDown();
      bridge.start();
      t.flushMicrotasks();
      bridge.stop();
      t.elapse(const Duration(minutes: 5));
      expect(link.connectAttempts.length, 1);
    });
  });
}

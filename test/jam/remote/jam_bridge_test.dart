import 'dart:async';
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

  test('the very first CONNECT times out: the same broker is tried again at once', () {
    fakeAsync((t) {
      setUp_();
      link.failNext = 1;
      bridge.start();
      t.flushMicrotasks();
      expect(link.connectAttempts, [a, a]);
      expect(bridge.broker, a);
      expect(seen, [JamBridgeStatus.up], reason: 'never "unreachable" for one timeout');
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
        var total = 1; // the first CONNECT is tried twice at once
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
        expect(link.connectAttempts.take(4), [a, a, b, a]);
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

  test('next gives up the broker in use for the following one', () {
    fakeAsync((t) {
      setUp_();
      bridge.start();
      t.flushMicrotasks();
      bridge.next();
      expect(bridge.status, JamBridgeStatus.retrying);
      t.flushMicrotasks();
      expect(bridge.broker, b);
      expect(link.connectAttempts, [a, b]);
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
      expect(link.connectAttempts.length, 2, reason: 'the immediate retry, then nothing');
    });
  });

  test('after stop the status is connecting and publish is false', () {
    fakeAsync((t) {
      setUp_();
      bridge.start();
      t.flushMicrotasks();
      bridge.stop();
      expect(bridge.status, JamBridgeStatus.connecting);
      expect(bridge.publish('t', Uint8List(1)), isFalse);
    });
  });

  test('stop during a connect leaves the link disconnected', () {
    fakeAsync((t) {
      setUp_();
      final gate = Completer<void>();
      link.hold = gate.future;
      bridge.start();
      t.flushMicrotasks();
      bridge.stop();
      gate.complete();
      t.flushMicrotasks();
      expect(link.connected, isFalse);
      expect(bridge.status, JamBridgeStatus.connecting);
    });
  });

  test(
    'stop then start: an old connect finishing does not drop the new link',
    () {
      fakeAsync((t) {
        setUp_();
        final gate = Completer<void>();
        link.hold = gate.future;
        bridge.start();
        t.flushMicrotasks();
        bridge.stop();
        link.hold = null;
        bridge.start();
        t.flushMicrotasks();
        gate.complete();
        t.flushMicrotasks();
        expect(link.connected, isTrue);
        expect(bridge.status, JamBridgeStatus.up);
      });
    },
  );

  test('dispose with a pending attempt is quiet', () {
    fakeAsync((t) {
      setUp_();
      final gate = Completer<void>();
      link.hold = gate.future;
      bridge.start();
      t.flushMicrotasks();
      bridge.dispose();
      gate.complete();
      t.flushMicrotasks();
      expect(link.connected, isFalse);
    });
  });

  test('a restart without network ends unreachable', () {
    fakeAsync((t) {
      setUp_();
      bridge.start();
      t.flushMicrotasks();
      bridge.stop();
      net[a].goDown();
      net[b].goDown();
      bridge.start();
      t.elapse(const Duration(seconds: 2));
      expect(bridge.status, JamBridgeStatus.unreachable);
    });
  });

  test(
    'publish between the socket dying and onDisconnected is false, no throw',
    () {
      fakeAsync((t) {
        setUp_();
        bridge.start();
        t.flushMicrotasks();
        link.disconnect(); // gone, onDisconnected not fired
        expect(bridge.publish('t', Uint8List(1)), isFalse);
      });
    },
  );
}

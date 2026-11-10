import 'package:codecore/core/system_volume.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('codecore/volume');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(ch, null));

  test('current, start and stop call the native methods', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(ch, (c) async {
      calls.add(c.method);
      return c.method == 'get' ? 0.5 : null;
    });
    final v = SystemVolume(ch);
    expect(await v.current(), 0.5);
    await v.start();
    await v.stop();
    expect(calls, ['get', 'start', 'stop']);
  });

  test('changed events reach the stream', () async {
    final v = SystemVolume(ch);
    final got = <double>[];
    final sub = v.changes.listen(got.add);
    await messenger.handlePlatformMessage(
      ch.name,
      ch.codec.encodeMethodCall(const MethodCall('changed', 0.25)),
      (_) {},
    );
    await messenger.handlePlatformMessage(
      ch.name,
      ch.codec.encodeMethodCall(const MethodCall('changed', 0)),
      (_) {},
    );
    await sub.cancel();
    expect(got, [0.25, 0.0]);
  });

  test('missing plugin does not crash', () async {
    final v = SystemVolume(ch);
    expect(await v.current(), isNull);
    await v.start();
    await v.stop();
  });
}

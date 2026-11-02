
import 'package:codecore/services/jam/remote/jam_beacon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('codecore/jam_beacon');
  final calls = <MethodCall>[];
  Future<Object?> Function(MethodCall) handler = (_) async => null;
  late ChannelJamBeacon beacon;

  setUp(() {
    calls.clear();
    handler = (_) async => null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) {
      calls.add(c);
      return handler(c);
    });
    beacon = ChannelJamBeacon(channel);
  });

  test('capabilities reads the flags, including location off', () async {
    handler = (_) async => {
          'bluetoothOn': true,
          'scan': true,
          'advertise': false,
          'locationOff': true,
        };
    final c = await beacon.capabilities();
    expect(
        (c.bluetoothOn, c.scan, c.advertise, c.locationOff),
        (true, true, false, true));
  });

  test('no channel or a failing one answers empty, never throws', () async {
    handler = (_) async => throw PlatformException(code: 'x');
    expect((await beacon.capabilities()).scan, isFalse);
    expect((await beacon.permissions()).advertise, isFalse);
    expect(await beacon.startScan(), isFalse);
    await beacon.stopScan();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    expect(await beacon.startAdvertising(Uint8List(26)), isFalse);
  });

  test('denied permissions come back as false', () async {
    handler = (_) async => {'scan': false, 'advertise': false};
    final p = await beacon.requestPermissions();
    expect((p.scan, p.advertise), (false, false));
    expect(calls.single.method, 'requestPermissions');
  });

  test('advertising and scanning are forwarded', () async {
    handler = (_) async => true;
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(await beacon.startAdvertising(bytes), isTrue);
    expect(await beacon.updateAdvertising(bytes), isTrue);
    await beacon.stopAdvertising();
    expect(await beacon.startScan(), isTrue);
    await beacon.stopScan();
    expect(calls.map((c) => c.method), [
      'startAdvertising',
      'updateAdvertising',
      'stopAdvertising',
      'startScan',
      'stopScan',
    ]);
    expect(calls.first.arguments, bytes);
  });

  test('found beacons reach the stream with bytes and rssi', () async {
    final got = <JamBeaconFound>[];
    final sub = beacon.found.listen(got.add);
    final data = const StandardMethodCodec().encodeMethodCall(MethodCall(
        'found', {'bytes': Uint8List.fromList([1, 9]), 'rssi': -70}));
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channel.name, data, (_) {});
    await sub.cancel();
    expect(got.single.bytes, [1, 9]);
    expect(got.single.rssi, -70);
  });
}

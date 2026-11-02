import 'dart:async';

import 'package:flutter/services.dart';

import '../../../core/app_log.dart';

/// What the phone can do over Bluetooth LE right now.
class JamBeaconCapabilities {
  const JamBeaconCapabilities({
    this.bluetoothOn = false,
    this.scan = false,
    this.advertise = false,
    this.locationOff = false,
    this.needsLocation = false,
  });
  final bool bluetoothOn;
  final bool scan;
  final bool advertise;

  /// Android <= 11 only: the scan needs the location switched on (D-234).
  final bool locationOff;

  /// Android <= 11: the scan permission is the location one (sheet wording).
  final bool needsLocation;
}

class JamBeaconPermissions {
  const JamBeaconPermissions({this.scan = false, this.advertise = false});
  final bool scan;
  final bool advertise;
}

/// A beacon heard nearby: the service-data bytes and the signal strength.
typedef JamBeaconFound = ({Uint8List bytes, int rssi});

/// The Bluetooth LE "there is a Jam here" beacon (D-254). Without support or
/// permission everything answers empty/false and never throws.
abstract class JamBeacon {
  Future<JamBeaconCapabilities> capabilities();
  Future<JamBeaconPermissions> permissions();
  Future<JamBeaconPermissions> requestPermissions();
  Future<bool> startAdvertising(Uint8List bytes);
  Future<bool> updateAdvertising(Uint8List bytes);
  Future<void> stopAdvertising();
  Future<bool> startScan();
  Future<void> stopScan();
  Stream<JamBeaconFound> get found;

  /// The native side lost the scan (`scan`) or the announcement (`advertise`) by itself:
  /// failure, Bluetooth switched off. Whoever thought it active must try again later.
  Stream<JamBeaconKind> get failed;
}

enum JamBeaconKind { scan, advertise }

/// On Android over `codecore/jam_beacon`; elsewhere the channel is missing and
/// every call answers empty.
class ChannelJamBeacon implements JamBeacon {
  ChannelJamBeacon([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('codecore/jam_beacon') {
    _channel.setMethodCallHandler(_onCall);
  }
  final MethodChannel _channel;
  final _found = StreamController<JamBeaconFound>.broadcast();
  final _failed = StreamController<JamBeaconKind>.broadcast();

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'scanFailed') return _failed.add(JamBeaconKind.scan);
    if (call.method == 'advertiseFailed') return _failed.add(JamBeaconKind.advertise);
    if (call.method != 'found') return;
    final a = call.arguments;
    if (a is! Map || a['bytes'] is! Uint8List || a['rssi'] is! int) return;
    _found.add((bytes: a['bytes'] as Uint8List, rssi: a['rssi'] as int));
  }

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } catch (e, st) {
      AppLog.w('beacon: $method failed', e, st);
      return null;
    }
  }

  Future<Map<String, bool>> _flags(String method) async {
    final m = await _call<Map<Object?, Object?>>(method);
    return {for (final e in (m ?? {}).entries) '${e.key}': e.value == true};
  }

  @override
  Future<JamBeaconCapabilities> capabilities() async {
    final m = await _flags('capabilities');
    return JamBeaconCapabilities(
      bluetoothOn: m['bluetoothOn'] ?? false,
      scan: m['scan'] ?? false,
      advertise: m['advertise'] ?? false,
      locationOff: m['locationOff'] ?? false,
      needsLocation: m['needsLocation'] ?? false,
    );
  }

  JamBeaconPermissions _perms(Map<String, bool> m) => JamBeaconPermissions(
      scan: m['scan'] ?? false, advertise: m['advertise'] ?? false);

  @override
  Future<JamBeaconPermissions> permissions() async =>
      _perms(await _flags('permissions'));

  @override
  Future<JamBeaconPermissions> requestPermissions() async =>
      _perms(await _flags('requestPermissions'));

  @override
  Future<bool> startAdvertising(Uint8List bytes) async =>
      await _call<bool>('startAdvertising', bytes) ?? false;

  @override
  Future<bool> updateAdvertising(Uint8List bytes) async =>
      await _call<bool>('updateAdvertising', bytes) ?? false;

  @override
  Future<void> stopAdvertising() => _call<void>('stopAdvertising');

  @override
  Future<bool> startScan() async => await _call<bool>('startScan') ?? false;

  @override
  Future<void> stopScan() => _call<void>('stopScan');

  @override
  Stream<JamBeaconFound> get found => _found.stream;
  @override
  Stream<JamBeaconKind> get failed => _failed.stream;
}

/// For tests: records calls, lets a test play beacons heard.
class FakeJamBeacon implements JamBeacon {
  JamBeaconCapabilities caps = const JamBeaconCapabilities(
      bluetoothOn: true, scan: true, advertise: true);
  JamBeaconPermissions perms =
      const JamBeaconPermissions(scan: true, advertise: true);

  /// What [requestPermissions] grants.
  JamBeaconPermissions grantOnRequest =
      const JamBeaconPermissions(scan: true, advertise: true);
  Uint8List? advertising;
  bool scanning = false;
  int requests = 0;
  final _found = StreamController<JamBeaconFound>.broadcast();
  final _failed = StreamController<JamBeaconKind>.broadcast();

  /// The native side drops the scan or the announcement by itself.
  void fail(JamBeaconKind kind) {
    if (kind == JamBeaconKind.scan) scanning = false;
    if (kind == JamBeaconKind.advertise) advertising = null;
    _failed.add(kind);
  }

  /// A beacon heard, only while scanning.
  void hear(Uint8List bytes, [int rssi = -60]) {
    if (scanning) _found.add((bytes: bytes, rssi: rssi));
  }

  @override
  Future<JamBeaconCapabilities> capabilities() async => caps;
  @override
  Future<JamBeaconPermissions> permissions() async => perms;
  @override
  Future<JamBeaconPermissions> requestPermissions() async {
    requests++;
    return perms = grantOnRequest;
  }

  @override
  Future<bool> startAdvertising(Uint8List bytes) async {
    if (!perms.advertise || !caps.advertise) return false;
    advertising = bytes;
    return true;
  }

  @override
  Future<bool> updateAdvertising(Uint8List bytes) => startAdvertising(bytes);
  @override
  Future<void> stopAdvertising() async => advertising = null;
  @override
  Future<bool> startScan() async {
    if (!perms.scan || !caps.scan) return false;
    return scanning = true;
  }

  @override
  Future<void> stopScan() async => scanning = false;
  @override
  Stream<JamBeaconFound> get found => _found.stream;
  @override
  Stream<JamBeaconKind> get failed => _failed.stream;
}

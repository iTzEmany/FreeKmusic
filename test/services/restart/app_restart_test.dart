import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/services/restart/app_restart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> started;
  late List<int> exits;
  late List<String> events;
  setUp(() {
    started = [];
    exits = [];
    events = [];
  });

  void mockChannel(Future<Object?> Function(MethodCall) h) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('codecore/restart'), h);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('codecore/restart'), null));
  }

  DesktopRestart make(Map<String, String> env, {bool throws = false}) => DesktopRestart(
    start: (exe, args) async {
      if (throws) throw const ProcessExceptionStub();
      started.add(exe);
      events.add('start');
    },
    exitApp: (c) {
      exits.add(c);
      events.add('exit');
    },
    env: env,
    executable: '/opt/app/codecore',
  );

  test('Android: missing channel gives false', () async {
    expect(await AndroidRestart(channel: const MethodChannel('nope')).restart(), isFalse);
  });

  test('Android: the channel answer is passed on; null and PlatformException give false', () async {
    final r = AndroidRestart();
    mockChannel((_) async => true);
    expect(await r.restart(), isTrue);
    mockChannel((_) async => null);
    expect(await r.restart(), isFalse);
    mockChannel((_) async => throw PlatformException(code: 'x'));
    expect(await r.restart(), isFalse);
  });

  test('desktop: starts \$APPIMAGE when set, then exits 0', () async {
    expect(await make({'APPIMAGE': '/tmp/a.AppImage', 'APPDIR': '/opt/app'}).restart(), isTrue);
    expect(started, ['/tmp/a.AppImage']);
    expect(exits, [0]);
    expect(events, ['start', 'exit']);
  });

  test('desktop: falls back to the resolved executable', () async {
    expect(await make({'APPIMAGE': ''}).restart(), isTrue);
    expect(started, ['/opt/app/codecore']);
    expect(exits, [0]);
  });

  test('desktop: an inherited \$APPIMAGE with the executable outside the mount is ignored', () async {
    expect(await make({'APPIMAGE': '/home/u/other.AppImage', 'APPDIR': '/tmp/.mount_x'}).restart(), isTrue);
    expect(started, ['/opt/app/codecore']);
  });

  test('quit: Android calls exit on the channel, desktop exits 0', () async {
    final calls = <String>[];
    mockChannel((c) async {
      calls.add(c.method);
      return null;
    });
    await AndroidRestart().quit();
    expect(calls, ['exit']);
    await make({}).quit();
    expect(exits, [0]);
  });

  test('Flatpak: false, nothing started', () async {
    expect(await make({'FLATPAK_ID': 'x'}).restart(), isFalse);
    expect(started, isEmpty);
    expect(exits, isEmpty);
  });

  test('starter throws: false and no exit', () async {
    expect(await make({}, throws: true).restart(), isFalse);
    expect(exits, isEmpty);
  });
}

class ProcessExceptionStub implements Exception {
  const ProcessExceptionStub();
}

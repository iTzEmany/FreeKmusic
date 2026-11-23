import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/services/restart/app_restart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> started;
  late List<int> exits;
  setUp(() {
    started = [];
    exits = [];
  });

  DesktopRestart make(Map<String, String> env, {bool throws = false}) => DesktopRestart(
    start: (exe, args) async {
      if (throws) throw const ProcessExceptionStub();
      started.add(exe);
    },
    exitApp: exits.add,
    env: env,
    executable: '/opt/app/codecore',
  );

  test('Android: missing channel gives false', () async {
    expect(await AndroidRestart(channel: const MethodChannel('nope')).restart(), isFalse);
  });

  test('desktop: starts \$APPIMAGE when set, then exits 0', () async {
    expect(await make({'APPIMAGE': '/tmp/a.AppImage'}).restart(), isTrue);
    expect(started, ['/tmp/a.AppImage']);
    expect(exits, [0]);
  });

  test('desktop: falls back to the resolved executable', () async {
    expect(await make({'APPIMAGE': ''}).restart(), isTrue);
    expect(started, ['/opt/app/codecore']);
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

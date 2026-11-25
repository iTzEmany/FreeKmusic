
import 'package:codecore/data/settings/settings_store.dart' show closeToTrayDefault;
import 'package:codecore/services/window/tray_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'window_fakes.dart';

Future<(TrayService, FakeWindowHost, FakeTrayAdapter, List<String>)> _make({bool supported = true, bool closeToTray = true}) async {
  final host = FakeWindowHost();
  final adapter = FakeTrayAdapter(supported: supported);
  final log = <String>[];
  final s = TrayService(
    host: host,
    adapter: adapter,
    labels: {for (final c in TrayCommand.values) c: c.name},
    closeToTray: () => closeToTray,
    playPause: () async => log.add('playPause'),
    next: () async => log.add('next'),
    quit: () async => log.add('quit'),
  );
  await s.start();
  return (s, host, adapter, log);
}

Future<void> _tick() => Future<void>.delayed(Duration.zero);

void main() {
  test('the default is on for Windows, off for Linux', () {
    expect(closeToTrayDefault(windows: true), isTrue);
    expect(closeToTrayDefault(windows: false), isFalse);
  });

  test('X with the option on hides the window; the menu brings it back', () async {
    final (_, host, adapter, log) = await _make();
    host.pressX();
    await _tick();
    adapter.press!(TrayCommand.toggleWindow);
    await _tick();
    expect(host.calls, ['preventClose true', 'hide', 'show']);
    expect(log, isEmpty);
  });

  test('X with the option off quits through the one clean exit', () async {
    final (_, host, _, log) = await _make(closeToTray: false);
    host.pressX();
    await _tick();
    expect(log, ['quit']);
    expect(host.calls, ['preventClose true']);
  });

  test('no tray: the option never hides the window', () async {
    final (s, host, _, log) = await _make(supported: false);
    expect(s.available, isFalse);
    host.pressX();
    await _tick();
    expect(log, ['quit']);
    expect(host.calls, isNot(contains('hide')));
  });

  test('the four menu commands call the player and the exit', () async {
    final (_, host, adapter, log) = await _make();
    expect(adapter.shown!.keys, TrayCommand.values);
    adapter.press!(TrayCommand.playPause);
    adapter.press!(TrayCommand.next);
    adapter.press!(TrayCommand.toggleWindow);
    adapter.press!(TrayCommand.quit);
    await _tick();
    expect(log, ['playPause', 'next', 'quit']);
    expect(host.calls, contains('hide'));
  });
}

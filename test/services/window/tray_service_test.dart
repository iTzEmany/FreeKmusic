
import 'package:codecore/data/settings/settings_store.dart' show SettingsStore, closeToTrayDefault, closeToTrayKey;
import 'package:codecore/services/window/tray_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'window_fakes.dart';

Future<(TrayService, FakeWindowHost, FakeTrayAdapter, List<String>)> _make({bool supported = true, bool closeToTray = true, bool fails = false}) async {
  final host = FakeWindowHost();
  final adapter = FakeTrayAdapter(supported: supported, fails: fails);
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

  test('the settings read the platform default until the user chooses', () async {
    SharedPreferences.setMockInitialValues({});
    expect(SettingsStore(await SharedPreferences.getInstance()).readSettings().closeToTray, closeToTrayDefault());
    SharedPreferences.setMockInitialValues({closeToTrayKey: !closeToTrayDefault()});
    expect(SettingsStore(await SharedPreferences.getInstance()).readSettings().closeToTray, !closeToTrayDefault());
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

  test('once the exit started, the close of the window being destroyed does not re-enter', () async {
    final (_, host, adapter, log) = await _make(closeToTray: false);
    adapter.press!(TrayCommand.quit);
    await _tick();
    host.pressX(); // the non-cancelable close that follows the destruction
    host.pressX();
    await _tick();
    expect(log, ['quit']);
  });

  test('Show/Hide asks the window, not a copy: a window shown by a second launch is hidden', () async {
    final (_, host, adapter, _) = await _make();
    host.pressX();
    await _tick();
    host.visible = true; // brought back without the tray
    adapter.press!(TrayCommand.toggleWindow);
    await _tick();
    host.visible = false; // hidden without the tray
    adapter.press!(TrayCommand.toggleWindow);
    await _tick();
    expect(host.calls, ['preventClose true', 'hide', 'hide', 'show']);
  });

  test('a tray that throws on show: not available, and the X quits', () async {
    final (s, host, _, log) = await _make(fails: true);
    expect(s.available, isFalse);
    host.pressX();
    await _tick();
    expect(log, ['quit']);
    expect(host.calls, isNot(contains('hide')));
  });
}

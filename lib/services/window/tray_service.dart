import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart' as tray;

import '../../core/app_log.dart';
import 'window_host.dart';

enum TrayCommand { playPause, next, toggleWindow, quit }

/// The system tray icon and its menu. The real one is [NativeTrayAdapter];
/// tests use a fake, so no icon is ever created there.
abstract class TrayAdapter {
  /// Shows the icon with one menu entry per [labels]; false when there is no tray to show it in.
  Future<bool> show(Map<TrayCommand, String> labels, void Function(TrayCommand) onCommand);

  void dispose();
}

/// Closing the window, the tray and «Chiudi nella barra di sistema» (D-729).
/// The window's X is always intercepted: it either hides the window (option on and a tray
/// there to bring it back) or leaves through [quit], the same clean exit as Ctrl+Q and the
/// menu's «Esci».
class TrayService {
  TrayService({
    required this.host,
    required this.adapter,
    required this.labels,
    required this.closeToTray,
    required this.playPause,
    required this.next,
    required this.quit,
  });

  final WindowHost host;
  final TrayAdapter adapter;
  final Map<TrayCommand, String> labels;
  final bool Function() closeToTray;
  final Future<void> Function() playPause, next, quit;
  bool available = false;
  bool _quitting = false;
  StreamSubscription<void>? _sub;

  Future<void> start() async {
    try {
      available = await adapter.show(labels, (c) => unawaited(_run(c)));
    } on Object catch (e, st) {
      AppLog.w('tray not started', e, st);
    }
    await host.setPreventClose(true);
    _sub = host.closeRequests.listen((_) => unawaited(onCloseRequested()));
  }

  /// Once the exit has started, destroying the window sends one more (not cancelable) close: ignored.
  Future<void> onCloseRequested() async {
    if (_quitting) return;
    if (available && closeToTray()) return host.hide();
    await _leave();
  }

  Future<void> _leave() {
    _quitting = true;
    return quit();
  }

  Future<void> _run(TrayCommand c) => switch (c) {
    TrayCommand.playPause => playPause(),
    TrayCommand.next => next(),
    TrayCommand.toggleWindow => _toggle(),
    TrayCommand.quit => _leave(),
  };

  /// Asks the window every time: the state may have changed without the tray (a second launch shows it).
  Future<void> _toggle() async => await host.isVisible() ? host.hide() : host.show();

  void dispose() {
    unawaited(_sub?.cancel());
    adapter.dispose();
  }
}

class NativeTrayAdapter implements TrayAdapter {
  tray.TrayIcon? _icon;
  tray.Menu? _menu;
  final _items = <tray.MenuItem>[];

  @override
  Future<bool> show(Map<TrayCommand, String> labels, void Function(TrayCommand) onCommand) async {
    if (!tray.TrayManager.instance.isSupported() || !await _linuxHasTray()) return false;
    final image = tray.ImageAsset.fromAsset('assets/icon/tray.png');
    final icon = tray.TrayIcon.create();
    final menu = tray.Menu.create();
    if (image == null || icon == null || menu == null) return false;
    for (final c in TrayCommand.values) {
      if (c == TrayCommand.quit) menu.addSeparator();
      final item = tray.MenuItem.createWithLabelAndType(labels[c]!, tray.MenuItemType.normal);
      if (item == null) continue;
      item.addListener((e) {
        if (e is tray.MenuItemClickedEvent) onCommand(c);
      });
      menu.addItem(item);
      _items.add(item); // held: a collected item would stop answering
    }
    // Windows: a click on the icon shows or hides the window; on Linux the menu is all there is.
    if (!Platform.isLinux) {
      icon.addListener((e) {
        if (e is tray.TrayIconClickedEvent) onCommand(TrayCommand.toggleWindow);
      });
    }
    icon.icon = image;
    icon.setTooltip('FreeKmusic');
    icon.setContextMenu(menu);
    icon.setVisible(true);
    _icon = icon;
    _menu = menu;
    return true;
  }

  /// Linux (StatusNotifierItem): the icon is seen only with a watcher on the bus AND a host registered
  /// (GNOME with no AppIndicator extension has neither), or a hidden window could not come back.
  /// Checked once, at start. In a Flatpak it is off until proven there: the X would hide the window with no icon.
  Future<bool> _linuxHasTray() async {
    if (!Platform.isLinux) return true;
    if (File('/.flatpak-info').existsSync() || Platform.environment.containsKey('FLATPAK_ID')) return false;
    final owner = await _gdbus(const [
      '--dest', 'org.freedesktop.DBus', '--object-path', '/org/freedesktop/DBus',
      '--method', 'org.freedesktop.DBus.NameHasOwner', 'org.kde.StatusNotifierWatcher',
    ]);
    if (!owner.contains('true')) return false;
    final host = await _gdbus(const [
      '--dest', 'org.kde.StatusNotifierWatcher', '--object-path', '/StatusNotifierWatcher',
      '--method', 'org.freedesktop.DBus.Properties.Get', 'org.kde.StatusNotifierWatcher', 'IsStatusNotifierHostRegistered',
    ]);
    return host.contains('true');
  }

  /// One `gdbus call` on the session bus; empty output on any failure. The child is killed at the timeout.
  Future<String> _gdbus(List<String> args) async {
    Process? proc;
    try {
      proc = await Process.start('gdbus', ['call', '--session', ...args]);
      final out = proc.stdout.transform(const SystemEncoding().decoder).join();
      final code = await proc.exitCode.timeout(const Duration(seconds: 3));
      return code == 0 ? await out : '';
    } on Object catch (e) {
      AppLog.d('tray bus check failed', e);
      proc?.kill();
      return '';
    }
  }

  @override
  void dispose() {
    _icon?.setVisible(false);
    _icon?.dispose();
    _menu?.dispose();
    _items.clear();
  }
}

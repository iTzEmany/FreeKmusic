import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:tray_manager/tray_manager.dart' as tray;

import '../../core/app_log.dart';
import '../../core/paths.dart';
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
  bool _hidden = false;
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

  Future<void> onCloseRequested() async {
    if (available && closeToTray()) return _hide();
    await quit();
  }

  Future<void> _run(TrayCommand c) => switch (c) {
    TrayCommand.playPause => playPause(),
    TrayCommand.next => next(),
    TrayCommand.toggleWindow => _hidden ? _show() : _hide(),
    TrayCommand.quit => quit(),
  };

  Future<void> _hide() async {
    _hidden = true;
    await host.hide();
  }

  Future<void> _show() async {
    _hidden = false;
    await host.show();
  }

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
    if (!tray.TrayManager.instance.isSupported() || !await _hasWatcher()) return false;
    final icon = tray.TrayIcon.create();
    final menu = tray.Menu.create();
    if (icon == null || menu == null) return false;
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
    final file = File(p.join(await appSupportDir(), 'tray.png'));
    await file.writeAsBytes((await rootBundle.load('assets/icon/tray.png')).buffer.asUint8List());
    icon.icon = tray.Image.fromFile(file.path);
    icon.setTooltip('FreeKmusic');
    icon.setContextMenu(menu);
    icon.setVisible(true);
    _icon = icon;
    _menu = menu;
    return true;
  }

  /// Linux (StatusNotifierItem): without a watcher on the bus (GNOME with no AppIndicator
  /// extension) the icon would be invisible, and a hidden window could not come back.
  Future<bool> _hasWatcher() async {
    if (!Platform.isLinux) return true;
    try {
      final r = await Process.run('gdbus', const [
        'call', '--session', '--dest', 'org.freedesktop.DBus', '--object-path', '/org/freedesktop/DBus',
        '--method', 'org.freedesktop.DBus.NameHasOwner', 'org.kde.StatusNotifierWatcher',
      ]).timeout(const Duration(seconds: 3));
      return r.exitCode == 0 && (r.stdout as String).contains('true');
    } on Object catch (e) {
      AppLog.d('tray watcher check failed', e);
      return false;
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

// The legacy API is the 0.5.x one: it keeps `hide`, `setPreventClose` and the listener as the docs of this phase name them.
// ignore_for_file: deprecated_member_use, depend_on_referenced_packages
import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:nativeapi/nativeapi.dart' as native show DisplayManager;
import 'package:window_manager/legacy.dart';
import 'package:window_manager/window_manager.dart' show RectangleToRect;

/// What the app needs from the desktop window. The real one is [PlatformWindowHost];
/// tests use a fake, so no native library is loaded.
abstract class WindowHost {
  Future<Rect> getBounds();
  Future<void> setBounds(Rect bounds);
  Future<void> setSize(Size size);

  /// The usable area of every screen, in the same coordinates as [getBounds].
  Future<List<Rect>> workAreas();

  /// Moved or resized by the user.
  Stream<void> get changes;

  /// The X (or Alt+F4) was pressed while [setPreventClose] is on.
  Stream<void> get closeRequests;

  Future<void> setPreventClose(bool on);
  Future<void> show();
  Future<void> hide();
}

class PlatformWindowHost with WindowListener implements WindowHost {
  PlatformWindowHost() {
    windowManager.addListener(this);
  }

  final _changes = StreamController<void>.broadcast();
  final _close = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;
  @override
  Stream<void> get closeRequests => _close.stream;

  @override
  void onWindowResized() => _changes.add(null);
  @override
  void onWindowMoved() => _changes.add(null);
  @override
  void onWindowClose() => _close.add(null);

  @override
  Future<Rect> getBounds() => windowManager.getBounds();
  @override
  Future<void> setBounds(Rect bounds) => windowManager.setBounds(bounds);
  @override
  Future<void> setSize(Size size) => windowManager.setSize(size);
  @override
  Future<List<Rect>> workAreas() async => [
    for (final d in native.DisplayManager.instance.getAll()) d.workArea.toRect(),
  ];
  @override
  Future<void> setPreventClose(bool on) => windowManager.setPreventClose(on);
  @override
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  Future<void> hide() => windowManager.hide();
}

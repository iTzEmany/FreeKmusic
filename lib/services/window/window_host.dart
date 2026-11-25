import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:nativeapi/nativeapi.dart' show DisplayManager;
import 'package:window_manager/window_manager.dart';

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
  Future<bool> isVisible();
}

class PlatformWindowHost implements WindowHost {
  PlatformWindowHost() {
    _window.addListener(_onEvent);
  }

  final _changes = StreamController<void>.broadcast();
  final _close = StreamController<void>.broadcast();
  bool _preventClose = false;

  Window get _window => WindowManager.instance.getCurrent()!;

  @override
  Stream<void> get changes => _changes.stream;
  @override
  Stream<void> get closeRequests => _close.stream;

  void _onEvent(WindowEvent e) {
    switch (e) {
      case WindowMovedEvent() || WindowResizedEvent():
        _changes.add(null);
      case WindowCloseRequestedEvent(:final request):
        // The destruction after «Esci» is not cancelable: it goes through.
        if (_preventClose && request.isCancelable) request.cancel();
        _close.add(null);
      default:
    }
  }

  @override
  Future<Rect> getBounds() async => _window.bounds.toRect();
  @override
  Future<void> setBounds(Rect bounds) async => _window.bounds = bounds.toNative();
  @override
  Future<void> setSize(Size size) async => _window.bounds = ((await getBounds()).topLeft & size).toNative();
  @override
  Future<List<Rect>> workAreas() async => [for (final d in DisplayManager.instance.getAll()) d.workArea.toRect()];
  @override
  Future<void> setPreventClose(bool on) async => _preventClose = on;
  @override
  Future<void> show() async {
    _window
      ..show()
      ..focus();
  }

  @override
  Future<void> hide() async => _window.hide();
  @override
  Future<bool> isVisible() async => _window.isVisible;
}

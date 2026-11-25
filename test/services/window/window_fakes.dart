import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:codecore/services/window/tray_service.dart';
import 'package:codecore/services/window/window_host.dart';

class FakeWindowHost implements WindowHost {
  FakeWindowHost({this.bounds = const Rect.fromLTWH(0, 0, 1280, 720), this.areas = const [Rect.fromLTWH(0, 0, 1920, 1080)]});

  Rect bounds;
  List<Rect> areas;
  bool visible = true; // changes by itself too, as a second launch does
  final calls = <String>[];
  final _changes = StreamController<void>.broadcast();
  final _close = StreamController<void>.broadcast();

  void userMoved(Rect to) {
    bounds = to;
    _changes.add(null);
  }

  void pressX() => _close.add(null);

  @override
  Stream<void> get changes => _changes.stream;
  @override
  Stream<void> get closeRequests => _close.stream;
  @override
  Future<Rect> getBounds() async => bounds;
  @override
  Future<void> setBounds(Rect b) async => calls.add('setBounds');
  @override
  Future<void> setSize(Size s) async => calls.add('setSize ${s.width.round()}x${s.height.round()}');
  @override
  Future<List<Rect>> workAreas() async => areas;
  @override
  Future<void> setPreventClose(bool on) async => calls.add('preventClose $on');
  @override
  Future<void> show() async {
    visible = true;
    calls.add('show');
  }

  @override
  Future<void> hide() async {
    visible = false;
    calls.add('hide');
  }

  @override
  Future<bool> isVisible() async => visible;
}

class FakeTrayAdapter implements TrayAdapter {
  FakeTrayAdapter({this.supported = true, this.fails = false});
  final bool supported, fails;
  bool disposed = false;
  void Function(TrayCommand)? press;
  Map<TrayCommand, String>? shown;

  @override
  Future<bool> show(Map<TrayCommand, String> labels, void Function(TrayCommand) onCommand) async {
    shown = labels;
    press = onCommand;
    if (fails) throw StateError('no bus');
    return supported;
  }

  @override
  void dispose() => disposed = true;
}

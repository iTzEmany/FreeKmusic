import 'dart:ui' show Rect;

import 'package:codecore/services/window/window_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'window_fakes.dart';

WindowState _state(FakeWindowHost host, {String? saved, bool wayland = false, List<String>? out}) => WindowState(
  host: host,
  read: () => saved,
  write: (s) async => out?.add(s),
  wayland: wayland,
  delay: const Duration(milliseconds: 10),
);

void main() {
  test('saved bounds are restored', () async {
    final host = FakeWindowHost();
    await _state(host, saved: '100,80,1000,700').start();
    expect(host.calls, ['setBounds']);
  });

  test('bounds off every screen, or too small, are dropped: the standard size stays', () async {
    final host = FakeWindowHost();
    await _state(host, saved: '3000,100,1000,700').start();
    await _state(host, saved: '100,100,50,50').start();
    await _state(host, saved: 'rubbish').start();
    await _state(host).start();
    expect(host.calls, isEmpty);
  });

  test('a change is saved once, after the delay', () async {
    final host = FakeWindowHost();
    final out = <String>[];
    await _state(host, out: out).start();
    host.userMoved(const Rect.fromLTWH(10, 20, 900, 600));
    host.userMoved(const Rect.fromLTWH(12, 22, 900, 600));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(out, ['12,22,900,600']);
  });

  test('Wayland: only the size is set and saved, never a position', () async {
    final host = FakeWindowHost();
    final out = <String>[];
    await _state(host, saved: '100,80,1000,700', wayland: true, out: out).start();
    expect(host.calls, ['setSize 1000x700']);
    host.userMoved(const Rect.fromLTWH(10, 20, 900, 600));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(out, ['0,0,900,600']);
    expect(host.calls, ['setSize 1000x700']);
  });

  test('Wayland is told from the session', () {
    expect(isWayland({'XDG_SESSION_TYPE': 'wayland'}), isTrue);
    expect(isWayland({'WAYLAND_DISPLAY': 'wayland-0'}), isTrue);
    expect(isWayland({'XDG_SESSION_TYPE': 'x11'}), isFalse);
    expect(isWayland({}), isFalse);
  });
}

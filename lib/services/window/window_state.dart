import 'dart:async';
import 'dart:ui' show Rect, Size;

import '../../core/app_log.dart';
import 'window_host.dart';

const kMinWindowSize = Size(400, 300);

/// Wayland: the app can read and set the size but not the position.
bool isWayland(Map<String, String> env) =>
    (env['XDG_SESSION_TYPE'] ?? '').toLowerCase() == 'wayland' ||
    (env['WAYLAND_DISPLAY'] ?? '').isNotEmpty;

String encodeBounds(Rect r) => '${r.left.round()},${r.top.round()},${r.width.round()},${r.height.round()}';

Rect? decodeBounds(String? s) {
  final p = s?.split(',').map(int.tryParse).toList();
  if (p == null || p.length != 4 || p.contains(null)) return null;
  return Rect.fromLTWH(p[0]!.toDouble(), p[1]!.toDouble(), p[2]!.toDouble(), p[3]!.toDouble());
}

/// Remembers the window's size and position between runs (F-206, D-739).
/// A saved rectangle that no longer fits a screen (monitor unplugged, resolution
/// changed) is dropped: the window keeps the standard size the runner gave it.
class WindowState {
  WindowState({
    required this.host,
    required this.read,
    required this.write,
    required this.wayland,
    this.delay = const Duration(milliseconds: 500),
  });

  final WindowHost host;
  final String? Function() read;
  final Future<void> Function(String) write;
  final bool wayland;
  final Duration delay;
  Timer? _timer;
  StreamSubscription<void>? _sub;

  /// Applies the saved bounds, then starts saving the changes.
  Future<void> start() async {
    try {
      await _restore();
    } on Object catch (e, st) {
      AppLog.w('window bounds not restored', e, st);
    }
    _sub = host.changes.listen((_) {
      _timer?.cancel();
      _timer = Timer(delay, () => unawaited(_save()));
    });
  }

  Future<void> _restore() async {
    final saved = decodeBounds(read());
    if (saved == null || saved.width < kMinWindowSize.width || saved.height < kMinWindowSize.height) return;
    final areas = await host.workAreas();
    if (wayland) {
      if (areas.any((a) => saved.width <= a.width && saved.height <= a.height)) await host.setSize(saved.size);
      return;
    }
    // At least a 120x60 corner of the window must be on some screen, or the user could not grab it.
    final visible = areas.any((a) {
      final i = a.intersect(saved);
      return i.width >= 120 && i.height >= 60;
    });
    if (visible) await host.setBounds(saved);
  }

  Future<void> _save() async {
    try {
      final b = await host.getBounds();
      if (b.width < kMinWindowSize.width || b.height < kMinWindowSize.height) return;
      await write(encodeBounds(wayland ? Rect.fromLTWH(0, 0, b.width, b.height) : b));
    } on Object catch (e, st) {
      AppLog.w('window bounds not saved', e, st);
    }
  }

  void dispose() {
    _timer?.cancel();
    unawaited(_sub?.cancel());
  }
}


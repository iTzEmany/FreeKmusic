import 'dart:async';

/// Sends at most one karaoke level per [every] while a slider is dragged: the
/// first goes at once, the last of the others when the time is up (D-587).
class KaraokeSendThrottle {
  KaraokeSendThrottle(this._send, {this.every = const Duration(milliseconds: 250)});

  final void Function(double? level) _send;
  final Duration every;
  Timer? _timer;
  bool _waiting = false;
  double? _pending;

  void add(double? level) {
    if (_timer != null) {
      _waiting = true;
      _pending = level;
      return;
    }
    _send(level);
    _timer = Timer(every, _tick);
  }

  void _tick() {
    _timer = null;
    if (_waiting) {
      _waiting = false;
      add(_pending);
    }
  }

  /// Sends what is waiting now (end of the drag, sheet closed).
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_waiting) {
      _waiting = false;
      _send(_pending);
    }
  }
}

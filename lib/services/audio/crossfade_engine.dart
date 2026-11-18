import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/app_log.dart';
import 'audio_backend.dart';
import 'equalizer.dart';

/// Calls [onTick] every [period] until the timer is cancelled (replaced in
/// tests by one that ticks by hand).
typedef RampTicker = Timer Function(Duration period, void Function() onTick);

Timer _realTicker(Duration period, void Function() onTick) =>
    Timer.periodic(period, (_) => onTick());

/// One of the two players and the volume it should have when fully in.
class _Side {
  _Side(this.backend);

  final AudioBackend backend;
  double volume = 1.0;
  double factor = 1.0; // 0..1, from the fade
  bool ready = false; // holds the prepared next track
  Duration? duration;

  /// Silences the side without tearing its native player down (see
  /// [GaplessCapable.park]); a backend that cannot park is stopped.
  Future<void> park() {
    final b = backend;
    return b is GaplessCapable ? (b as GaplessCapable).park() : b.stop();
  }

  void apply() {
    backend.setVolume((volume * factor).clamp(0.0, 1.0).toDouble()).catchError(
        (Object e, StackTrace st) => AppLog.w('crossfade: volume failed', e, st));
  }
}

/// Plays through two backends, one at a time except during a crossfade: the
/// next track is loaded on the idle player and, [crossfade] before the end of
/// the current one, faded in while the current one fades out (equal power, 20
/// steps). It looks like a single backend to the handler. Joins that must not
/// overlap are handed to the playing backend's own gapless window.
class CrossfadeEngine implements AudioBackend, GaplessCapable {
  CrossfadeEngine(this._factory, {RampTicker? ticker})
      : _ticker = ticker ?? _realTicker {
    _main = _attach(_factory());
  }

  static const steps = 20;

  final AudioBackend Function() _factory;
  final RampTicker _ticker;
  late _Side _main;
  _Side? _other;
  final _subs = <StreamSubscription<Object?>>[];
  final _mirror = MirrorEqualizer();

  final _stateC = StreamController<BackendState>.broadcast();
  final _positionC = StreamController<Duration>.broadcast();
  final _durationC = StreamController<Duration?>.broadcast();
  final _titleC = StreamController<String?>.broadcast();
  final _advancedC = StreamController<void>.broadcast();

  /// Length of the overlap; null means tracks never overlap.
  Duration? crossfade;

  double _speed = 1.0;
  String? _nextPath;
  int _prepToken = 0;
  ({String? path, double volume, bool overlap})? _pending;

  bool _fading = false;
  bool _swapped = false;
  bool _skipFade = false;
  int _step = 0;
  Timer? _timer;
  Duration _tick = const Duration(milliseconds: 100);
  _Side? _out, _in;

  _Side _attach(AudioBackend b) {
    final side = _Side(b);
    final eq = b.equalizer;
    if (eq != null) _mirror.add(eq);
    bool isMain() => identical(side, _main);
    _subs
      ..add(b.state.listen((s) {
        if (isMain()) _stateC.add(s);
      }))
      ..add(b.position.listen((p) {
        if (!isMain()) return;
        _positionC.add(p);
        _onMainPosition(p);
      }))
      ..add(b.duration.listen((d) {
        side.duration = d;
        if (isMain()) _durationC.add(d);
      }))
      ..add(b.streamTitle.listen((t) {
        if (isMain()) _titleC.add(t);
      }));
    if (b is GaplessCapable) {
      _subs.add((b as GaplessCapable).advanced.listen((_) {
        if (isMain()) _advancedC.add(null);
      }));
    }
    return side;
  }

  @override
  Stream<BackendState> get state => _stateC.stream;
  @override
  Stream<Duration> get position => _positionC.stream;
  @override
  Stream<Duration?> get duration => _durationC.stream;
  @override
  Stream<String?> get streamTitle => _titleC.stream;
  @override
  Stream<void> get advanced => _advancedC.stream;
  @override
  Equalizer? get equalizer => _mirror.isEmpty ? null : _mirror;
  @override
  Duration get positionNow => _main.backend.positionNow;

  GaplessCapable? get _mainGapless {
    final b = _main.backend;
    return b is GaplessCapable ? b as GaplessCapable : null;
  }

  // ----------------------------------------------------------------- joins

  @override
  Future<void> setNext(String? path,
      {double volume = 1.0, bool overlap = true}) async {
    if (_fading) {
      _pending = (path: path, volume: volume, overlap: overlap);
      return;
    }
    final token = ++_prepToken;
    final window = crossfade;
    final mainLength = _main.duration;
    final overlaps = overlap &&
        window != null &&
        path != null &&
        !(mainLength != null && mainLength < window * 2);
    if (!overlaps) {
      _nextPath = null;
      _skipFade = false;
      await _releaseOther();
      await _mainGapless?.setNext(path, volume: volume, overlap: false);
      return;
    }
    await _mainGapless?.setNext(null); // a plain join must not pre-empt the fade
    final other = _other;
    if (path == _nextPath && other != null && other.ready) {
      other.volume = volume; // same track, maybe a new volume
      return;
    }
    _nextPath = path;
    _skipFade = false;
    await _prepareOther(path, volume, token);
  }

  Future<void> _prepareOther(String path, double volume, int token) async {
    final other = _other ??= _attach(_factory());
    other.ready = false;
    other.volume = volume;
    other.factor = 0;
    other.duration = null;
    try {
      await other.backend.load(path);
      if (token != _prepToken) return;
      other.apply();
      if (_speed != 1.0) await other.backend.setSpeed(_speed);
      other.ready = true;
    } on BackendException catch (e) {
      AppLog.w('crossfade: next track not ready: ${e.message}');
      if (token == _prepToken) _nextPath = null;
    }
  }

  Future<void> _releaseOther() async {
    final other = _other;
    if (other != null && (other.ready || other.duration != null)) {
      other.ready = false;
      await other.park();
    }
  }

  void _onMainPosition(Duration p) {
    final window = crossfade;
    final other = _other;
    if (_fading || _skipFade || window == null || _nextPath == null) return;
    if (other == null || !other.ready) return;
    final length = _main.duration;
    if (length == null) return;
    final remaining = length - p;
    if (remaining <= Duration.zero || remaining > window * _speed) return;
    final incoming = other.duration;
    if (length < window * 2 || (incoming != null && incoming < window * 2)) {
      _skipFade = true; // too short to fade: the join stays a plain one
      return;
    }
    unawaited(_startFade(remaining));
  }

  // ------------------------------------------------------------------ fade

  Future<void> _startFade(Duration remaining) async {
    final incoming = _other!;
    _fading = true;
    _swapped = false;
    _step = 0;
    _out = _main;
    _in = incoming;
    final wallMs = (remaining.inMilliseconds / _speed).round();
    _tick = Duration(milliseconds: math.max(1, wallMs ~/ steps));
    incoming.factor = 0;
    incoming.apply();
    await incoming.backend.play();
    _timer = _ticker(_tick, _onTick);
  }

  void _onTick() {
    _step++;
    final t = (_step / steps).clamp(0.0, 1.0);
    _out!.factor = math.cos(t * math.pi / 2);
    _in!.factor = math.sin(t * math.pi / 2);
    _out!.apply();
    _in!.apply();
    if (!_swapped && _step >= steps ~/ 2) _swap();
    if (_step >= steps) _endFade();
  }

  /// Halfway: the incoming track is now «the» track.
  void _swap() {
    _swapped = true;
    final incoming = _in!;
    _other = _main;
    _main = incoming;
    _nextPath = null;
    _durationC.add(incoming.duration);
    _advancedC.add(null);
  }

  Future<void> _endFade() async {
    _timer?.cancel();
    _timer = null;
    final outgoing = _out!;
    final incoming = _in!;
    _fading = false;
    _out = _in = null;
    incoming.factor = 1;
    incoming.apply();
    outgoing.ready = false;
    outgoing.factor = 1;
    outgoing.duration = null;
    await outgoing.park();
    final pending = _pending;
    _pending = null;
    if (pending != null) {
      await setNext(pending.path, volume: pending.volume, overlap: pending.overlap);
    }
  }

  /// Abandons a fade in progress. The side that is not [_main] stops at once;
  /// if the incoming track had not become the main one yet, it is prepared
  /// again for the next approach to the end.
  Future<void> _cancelFade() async {
    if (!_fading) return;
    _timer?.cancel();
    _timer = null;
    final dropped = identical(_main, _in) ? _out! : _in!;
    final keepNext = !_swapped;
    final path = _nextPath;
    final volume = dropped.volume;
    _fading = false;
    _out = _in = null;
    _main.factor = 1;
    _main.apply();
    dropped.ready = false;
    dropped.factor = 1;
    dropped.duration = null;
    await dropped.park();
    _pending = null;
    if (keepNext && path != null) {
      await _prepareOther(path, volume, ++_prepToken);
    }
  }

  // ----------------------------------------------------- the usual commands

  @override
  Future<void> load(String filePath) async {
    await _forgetNext();
    await _main.backend.load(filePath);
  }

  @override
  Future<void> loadUri(Uri uri, {Map<String, String> headers = const {}}) async {
    await _forgetNext();
    await _main.backend.loadUri(uri, headers: headers);
  }

  Future<void> _forgetNext() async {
    _prepToken++;
    _pending = null;
    _nextPath = null;
    _skipFade = false;
    if (_fading) {
      _timer?.cancel();
      _timer = null;
      final dropped = identical(_main, _in) ? _out! : _in!;
      _fading = false;
      _out = _in = null;
      _main.factor = 1;
      _main.apply();
      dropped.factor = 1;
      dropped.ready = false;
      dropped.duration = null;
      await dropped.park();
    }
    await _releaseOther();
  }

  @override
  Future<void> play() async {
    await _main.backend.play();
    if (_fading && _timer == null) {
      await (identical(_main, _in) ? _out! : _in!).backend.play();
      _timer = _ticker(_tick, _onTick);
    }
  }

  @override
  Future<void> pause() async {
    _timer?.cancel();
    _timer = null;
    if (_fading) {
      await (identical(_main, _in) ? _out! : _in!).backend.pause();
    }
    await _main.backend.pause();
  }

  @override
  Future<void> park() => stop(); // nothing wraps the engine

  @override
  Future<void> stop() async {
    await _forgetNext();
    await _main.backend.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _cancelFade();
    await _main.backend.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    _main.volume = volume;
    _main.apply();
  }

  @override
  Future<void> setSpeed(double speed) async {
    _speed = speed;
    await _main.backend.setSpeed(speed);
    await _other?.backend.setSpeed(speed);
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    for (final s in _subs) {
      await s.cancel();
    }
    await _main.backend.dispose();
    await _other?.backend.dispose();
    await _stateC.close();
    await _positionC.close();
    await _durationC.close();
    await _titleC.close();
    await _advancedC.close();
  }
}

/// One equalizer for two players: every setting goes to both, and to the
/// second one when it is created later.
@visibleForTesting
class MirrorEqualizer implements Equalizer {
  final _targets = <Equalizer>[];
  bool? _enabled;
  List<double>? _gains;

  bool get isEmpty => _targets.isEmpty;

  void add(Equalizer e) {
    _targets.add(e);
    final enabled = _enabled, gains = _gains;
    if (gains != null) unawaited(e.setGains(gains));
    if (enabled != null) unawaited(e.setEnabled(enabled));
  }

  @override
  Future<EqBands> bands() => _targets.first.bands();

  @override
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    // A copy: the second player may join while this waits, and gets the
    // setting from add().
    for (final t in List.of(_targets)) {
      await t.setEnabled(enabled);
    }
  }

  @override
  Future<void> setGains(List<double> gainsDb) async {
    _gains = gainsDb;
    for (final t in List.of(_targets)) {
      await t.setGains(gainsDb);
    }
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:media_kit/media_kit.dart' hide Track;
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import 'karaoke_video.dart';
import 'karaoke_video_gate.dart';

enum KaraokeVideoStatus { none, loading, ready, failed }

/// What the player shows (D-646): [controller] is set only when [status] is `ready` (first frame drawn).
class KaraokeVideoState {
  const KaraokeVideoState(this.status, [this.controller]);
  final KaraokeVideoStatus status;
  final VideoController? controller;

  @override
  bool operator ==(Object other) =>
      other is KaraokeVideoState && other.status == status && other.controller == controller;
  @override
  int get hashCode => Object.hash(status, controller);
}

enum SyncAction { none, play, pause, seek }

typedef SyncStep = ({SyncAction action, Duration? seekTo});

const _driftLimit = Duration(milliseconds: 300);
const _seekEvery = Duration(seconds: 2);

/// What to do to the (silent) video so it follows the audio, the only clock (D-156). The video seeks
/// when it is off by more than 300 ms, at most once every 2 s; a seek of the user always passes.
SyncStep syncStep({
  required bool audioPlaying,
  required bool videoPlaying,
  required Duration audioPos,
  required Duration videoPos,
  required DateTime now,
  DateTime? lastSeek,
  bool userSeek = false,
}) {
  if (userSeek) return (action: SyncAction.seek, seekTo: audioPos);
  if (audioPlaying != videoPlaying) {
    return (action: audioPlaying ? SyncAction.play : SyncAction.pause, seekTo: null);
  }
  final off = (audioPos - videoPos).abs() > _driftLimit;
  if (off && (lastSeek == null || now.difference(lastSeek) >= _seekEvery)) {
    return (action: SyncAction.seek, seekTo: audioPos);
  }
  return (action: SyncAction.none, seekTo: null);
}

/// The thin part of media_kit's `Player` the controller needs (so tests do not start libmpv).
abstract interface class KaraokeVideoPort {
  VideoController? get video;
  Stream<String> get errors;
  Stream<Duration> get position;

  /// Loads [source] (a file path or an address) paused.
  Future<void> open(String source, Map<String, String> headers);
  Future<void> firstFrame();
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration pos);
  Future<void> dispose();
}

bool _mediaKitReady = false;

/// A media_kit player with no sound: the stream is video-only, the volume is 0 and nothing asks for
/// audio focus (F-2).
class MediaKitVideoPort implements KaraokeVideoPort {
  MediaKitVideoPort() {
    if (!_mediaKitReady) {
      MediaKit.ensureInitialized();
      _mediaKitReady = true;
    }
    _player = Player(configuration: const PlayerConfiguration(muted: true, bufferSize: 8 * 1024 * 1024));
    unawaited(_player.setVolume(0));
    video = VideoController(_player);
  }
  late final Player _player;
  @override
  late final VideoController video;

  @override
  Stream<String> get errors => _player.stream.error;
  @override
  Stream<Duration> get position => _player.stream.position;
  @override
  Future<void> open(String source, Map<String, String> headers) =>
      _player.open(Media(source, httpHeaders: headers.isEmpty ? null : headers), play: false);
  @override
  Future<void> firstFrame() => video.waitUntilFirstFrameRendered;
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration pos) => _player.seek(pos);
  @override
  Future<void> dispose() => _player.dispose();
}

/// The video of the current karaoke track (D-646, D-647): created with the first one, closed when a
/// normal track starts. It follows the audio and never touches it, except by holding the start (the gate).
class KaraokeVideoController implements KaraokeVideoGate {
  KaraokeVideoController({
    required this.source,
    required this.cached,
    required this.download,
    required this.release,
    required this.tracks,
    required this.positions,
    required this.playing,
    required this.audioPlaying,
    required this.onState,
    KaraokeVideoPort Function()? createPort,
    DateTime Function()? clock,
  }) : _createPort = createPort ?? MediaKitVideoPort.new,
       _clock = clock ?? DateTime.now {
    _audioPlaying = audioPlaying();
    _subs = [
      tracks.listen(_track),
      positions.listen((p) {
        _audioPos = p;
        _tick();
      }),
      playing.listen((p) {
        _audioPlaying = p;
        _tick();
      }),
    ];
  }

  final KaraokeVideoSource source;
  final Future<File?> Function(String id) cached;
  final void Function(String id, KaraokeVideoStream stream) download;
  final void Function(String id) release;
  final Stream<Track?> tracks;
  final Stream<Duration> positions;
  final Stream<bool> playing;
  final bool Function() audioPlaying;
  final void Function(KaraokeVideoState state) onState;
  final KaraokeVideoPort Function() _createPort;
  final DateTime Function() _clock;

  late final List<StreamSubscription<Object?>> _subs;
  List<StreamSubscription<Object?>> _portSubs = const [];
  KaraokeVideoPort? _port;
  String? _id;
  KaraokeVideoStream? _stream;
  var _status = KaraokeVideoStatus.none;
  var _gen = 0; // one per video id: what a late answer checks
  var _attempt = 0;
  var _failedAttempt = -1;
  var _errors = 0;
  Completer<void> _ready = Completer<void>()..complete();
  var _videoPlaying = false;
  var _background = false;
  var _audioPlaying = false;
  var _audioPos = Duration.zero;
  var _videoPos = Duration.zero;
  DateTime? _lastSeek;

  KaraokeVideoStatus get status => _status;

  void _emit(KaraokeVideoStatus s) {
    _status = s;
    onState(KaraokeVideoState(s, s == KaraokeVideoStatus.ready ? _port?.video : null));
  }

  void _done() {
    if (!_ready.isCompleted) _ready.complete();
  }

  Future<void> _guard(Future<void> f, String what) => f.onError((Object e, StackTrace st) {
    AppLog.w('karaoke video $what failed', e, st);
  });

  void _track(Track? t) {
    final id = t != null && isKaraokeVideo(t) ? karaokeVideoId(t) : null;
    if (id == _id) return;
    final old = _id;
    _gen++;
    _id = id;
    _stream = null;
    _videoPlaying = false;
    _done();
    if (old != null) release(old);
    if (id == null) {
      final port = _port;
      _port = null;
      _cancelPortSubs();
      if (port != null) unawaited(_guard(port.dispose(), 'dispose'));
      _emit(KaraokeVideoStatus.none);
      return;
    }
    _errors = 0;
    _ready = Completer<void>();
    _emit(KaraokeVideoStatus.loading);
    unawaited(_load(first: true));
  }

  Future<void> _load({required bool first}) async {
    final gen = _gen;
    final id = _id!;
    final attempt = ++_attempt;
    try {
      final port = _port ??= _newPort();
      final file = first ? await cached(id) : null;
      if (gen != _gen) {
        if (file != null) release(id);
        return;
      }
      if (file != null) {
        await port.open(file.path, const {});
      } else {
        final s = await source.videoUrl(id);
        if (gen != _gen) return;
        _stream = s;
        if (first) download(id, s);
        await port.open(s.url.toString(), s.headers);
      }
      await port.firstFrame().timeout(const Duration(seconds: 15));
      if (gen != _gen) return;
      _videoPlaying = false;
      _videoPos = _audioPos;
      if (_audioPos > _driftLimit) await port.seek(_audioPos);
      if (gen != _gen) return;
      _emit(KaraokeVideoStatus.ready);
      _done();
      _tick();
    } on Object catch (e, st) {
      if (gen != _gen) return;
      AppLog.w('karaoke video load failed', e, st);
      _onError(attempt);
    }
  }

  void _cancelPortSubs() {
    for (final s in _portSubs) {
      unawaited(s.cancel());
    }
    _portSubs = const [];
  }

  KaraokeVideoPort _newPort() {
    final port = _createPort();
    _portSubs = [
      port.errors.listen((m) {
        AppLog.w('karaoke video player error: $m');
        _onError(_attempt);
      }),
      port.position.listen((p) => _videoPos = p),
    ];
    return port;
  }

  /// The first error asks the address again; the second gives up (the audio goes on as it was).
  void _onError(int attempt) {
    if (attempt == _failedAttempt || _id == null) return; // one failure, one count
    _failedAttempt = attempt;
    if (++_errors >= 2) {
      final port = _port;
      if (port != null) unawaited(_guard(port.pause(), 'pause'));
      _emit(KaraokeVideoStatus.failed);
      _done();
      return;
    }
    if (_ready.isCompleted) _ready = Completer<void>();
    _emit(KaraokeVideoStatus.loading);
    unawaited(_load(first: false));
  }

  void _tick({bool user = false}) {
    final port = _port;
    if (port == null || _background || _status != KaraokeVideoStatus.ready) return;
    final now = _clock();
    final step = syncStep(
      audioPlaying: _audioPlaying,
      videoPlaying: _videoPlaying,
      audioPos: _audioPos,
      videoPos: _videoPos,
      now: now,
      lastSeek: _lastSeek,
      userSeek: user,
    );
    switch (step.action) {
      case SyncAction.none:
        break;
      case SyncAction.play:
        _videoPlaying = true;
        unawaited(_guard(port.play(), 'play'));
      case SyncAction.pause:
        _videoPlaying = false;
        unawaited(_guard(port.pause(), 'pause'));
      case SyncAction.seek:
        _lastSeek = now;
        _videoPos = step.seekTo!;
        unawaited(_guard(port.seek(step.seekTo!), 'seek'));
    }
  }

  @override
  Future<void>? beforePlay(Track t) {
    _track(t);
    return _id == null ? null : _ready.future;
  }

  @override
  Future<void>? afterSeek(Duration pos) {
    final port = _port;
    if (port == null || _background) return null;
    _audioPos = pos;
    if (_status == KaraokeVideoStatus.loading) return _ready.future; // the load seeks to the audio when done
    if (_status != KaraokeVideoStatus.ready) return null;
    _lastSeek = _clock();
    _videoPos = pos;
    return _guard(port.seek(pos), 'seek');
  }

  /// The app goes to the background: the video stops, the audio does not. Back: it joins the audio again.
  void onLifecycle(AppLifecycleState s) {
    final port = _port;
    if (port == null) return;
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _background = true;
      _videoPlaying = false;
      unawaited(_guard(port.pause(), 'pause'));
    } else if (s == AppLifecycleState.resumed && _background) {
      _background = false;
      if (_status != KaraokeVideoStatus.ready) return;
      final expires = _stream?.expires;
      if (expires != null && !_clock().isBefore(expires)) {
        _status = KaraokeVideoStatus.loading; // the address ran out meanwhile: a new one, not an error
        _ready = Completer<void>();
        _emit(KaraokeVideoStatus.loading);
        unawaited(_load(first: false));
        return;
      }
      _tick(user: true);
      if (_audioPlaying) {
        _videoPlaying = true;
        unawaited(_guard(port.play(), 'play'));
      }
    }
  }

  Future<void> dispose() async {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
    final id = _id;
    _id = null;
    _gen++;
    _done();
    if (id != null) release(id);
    _cancelPortSubs();
    await _port?.dispose();
    _port = null;
  }
}

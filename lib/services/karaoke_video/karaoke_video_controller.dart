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

/// A media_kit player with no sound: the stream is video-only, the volume is 0, the audio track is
/// off and nothing asks for audio focus (F-2). One per load: `waitUntilFirstFrameRendered` lives as long as its controller.
class MediaKitVideoPort implements KaraokeVideoPort {
  MediaKitVideoPort() {
    if (!_mediaKitReady) {
      MediaKit.ensureInitialized();
      _mediaKitReady = true;
    }
    _player = Player(configuration: const PlayerConfiguration(muted: true, bufferSize: 8 * 1024 * 1024));
    unawaited(_player.setVolume(0));
    unawaited(
      (_player.platform as NativePlayer).setProperty('aid', 'no').onError((Object e, StackTrace st) {
        AppLog.w('karaoke video: audio track not switched off', e, st);
      }),
    );
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

/// The video of the current karaoke track (D-646, D-647): a silent player per load, closed when a
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
    this.loadTimeout = const Duration(seconds: 10), // the audio handler's wait
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
  final Duration loadTimeout;
  final KaraokeVideoPort Function() _createPort;
  final DateTime Function() _clock;

  late final List<StreamSubscription<Object?>> _subs;
  List<StreamSubscription<Object?>> _portSubs = const [];
  KaraokeVideoPort? _port;
  String? _id;
  String? _pinned; // the id whose cache file is fixed for us: released once
  KaraokeVideoStream? _stream;
  var _status = KaraokeVideoStatus.none;
  var _gen = 0; // one per track change
  var _attempt = 0; // one per load of a video
  var _failedAttempt = -1;
  var _errors = 0; // in a row, without a ready between
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

  void _unpin() {
    final id = _pinned;
    _pinned = null;
    if (id != null) release(id);
  }

  void _closePort() {
    for (final s in _portSubs) {
      unawaited(s.cancel());
    }
    _portSubs = const [];
    final port = _port;
    _port = null;
    _videoPlaying = false;
    if (port != null) unawaited(_guard(port.dispose(), 'dispose'));
  }

  void _track(Track? t, {bool retry = false}) {
    final id = t != null && isKaraokeVideo(t) ? karaokeVideoId(t) : null;
    if (id == _id) {
      if (id != null && retry && _status == KaraokeVideoStatus.failed) _restart(); // played again after a failure
      return;
    }
    _gen++;
    _attempt++; // the answers of the old track's load are void
    _id = id;
    _stream = null;
    _done();
    _unpin();
    _closePort();
    if (id == null) {
      _emit(KaraokeVideoStatus.none);
      return;
    }
    _restart();
  }

  void _restart() {
    _errors = 0;
    _ready = Completer<void>();
    _emit(KaraokeVideoStatus.loading);
    unawaited(_load(first: true));
  }

  Future<void> _load({required bool first}) async {
    final gen = _gen;
    final id = _id!;
    final attempt = ++_attempt;
    bool stale() => attempt != _attempt || gen != _gen || _status == KaraokeVideoStatus.failed;
    _closePort();
    try {
      await _open(id, first, gen, stale).timeout(loadTimeout);
      if (stale()) return;
      _errors = 0;
      _emit(KaraokeVideoStatus.ready);
      _done();
      _tick();
    } on Object catch (e, st) {
      if (stale()) return;
      AppLog.w('karaoke video load failed', e, st);
      _onError(attempt);
    }
  }

  Future<void> _open(String id, bool first, int gen, bool Function() stale) async {
    final port = _createPort();
    _port = port;
    final attempt = _attempt;
    _portSubs = [
      port.errors.listen((m) {
        AppLog.w('karaoke video player error: $m');
        _onError(attempt);
      }),
      port.position.listen((p) => _videoPos = p),
    ];
    final file = first ? await cached(id) : null;
    if (file != null) {
      // Fixed in the cache by now: a track change that came first found nothing of ours to release.
      if (gen == _gen) {
        _pinned = id;
      } else {
        release(id);
      }
    }
    if (stale()) return;
    if (file != null) {
      _stream = null;
      await port.open(file.path, const {});
    } else {
      final s = await source.videoUrl(id);
      if (stale()) return;
      _stream = s;
      if (first) {
        _pinned = id;
        download(id, s);
      }
      await port.open(s.url.toString(), s.headers);
    }
    if (stale()) return;
    await port.firstFrame();
    if (stale()) return;
    _videoPos = Duration.zero;
    _lastSeek = null;
    if (_audioPos > _driftLimit) {
      await port.seek(_audioPos);
      _videoPos = _audioPos;
    }
  }

  /// The first error asks the address again; two in a row (no frame between) give up, the audio goes on as it was.
  void _onError(int attempt) {
    if (attempt != _attempt || attempt == _failedAttempt || _id == null || _status == KaraokeVideoStatus.failed) return;
    _failedAttempt = attempt;
    if (++_errors >= 2) {
      _closePort();
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
  Future<void>? beforePlay(Track t, Duration start) {
    _audioPos = start;
    _track(t, retry: true);
    if (_id == null) return null;
    if (_status == KaraokeVideoStatus.ready && (start - _videoPos).abs() > _driftLimit) _tick(user: true);
    return _background ? null : _ready.future; // in the background nobody sees it: it joins the audio on return
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
    // Done when the video's own clock is there, not when the command returns.
    return _guard(
      port.seek(pos).then((_) => port.position.firstWhere((p) => (p - pos).abs() <= _driftLimit)).then<void>((_) {}),
      'seek',
    );
  }

  /// The app goes to the background: the video stops, the audio does not. Back: it joins the audio again.
  void onLifecycle(AppLifecycleState s) {
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) {
      _background = true;
      _videoPlaying = false;
      final port = _port;
      if (port != null) unawaited(_guard(port.pause(), 'pause'));
    } else if (s == AppLifecycleState.resumed && _background) {
      _background = false;
      final port = _port;
      if (port == null || _status != KaraokeVideoStatus.ready) return;
      final expires = _stream?.expires;
      if (expires != null && !_clock().isBefore(expires)) {
        // The address ran out meanwhile: a new one, not an error.
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
    _id = null;
    _gen++;
    _attempt++;
    _done();
    _unpin();
    _closePort();
  }
}

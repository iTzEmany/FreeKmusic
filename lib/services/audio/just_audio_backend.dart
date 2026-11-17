import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';

import '../../core/app_log.dart';
import 'audio_backend.dart';
import 'desktop_voice_filter.dart';
import 'equalizer.dart';

/// Whether a failed stream load is worth one more address. ExoPlayer hides the
/// HTTP status of a refused address behind «(0) Source error» (the 403 is only
/// in logcat), so that message counts too; desktop (mpv) may name the status.
bool streamLooksExpired(Object e) {
  final text = '$e';
  return RegExp(r'\b(403|410)\b').hasMatch(text) ||
      (e is PlayerException && e.code == 0 && text.contains('Source error'));
}

class JustAudioBackend implements AudioBackend, GaplessCapable {
  /// [withEqualizer] (Android only) puts an `AndroidEqualizer` in the player's
  /// audio pipeline; only the main player asks for it. The voice filter comes with
  /// it, or alone with [withVoiceFilter] (the Jam's player, D-587); previews have
  /// none. On Android it is the `AudioProcessor` of the just_audio copy, on Linux
  /// (only) mpv's `af`. Every backend the crossfade creates gets its own filter.
  factory JustAudioBackend({bool withEqualizer = false, bool withVoiceFilter = false}) {
    final voice = withEqualizer || withVoiceFilter;
    if (voice && Platform.isAndroid) {
      final eq = withEqualizer ? AndroidEqualizer() : null;
      final player = AudioPlayer(
        audioPipeline: eq == null ? null : AudioPipeline(androidAudioEffects: [eq]),
      );
      return JustAudioBackend._(player, eq == null ? null : _AndroidEq(eq), _AndroidVoiceFilter(player));
    }
    if (voice && DesktopVoiceFilter.supported) {
      final dv = DesktopVoiceFilter();
      return JustAudioBackend._(
        AudioPlayer(
          audioLoadConfiguration: AudioLoadConfiguration(
            darwinLoadControl: DarwinLoadControl(
              preferredPeakBitRate: dv.preferredPeakBitRate,
            ),
          ),
        ),
        null,
        dv,
      );
    }
    return JustAudioBackend._(AudioPlayer(), null, null);
  }

  JustAudioBackend._(this._player, this.equalizer, this.voiceFilter) {
    _indexSub = _player.currentIndexStream.listen(_onIndex);
  }

  final AudioPlayer _player;
  late final StreamSubscription<int?> _indexSub;
  final _advanced = StreamController<void>.broadcast();

  // The playlist holds the current track and, when [setNext] was called, the
  // one that follows. Edits run one after the other; `load` makes the ones
  // still waiting obsolete.
  Future<void> _window = Future<void>.value();
  int _generation = 0;
  int _index = 0;
  String? _nextPath;

  @override
  final Equalizer? equalizer;

  @override
  final VoiceFilter? voiceFilter;

  @override
  Stream<Duration> get position => _player.positionStream;

  @override
  Stream<Duration?> get duration => _player.durationStream;

  @override
  Stream<BackendState> get state => _player.playerStateStream
      .map(
        (s) => switch (s.processingState) {
          ProcessingState.idle => BackendState.idle,
          ProcessingState.loading ||
          ProcessingState.buffering => BackendState.loading,
          ProcessingState.ready =>
            s.playing ? BackendState.playing : BackendState.paused,
          ProcessingState.completed => BackendState.completed,
        },
      )
      // A stream that breaks while playing arrives as an error event.
      .transform(StreamTransformer<BackendState, BackendState>.fromHandlers(
        handleError: (e, st, sink) {
          AppLog.w('player error', e, st);
          sink.add(BackendState.error);
        },
      ));

  @override
  Stream<String?> get streamTitle =>
      _player.icyMetadataStream.map((m) => m?.info?.title);

  @override
  Stream<void> get advanced => _advanced.stream;

  void _onIndex(int? i) {
    if (i == null) return;
    final moved = i == 1 && _index == 0 && _nextPath != null;
    _index = i;
    if (!moved) return;
    _nextPath = null;
    _advanced.add(null);
    // The finished track leaves the playlist: the window is [current] again.
    _enqueue(() => _player.removeAudioSourceAt(0));
  }

  void _enqueue(Future<void> Function() edit) {
    final generation = _generation;
    _window = _window.then((_) async {
      if (generation != _generation) return;
      try {
        await edit();
      } on Object catch (e, st) {
        AppLog.w('gapless window edit failed', e, st);
      }
    });
  }

  @override
  Future<void> setNext(String? path,
      {double volume = 1.0, bool overlap = true}) {
    _enqueue(() async {
      var wanted = path;
      if (wanted != null && !await File(wanted).exists()) wanted = null;
      if (wanted == _nextPath) return;
      // Playback may have moved on while this edit waited: leave it to the
      // next call, which the move itself triggers.
      if (_player.currentIndex != 0) return;
      if (_player.audioSources.length > 1) {
        await _player.removeAudioSourceAt(1);
      }
      _nextPath = null;
      if (wanted != null) {
        await _player.addAudioSource(AudioSource.file(wanted));
        _nextPath = wanted;
      }
    });
    return _window;
  }

  void _resetWindow() {
    _generation++;
    _nextPath = null;
    _index = 0;
  }

  @override
  Future<void> load(String filePath) async {
    if (!await File(filePath).exists()) {
      throw const BackendException('file missing', fileMissing: true);
    }
    _resetWindow();
    try {
      await _player.setFilePath(filePath);
    } on PlayerInterruptedException catch (e) {
      // A newer load replaced this one: expected when skipping quickly.
      AppLog.d('load interrupted: $filePath (${e.message})');
      throw BackendException('load interrupted: ${e.message}');
    } on Object catch (e, st) {
      AppLog.w('load failed: $filePath', e, st);
      throw BackendException('unplayable file: $e');
    }
  }

  @override
  Future<void> loadUri(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    _resetWindow();
    try {
      // An empty (non-null) map would still start just_audio's local proxy,
      // which breaks HLS: relative segments after a redirect.
      await _player.setAudioSource(
          AudioSource.uri(uri, headers: headers.isEmpty ? null : headers));
    } on Object catch (e, st) {
      AppLog.w('stream load failed: ${uri.host}', e, st);
      throw BackendException('unplayable stream: $e',
          expired: streamLooksExpired(e));
    }
  }

  // play() completes only when playback ends or pauses: never await it.
  @override
  Future<void> play() async {
    _player.play().catchError((Object e, StackTrace st) {
      AppLog.e('play failed', e, st);
    });
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> park() {
    _resetWindow();
    return _player.pause();
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Duration get positionNow => _player.position;

  @override
  Future<void> dispose() async {
    _generation++;
    await _indexSub.cancel();
    await _advanced.close();
    await _player.dispose();
  }
}

class _AndroidVoiceFilter implements VoiceFilter {
  _AndroidVoiceFilter(this._player);

  final AudioPlayer _player;

  // The call can fail while the native player is being replaced; the new one
  // gets the remembered level from just_audio itself, so a failure is only logged.
  @override
  Future<void> setLevel(double? level) async {
    try {
      await _player.setAndroidVoiceLevel(level);
    } catch (e, st) {
      AppLog.w('voice filter: setLevel($level) failed', e, st);
    }
  }
}

class _AndroidEq implements Equalizer {
  _AndroidEq(this._eq);

  final AndroidEqualizer _eq;

  @override
  Future<EqBands> bands() async {
    final p = await _eq.parameters;
    return EqBands(
      centerHz: [for (final b in p.bands) b.centerFrequency],
      minDb: p.minDecibels,
      maxDb: p.maxDecibels,
    );
  }

  @override
  Future<void> setEnabled(bool enabled) => _eq.setEnabled(enabled);

  @override
  Future<void> setGains(List<double> gainsDb) async {
    final p = await _eq.parameters;
    for (var i = 0; i < p.bands.length; i++) {
      final g = i < gainsDb.length ? gainsDb[i] : 0.0;
      await p.bands[i].setGain(
        g.clamp(p.minDecibels, p.maxDecibels).toDouble(),
      );
    }
  }
}

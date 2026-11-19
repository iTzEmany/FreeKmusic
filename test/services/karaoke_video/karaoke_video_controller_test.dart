import 'dart:async';

import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/services/karaoke_video/karaoke_video.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_controller.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

final _t0 = DateTime(2026);
const _s = Duration(seconds: 1);

void main() {
  group('syncStep', () {
    SyncStep step({
      bool audioPlaying = true,
      bool videoPlaying = true,
      Duration audioPos = _s,
      Duration videoPos = _s,
      DateTime? lastSeek,
      bool user = false,
      DateTime? now,
    }) => syncStep(
      audioPlaying: audioPlaying,
      videoPlaying: videoPlaying,
      audioPos: audioPos,
      videoPos: videoPos,
      now: now ?? _t0,
      lastSeek: lastSeek,
      userSeek: user,
    );

    test('follows play and pause', () {
      expect(step(videoPlaying: false).action, SyncAction.play);
      expect(step(audioPlaying: false).action, SyncAction.pause);
    });
    test('seeks past 300 ms, not below', () {
      final off = step(videoPos: _s * 2);
      expect((off.action, off.seekTo), (SyncAction.seek, _s));
      expect(step(videoPos: _s + const Duration(milliseconds: 250)).action, SyncAction.none);
    });
    test('at most one seek every 2 s', () {
      expect(step(videoPos: _s * 5, lastSeek: _t0.subtract(_s)).action, SyncAction.none);
      expect(step(videoPos: _s * 5, lastSeek: _t0.subtract(_s * 2)).action, SyncAction.seek);
    });
    test('a seek of the user always passes', () {
      expect(step(user: true, lastSeek: _t0).action, SyncAction.seek);
    });
  });

  group('controller', () {
    late _Port port;
    late int created;
    late List<KaraokeVideoStatus> states;
    late List<String> cache;
    late StreamController<Track?> tracks;
    late StreamController<Duration> positions;
    late StreamController<bool> playing;
    late int fetches;
    late KaraokeVideoController c;
    var now = _t0;
    var audioIsPlaying = false;

    Track track(String title, {String path = 'online:youtube:abc'}) => Track(
      saved: false, coverSource: 0, id: 1, path: path, title: title, albumKey: 'k', durationMs: 1000,
      format: 'm4a', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false, enrichStatus: 0,
      userEdited: false, missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
    );

    setUp(() {
      created = 0;
      fetches = 0;
      states = [];
      cache = [];
      now = _t0;
      audioIsPlaying = false;
      port = _Port();
      tracks = StreamController.broadcast();
      positions = StreamController.broadcast();
      playing = StreamController.broadcast();
      c = KaraokeVideoController(
        source: KaraokeVideoSource((id) async {
          fetches++;
          return (url: Uri.parse('https://v/$id'), headers: const <String, String>{}, expires: null);
        }),
        cached: (id) async => null,
        download: (id, s) => cache.add('download $id'),
        release: (id) => cache.add('release $id'),
        tracks: tracks.stream,
        positions: positions.stream,
        playing: playing.stream,
        audioPlaying: () => audioIsPlaying,
        onState: (s) => states.add(s.status),
        createPort: () {
          created++;
          return port;
        },
        clock: () => now,
      );
    });
    tearDown(() async {
      await c.dispose();
    });

    Future<void> startKaraoke() async {
      tracks.add(track('Hello (Karaoke Version)'));
      await pumpEventQueue();
    }

    test('a karaoke track gets a video, ready at the first frame; a normal track closes it', () async {
      await startKaraoke();
      expect(states.last, KaraokeVideoStatus.ready);
      expect(created, 1);
      expect(port.opened, ['https://v/abc']);
      tracks.add(track('Hello', path: '/m/a.mp3'));
      await pumpEventQueue();
      expect(states.last, KaraokeVideoStatus.none);
      expect(port.disposed, isTrue);
      expect(cache, ['download abc', 'release abc']);
    });

    test('another karaoke track: a new video in the same player', () async {
      await startKaraoke();
      tracks.add(track('Other karaoke', path: 'online:youtube:xyz'));
      await pumpEventQueue();
      expect(port.opened, ['https://v/abc', 'https://v/xyz']);
      expect(created, 1);
    });

    test('follows the audio: play, pause, and a drift is corrected', () async {
      await startKaraoke();
      playing.add(true);
      await pumpEventQueue();
      expect(port.calls, contains('play'));
      now = now.add(_s * 3);
      positions.add(_s * 10);
      await pumpEventQueue();
      expect(port.calls.last, 'seek 10s');
      playing.add(false);
      await pumpEventQueue();
      expect(port.calls.last, 'pause');
    });

    test('background pauses the video; foreground seeks to the audio and plays', () async {
      await startKaraoke();
      audioIsPlaying = true;
      playing.add(true);
      positions.add(_s * 20);
      await pumpEventQueue();
      port.calls.clear();
      c.onLifecycle(AppLifecycleState.paused);
      expect(port.calls, ['pause']);
      positions.add(_s * 25); // the audio goes on, the video does not follow
      await pumpEventQueue();
      expect(port.calls, ['pause']);
      c.onLifecycle(AppLifecycleState.resumed);
      expect(port.calls, ['pause', 'seek 25s', 'play']);
    });

    test('two errors: failed, a new address asked once in between', () async {
      await startKaraoke();
      port.errorsC.add('boom');
      await pumpEventQueue();
      expect(fetches, 2);
      expect(states.last, KaraokeVideoStatus.ready);
      port.errorsC.add('boom again');
      await pumpEventQueue();
      expect(states.last, KaraokeVideoStatus.failed);
      expect(fetches, 2);
    });

    test('the gate holds until the first frame, and does not hold normal tracks', () async {
      port.frame = Completer<void>();
      var released = false;
      unawaited(c.beforePlay(track('x karaoke'))!.then((_) => released = true));
      await pumpEventQueue();
      expect(released, isFalse);
      port.frame.complete();
      await pumpEventQueue();
      expect(released, isTrue);
      expect(c.beforePlay(track('plain', path: '/m/a.mp3')), isNull);
    });
  });
}

class _Port implements KaraokeVideoPort {
  final errorsC = StreamController<String>.broadcast();
  final calls = <String>[];
  final opened = <String>[];
  var disposed = false;
  var frame = Completer<void>()..complete();

  @override
  VideoController? get video => null;
  @override
  Stream<String> get errors => errorsC.stream;
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Future<void> open(String source, Map<String, String> headers) async => opened.add(source);
  @override
  Future<void> firstFrame() => frame.future;
  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration pos) async => calls.add('seek ${pos.inSeconds}s');
  @override
  Future<void> dispose() async => disposed = true;
}

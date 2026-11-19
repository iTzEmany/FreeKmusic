import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/services/karaoke_video/karaoke_video.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_controller.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart' show VideoController;

var _ports = <FakePort>[];
var _states = <KaraokeVideoState>[];
FakePort get port => _ports.last;
KaraokeVideoStatus get last => _states.last.status;
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
    }) => syncStep(
      audioPlaying: audioPlaying,
      videoPlaying: videoPlaying,
      audioPos: audioPos,
      videoPos: videoPos,
      now: _t0,
      lastSeek: lastSeek,
      userSeek: user,
    );

    test('follows play and pause', () {
      expect(step(videoPlaying: false).action, SyncAction.play);
      expect(step(audioPlaying: false).action, SyncAction.pause);
    });
    test('seeks past 300 ms, not at 300', () {
      final off = step(videoPos: _s + const Duration(milliseconds: 350));
      expect((off.action, off.seekTo), (SyncAction.seek, _s));
      expect(step(videoPos: _s + const Duration(milliseconds: 300)).action, SyncAction.none);
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
    late List<String> cache;
    late StreamController<Track?> tracks;
    late StreamController<Duration> positions;
    late StreamController<bool> playing;
    late int fetches;
    late DateTime expires;
    late KaraokeVideoController c;
    late File? cachedFile;
    Completer<void>? urlGate;
    Completer<void>? cachedGate;
    var now = _t0;
    var audioIsPlaying = false;
    var autoFrame = true;
    var loadTimeout = const Duration(seconds: 10);

    Track track(String title, {String path = 'online:youtube:abc'}) => Track(
      saved: false, coverSource: 0, id: 1, path: path, title: title, albumKey: 'k', durationMs: 1000,
      format: 'm4a', sizeBytes: 1, mtimeMs: 1, hasCover: false, isFavorite: false, enrichStatus: 0,
      userEdited: false, missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
    );
    final karaoke = track('Hello (Karaoke Version)');
    final plain = track('Hello', path: '/m/a.mp3');

    void make() {
      c = KaraokeVideoController(
        source: KaraokeVideoSource((id) async {
          fetches++;
          await urlGate?.future;
          return (url: Uri.parse('https://v/$id/$fetches'), headers: const <String, String>{}, expires: expires);
        }),
        cached: (id) async {
          await cachedGate?.future;
          return cachedFile;
        },
        download: (id, s) => cache.add('download $id'),
        release: (id) => cache.add('release $id'),
        tracks: tracks.stream,
        positions: positions.stream,
        playing: playing.stream,
        audioPlaying: () => audioIsPlaying,
        onState: _states.add,
        createPort: () {
          final p = FakePort();
          if (autoFrame) p.frame.complete();
          _ports.add(p);
          return p;
        },
        clock: () => now,
        loadTimeout: loadTimeout,
      );
    }

    setUp(() {
      fetches = 0;
      _ports = <FakePort>[];
      _states = <KaraokeVideoState>[];
      cache = [];
      now = _t0;
      expires = _t0.add(const Duration(hours: 5));
      audioIsPlaying = false;
      autoFrame = true;
      loadTimeout = const Duration(seconds: 10);
      urlGate = null;
      cachedGate = null;
      cachedFile = null;
      tracks = StreamController.broadcast();
      positions = StreamController.broadcast();
      playing = StreamController.broadcast();
      make();
    });
    tearDown(() async {
      await c.dispose();
    });

    Future<void> startKaraoke() async {
      tracks.add(karaoke);
      await pumpEventQueue();
    }

    Future<void> play() async {
      audioIsPlaying = true;
      playing.add(true);
      await pumpEventQueue();
    }

    test('a karaoke track gets a video, ready at the first frame; a normal track closes it', () async {
      await startKaraoke();
      expect(last, KaraokeVideoStatus.ready);
      expect(_ports.single.opened, ['https://v/abc/1']);
      tracks.add(plain);
      await pumpEventQueue();
      expect(last, KaraokeVideoStatus.none);
      expect(port.disposed, isTrue);
      expect(cache, ['download abc', 'release abc']);
    });

    test('another karaoke track: a new player, the old one closed', () async {
      await startKaraoke();
      tracks.add(track('Other karaoke', path: 'online:youtube:xyz'));
      await pumpEventQueue();
      expect(_ports.length, 2);
      expect(_ports.first.disposed, isTrue);
      expect(_ports.last.opened.single, startsWith('https://v/xyz'));
      expect(cache, ['download abc', 'release abc', 'download xyz']);
    });

    test('a cached file opens as a file: no address, no download', () async {
      cachedFile = File('/cache/abc.mp4');
      await startKaraoke();
      expect(port.opened, ['/cache/abc.mp4']);
      expect(fetches, 0);
      expect(cache, isEmpty);
      tracks.add(plain);
      await pumpEventQueue();
      expect(cache, ['release abc']);
    });

    test('the load seeks to where the audio is', () async {
      positions.add(_s * 10);
      await startKaraoke();
      expect(port.calls, ['seek 10s']);
    });

    test('follows the audio: play, pause, and a drift is corrected', () async {
      await startKaraoke();
      await play();
      expect(port.calls, contains('play'));
      now = now.add(_s * 3);
      positions.add(_s * 10);
      await pumpEventQueue();
      expect(port.calls.last, 'seek 10s');
      audioIsPlaying = false;
      playing.add(false);
      await pumpEventQueue();
      expect(port.calls.last, 'pause');
    });

    group('lifecycle', () {
      test('background pauses the video; foreground seeks to the audio and plays', () async {
        await startKaraoke();
        await play();
        positions.add(_s * 20);
        await pumpEventQueue();
        port.calls.clear();
        c.onLifecycle(AppLifecycleState.hidden);
        expect(port.calls, ['pause']);
        positions.add(_s * 25); // the audio goes on, the video does not follow
        await pumpEventQueue();
        expect(port.calls, ['pause']);
        c.onLifecycle(AppLifecycleState.resumed);
        expect(port.calls, ['pause', 'seek 25s', 'play']);
      });

      test('foreground with the audio paused: aligned, not playing', () async {
        await startKaraoke();
        c.onLifecycle(AppLifecycleState.paused);
        positions.add(_s * 25);
        await pumpEventQueue();
        port.calls.clear();
        c.onLifecycle(AppLifecycleState.resumed);
        expect(port.calls, ['seek 25s']);
      });

      test('«resumed» without a background does nothing', () async {
        await startKaraoke();
        port.calls.clear();
        c.onLifecycle(AppLifecycleState.resumed);
        expect(port.calls, isEmpty);
      });

      test('an address that ran out is asked again on return, not counted as an error', () async {
        expires = _t0.add(const Duration(minutes: 5));
        await startKaraoke();
        c.onLifecycle(AppLifecycleState.paused);
        now = _t0.add(const Duration(minutes: 6));
        c.onLifecycle(AppLifecycleState.resumed);
        await pumpEventQueue();
        expect(fetches, 2);
        expect(_ports.length, 2);
        expect(last, KaraokeVideoStatus.ready);
      });

      test('in the background the gate does not hold the audio', () async {
        c.onLifecycle(AppLifecycleState.paused); // no video at all yet
        expect(c.beforePlay(karaoke, Duration.zero), isNull);
      });
    });

    group('errors', () {
      test('several lines of one failure: one new address; then ready', () async {
        await startKaraoke();
        port.errorsC.add('boom');
        port.errorsC.add('boom again');
        await pumpEventQueue();
        expect(fetches, 2);
        expect(last, KaraokeVideoStatus.ready);
      });

      test('error, ready, error: not failed', () async {
        await startKaraoke();
        port.errorsC.add('1');
        await pumpEventQueue();
        port.errorsC.add('2');
        await pumpEventQueue();
        expect(fetches, 3);
        expect(last, KaraokeVideoStatus.ready);
      });

      test('two in a row: failed, and the video is closed', () async {
        autoFrame = false;
        tracks.add(karaoke);
        await pumpEventQueue();
        port.errorsC.add('boom');
        await pumpEventQueue();
        expect(_ports.length, 2);
        port.errorsC.add('boom');
        await pumpEventQueue();
        expect(last, KaraokeVideoStatus.failed);
        expect(fetches, 2);
        expect(port.disposed, isTrue);
        expect(c.afterSeek(_s), isNull);
      });

      test('played again after a failure: a new try', () async {
        loadTimeout = const Duration(milliseconds: 10);
        c = KaraokeVideoController(
          source: KaraokeVideoSource((id) async => (url: Uri.parse('https://v/$id'), headers: const <String, String>{}, expires: null)),
          cached: (id) async => null,
          download: (id, s) {},
          release: (id) {},
          tracks: tracks.stream,
          positions: positions.stream,
          playing: playing.stream,
          audioPlaying: () => false,
          onState: _states.add,
          createPort: () {
            final p = FakePort();
            _ports.add(p);
            return p;
          },
          loadTimeout: loadTimeout,
        );
        tracks.add(karaoke);
        await Future<void>.delayed(const Duration(milliseconds: 80)); // two timeouts
        expect(last, KaraokeVideoStatus.failed);
        final hold = c.beforePlay(karaoke, Duration.zero)!;
        _ports.last.frame.complete();
        await hold;
        expect(last, KaraokeVideoStatus.ready);
      });
    });

    group('the gate', () {
      test('holds until the first frame; normal tracks are not held', () async {
        autoFrame = false;
        var released = false;
        unawaited(c.beforePlay(karaoke, Duration.zero)!.then((_) => released = true));
        await pumpEventQueue();
        expect(released, isFalse);
        port.frame.complete();
        await pumpEventQueue();
        expect(released, isTrue);
        expect(c.beforePlay(plain, Duration.zero), isNull);
      });

      test('the video starts where the audio will: the saved place', () async {
        final hold = c.beforePlay(karaoke, _s * 40)!;
        await hold;
        expect(port.calls, ['seek 40s']);
      });

      test('another track in the middle of the first frame: that video never shows', () async {
        autoFrame = false;
        tracks.add(karaoke);
        await pumpEventQueue();
        tracks.add(plain);
        await pumpEventQueue();
        port.frame.complete();
        await pumpEventQueue();
        expect(_states.map((s) => s.status), isNot(contains(KaraokeVideoStatus.ready)));
        expect(last, KaraokeVideoStatus.none);
      });

      test('a seek waits for the video clock to get there', () async {
        await startKaraoke();
        port.autoPosition = false;
        var done = false;
        unawaited(c.afterSeek(_s * 30)!.then((_) => done = true));
        await pumpEventQueue();
        expect(done, isFalse);
        port.positionC.add(_s * 30);
        await pumpEventQueue();
        expect(done, isTrue);
      });

      test('a seek while loading waits for the load; with no video, no wait', () async {
        expect(c.afterSeek(_s), isNull);
        autoFrame = false;
        tracks.add(karaoke);
        await pumpEventQueue();
        var done = false;
        unawaited(c.afterSeek(_s)!.then((_) => done = true));
        port.frame.complete();
        await pumpEventQueue();
        expect(done, isTrue);
        c.onLifecycle(AppLifecycleState.paused);
        expect(c.afterSeek(_s), isNull);
      });
    });

    group('the cache pin', () {
      test('a track change while the address is pending: nothing to release', () async {
        urlGate = Completer<void>();
        tracks.add(karaoke);
        await pumpEventQueue();
        tracks.add(plain);
        await pumpEventQueue();
        urlGate!.complete();
        await pumpEventQueue();
        expect(cache, isEmpty);
      });

      test('a file answered after the track changed: one release', () async {
        cachedFile = File('/cache/abc.mp4');
        cachedGate = Completer<void>();
        tracks.add(karaoke);
        await pumpEventQueue();
        tracks.add(plain);
        await pumpEventQueue();
        cachedGate!.complete();
        await pumpEventQueue();
        expect(cache, ['release abc']);
        expect(port.opened, isEmpty);
      });

      test('closing releases the current video', () async {
        await startKaraoke();
        await c.dispose();
        expect(cache, ['download abc', 'release abc']);
      });
    });
  });
}

class FakePort implements KaraokeVideoPort {
  final errorsC = StreamController<String>.broadcast();
  final positionC = StreamController<Duration>.broadcast();
  final calls = <String>[];
  final opened = <String>[];
  var disposed = false;
  var autoPosition = true;
  final frame = Completer<void>();

  @override
  VideoController? get video => null;
  @override
  Stream<String> get errors => errorsC.stream;
  @override
  Stream<Duration> get position => positionC.stream;
  @override
  Future<void> open(String source, Map<String, String> headers) async => opened.add(source);
  @override
  Future<void> firstFrame() => frame.future;
  @override
  Future<void> play() async => calls.add('play');
  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> seek(Duration pos) async {
    calls.add('seek ${pos.inSeconds}s');
    if (autoPosition) Timer.run(() => positionC.add(pos));
  }

  @override
  Future<void> dispose() async => disposed = true;
}

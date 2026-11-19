import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/audio_backend.dart' show TransitionMode;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_gate.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_stream_preparer.dart';

/// The path of the track that was loaded at each `play()`.
class _CountingBackend extends FakeBackend {
  final played = <String>[];
  @override
  Future<void> play() {
    played.add(loaded.last);
    return super.play();
  }
}

/// Holds track «a» (the karaoke one) until [hold] completes; «b» has no video.
class _Gate implements KaraokeVideoGate {
  var hold = Completer<void>();
  var seekHold = Completer<void>();
  final nextSeekHolds = <Completer<void>>[]; // one per seek, in order; then [seekHold]
  var seeks = 0;
  var noVideo = false; // the gate answers null to a seek
  Duration? lastStart;
  @override
  Future<void>? beforePlay(Track t, Duration start) {
    lastStart = start;
    return t.title == 'a' || t.title.startsWith('Song') ? hold.future : null;
  }

  @override
  Future<void>? afterSeek(Duration pos) {
    seeks++;
    if (noVideo) return null;
    return (nextSeekHolds.isEmpty ? seekHold : nextSeekHolds.removeAt(0)).future;
  }
}

void main() {
  late AppDatabase db;
  late _CountingBackend backend;
  late CodecoreAudioHandler handler;
  late _Gate gate;
  late List<int> ids;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final repo = TrackRepository(db);
    backend = _CountingBackend();
    ids = [];
    for (final n in ['a', 'b']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$n.mp3', title: n, albumKey: 'k', format: 'mp3',
            sizeBytes: 1, mtimeMs: 1, addedAt: 1, durationMs: const Value(100000),
          ));
      ids.add((await repo.idForPath('/m/$n.mp3'))!);
    }
    gate = _Gate();
    handler = CodecoreAudioHandler(backend, PlayQueue(), repo, onError: (_) {})..videoGate = gate;
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  test('no play() before the video is ready; the audio starts when it is', () async {
    final started = handler.playQueue(ids, 0);
    await pumpEventQueue();
    expect(backend.loaded.last, '/m/a.mp3');
    expect(backend.played, isEmpty);
    gate.hold.complete();
    await started;
    expect(backend.played, ['/m/a.mp3']);
  });

  test('a video that is never ready: the audio starts after 10 s', () {
    fakeAsync((fa) {
      unawaited(handler.playQueue(ids, 0));
      fa.flushMicrotasks();
      fa.elapse(const Duration(seconds: 9));
      expect(backend.played, isEmpty);
      fa.elapse(const Duration(seconds: 2));
      expect(backend.played, ['/m/a.mp3']);
    });
  });

  // The handler of the streamed tracks (its preparer does real I/O: not for the fake-async tests).
  (CodecoreAudioHandler, OnlineEntries) streaming() {
    final online = OnlineEntries();
    final dir = Directory.systemTemp.createTempSync('video_gate');
    final h = CodecoreAudioHandler(backend, PlayQueue(), TrackRepository(db),
        onError: (_) {}, online: online, preparer: FakeStreamPreparer(TrackRepository(db), dir))
      ..videoGate = gate;
    addTearDown(() async {
      await h.dispose();
      dir.deleteSync(recursive: true);
    });
    return (h, online);
  }

  YtResult video(String title) =>
      YtResult(id: 'v1', title: title, channel: 'C', artists: const ['A'], album: 'B', duration: const Duration(minutes: 3));

  test('a pause during the video wait stays a pause', () async {
    final started = handler.playQueue(ids, 0);
    await pumpEventQueue();
    expect(backend.played, isEmpty);
    await handler.pause();
    gate.hold.complete();
    await started;
    expect(backend.playing, isFalse);
    expect(backend.played, isEmpty);
    expect(handler.playbackState.value.playing, isFalse);
  });

  test('▶ again during the wait (after a pause) plays when the video is there', () async {
    final started = handler.playQueue(ids, 0);
    await pumpEventQueue();
    await handler.pause();
    await handler.play();
    expect(backend.played, isEmpty);
    gate.hold.complete();
    await started;
    expect(backend.played, ['/m/a.mp3']);
  });

  test('a pause that comes while the track is loading, before the wait: no wait, no play', () async {
    final started = handler.playQueue(ids, 0);
    await handler.pause();
    gate.hold.complete();
    await started;
    expect(backend.played, isEmpty);
  });

  test('a streamed karaoke track waits too, and a pause meanwhile stays a pause', () async {
    final (h, online) = streaming();
    final id = online.register(video('Song v1'));
    final started = h.playQueue([id], 0);
    // Resolving the stream touches files and the DB: slower on Windows runners.
    for (var i = 0; i < 200 && backend.loaded.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(backend.loaded, isNotEmpty);
    expect(backend.played, isEmpty);
    await h.pause();
    gate.hold.complete();
    await started;
    expect(backend.played, isEmpty);
    expect(backend.playing, isFalse);
  });

  test('the video is told where the audio starts: the saved place', () async {
    await (db.update(db.tracks)..where((t) => t.id.equals(ids[0])))
        .write(const TracksCompanion(resumePositionMs: Value(40000)));
    gate.hold.complete();
    await handler.playQueue(ids, 0);
    expect(gate.lastStart, greaterThan(const Duration(seconds: 30)));
  });

  test('the gapless window does not take a karaoke video (it goes through the wait)', () async {
    final (h, online) = streaming();
    final karaoke = online.register(video('Hello (Karaoke Version)'));
    await h.playQueue([ids[1], karaoke], 0);
    await h.setTransition(TransitionMode.gapless);
    await pumpEventQueue();
    expect(backend.loaded.last, '/m/b.mp3');
    expect(backend.nextPath, isNull);
  });

  test('with a karaoke hook too, the gapless window does not take a karaoke video', () async {
    final (h, online) = streaming();
    h.karaokeSource = (t, _) async => null;
    final karaoke = online.register(video('Hello (Karaoke Version)'));
    await h.playQueue([ids[1], karaoke], 0);
    await h.setTransition(TransitionMode.gapless);
    await pumpEventQueue();
    expect(backend.nextPath, isNull);
  });

  test('a normal track does not wait', () async {
    await handler.playQueue(ids, 1);
    expect(backend.played, ['/m/b.mp3']);
  });

  test('another track loaded during the wait: the old one never plays', () async {
    final first = handler.playQueue(ids, 0);
    await pumpEventQueue();
    await handler.playQueue(ids, 1);
    gate.hold.complete();
    await first;
    expect(backend.played, ['/m/b.mp3']);
  });

  group('seek', () {
    setUp(() async {
      gate.hold.complete();
      await handler.playQueue(ids, 0);
      await pumpEventQueue();
      backend.played.clear();
    });

    test('the audio waits for the video, then goes on', () async {
      final seeking = handler.seek(const Duration(seconds: 30));
      await pumpEventQueue();
      expect(gate.seeks, 1);
      expect(backend.playing, isFalse);
      gate.seekHold.complete();
      await seeking;
      expect(backend.playing, isTrue);
    });

    test('a video that does not answer holds the audio at most 3 s', () {
      fakeAsync((fa) {
        unawaited(handler.seek(const Duration(seconds: 30)));
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 2));
        expect(backend.playing, isFalse);
        fa.elapse(const Duration(seconds: 2));
        expect(backend.playing, isTrue);
      });
    });

    test('a seek from a pause does not start the audio', () async {
      await handler.pause();
      await pumpEventQueue();
      backend.played.clear();
      await handler.seek(const Duration(seconds: 30));
      expect(gate.seeks, 1);
      expect(backend.played, isEmpty);
      expect(backend.playing, isFalse);
    });

    test('no video: the seek does not pause the audio', () async {
      gate.noVideo = true;
      await handler.seek(const Duration(seconds: 30));
      expect(backend.playing, isTrue);
    });

    test('the state shown stays «playing» during the wait', () async {
      final seen = <bool>[];
      final sub = handler.playbackState.listen((s) => seen.add(s.playing));
      final seeking = handler.seek(const Duration(seconds: 30));
      await pumpEventQueue();
      gate.seekHold.complete();
      await seeking;
      await pumpEventQueue();
      await sub.cancel();
      expect(seen, isNot(contains(false)));
    });

    test('a second seek replaces the first: one play, after the last', () async {
      final h1 = Completer<void>(), h2 = Completer<void>();
      gate.nextSeekHolds.addAll([h1, h2]);
      final s1 = handler.seek(const Duration(seconds: 30));
      await pumpEventQueue();
      final s2 = handler.seek(const Duration(seconds: 60));
      await pumpEventQueue();
      h1.complete();
      await s1;
      await pumpEventQueue();
      expect(backend.playing, isFalse);
      h2.complete();
      await s2;
      expect(backend.playing, isTrue);
      expect(backend.played, ['/m/a.mp3']);
    });

    test('another track during the wait: the new one is not restarted', () async {
      final seeking = handler.seek(const Duration(seconds: 30));
      await pumpEventQueue();
      await handler.playQueue(ids, 1);
      final plays = backend.played.length;
      gate.seekHold.complete();
      await seeking;
      expect(backend.played.length, plays);
      expect(backend.loaded.last, '/m/b.mp3');
    });

    test('a seek with no video while an older one waits: the audio goes on', () async {
      final s1 = handler.seek(const Duration(seconds: 30));
      await pumpEventQueue();
      expect(backend.playing, isFalse);
      gate.noVideo = true;
      await handler.seek(const Duration(seconds: 60));
      expect(backend.playing, isTrue);
      gate.seekHold.complete();
      await s1;
      expect(backend.playing, isTrue);
    });

    test('a pause during the wait stays a pause', () async {
      final seeking = handler.seek(const Duration(seconds: 30));
      await pumpEventQueue();
      await handler.pause();
      gate.seekHold.complete();
      await seeking;
      expect(backend.playing, isFalse);
    });
  });
}

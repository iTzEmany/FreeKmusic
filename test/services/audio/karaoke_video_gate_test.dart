import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/karaoke_video/karaoke_video_gate.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
// ignore: depend_on_referenced_packages
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';

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
  var seeks = 0;
  @override
  Future<void>? beforePlay(Track t) => t.title == 'a' ? hold.future : null;
  @override
  Future<void>? afterSeek(Duration pos) {
    seeks++;
    return seekHold.future;
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

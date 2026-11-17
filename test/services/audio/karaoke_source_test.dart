import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late CodecoreAudioHandler handler;
  late List<int> ids;
  var useBase = false;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final repo = TrackRepository(db);
    backend = FakeBackend();
    ids = [];
    for (final n in ['a', 'b']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$n.mp3',
            title: n,
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            durationMs: const Value(100000),
          ));
      ids.add((await repo.idForPath('/m/$n.mp3'))!);
    }
    handler = CodecoreAudioHandler(backend, PlayQueue(), repo, onError: (_) {});
    useBase = false;
    handler.karaokeSource = (t, _) async => useBase ? '/cache/${t.title}.wav' : null;
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  test('the base becomes ready mid-track: it loads at the same position, still playing', () async {
    await handler.playQueue(ids, 0);
    expect(backend.loaded.last, '/m/a.mp3');
    expect(handler.karaokePath, isNull);
    backend.posC.add(const Duration(seconds: 42));
    await pumpEventQueue();
    useBase = true;
    await handler.karaokeChanged('/cache/a.wav');
    expect(backend.loaded.last, '/cache/a.wav');
    expect(backend.seeks.last, const Duration(seconds: 42));
    expect(handler.isPlaying, isTrue);
    expect(handler.karaokePath, '/cache/a.wav');
    // Originale again: the own file, same place.
    useBase = false;
    await handler.karaokeChanged(null);
    expect(backend.loaded.last, '/m/a.mp3');
    expect(handler.karaokePath, isNull);
  });

  test('a paused track stays paused after the switch', () async {
    await handler.playQueue(ids, 0);
    await handler.pause();
    backend.posC.add(const Duration(seconds: 10));
    await pumpEventQueue();
    useBase = true;
    await handler.karaokeChanged('/cache/a.wav');
    expect(backend.loaded.last, '/cache/a.wav');
    expect(handler.isPlaying, isFalse);
  });

  test('gapless prepares the next track with the base when it has one', () async {
    useBase = true;
    await handler.playQueue(ids, 0);
    await handler.setTransition(TransitionMode.gapless);
    await pumpEventQueue();
    expect(backend.nextPath, '/cache/b.wav');
    backend.advance();
    await pumpEventQueue();
    expect(handler.karaokePath, '/cache/b.wav');
  });

  test('a reload after 30 s does not count the play again', () async {
    await handler.playQueue(ids, 0);
    backend.posC.add(const Duration(seconds: 60));
    await pumpEventQueue();
    expect((await TrackRepository(db).getById(ids[0]))!.playCount, 1);
    useBase = true;
    await handler.karaokeChanged('/cache/a.wav');
    backend.posC.add(const Duration(seconds: 61));
    await pumpEventQueue();
    backend.posC.add(const Duration(seconds: 62));
    await pumpEventQueue();
    expect((await TrackRepository(db).getById(ids[0]))!.playCount, 1);
  });

  test('karaoke off: the gapless next track goes back to its own file', () async {
    useBase = true;
    await handler.playQueue(ids, 0);
    await handler.setTransition(TransitionMode.gapless);
    await pumpEventQueue();
    expect(backend.nextPath, '/cache/b.wav');
    useBase = false;
    await handler.karaokeChanged(null);
    await pumpEventQueue();
    expect(backend.nextPath, '/m/b.mp3');
  });

  test('a second switch during a load keeps the position and the play state', () async {
    await handler.playQueue(ids, 0);
    backend.posC.add(const Duration(seconds: 42));
    await pumpEventQueue();
    final gate = Completer<void>();
    handler.karaokeSource = (t, _) async {
      await gate.future;
      return '/cache/${t.title}.wav';
    };
    final first = handler.karaokeChanged('/cache/a.wav');
    await pumpEventQueue();
    final second = handler.karaokeChanged('/cache/a.wav'); // while the first load waits
    await pumpEventQueue();
    gate.complete();
    await Future.wait([first, second]);
    expect(backend.loaded.last, '/cache/a.wav');
    expect(backend.seeks.last, const Duration(seconds: 42));
    expect(handler.isPlaying, isTrue);
  });
}

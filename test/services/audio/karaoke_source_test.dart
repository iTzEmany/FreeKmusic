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
    await handler.reloadCurrent();
    expect(backend.loaded.last, '/cache/a.wav');
    expect(backend.seeks.last, const Duration(seconds: 42));
    expect(handler.isPlaying, isTrue);
    expect(handler.karaokePath, '/cache/a.wav');
    // Originale again: the own file, same place.
    useBase = false;
    await handler.reloadCurrent();
    expect(backend.loaded.last, '/m/a.mp3');
    expect(handler.karaokePath, isNull);
  });

  test('a paused track stays paused after the switch', () async {
    await handler.playQueue(ids, 0);
    await handler.pause();
    backend.posC.add(const Duration(seconds: 10));
    await pumpEventQueue();
    useBase = true;
    await handler.reloadCurrent();
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
}

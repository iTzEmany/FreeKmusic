import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/radio_repository.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/media_browse_tree.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';

void main() {
  late AppDatabase db;
  late CodecoreAudioHandler handler;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final repo = TrackRepository(db);
    await repo.upsertBatch([
      for (var i = 0; i < 3; i++)
        TracksCompanion.insert(
            path: '/m/$i.mp3', title: 'T$i', albumKey: 'alb', format: 'mp3',
            sizeBytes: 1, mtimeMs: 1, addedAt: 1 + i, album: const Value('Alb'),
            trackNumber: Value(i + 1), durationMs: const Value(60000)),
    ]);
    handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), repo, onError: (_) {});
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  test('without a tree the browser sees nothing and a play request does nothing', () async {
    expect(await handler.getChildren('root'), isEmpty);
    expect(await handler.search('T'), isEmpty);
    await handler.playFromMediaId('track:1@album:alb');
    expect(handler.queueIds, isEmpty);
  });

  test('with the tree: browse, search and play a track of an album as its queue', () async {
    handler.browse = MediaBrowseTree(DbBrowseSource(
        TrackRepository(db), LibraryQueries(db), PlaylistRepository(db)));
    expect((await handler.getChildren('root')).map((i) => i.id), contains('albums'));
    final items = await handler.getChildren('album:alb');
    expect(items, hasLength(3));
    expect((await handler.getMediaItem(items[1].id))!.title, 'T1');
    expect((await handler.search('T2')).single.title, 'T2');

    handler.setPlayContext(2, 'Last list of the app');
    await handler.playFromMediaId(items[1].id);
    expect(handler.queueIds, hasLength(3));
    expect(handler.currentIndex, 1);
    expect(handler.currentTrack!.title, 'T1');
    expect(handler.playContext, isNull, reason: 'the car menu is not the app\'s last list');
  });

  test('choosing a saved station in the browser plays the saved list from it', () async {
    final h = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db),
        onError: (_) {}, online: OnlineEntries());
    addTearDown(h.dispose);
    final radios = RadioRepository(db);
    for (final id in ['a', 'manual:m', 'c']) {
      await radios.save(RadioStation(id: id, name: 'R $id', streamUrl: 'http://r.test/$id'));
    }
    h.browse = MediaBrowseTree(DbBrowseSource(
        TrackRepository(db), LibraryQueries(db), PlaylistRepository(db), radios));
    final items = await h.getChildren('radio');
    expect(items, hasLength(3));

    await h.playFromMediaId(items[1].id);
    expect(h.queueIds, hasLength(3));
    expect(h.currentIndex, 1);
    expect(h.currentTrack!.title, 'R manual:m');
  });
}

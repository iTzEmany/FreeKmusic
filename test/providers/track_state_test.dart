import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/free_space_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/providers/library_add_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/track_state_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

const _r = YtResult(id: 'abc', title: 'Song', channel: 'Chan', duration: Duration(seconds: 200));

void main() {
  late AppDatabase db;
  late TrackRepository tracks;
  late DownloadIndex index;
  late Directory dir;
  late File file;
  late ProviderContainer c;
  final key = _r.indexKey;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    tracks = TrackRepository(db);
    dir = await Directory.systemTemp.createTemp('track_state');
    addTearDown(() => dir.delete(recursive: true));
    file = File('${dir.path}/Song.m4a')..writeAsBytesSync([1, 2, 3]);
    index = DownloadIndex(File('${dir.path}/downloads.json'));
    final handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), tracks, onError: (_) {});
    addTearDown(handler.dispose);
    c = ProviderContainer(overrides: [
      audioHandlerProvider.overrideWithValue(handler),
      databaseProvider.overrideWithValue(db),
      trackRepositoryProvider.overrideWithValue(tracks),
      downloadIndexProvider.overrideWith((ref) async => index),
    ]);
    addTearDown(c.dispose);
  });

  // Waits for the stream/future providers to deliver, then reads the state.
  Future<TrackState> state(ProviderContainer cc, String k) async {
    await cc.read(downloadIndexProvider.future);
    await cc.read(savedStreamKeysProvider.future);
    await pumpEventQueue();
    return cc.read(trackStateProvider(k));
  }

  // Completes when the state of [k] becomes [want] (event driven, no fixed wait).
  Future<void> until(String k, TrackState want) {
    final done = Completer<void>();
    final sub = c.listen(trackStateProvider(k), (_, v) {
      if (v == want && !done.isCompleted) done.complete();
    }, fireImmediately: true);
    return done.future.timeout(const Duration(seconds: 5)).whenComplete(sub.close);
  }

  test('online -> saved -> downloaded -> freed space -> saved, on one stream key', () async {
    c.listen(trackStateProvider(key), (_, _) {});
    expect(await state(c, key), TrackState.online);

    final id = (await tracks.saveStream(_r))!;
    expect(await state(c, key), TrackState.savedStream);

    await tracks.promoteStreamRow(key, file.path, 1, file);
    await index.add(_r.id, file.path);
    c.invalidate(downloadIndexProvider); // what the downloader does
    expect(await state(c, key), TrackState.downloaded);

    // The real «Libera spazio» path: it must refresh the state by itself.
    final report = await (await c.read(freeSpaceServiceProvider.future)).freeSpace([id]);
    expect(report.freedIds, [id]);
    expect(await state(c, key), TrackState.savedStream);
  });

  test('a row key follows the row; a missing file is not downloaded', () async {
    final id = (await tracks.saveStream(_r))!;
    final k = '#$id';
    await until(k, TrackState.savedStream);
    await tracks.promoteStreamRow(key, file.path, 1, file);
    await until(k, TrackState.downloaded);
    await tracks.markMissing({file.path}, true);
    await until(k, TrackState.online);
  });

  test('the playing online entry reads as downloaded once the download is indexed', () async {
    final online = OnlineEntries();
    final entry = online.register(_r);
    final player = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trackRepositoryProvider.overrideWithValue(tracks),
      downloadIndexProvider.overrideWith((ref) async => index),
      onlineEntriesProvider.overrideWithValue(online),
      currentTrackProvider.overrideWith((ref) => Stream.value(online.trackOf(entry))),
    ]);
    addTearDown(player.dispose);
    final first = Completer<Track>();
    player.listen(liveCurrentTrackProvider, (_, v) {
      final t = v.value;
      if (t != null && !first.isCompleted) first.complete(t);
    }, fireImmediately: true);
    final live = await first.future.timeout(const Duration(seconds: 5));
    expect(live.id, entry); // the id stays the entry's own
    final k = trackStateKey(live);
    expect(k, key);
    player.listen(trackStateProvider(k), (_, _) {});
    expect(await state(player, k), TrackState.online);

    await index.add(_r.id, file.path);
    player.invalidate(downloadIndexProvider);
    expect(await state(player, k), TrackState.downloaded);
  });
}

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
import 'package:codecore/providers/track_deleter_providers.dart';
import 'package:codecore/providers/track_state_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_queue.dart' show DownloadItem;
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

const _r = YtResult(id: 'abc', title: 'Song', channel: 'Chan', duration: Duration(seconds: 200));

class _NoDownloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => [];
}

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
      downloadsProvider.overrideWith(_NoDownloads.new),
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

  test('«Elimina dal dispositivo» forgets the download: the key reads online again', () async {
    c.listen(trackStateProvider(key), (_, _) {});
    final id = (await tracks.saveStream(_r))!;
    await tracks.promoteStreamRow(key, file.path, 1, file);
    await index.add(_r.id, file.path);
    c.invalidate(downloadIndexProvider);
    expect(await state(c, key), TrackState.downloaded);

    final report = await c.read(trackDeleterProvider).deleteTracks([(await tracks.getById(id))!]);
    expect(report.deleted, hasLength(1));
    expect(await state(c, key), TrackState.online);
    expect(index.pathForKey(key), isNull);
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

  test('a `#id` key reads online for an unsaved stream row, an episode and a missing row', () async {
    final shadow = await tracks.ensureStreamRow(_r); // streamed, never saved
    final episode = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: 'https://x/e.mp3', title: 'Ep', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1, kind: const Value(1)));
    for (final id in [shadow, episode, 9999]) {
      c.listen(trackStateProvider('#$id'), (_, _) {});
      await pumpEventQueue();
      expect(c.read(trackStateProvider('#$id')), TrackState.online, reason: '#$id');
    }
  });

  test('trackStateKey: the given stream key wins, else the stream key of the path, else #id', () async {
    final id = (await tracks.saveStream(_r))!;
    final row = (await tracks.getById(id))!;
    expect(trackStateKey(row), key);
    expect(trackStateKey(row, streamKey: 'other:k'), 'other:k');
    await tracks.promoteStreamRow(key, file.path, 1, file);
    expect(trackStateKey((await tracks.getById(id))!), '#$id');
  });

  test('the row lookup of a menu follows a stream key to the downloaded file, and a `#id` key to its row', () async {
    final id = (await tracks.saveStream(_r))!;
    final shadow = (await tracks.getById(id))!;
    final lookup = c.read(trackRowLookupProvider);
    expect((await lookup(shadow, key))!.path, 'stream:$key', reason: 'not downloaded: the shadow row');
    expect((await lookup(shadow, '#$id'))!.id, id);

    await tracks.promoteStreamRow(key, file.path, 1, file);
    await index.add(_r.id, file.path);
    expect((await lookup(shadow, key))!.path, file.path);
  });
}

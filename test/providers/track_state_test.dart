import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/database_providers.dart';
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
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trackRepositoryProvider.overrideWithValue(tracks),
      downloadIndexProvider.overrideWith((ref) async => index),
    ]);
    addTearDown(c.dispose);
  });

  // Lets the stream/future providers deliver, then reads the state.
  Future<TrackState> state(String k) async {
    await c.read(downloadIndexProvider.future);
    await c.read(savedStreamKeysProvider.future);
    await Future<void>.delayed(Duration.zero);
    return c.read(trackStateProvider(k));
  }

  test('online -> saved -> downloaded -> freed space -> saved, on one stream key', () async {
    c.listen(trackStateProvider(key), (_, _) {});
    expect(await state(key), TrackState.online);

    final id = (await tracks.saveStream(_r))!;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await state(key), TrackState.savedStream);

    await tracks.promoteStreamRow(key, file.path, 1, file);
    await index.add(_r.id, file.path);
    c.invalidate(downloadIndexProvider); // what the downloader does
    expect(await state(key), TrackState.downloaded);

    await tracks.demoteToStream(id, key);
    await index.remove(key);
    c.invalidate(downloadIndexProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(await state(key), TrackState.savedStream);
  });

  test('a row key follows the row: stream, file', () async {
    final id = (await tracks.saveStream(_r))!;
    final k = '#$id';
    c.listen(trackStateProvider(k), (_, _) {});
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(trackStateProvider(k)), TrackState.savedStream);
    await tracks.promoteStreamRow(key, file.path, 1, file);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(trackStateProvider(k)), TrackState.downloaded);
  });

  test('the playing entry points at the library row once it is downloaded', () async {
    final online = OnlineEntries();
    final entry = online.register(_r);
    final shadowId = (await tracks.ensureStreamRow(_r));
    online.bindRow(entry, shadowId);
    final player = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      trackRepositoryProvider.overrideWithValue(tracks),
      onlineEntriesProvider.overrideWithValue(online),
      currentTrackProvider.overrideWith((ref) => Stream.value(online.trackOf(entry))),
    ]);
    addTearDown(player.dispose);
    player.listen(liveCurrentTrackProvider, (_, _) {});
    Future<Track?> live() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return player.read(liveCurrentTrackProvider).value;
    }

    expect((await live())!.id, entry); // still a stream: the entry's own id

    await tracks.promoteStreamRow(key, file.path, 1, file);
    final t = (await live())!;
    expect(t.id, shadowId);
    expect(t.kind, 0);
  });
}

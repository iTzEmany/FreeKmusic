import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_add_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:codecore/providers/pending_playlist_adds.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

const _song = YtResult(id: 'v1', title: 'T', channel: 'C', duration: null);

DownloadItem _item(DownloadStatus status, {String? tag, String? path}) =>
    DownloadItem(id: 1, result: _song, status: status, tag: tag, path: path);

void main() {
  late StreamController<DownloadItem> settled;
  late List<String> added;
  late List<String> replaced;

  setUp(() {
    settled = StreamController<DownloadItem>.broadcast(sync: true);
    added = [];
    replaced = [];
    PendingPlaylistAdds(
      settled: settled.stream,
      trackIdForPath: (path) async => path == '/m/a.m4a' ? 42 : null,
      addTracks: (pl, ids) async => added.add('$pl:$ids'),
      replaceStream: (r, id) => replaced.add('${r.id}:$id'),
    );
  });

  test('a download that finished joins the playlist in its tag', () async {
    settled.add(_item(DownloadStatus.done, tag: addToPlaylistTag(7), path: '/m/a.m4a'));
    await pumpEventQueue();
    expect(added, ['7:[42]']);
  });

  test('a failed download adds nothing', () async {
    settled.add(_item(DownloadStatus.failed, tag: addToPlaylistTag(7)));
    await pumpEventQueue();
    expect(added, isEmpty);
  });

  test('another tag, or none, adds nothing', () async {
    settled.add(_item(DownloadStatus.done, tag: 'import:1:2', path: '/m/a.m4a'));
    settled.add(_item(DownloadStatus.done, path: '/m/a.m4a'));
    await pumpEventQueue();
    expect(added, isEmpty);
  });

  test('any finished download swaps the stream entries of that song for the library track', () async {
    settled.add(_item(DownloadStatus.done, path: '/m/a.m4a'));
    await pumpEventQueue();
    expect(replaced, ['v1:42']);
    expect(added, isEmpty);
    settled.add(_item(DownloadStatus.done, tag: addToPlaylistTag(7), path: '/m/a.m4a'));
    await pumpEventQueue();
    expect(replaced, ['v1:42', 'v1:42']);
    expect(added, ['7:[42]']);
  });

  test('a failed download replaces nothing', () async {
    settled.add(_item(DownloadStatus.failed, path: '/m/a.m4a'));
    await pumpEventQueue();
    expect(replaced, isEmpty);
  });

  group('libraryAdder', () {
    late AppDatabase db;
    late SettingsStore store;
    late _Queue queue;
    late Directory dir;
    late DownloadIndex index;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = SettingsStore(await SharedPreferences.getInstance());
      db = AppDatabase(NativeDatabase.memory());
      queue = _Queue();
      dir = await Directory.systemTemp.createTemp('adder');
      index = DownloadIndex(File('${dir.path}/i.json'));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
    });

    Future<ProviderContainer> container(
      StorageMode mode, {
      TrackRepository Function(AppDatabase)? repo,
      PlaylistRepository Function(AppDatabase)? playlists,
    }) async {
      await store.writeSettings(store.readSettings().copyWith(storageMode: mode));
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        if (repo != null) trackRepositoryProvider.overrideWithValue(repo(db)),
        if (playlists != null) playlistRepositoryProvider.overrideWithValue(playlists(db)),
        settingsStoreProvider.overrideWithValue(store),
        downloadsProvider.overrideWith(() => queue),
        downloadIndexProvider.overrideWith((ref) async => index),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    Future<List<Track>> savedRows() async =>
        (await db.select(db.tracks).get()).where((t) => t.kind == 2 && t.saved).toList();

    test('streaming mode saves a row, starts no job and joins the playlist of an addto: tag at once', () async {
      final c = await container(StorageMode.stream);
      final pid = await c.read(playlistRepositoryProvider).create('P');
      expect(await c.read(libraryAdderProvider).add(_song, tag: addToPlaylistTag(pid)), isTrue);
      expect(queue.added, isEmpty);
      final rows = await savedRows();
      expect(rows, hasLength(1));
      expect((await c.read(playlistRepositoryProvider).watchTracks(pid).first).map((t) => t.id), [rows.single.id]);
    });

    test('device mode goes to the download queue and saves no row', () async {
      final c = await container(StorageMode.device);
      await c.read(libraryAdderProvider).add(_song, tag: addToPlaylistTag(1));
      expect(queue.added, ['v1:addto:1']);
      expect(await savedRows(), isEmpty);
    });

    test('a song already downloaded makes no second row in streaming mode', () async {
      final file = File('${dir.path}/a.m4a')..writeAsStringSync('x');
      await index.add('v1', file.path);
      final c = await container(StorageMode.stream);
      await c.read(libraryAdderProvider).add(_song);
      expect(await savedRows(), isEmpty);
      expect(await c.read(libraryAdderProvider).saveNow(_song), isNull);
    });

    test('a saved song counts as «in libreria» and a second add changes nothing', () async {
      final c = await container(StorageMode.stream);
      final sub = c.listen(savedStreamKeysProvider, (_, _) {});
      addTearDown(sub.close);
      expect(c.read(inLibraryOfProvider)('v1', MediaSource.youtube), isFalse);
      expect(await c.read(libraryAdderProvider).add(_song), isTrue);
      await c.read(savedStreamKeysProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(inLibraryOfProvider)('v1', MediaSource.youtube), isTrue);
      expect(await c.read(libraryAdderProvider).add(_song), isTrue);
      expect(await savedRows(), hasLength(1));
      expect(queue.added, isEmpty);
    });

    test('a failed save is reported (null), never turned into a download', () async {
      final c = await container(StorageMode.stream, repo: (db) => _FailingTracks(db));
      expect(await c.read(libraryAdderProvider).add(_song), isNull);
      expect(queue.added, isEmpty);
    });

    test('a failed put in the playlist is reported (null)', () async {
      final c = await container(StorageMode.stream, playlists: (db) => _FailingPlaylists(db));
      expect(await c.read(libraryAdderProvider).add(_song, tag: addToPlaylistTag(1)), isNull);
      expect(queue.added, isEmpty);
    });
  });
}

class _FailingTracks extends TrackRepository {
  _FailingTracks(super.db);
  @override
  Future<int?> saveStream(YtResult r) => throw StateError('disk full');
}

class _FailingPlaylists extends PlaylistRepository {
  _FailingPlaylists(super.db);
  @override
  Future<int> addStreamTracks(int playlistId, List<int> ids) => throw StateError('locked');
}

class _Queue extends DownloadsNotifier {
  final added = <String>[];
  @override
  List<DownloadItem> build() => const [];
  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    added.add('${r.id}:${tag ?? ''}'.replaceAll(RegExp(r':$'), ''));
    return false;
  }
}

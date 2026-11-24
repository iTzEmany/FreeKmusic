import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/scanner/library_scanner.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';

const _r = YtResult(id: 'abcdefghijk', title: 'Song', channel: 'Chan', duration: Duration(seconds: 200));

class _Yt implements YoutubeService {
  @override
  Stream<DownloadProgress> download(YtResult r, Directory dir,
      {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) async* {
    final f = File('${dir.path}/Song.m4a')..writeAsStringSync('audio');
    yield DownloadProgress(received: 1, total: 1, path: f.path);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// «Scans» the file: the library row of the new file appears.
class _Scanner implements LibraryScanner {
  _Scanner(this.db);
  final AppDatabase db;
  @override
  Stream<ScanProgress> scanFiles(Folder folder, List<String> paths) async* {
    for (final p in paths) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: p, title: 'Song', albumKey: 'k', format: 'm4a', sizeBytes: 5, mtimeMs: 1, addedAt: 1));
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Settings extends SettingsNotifier {
  _Settings(this.dir);
  final String dir;
  @override
  AppSettings build() => AppSettings(downloadLocation: dir);
}

void main() {
  test('a finished download without a shadow row still keeps its video id on the file row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('dl_merge');
    addTearDown(() => dir.delete(recursive: true));
    final tracks = TrackRepository(db);
    final handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), tracks, onError: (_) {});
    addTearDown(handler.dispose);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
      trackRepositoryProvider.overrideWithValue(tracks),
      audioHandlerProvider.overrideWithValue(handler),
      onlineEntriesProvider.overrideWithValue(OnlineEntries()),
      youtubeServiceProvider.overrideWithValue(_Yt()),
      settingsProvider.overrideWith(() => _Settings(dir.path)),
      libraryScannerProvider.overrideWithValue(_Scanner(db)),
      downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File('${dir.path}/downloads.json'))),
    ]);
    addTearDown(c.dispose);

    c.read(downloadsProvider.notifier).add(_r, tag: 'x');
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect((await db.select(db.tracks).getSingle()).videoId, _r.id);
  });

  test('a finished download swaps the queue id of the shadow row and points the online entry at the file row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('dl_merge');
    addTearDown(() => dir.delete(recursive: true));
    final tracks = TrackRepository(db);
    final handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), tracks, onError: (_) {});
    addTearDown(handler.dispose);
    final shadow = (await tracks.saveStream(_r))!;
    final playing = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/m/z.mp3', title: 'Z', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    await handler.playQueue([playing, shadow], 0); // the playing entry is never swapped
    final online = OnlineEntries();
    final entry = online.register(_r);
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
      trackRepositoryProvider.overrideWithValue(tracks),
      audioHandlerProvider.overrideWithValue(handler),
      onlineEntriesProvider.overrideWithValue(online),
      youtubeServiceProvider.overrideWithValue(_Yt()),
      settingsProvider.overrideWith(() => _Settings(dir.path)),
      libraryScannerProvider.overrideWithValue(_Scanner(db)),
      downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File('${dir.path}/downloads.json'))),
    ]);
    addTearDown(c.dispose);

    c.read(downloadsProvider.notifier).add(_r, tag: 'x'); // a tag: no enrichment afterwards
    await Future<void>.delayed(const Duration(milliseconds: 400));

    final file = (await db.select(db.tracks).get()).singleWhere((t) => t.path.endsWith('Song.m4a'));
    expect(handler.queueIds, [playing, file.id]);
    expect(online.entryOf(entry)!.trackId, file.id);
    expect(file.videoId, _r.id, reason: 'the id of the download stays on the file row (D-713)');
  });
}

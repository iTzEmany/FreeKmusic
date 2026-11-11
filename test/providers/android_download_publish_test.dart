import 'dart:io';

import 'package:codecore/core/platform.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/scanner/library_scanner.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/media_publisher.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _r = YtResult(id: 'abc', title: 'Song', channel: 'Chan', duration: Duration(seconds: 200));
const _final = '/storage/emulated/0/Music/FreeKmusic/Song.m4a';

class _Yt implements YoutubeService {
  _Yt(this.file);
  final String file;
  Directory? outDir;
  @override
  Stream<DownloadProgress> download(YtResult r, Directory dir,
      {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) async* {
    outDir = dir;
    File(file).writeAsStringSync('audio');
    yield DownloadProgress(received: 1, total: 1, path: file);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Scanner implements LibraryScanner {
  final scanned = <String>[];
  @override
  Stream<ScanProgress> scanFiles(Folder folder, List<String> paths) async* {
    scanned.addAll(paths);
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android: the download is made in the work folder, published, and the final path is registered', () async {
    debugIsAndroidOverride = true;
    addTearDown(() => debugIsAndroidOverride = null);
    final root = await Directory.systemTemp.createTemp('android_pub');
    addTearDown(() => root.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (c) async => root.path);
    final published = <String>[];
    const channel = MethodChannel('codecore/publish');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
      published.add((c.arguments as Map)['path'] as String);
      return _final;
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final index = DownloadIndex(File('${root.path}/downloads.json'));
    final yt = _Yt('${root.path}/download-work/Song.m4a');
    final scanner = _Scanner();
    final c = ProviderContainer(overrides: [
      folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      youtubeServiceProvider.overrideWithValue(yt),
      settingsProvider.overrideWith(_Settings.new),
      libraryScannerProvider.overrideWithValue(scanner),
      downloadIndexProvider.overrideWith((ref) async => index),
      mediaPublisherProvider.overrideWithValue(MediaPublisher(channel: channel)),
    ]);
    addTearDown(c.dispose);

    c.read(downloadsProvider.notifier).add(_r, tag: 'x');
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(yt.outDir!.path, '${root.path}/download-work');
    expect(published, ['${root.path}/download-work/Song.m4a']);
    expect(File(published.single).existsSync(), isFalse); // work copy deleted
    expect(scanner.scanned, [_final]);
    expect(index.idForPath(_final), _r.id);
    expect(c.read(downloadsProvider).single.path, _final);
    expect([for (final f in await FolderRepository(db).getAll()) f.path], ['/storage/emulated/0/Music/FreeKmusic']);
  });
}

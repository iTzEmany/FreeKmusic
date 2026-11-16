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
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/core/storage_volumes.dart';
import 'package:codecore/services/online/media_publisher.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/native.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

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
    debugAndroidSdk = 33;
    addTearDown(() {
      debugIsAndroidOverride = null;
      debugAndroidSdk = null;
    });
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
    final yt = _Yt(p.join(root.path, 'download-work', 'Song.m4a'));
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

    expect(yt.outDir!.path, p.join(root.path, 'download-work'));
    expect(published, [p.join(root.path, 'download-work', 'Song.m4a')]);
    expect(File(published.single).existsSync(), isFalse); // work copy deleted
    expect(scanner.scanned, [_final]);
    expect(index.idForPath(_final), _r.id);
    expect(c.read(downloadsProvider).single.path, _final);
    expect([for (final f in await FolderRepository(db).getAll()) f.path], ['/storage/emulated/0/Music'], reason: 'FreeKmusic is scanned from Music, not its own folder');
  });

  test('Android: a refused publish leaves no copy in download-work and the item is internal', () async {
    debugIsAndroidOverride = true;
    debugAndroidSdk = 33;
    addTearDown(() {
      debugIsAndroidOverride = null;
      debugAndroidSdk = null;
    });
    final root = await Directory.systemTemp.createTemp('android_pub_fail');
    addTearDown(() => root.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (c) async => root.path);
    const channel = MethodChannel('codecore/publish');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async => throw PlatformException(code: 'publish'));
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final c = ProviderContainer(overrides: [
      folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      youtubeServiceProvider.overrideWithValue(_Yt(p.join(root.path, 'download-work', 'Song.m4a'))),
      settingsProvider.overrideWith(_Settings.new),
      libraryScannerProvider.overrideWithValue(_Scanner()),
      downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File('${root.path}/downloads.json'))),
      mediaPublisherProvider.overrideWithValue(MediaPublisher(channel: channel)),
    ]);
    addTearDown(c.dispose);
    c.read(downloadsProvider.notifier).add(_r, tag: 'x');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(File('${root.path}/download-work/Song.m4a').existsSync(), isFalse);
    expect(c.read(downloadsProvider).single.error, YtErrorKind.internal);
  });

  test('Android 11+: FreeKmusic inside a library folder is not registered on its own', () async {
    debugIsAndroidOverride = true;
    debugAndroidSdk = 33;
    addTearDown(() {
      debugIsAndroidOverride = null;
      debugAndroidSdk = null;
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FolderRepository(db);
    final music = await repo.add('/storage/emulated/0/Music');
    final res = await resolveDownloadFolder(repo, location: '');
    expect(res!.$1.path, '/storage/emulated/0/Music/FreeKmusic');
    expect(res.$2.id, music.id);
    expect((await repo.getAll()).length, 1);
  });

  test('Android 11+: a library folder equal to FreeKmusic is reused, the parent is not added', () async {
    debugIsAndroidOverride = true;
    debugAndroidSdk = 33;
    addTearDown(() {
      debugIsAndroidOverride = null;
      debugAndroidSdk = null;
    });
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = FolderRepository(db);
    await repo.add('/storage/emulated/0/Music/FreeKmusic');
    final res = await resolveDownloadFolder(repo, location: '');
    expect([for (final f in await repo.getAll()) f.path], ['/storage/emulated/0/Music/FreeKmusic']);
    expect(res!.$2.path, '/storage/emulated/0/Music/FreeKmusic');
  });

  group('SD card / chosen folder (D-579)', () {
    const sd = '/storage/1234-5678/Android/data/com.codecore.player/files';
    setUp(() => debugSdDirs = [sd]);
    tearDown(() {
      debugIsAndroidOverride = null;
      debugAndroidSdk = null;
      debugSdDirs = null;
    });

    test('card removed: effectiveLocation is internal, 11+ registers no ghost folder', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 33;
      debugSdDirs = [];
      expect(await effectiveLocation(sd), '');
      expect(sdRootOf('/storage/emulated/0/Music'), isNull);
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FolderRepository(db);
      final res = await resolveDownloadFolder(repo, location: sd);
      expect(res!.$1.path, isNot(contains('1234-5678')));
      expect([for (final f in await repo.getAll()) f.path], isNot(contains('/storage/1234-5678/Music')));
    });

    test('card removed: publish goes to the primary volume', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 33;
      debugSdDirs = [];
      const channel = MethodChannel('codecore/publish');
      Map<Object?, Object?>? args;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
        args = c.arguments as Map;
        return '/x/S.m4a';
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      final tmp = await Directory.systemTemp.createTemp('pubgone');
      addTearDown(() => tmp.delete(recursive: true));
      final f = File(p.join(tmp.path, 'S.m4a'))..writeAsStringSync('x');
      await MediaPublisher(channel: channel, volume: () => effectiveLocation(sd)).publish(f.path);
      expect(args!.containsKey('volume'), isFalse);
    });

    test('tags on the SD: replace carries the volume and the guard admits the SD Music', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 33;
      const channel = MethodChannel('codecore/publish');
      Map<Object?, Object?>? args;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
        args = c.arguments as Map;
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      await installTagged('/tmp/src.m4a', '/storage/ABCD-1234/Music/FreeKmusic/S.m4a', publisher: MediaPublisher(channel: channel));
      expect(args!['volume'], 'abcd-1234');
    });

    test('StreamCache.deleteAt removes only the stream_cache folder of the volume', () async {
      final tmp = await Directory.systemTemp.createTemp('sdcache');
      addTearDown(() => tmp.delete(recursive: true));
      Directory(p.join(tmp.path, 'stream_cache')).createSync();
      File(p.join(tmp.path, 'keep.txt')).writeAsStringSync('x');
      await StreamCache.deleteAt(tmp.path);
      expect(Directory(p.join(tmp.path, 'stream_cache')).existsSync(), isFalse);
      expect(File(p.join(tmp.path, 'keep.txt')).existsSync(), isTrue);
    });

    test('dropLeftBehind deletes the old volume cache, never the one in use or nothing recorded', () async {
      final a = await Directory.systemTemp.createTemp('cacheA');
      final b = await Directory.systemTemp.createTemp('cacheB');
      addTearDown(() => Future.wait([a.delete(recursive: true), b.delete(recursive: true)]));
      for (final d in [a, b]) {
        Directory(p.join(d.path, 'stream_cache')).createSync();
      }
      await StreamCache.dropLeftBehind(last: null, current: b.path);
      await StreamCache.dropLeftBehind(last: b.path, current: b.path);
      expect(Directory(p.join(a.path, 'stream_cache')).existsSync() && Directory(p.join(b.path, 'stream_cache')).existsSync(), isTrue);
      await StreamCache.dropLeftBehind(last: a.path, current: b.path);
      expect(Directory(p.join(a.path, 'stream_cache')).existsSync(), isFalse);
      expect(Directory(p.join(b.path, 'stream_cache')).existsSync(), isTrue);
    });

    test('libraryFolderFor reuses a containing library folder', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FolderRepository(db);
      final parent = await repo.add('/data/Music');
      expect((await libraryFolderFor(repo, '/data/Music/Sub', '/data/Music/Sub')).id, parent.id);
      expect((await repo.getAll()).length, 1);
    });

    test('Android 10: the app folder on the SD, as its own library folder', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 29;
      final tmp = await Directory.systemTemp.createTemp('sd10');
      addTearDown(() => tmp.delete(recursive: true));
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final res = await resolveDownloadFolder(FolderRepository(db), location: p.join(tmp.path, 'files'));
      expect(res!.$1.path, p.join(tmp.path, 'files', 'Music'));
      expect(res.$2.path, res.$1.path);
    });

    test('Android 11+: Music/FreeKmusic on the volume, the volume Music is the library folder', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 33;
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final res = await resolveDownloadFolder(FolderRepository(db), location: sd);
      expect(res!.$1.path, '/storage/1234-5678/Music/FreeKmusic');
      expect(res.$2.path, '/storage/1234-5678/Music');
    });

    test('Android 11+: publish names the volume (lower case) for MediaStore', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 33;
      const channel = MethodChannel('codecore/publish');
      Map<Object?, Object?>? args;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
        args = c.arguments as Map;
        return '/storage/ABCD-1234/Music/FreeKmusic/S.m4a';
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      final tmp = await Directory.systemTemp.createTemp('pubvol');
      addTearDown(() => tmp.delete(recursive: true));
      final f = File(p.join(tmp.path, 'S.m4a'))..writeAsStringSync('x');
      await MediaPublisher(channel: channel, volume: () async => '/storage/ABCD-1234/Android/data/x/files').publish(f.path);
      expect(args!['volume'], 'abcd-1234');
    });

    test('desktop: the chosen folder, registered as a library folder', () async {
      debugIsAndroidOverride = false;
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = FolderRepository(db);
      final res = await resolveDownloadFolder(repo, location: '/data/Songs');
      expect(res!.$1.path, '/data/Songs');
      expect([for (final f in await repo.getAll()) f.path], ['/data/Songs']);
    });
  });
}

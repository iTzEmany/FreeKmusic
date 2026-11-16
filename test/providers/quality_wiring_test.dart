import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/scanner/library_scanner.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _r = YtResult(id: 'abc', title: 'Song', channel: 'Chan', duration: Duration(seconds: 200));

class _Yt implements YoutubeService {
  DownloadOptions? seen;
  @override
  Stream<DownloadProgress> download(YtResult r, Directory dir,
      {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) async* {
    seen = options;
    throw const YtException(YtErrorKind.internal, 'stop');
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings(downloadQuality: AudioQuality.low, streamQuality: AudioQuality.medium);
}

class _Scanner implements LibraryScanner {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('«Qualità download» reaches the DownloadOptions of a download', () async {
    final root = await Directory.systemTemp.createTemp('quality');
    addTearDown(() => root.delete(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'), (c) async => root.path);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final yt = _Yt();
    final c = ProviderContainer(overrides: [
      folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      youtubeServiceProvider.overrideWithValue(yt),
      settingsProvider.overrideWith(_Settings.new),
      libraryScannerProvider.overrideWithValue(_Scanner()),
      downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File('${root.path}/downloads.json'))),
    ]);
    addTearDown(c.dispose);
    c.read(downloadsProvider.notifier).add(_r, tag: 'x');
    for (var i = 0; i < 100 && yt.seen == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(yt.seen?.quality, AudioQuality.low);
  });
}

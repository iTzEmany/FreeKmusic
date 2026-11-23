import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/free_space_providers.dart';
import 'package:codecore/providers/library_providers.dart' show coversDirProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:codecore/providers/vanished_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Handler implements CodecoreAudioHandler {
  final merged = <(int, int)>[];
  @override
  bool replaceQueueId(int oldId, int newId) {
    merged.add((oldId, newId));
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => i.isGetter ? const Stream<Never>.empty() : null; // streams the providers listen to
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

void main() {
  late _Handler handler;
  late ProviderContainer c;

  setUp(() async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final dir = await Directory.systemTemp.createTemp('shadow_wiring');
    addTearDown(() => dir.delete(recursive: true));
    handler = _Handler();
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      playlistRepositoryProvider.overrideWithValue(PlaylistRepository(db)),
      settingsProvider.overrideWith(_Settings.new),
      audioHandlerProvider.overrideWithValue(handler),
      coversDirProvider.overrideWithValue(dir),
      streamCacheProvider.overrideWithValue(StreamCache(Directory('${dir.path}/c'), freeSpace: () async => null)),
      downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File('${dir.path}/d.json'))),
    ]);
    addTearDown(c.dispose);
  });

  test('«Libera spazio» tells the queue about a merged shadow row', () async {
    (await c.read(freeSpaceServiceProvider.future)).onShadowMerged!(-1, 5);
    expect(handler.merged, [(-1, 5)]);
  });

  test('the vanished-streams replacement tells the queue about a merged shadow row', () {
    c.read(vanishedTracksProvider).onShadowMerged!(-2, 6);
    expect(handler.merged, [(-2, 6)]);
  });

  test('«Scarica» of a cached track tells the queue about a merged shadow row', () {
    c.read(streamPromoterProvider).onShadowMerged!(-3, 7);
    expect(handler.merged, [(-3, 7)]);
  });
}

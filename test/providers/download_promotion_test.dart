import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/activity_log_providers.dart';
import 'package:codecore/providers/pending_playlist_adds.dart';
import 'package:codecore/providers/activity_providers.dart' show ActivityKind;
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/stream/stream_promoter.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _r = YtResult(id: 'abc', title: 'Song', channel: 'Chan', duration: Duration(seconds: 200));

class _Yt implements YoutubeService {
  @override
  dynamic noSuchMethod(Invocation i) =>
      i.memberName == #download ? Completer<String>().future : throw UnimplementedError(); // never ends
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _Promoter implements StreamPromoter {
  int calls = 0;
  bool result = true;
  Completer<bool>? gate; // holds the promotion until the test releases it
  Object? error;
  @override
  Future<bool> promote(YtResult r) async {
    calls++;
    if (error != null) throw error!;
    return gate != null ? gate!.future : result;
  }
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late DownloadIndex index;
  late Directory dir;
  late _Promoter promoter;
  late ProviderContainer c;
  var builds = 0;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    dir = await Directory.systemTemp.createTemp('dl_promo');
    addTearDown(() => dir.delete(recursive: true));
    index = DownloadIndex(File('${dir.path}/downloads.json'));
    builds = 0;
    promoter = _Promoter();
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      playlistRepositoryProvider.overrideWithValue(PlaylistRepository(db)),
      youtubeServiceProvider.overrideWithValue(_Yt()),
      settingsProvider.overrideWith(_Settings.new),
      streamPromoterProvider.overrideWithValue(promoter),
      downloadIndexProvider.overrideWith((ref) async {
        builds++;
        return index;
      }),
    ]);
    addTearDown(c.dispose);
    c.listen(downloadIndexProvider, (_, _) {}); // what a row watching it does
    await c.read(downloadIndexProvider.future);
  });

  test('a promotion refreshes the download index the rows watch', () async {
    expect(builds, 1);
    expect(await c.read(downloadsProvider.notifier).add(_r), isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(promoter.calls, 1);
    expect(builds, 2);
  });

  test('a promoted download leaves its «Brano scaricato» line in the Registro', () async {
    c.listen(activityLogProvider, (_, _) {});
    await c.read(downloadsProvider.notifier).add(_r);
    await pumpEventQueue();
    final e = c.read(activityLogProvider).entries.single;
    expect(e.item!.kind, ActivityKind.download);
    expect(e.item!.name, 'Song');
    expect(e.failed, isFalse);
  });

  test('«Scarica» on a video already in the index starts nothing', () async {
    final file = File('${dir.path}/song.m4a')..writeAsStringSync('x');
    await index.add(_r.id, file.path);
    c.read(downloadsProvider.notifier).add(_r);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(promoter.calls, 0);
    expect(c.read(downloadsProvider), isEmpty);
  });

  test('«Aggiungi a playlist» on a video already in the index joins the playlist, no download', () async {
    final file = File('${dir.path}/song.m4a')..writeAsStringSync('x');
    await index.add(_r.id, file.path);
    final trackId = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: file.path, title: 'Song', albumKey: 'k', format: 'm4a', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    final playlistId = await PlaylistRepository(db).create('P');
    final second = await PlaylistRepository(db).create('Q');
    c.read(downloadsProvider.notifier).add(_r, tag: addToPlaylistTag([playlistId, second]));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(promoter.calls, 0);
    expect(c.read(downloadsProvider), isEmpty);
    expect(await PlaylistRepository(db).containing([trackId]), {playlistId, second});
  });

  group('double tap with different playlists', () {
    Future<(int, int, int)> setup() async {
      final file = File('${dir.path}/song.m4a')..writeAsStringSync('x');
      final trackId = await db.into(db.tracks).insert(TracksCompanion.insert(
          path: file.path, title: 'Song', albumKey: 'k', format: 'm4a', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      final repo = PlaylistRepository(db);
      return (trackId, await repo.create('P'), await repo.create('Q'));
    }

    test('while it is promoting: both playlists get the song', () async {
      final (trackId, p, q) = await setup();
      promoter.gate = Completer<bool>();
      final n = c.read(downloadsProvider.notifier);
      final first = n.add(_r, tag: addToPlaylistTag([p]));
      final second = n.add(_r, tag: addToPlaylistTag([q]));
      await pumpEventQueue();
      await index.add(_r.id, '${dir.path}/song.m4a'); // what the promotion leaves behind
      promoter.gate!.complete(true);
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(await PlaylistRepository(db).containing([trackId]), {p, q});
      expect(promoter.calls, 1);
    });

    test('while it is promoting and a download is queued instead: one job with both playlists', () async {
      final (_, p, q) = await setup();
      promoter.gate = Completer<bool>();
      final n = c.read(downloadsProvider.notifier);
      final first = n.add(_r, tag: addToPlaylistTag([p]));
      final second = n.add(_r, tag: addToPlaylistTag([q]));
      await pumpEventQueue();
      promoter.gate!.complete(false);
      await Future.wait([first, second]);
      final items = c.read(downloadsProvider);
      expect(items, hasLength(1));
      expect(parseAddToPlaylistTag(items.single.tag), [p, q]);
    });

    test('after a download was queued: still one job with both playlists', () async {
      final (_, p, q) = await setup();
      promoter.result = false;
      final n = c.read(downloadsProvider.notifier);
      await n.add(_r, tag: addToPlaylistTag([p]));
      await n.add(_r, tag: addToPlaylistTag([q, p]));
      final items = c.read(downloadsProvider);
      expect(items, hasLength(1));
      expect(parseAddToPlaylistTag(items.single.tag), [p, q]);
    });
  });

  test('add returns false for a video already in the library', () async {
    final file = File('${dir.path}/song.m4a')..writeAsStringSync('x');
    await index.add(_r.id, file.path);
    expect(await c.read(downloadsProvider.notifier).add(_r), isFalse);
  });

  test('add returns false and queues a download when the cache has nothing', () async {
    promoter.result = false;
    expect(await c.read(downloadsProvider.notifier).add(_r), isFalse);
    expect(c.read(downloadsProvider), isNotEmpty);
  });

  test('the same song added twice while it is queued or downloading makes one job', () async {
    promoter.result = false;
    final n = c.read(downloadsProvider.notifier);
    await n.add(_r);
    await n.add(_r);
    expect(c.read(downloadsProvider), hasLength(1));
  });

  test('a failed promotion falls back to the queue', () async {
    promoter.error = StateError('boom');
    expect(await c.read(downloadsProvider.notifier).add(_r), isFalse);
    expect(c.read(downloadsProvider), isNotEmpty);
  });

  test('no space: nothing is queued and the error says so', () async {
    promoter.error = const StreamPromoteException('full', noSpace: true);
    final errors = <bool>[];
    c.read(downloadsProvider.notifier).promoteErrors.listen(errors.add);
    expect(await c.read(downloadsProvider.notifier).add(_r), isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(downloadsProvider), isEmpty);
    expect(errors, [true]);
  });
}

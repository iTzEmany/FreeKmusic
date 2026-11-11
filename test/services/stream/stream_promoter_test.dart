import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/folder_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/providers/pending_playlist_adds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:codecore/services/scanner/library_scanner.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:codecore/services/stream/stream_promoter.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

const _r = YtResult(
  id: 'abc',
  title: 'Song',
  channel: 'Chan',
  duration: Duration(seconds: 200),
  artists: ['Artist'],
  album: 'Album',
);
const _key = 'youtube:abc';

class _Yt implements YoutubeService {
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _DownloadingYt extends _Yt {
  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
          {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) =>
      Stream.value(DownloadProgress(received: 1, total: 1, path: p.join(outDir.path, 'dl.m4a')));
}

class _Scanner implements LibraryScanner {
  _Scanner(this.db);
  final AppDatabase db;
  @override
  Stream<ScanProgress> scanFiles(Folder folder, List<String> paths) async* {
    for (final path in paths) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: path, title: 'Song', albumKey: 'k', format: 'm4a', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    }
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _MergeSpy extends TrackRepository {
  _MergeSpy(super.db);
  final merged = <String>[];
  @override
  Future<int?> mergeStreamRow(String key, int keepId) async {
    merged.add(key);
    return null;
  }
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _FakePromoter implements StreamPromoter {
  _FakePromoter(this.calls, [this.gate, this.error]);
  final List<String> calls;
  final Completer<void>? gate;
  final Object? error;
  @override
  Future<bool> promote(YtResult r) async {
    calls.add(r.indexKey);
    await gate?.future;
    if (error != null) throw error!;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

Future<ProviderContainer> _notifierWith(StreamPromoter promoter,
    {List<Override> extra = const [], YoutubeService? yt}) async {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final dir = await Directory.systemTemp.createTemp('dl');
  addTearDown(() => dir.delete(recursive: true));
  await FolderRepository(db).add(dir.path);
  final c = ProviderContainer(overrides: [
    folderRepositoryProvider.overrideWithValue(FolderRepository(db)),
    youtubeServiceProvider.overrideWithValue(yt ?? _Yt()),
    settingsProvider.overrideWith(_Settings.new),
    streamPromoterProvider.overrideWithValue(promoter),
    ...extra,
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  late Directory root;
  late AppDatabase db;
  late TrackRepository tracks;
  late StreamCache cache;
  late CoverStore covers;
  late DownloadIndex index;
  late Folder folder;
  late StreamPromoter promoter;
  late int shadowId;
  final tagged = <int>[];
  final scanned = <String>[];
  var scanSkipped = false;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('promoter');
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    cache = StreamCache(Directory(p.join(root.path, 'cache')), freeSpace: () async => null);
    await cache.open();
    covers = CoverStore(Directory(p.join(root.path, 'covers')));
    index = DownloadIndex(File(p.join(root.path, 'downloads.json')));
    final music = Directory(p.join(root.path, 'Music'))..createSync();
    folder = await FolderRepository(db).add(music.path);
    tagged.clear();
    scanned.clear();
    promoter = StreamPromoter(
      cache: cache,
      tracks: tracks,
      covers: covers,
      downloadFolder: () async => (music, folder),
      index: () async => index,
      scan: (f, path) async {
        scanned.add(path);
        // The scanner skips a path whose size and mtime the row already has (K-02).
        final known = (await tracks.fileIndexForFolder(f.id))[path];
        final st = File(path).statSync();
        scanSkipped = known != null &&
            known.size == st.size &&
            known.mtime == st.modified.millisecondsSinceEpoch;
      },
      tag: (id) async => tagged.add(id),
    );
    final part = File(p.join(cache.dir.path, 'youtube_abc.m4a.part'))..writeAsBytesSync([1, 2, 3, 4]);
    final cached = await cache.put(_key, part);
    shadowId = await tracks.upsertStreamRow(_key, _r, cached);
    await (db.update(db.tracks)..where((t) => t.id.equals(shadowId))).write(const TracksCompanion(
      lyricsPlain: Value('la la'),
      curiosities: Value('fact'),
      playCount: Value(3),
    ));
    await db.into(db.plays).insert(PlaysCompanion.insert(trackId: shadowId, playedAt: 10));
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test('promote moves the cached file and keeps the row, its plays and its text', () async {
    expect(await promoter.promote(_r), isTrue);

    final dest = p.join(root.path, 'Music', '${downloadBaseName(_r)}.m4a');
    expect(File(dest).existsSync(), isTrue);
    expect(await cache.fileFor(_key), isNull);
    final row = (await tracks.getById(shadowId))!;
    expect((row.kind, row.path, row.folderId), (0, dest, folder.id));
    expect((row.lyricsPlain, row.curiosities, row.playCount), ('la la', 'fact', 3));
    expect(row.albumKey, 'artist|album');
    expect(await db.select(db.plays).get(), hasLength(1));
    expect(index.pathFor(_key), dest);
    expect(tagged, [shadowId]);
    expect(scanned, [dest]);
    expect(scanSkipped, isTrue, reason: 'no second row after the scan');
    expect(await db.select(db.tracks).get(), hasLength(1));
  });

  test('the cover of the shadow row follows the new album key', () async {
    final key = await covers.saveFromBytes('stream|$_key', [9, 9], 'image/jpeg');
    await tracks.setCoverForAlbum('stream|$_key', true, key);
    await promoter.promote(_r);

    final row = (await tracks.getById(shadowId))!;
    expect(row.coverKey, CoverStore.coverKeyFor('artist|album'));
    expect(covers.fileFor(row.coverKey!)!.readAsBytesSync(), [9, 9]);
  });

  test('a hand-picked cover of the shadow row stays as it is after the promotion', () async {
    final mine = (await covers.saveFromBytes('manual:track:$shadowId:1', [4, 4], 'image/jpeg'))!;
    await tracks.setManualCover(shadowId, mine);
    await promoter.promote(_r);
    final row = (await tracks.getById(shadowId))!;
    expect([row.coverKey, row.coverSource], [mine, 2]);
    expect(covers.fileFor(CoverStore.coverKeyFor('artist|album')), isNull);
  });

  test('promote with no file in the cache does nothing', () async {
    await File((await cache.fileFor(_key))!.path).delete();
    cache = StreamCache(cache.dir, freeSpace: () async => null);
    promoter = StreamPromoter(
        cache: cache,
        tracks: tracks,
        covers: covers,
        downloadFolder: () async => fail('not asked'),
        index: () async => index,
        scan: (_, _) async {},
        tag: (_) async {});
    expect(await promoter.promote(_r), isFalse);
    expect((await tracks.getById(shadowId))!.kind, 2);
  });

  test('mergeStreamRow moves plays and text to the downloaded row and drops the shadow', () async {
    final newId = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/m/new.m4a', title: 'Song', albumKey: 'artist|album', format: 'm4a', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    await tracks.mergeStreamRow(_key, newId);

    final row = (await tracks.getById(newId))!;
    expect((row.playCount, row.lyricsPlain, row.curiosities), (3, 'la la', 'fact'));
    expect((await db.select(db.plays).get()).single.trackId, newId);
    expect(await tracks.getById(shadowId), isNull);
  });

  test('mergeStreamRow keeps the credits and the details of the shadow row', () async {
    for (final n in ['a', 'b', 'c']) {
      await db.into(db.trackCredits).insert(TrackCreditsCompanion.insert(
          trackId: shadowId, name: n, nameKey: n, role: 'producer', source: 'deezer'));
    }
    await db.into(db.trackEnrich).insert(
        TrackEnrichCompanion.insert(trackId: Value(shadowId), details: const Value('{"bpm":90}')));
    final newId = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/m/new.m4a', title: 'Song', albumKey: 'artist|album', format: 'm4a', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    await tracks.mergeStreamRow(_key, newId);

    final credits = await db.select(db.trackCredits).get();
    expect(credits.map((c) => (c.trackId, c.name)).toSet(), {(newId, 'a'), (newId, 'b'), (newId, 'c')});
    final enrich = await db.select(db.trackEnrich).getSingle();
    expect((enrich.trackId, enrich.details), (newId, '{"bpm":90}'));
  });

  test('a failing step after the move is logged and the track still counts as promoted', () async {
    promoter = StreamPromoter(
        cache: cache,
        tracks: tracks,
        covers: covers,
        downloadFolder: () async => (Directory(p.join(root.path, 'Music')), folder),
        index: () async => index,
        scan: (_, _) async => throw StateError('scan'),
        tag: (_) async => throw StateError('tag'));
    expect(await promoter.promote(_r), isTrue);
    expect(File(p.join(root.path, 'Music', '${downloadBaseName(_r)}.m4a')).existsSync(), isTrue);
  });

  test('the shadow row gone after the move still scans the file and frees the cache entry', () async {
    await db.delete(db.tracks).go();
    // streamRow answers once (the guard), then the row is gone.
    final gone = _VanishingTracks(db);
    promoter = StreamPromoter(
        cache: cache,
        tracks: gone,
        covers: covers,
        downloadFolder: () async => (Directory(p.join(root.path, 'Music')), folder),
        index: () async => index,
        scan: (_, path) async => scanned.add(path),
        tag: (id) async => tagged.add(id));
    expect(await promoter.promote(_r), isTrue);
    expect(scanned, hasLength(1));
    expect(tagged, isEmpty);
    expect(await cache.fileFor(_key), isNull);
  });

  StreamPromoter build({
    Future<(Directory, Folder)?> Function()? folderFn,
    Future<void> Function(File, String)? rename,
    Future<void> Function(File, String)? copy,
    void Function(int, int)? onShadowMerged,
    Future<String> Function(String)? publish,
    Future<Directory> Function()? workDir,
  }) =>
      StreamPromoter(
        cache: cache,
        tracks: tracks,
        covers: covers,
        downloadFolder: folderFn ?? () async => (Directory(p.join(root.path, 'Music')), folder),
        index: () async => index,
        scan: (_, path) async => scanned.add(path),
        tag: (id) async => tagged.add(id),
        rename: rename,
        copy: copy,
        onShadowMerged: onShadowMerged,
        publish: publish,
        workDir: workDir,
      );
  String destOf([String suffix = '']) => p.join(root.path, 'Music', '${downloadBaseName(_r)}$suffix.m4a');

  test('Android: the file is staged in the work folder, published, and the published path is registered', () async {
    final work = Directory(p.join(root.path, 'work'))..createSync();
    final staged = <String>[];
    final id = await build(
      workDir: () async => work,
      publish: (path) async {
        staged.add(path);
        return File(path).copySync(destOf()).path;
      },
    ).promote(_r);
    expect(id, isTrue);
    expect(staged, [p.join(work.path, '${downloadBaseName(_r)}.m4a')]);
    expect(index.pathFor(_key), destOf());
    expect((await tracks.getById(shadowId))!.path, destOf());
    expect(scanned, [destOf()]);
  });

  test('a missing row already at the destination path: the index has the file and the scan runs', () async {
    final libId = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: destOf(), title: 'Song', albumKey: 'artist|album', format: 'm4a', sizeBytes: 1, mtimeMs: 1,
        addedAt: 1, missing: const Value(true)));
    final merged = <(int, int)>[];
    expect(await build(onShadowMerged: (s, k) => merged.add((s, k))).promote(_r), isTrue);
    expect(merged, [(shadowId, libId)], reason: 'queues holding the shadow id can follow');
    expect(index.pathFor(_key), destOf());
    expect(scanned, [destOf()]);
    expect(tagged, [libId]);
    expect(await tracks.getById(shadowId), isNull, reason: 'the shadow merged into the library row');
    expect((await db.select(db.plays).get()).single.trackId, libId);
  });

  test('no download folder: nothing is promoted and the cache keeps the file', () async {
    expect(await build(folderFn: () async => null).promote(_r), isFalse);
    expect(await cache.fileFor(_key), isNotNull);
    expect((await tracks.getById(shadowId))!.kind, 2);
  });

  test('no shadow row: nothing is promoted and the cache keeps the file', () async {
    await db.delete(db.plays).go();
    await db.delete(db.tracks).go();
    expect(await build().promote(_r), isFalse);
    expect(await cache.fileFor(_key), isNotNull);
    expect(File(destOf()).existsSync(), isFalse);
  });

  test('a taken destination name gets " (2)"', () async {
    File(destOf()).writeAsBytesSync([7]);
    expect(await build().promote(_r), isTrue);
    expect(File(destOf(' (2)')).existsSync(), isTrue);
    expect((await tracks.getById(shadowId))!.path, destOf(' (2)'));
    expect(File(destOf()).readAsBytesSync(), [7]);
  });

  group('rename fails (other volume): copy', () {
    Future<void> noRename(File f, String to) async => throw const FileSystemException('cross-device');

    test('an incomplete copy throws, the partial copy goes and the source stays', () async {
      final src = (await cache.fileFor(_key))!;
      final pr = build(rename: noRename, copy: (f, to) async => File(to).writeAsBytesSync([1]));
      await expectLater(pr.promote(_r), throwsA(isA<StreamPromoteException>().having((e) => e.noSpace, 'noSpace', isFalse)));
      expect(File(destOf()).existsSync(), isFalse);
      expect(src.existsSync(), isTrue);
      expect((await tracks.getById(shadowId))!.kind, 2);
    });

    for (final (label, err) in [
      ('code 28', OSError('x', 28)),
      ('code 112', OSError('x', 112)),
      ('message', OSError('No space left on device', 5)),
    ]) {
      test('disk full ($label) -> noSpace', () async {
        final pr = build(rename: noRename, copy: (f, to) async => throw FileSystemException('copy', to, err));
        await expectLater(pr.promote(_r), throwsA(isA<StreamPromoteException>().having((e) => e.noSpace, 'noSpace', isTrue)));
        expect((await cache.fileFor(_key))!.existsSync(), isTrue);
      });
    }
  });

  test('a second add of the same track while it moves is ignored', () async {
    final calls = <String>[];
    final gate = Completer<void>();
    final c = await _notifierWith(_FakePromoter(calls, gate));
    final n = c.read(downloadsProvider.notifier);
    n.add(_r);
    n.add(_r);
    await Future<void>.delayed(Duration.zero);
    expect(calls, [_key]);
    gate.complete();
  });

  test('a second add after the first finished is not ignored', () async {
    final calls = <String>[];
    final c = await _notifierWith(_FakePromoter(calls));
    final n = c.read(downloadsProvider.notifier);
    n.add(_r);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    n.add(_r);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(calls, [_key, _key]);
  });

  test('a normal download of a track with a shadow row merges the row', () async {
    final spy = _MergeSpy(db);
    final c = await _notifierWith(_FakePromoter([], null, null), yt: _DownloadingYt(), extra: [
      libraryScannerProvider.overrideWithValue(_Scanner(db)),
      trackRepositoryProvider.overrideWithValue(spy),
      downloadIndexProvider.overrideWith((ref) async => index),
    ]);
    c.read(downloadsProvider.notifier).add(_r, tag: 'import:1:2');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(spy.merged, [_key]);
  });

  test('noSpace queues no download', () async {
    final c = await _notifierWith(
        _FakePromoter([], null, const StreamPromoteException('disk full', noSpace: true)));
    c.read(downloadsProvider.notifier).add(_r);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(c.read(downloadsProvider), isEmpty);
  });

  test('a promotion error that lands after the notifier is gone does not throw', () async {
    final gate = Completer<void>();
    final c = await _notifierWith(
        _FakePromoter([], gate, const StreamPromoteException('late')));
    c.read(downloadsProvider.notifier).add(_r);
    c.dispose();
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50)); // an unhandled error fails the test
  });

  test('an import-tagged add skips the promoter', () async {
    final calls = <String>[];
    final c = await _notifierWith(_FakePromoter(calls));
    c.read(downloadsProvider.notifier).add(_r, tag: 'import:1:2');
    await Future<void>.delayed(Duration.zero);
    expect(calls, isEmpty);
    expect(c.read(downloadsProvider), hasLength(1));
  });

  group('addto: with a cached track', () {
    Future<(ProviderContainer, int)> setup(StreamPromoter pr) async {
      final playlists = PlaylistRepository(db);
      final pl = await playlists.create('P');
      final c = await _notifierWith(pr, extra: [
        trackRepositoryProvider.overrideWithValue(tracks),
        playlistRepositoryProvider.overrideWithValue(playlists),
        downloadIndexProvider.overrideWith((ref) async => index),
      ]);
      return (c, pl);
    }

    test('moves the file (no download) and the row joins the playlist', () async {
      final (c, pl) = await setup(promoter);
      c.read(downloadsProvider.notifier).add(_r, tag: addToPlaylistTag(pl));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(c.read(downloadsProvider), isEmpty);
      final rows = await (db.select(db.playlistTracks)..where((t) => t.playlistId.equals(pl))).get();
      expect(rows.map((e) => e.trackId), [shadowId]);
    });

    test('without a cached file it downloads with the tag', () async {
      cache.forget(_key);
      final (c, pl) = await setup(promoter);
      c.read(downloadsProvider.notifier).add(_r, tag: addToPlaylistTag(pl));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(c.read(downloadsProvider).single.tag, addToPlaylistTag(pl));
    });
  });
}

/// The guard in `promote` sees the shadow row; right after the move it is gone.
class _VanishingTracks extends TrackRepository {
  _VanishingTracks(super.db);
  @override
  Future<Track?> streamRow(String key) async => _first++ == 0 ? _fake : null;
  var _first = 0;
  final _fake = Track(coverSource: 0, 
      id: 1, path: 'stream:x', title: 't', albumKey: '', durationMs: 0, format: 'm4a', sizeBytes: 0, mtimeMs: 0,
      hasCover: false, isFavorite: false, enrichStatus: 0, userEdited: false, missing: false, ignored: false,
      kind: 2, addedAt: 0, playCount: 0);
  @override
  Future<Track?> promoteStreamRow(String key, String path, int folderId, File file) async => null;
}

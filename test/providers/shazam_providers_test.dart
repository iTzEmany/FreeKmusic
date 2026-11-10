import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shazam_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/collection_matcher.dart';
import 'package:codecore/services/online/download_queue.dart' show DownloadItem;
import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/shared_text.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_ytm.dart';

class _Matcher implements CollectionMatcher {
  _Matcher(this.out);
  final TrackMatch out;
  @override
  Stream<(int, TrackMatch)> match(List<ExternalTrack> tracks) => Stream.value((0, out));
  @override
  void cancel() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Downloads extends DownloadsNotifier {
  final added = <String>[];
  @override
  List<DownloadItem> build() => const [];
  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    added.add(r.id);
    return false;
  }
}

const _share = ShazamShare('Siren', 'The Chainsmokers & Aazar');

void main() {
  late AppDatabase db;
  late SettingsStore store;
  late _Downloads downloads;
  late TrackMatch match;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = AppDatabase(NativeDatabase.memory());
    downloads = _Downloads();
    match = TrackReady.online(ytmSong('y1', 'Siren', artist: 'The Chainsmokers'));
  });
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      settingsStoreProvider.overrideWithValue(store),
      collectionMatcherProvider.overrideWith((ref, page) => _Matcher(match)),
      downloadsProvider.overrideWith(() => downloads),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<ShazamResult> add(ProviderContainer c) => c.read(shazamInboxProvider).add(_share);

  Future<List<String>> titles(ProviderContainer c) async {
    final repo = c.read(playlistRepositoryProvider);
    final pid = (await repo.idByUuid(store.readShazamPlaylistUuid()!))!;
    return [for (final t in await repo.watchTracks(pid).first) t.title];
  }

  test('the playlist is created once and found again by its uuid', () async {
    final c = container();
    expect(await add(c), isA<ShazamAdded>());
    match = TrackReady.online(ytmSong('y2', 'Other', artist: 'Someone'));
    await add(c);
    expect(await db.select(db.playlists).get(), hasLength(1));
    expect(await titles(c), ['Other', 'Siren']); // the newest on top
  });

  test('a deleted playlist is created again', () async {
    final c = container();
    await add(c);
    final repo = c.read(playlistRepositoryProvider);
    await repo.delete((await repo.idByUuid(store.readShazamPlaylistUuid()!))!);
    await add(c);
    expect(await titles(c), ['Siren']);
  });

  test('the same track id is a duplicate and changes nothing', () async {
    final c = container();
    await add(c);
    expect(await add(c), isA<ShazamDuplicate>());
    expect(await titles(c), ['Siren']);
  });

  test('same title and artist under another id is a duplicate', () async {
    final c = container();
    await add(c);
    match = TrackReady.online(ytmSong('y9', 'Siren (Deluxe)', artist: 'The Chainsmokers'));
    expect(await add(c), isA<ShazamDuplicate>());
    expect(await titles(c), ['Siren']);
  });

  test('not found adds no row and no playlist', () async {
    match = const TrackNotFound();
    expect(await add(container()), isA<ShazamNotFound>());
    expect(await db.select(db.playlistTracks).get(), isEmpty);
  });

  test('a passing failure asks to retry', () async {
    match = const TrackNotFound(transient: true);
    expect(await add(container()), isA<ShazamRetry>());
  });

  test('a library track goes in without a download', () async {
    final id = await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/m/s.mp3', title: 'Siren', albumKey: 'a|b', format: 'mp3', sizeBytes: 1,
        mtimeMs: 1, addedAt: 1, artist: const Value('The Chainsmokers')));
    final t = await (db.select(db.tracks)..where((r) => r.id.equals(id))).getSingle();
    match = TrackReady.library(t);
    await store.writeShazamAutoDownload(true);
    final c = container();
    final r = await add(c) as ShazamAdded;
    expect(r.track?.id, id);
    expect(downloads.added, isEmpty);
  });

  test('download starts only with the setting on', () async {
    await add(container());
    expect(downloads.added, isEmpty);
    await store.writeShazamAutoDownload(true);
    match = TrackReady.online(ytmSong('y3', 'New', artist: 'Else'));
    await add(container());
    expect(downloads.added, ['y3']);
  });
}

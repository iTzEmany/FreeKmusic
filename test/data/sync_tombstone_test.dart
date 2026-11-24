import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/backup_merge.dart';
import 'package:codecore/data/repositories/favorite_collections_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/services/backup/user_data.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/sync_tombstone_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FavoriteCollectionsRepository favs;
  late PlaylistRepository lists;
  late TrackRepository tracks;
  late SyncTombstoneRepository tombs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    favs = FavoriteCollectionsRepository(db);
    lists = PlaylistRepository(db);
    tracks = TrackRepository(db);
    tombs = SyncTombstoneRepository(db);
  });
  tearDown(() => db.close());

  Future<Set<String>> left() async => {for (final t in await tombs.all()) '${t.kind}:${t.key}'};
  YtResult yt(String id) => YtResult(id: id, title: 'T$id', channel: 'Ch', duration: null);
  Future<int> local(String path, {String album = 'a|b'}) => db.into(db.tracks).insert(TracksCompanion.insert(
      path: path, title: path, albumKey: album, format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));

  test('record keeps the highest date, clear removes, all filters by since', () async {
    await tombs.record('playlist', 'u', at: 50);
    await tombs.record('playlist', 'u', at: 20);
    await tombs.record('playlist', 'v', at: 10);
    expect((await tombs.all()).firstWhere((t) => t.key == 'u').deletedAt, 50);
    expect((await tombs.all(since: 30)).map((t) => t.key), ['u']);
    await tombs.clear('playlist', 'u');
    expect(await left(), {'playlist:v'});
  });

  test('deleting a favourite playlist leaves both tombstones; putting the favourite back clears its tombstone', () async {
    final id = await lists.create('Mix');
    final uuid = (await lists.uuidOf(id))!;
    await favs.add('playlist', uuid);
    await lists.delete(id);
    expect(await left(), {'playlist:$uuid', 'favoritePlaylist:$uuid'});
    await favs.add('playlist', uuid);
    expect(await left(), {'playlist:$uuid'});
  });

  test('removing and toggling off a favourite album leaves a tombstone, adding it back clears it', () async {
    await favs.add('album', 'art|alb');
    await favs.remove('album', 'stream|art|alb');
    expect(await left(), {'favoriteAlbum:art|alb'});
    await favs.add('album', 'art|alb');
    expect(await left(), isEmpty);
    await favs.toggle('album', 'art|alb');
    expect(await left(), {'favoriteAlbum:art|alb'});
    await favs.remove('album', 'never|there'); // nothing was removed: nothing to tell
    expect(await left(), {'favoriteAlbum:art|alb'});
  });

  test('an unknown| album key never gets a tombstone', () async {
    await favs.add('album', 'unknown|/home/me/Music');
    await favs.remove('album', 'unknown|/home/me/Music');
    expect(await favs.isFavoriteNow('album', 'unknown|/home/me/Music'), isFalse);
    expect(await left(), isEmpty);
  });

  test('followAlbumKey writes no tombstone; an undone merge (both albums favourites) keeps both hearts', () async {
    final t = await local('/x', album: 'old');
    await favs.add('album', 'old');
    await favs.add('album', 'new');
    await db.customUpdate("UPDATE tracks SET album_key = 'new' WHERE id = ?", variables: [Variable.withInt(t)]);
    await favs.followAlbumKey('old', 'new');
    expect(await left(), isEmpty);
    await db.customUpdate("UPDATE tracks SET album_key = 'old' WHERE id = ?", variables: [Variable.withInt(t)]);
    await favs.followAlbumKey('new', 'old');
    expect(await favs.watch('album').first, containsAll(['old', 'new']));
    // A track still on the old key keeps its favourite.
    await local('/y', album: 'old');
    await favs.followAlbumKey('old', 'new');
    expect(await favs.watch('album').first, containsAll(['old', 'new']));
  });

  test('unsaving a saved stream leaves savedStream, saving again (and saveStream) clears it; a never-saved row leaves none', () async {
    final r = yt('a');
    await tracks.saveStream(r);
    await tracks.setSaved(r.indexKey, false);
    expect(await left(), {'savedStream:youtube:a'});
    await tracks.setSaved(r.indexKey, false);
    await tracks.saveStream(r);
    expect(await left(), isEmpty);
    await tracks.ensureStreamRow(yt('b'));
    await tracks.setSaved('youtube:b', false);
    expect(await left(), isEmpty);
  });

  test('deleting a saved stream row leaves savedStream; a local row (kind 0) and an unsaved shadow row leave nothing', () async {
    final saved = (await tracks.saveStream(yt('s')))!;
    final shadow = await tracks.ensureStreamRow(yt('u'));
    final file = await local('/music/a.mp3');
    await tracks.deleteTrack(file);
    await tracks.deleteTracks([shadow]);
    expect(await left(), isEmpty);
    await tracks.deleteTracks([saved]);
    expect(await left(), {'savedStream:youtube:s'});
  });

  test('un-hearting a streamed row leaves favoriteStream, hearting dates it and clears it; local rows leave nothing', () async {
    final s = await tracks.ensureStreamRow(yt('h'));
    final file = await local('/music/b.mp3');
    await tracks.setFavoriteMany([s, file], true);
    expect((await tracks.getById(s))!.favoritedAt, isNotNull);
    expect(await left(), isEmpty);
    await tracks.setFavorite(s, false);
    await tracks.setFavorite(file, false);
    expect(await left(), {'favoriteStream:youtube:h'});
    await tracks.setFavorite(s, true);
    expect(await left(), isEmpty);
    await tracks.setFavorite(s, false);
    await tracks.setFavorite(s, false);
    expect(await left(), {'favoriteStream:youtube:h'});
  });

  test('deleting a streamed row that was only hearted leaves favoriteStream; saved and hearted leaves both', () async {
    final h = await tracks.ensureStreamRow(yt('h'));
    await tracks.setFavorite(h, true);
    final both = (await tracks.saveStream(yt('b')))!;
    await tracks.setFavorite(both, true);
    await tracks.deleteTracks([h, both]);
    expect(await left(), {'favoriteStream:youtube:h', 'savedStream:youtube:b', 'favoriteStream:youtube:b'});
  });

  test('a heart already there keeps its favorited_at', () async {
    final s = await tracks.ensureStreamRow(yt('h'));
    await tracks.setFavorite(s, true);
    await db.customUpdate('UPDATE tracks SET favorited_at = 7 WHERE id = ?', variables: [Variable.withInt(s)]);
    await tracks.setFavoriteMany([s], true);
    expect((await tracks.getById(s))!.favoritedAt, 7);
  });

  test('setFavoriteMany rolls back with its transaction', () async {
    final s = await tracks.ensureStreamRow(yt('h'));
    await tracks.setFavorite(s, true);
    await db.customStatement("CREATE TRIGGER no_upd BEFORE UPDATE OF is_favorite ON tracks BEGIN SELECT RAISE(ABORT, 'no'); END");
    await expectLater(tracks.setFavoriteMany([s], false), throwsA(anything));
    expect(await left(), isEmpty);
  });

  test('deleteTracks rolls back the tombstone when the delete fails', () async {
    final saved = (await tracks.saveStream(yt('s')))!;
    await db.customStatement("CREATE TRIGGER no_del_t BEFORE DELETE ON tracks BEGIN SELECT RAISE(ABORT, 'no'); END");
    await expectLater(tracks.deleteTracks([saved]), throwsA(anything));
    expect(await left(), isEmpty);
  });

  test('rekeyStream: the old key of a saved and hearted row gets both tombstones, the new key none', () async {
    final id = (await tracks.saveStream(yt('o')))!;
    await tracks.setFavorite(id, true);
    await tombs.record('savedStream', 'youtube:n', at: 1);
    await tombs.record('favoriteStream', 'youtube:n', at: 1);
    expect(await tracks.rekeyStream(id, 'youtube:n'), isTrue);
    expect(await left(), {'savedStream:youtube:o', 'favoriteStream:youtube:o'});
  });

  test('demoteToStream clears the tombstones of the key (saved, hearted)', () async {
    final file = await local('/music/d.mp3');
    await tracks.setFavorite(file, true);
    await tombs.record('savedStream', 'youtube:d');
    await tombs.record('favoriteStream', 'youtube:d');
    await tracks.demoteToStream(file, 'youtube:d');
    expect(await left(), isEmpty);
  });

  test('deleting a hidden «Scarica album» playlist leaves no tombstone, a visible one does', () async {
    final hidden = await lists.create('Album');
    final shown = await lists.create('Mix');
    await db.customStatement(
        "INSERT INTO playlist_imports (playlist_id, source_name, created_at, source_kind) VALUES ($hidden, 'x', 1, 'ytm-album')");
    await lists.delete(hidden);
    expect(await left(), isEmpty);
    final uuid = (await lists.uuidOf(shown))!;
    await lists.delete(shown);
    expect(await left(), {'playlist:$uuid'});
  });

  test('a backup merge dates a new heart, clears favoriteStream, and a recreated playlist clears its tombstone', () async {
    final s = await tracks.ensureStreamRow(yt('abcdefghijk'));
    await tracks.setFavorite(s, true);
    await tracks.setFavorite(s, false);
    expect(await left(), {'favoriteStream:youtube:abcdefghijk'});
    await tombs.record('playlist', 'u-1');
    final file = await local('/music/m.mp3');
    final resolver = await PlaylistSyncRepository(db).resolver();
    await mergeUserData(
        db,
        UserData(createdAt: 1, tracks: [
          const TrackUserData(ref: TrackRef(title: 'Th', streamKey: 'youtube:abcdefghijk'), favorite: true),
          TrackUserData(ref: TrackRef(title: '/music/m.mp3', folder: '/music/m.mp3'), favorite: true),
        ], playlists: [
          const PlaylistData(name: 'Back', createdAt: 1, uuid: 'u-1'),
        ]),
        resolver);
    expect(await left(), isEmpty);
    expect((await tracks.getById(s))!.favoritedAt, isNotNull);
    expect(file, isPositive);
  });

  test('if the deletion fails the tombstone is rolled back too', () async {
    final id = await lists.create('Mix');
    final uuid = (await lists.uuidOf(id))!;
    await favs.add('playlist', uuid);
    await db.customStatement("CREATE TRIGGER no_del BEFORE DELETE ON playlists BEGIN SELECT RAISE(ABORT, 'no'); END");
    await expectLater(lists.delete(id), throwsA(anything));
    expect(await left(), isEmpty);
    expect(await favs.isFavoriteNow('playlist', uuid), isTrue);
  });
}

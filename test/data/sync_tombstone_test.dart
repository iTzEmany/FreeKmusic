import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/favorite_collections_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/sync_tombstone_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
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

  test('followAlbumKey writes no tombstone and drops the orphan row when both albums were favourites', () async {
    await local('/x', album: 'new');
    await favs.add('album', 'old');
    await favs.add('album', 'new');
    await favs.followAlbumKey('old', 'new');
    expect(await favs.watch('album').first, ['new']);
    expect(await left(), isEmpty);
    // A track still on the old key keeps its favourite.
    await local('/y', album: 'old');
    await favs.add('album', 'old');
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

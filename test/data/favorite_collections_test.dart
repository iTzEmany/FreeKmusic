import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/favorite_collections_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late FavoriteCollectionsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FavoriteCollectionsRepository(db);
  });
  tearDown(() => db.close());

  test('add, remove, toggle and watch by kind; a double add is one row', () async {
    await repo.add('album', 'k1', addedAt: 1);
    await repo.add('album', 'k1', addedAt: 9);
    await repo.add('album', 'k2', addedAt: 5);
    await repo.add('playlist', 'k1');
    expect(await repo.watch('album').first, ['k2', 'k1']);
    expect((await db.select(db.favoriteCollections).get()).where((r) => r.key == 'k1' && r.kind == 'album').single.addedAt, 1);
    await repo.toggle('album', 'k2');
    await repo.toggle('album', 'k3');
    expect(await repo.watch('album').first, ['k3', 'k1']);
    expect(await repo.isFavorite('playlist', 'k1').first, isTrue);
    await repo.remove('playlist', 'k1');
    expect(await repo.isFavorite('playlist', 'k1').first, isFalse);
  });

  test('deleting a playlist drops its favourite, not an album with the same key', () async {
    final pl = PlaylistRepository(db);
    final id = await pl.create('Mix');
    final uuid = (await pl.uuidOf(id))!;
    await repo.add('playlist', uuid);
    await repo.add('album', uuid);
    await pl.delete(id);
    expect(await repo.watch('playlist').first, isEmpty);
    expect(await repo.watch('album').first, [uuid]);
  });

  test('an album favourite is one key whether given as stream or file album key', () async {
    await repo.add('album', 'stream|art|alb');
    expect(await repo.isFavorite('album', 'art|alb').first, isTrue);
    await repo.toggle('album', 'art|alb');
    expect(await repo.watch('album').first, isEmpty);
    await repo.add('album', 'art|alb');
    expect(await repo.isFavoriteNow('album', 'stream|art|alb'), isTrue);
    await repo.add('album', 'stream|art|alb');
    expect(await repo.watch('album').first, ['art|alb']);
    await repo.remove('album', 'stream|art|alb');
    expect(await repo.watch('album').first, isEmpty);
  });

  Future<void> row(String path, String albumKey) => db.into(db.tracks).insert(TracksCompanion.insert(
      path: path, title: path, albumKey: albumKey, format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));

  test('followAlbumKey moves the favourite when no track keeps the old key, else leaves it', () async {
    await repo.add('album', 'art|alb');
    await row('/a', 'art|alb');
    await repo.followAlbumKey('art|alb', 'art|alb (deluxe)');
    expect(await repo.watch('album').first, ['art|alb'], reason: 'a track still has the old key');
    await db.update(db.tracks).write(const TracksCompanion(albumKey: Value('art|alb (deluxe)')));
    await repo.followAlbumKey('art|alb', 'art|alb (deluxe)');
    expect(await repo.watch('album').first, ['art|alb (deluxe)']);
  });

  test('a stream| album key is empty after the prefix: it is not a favourite', () async {
    await repo.add('album', 'stream|');
    expect(await repo.watch('album').first, isEmpty);
  });
}

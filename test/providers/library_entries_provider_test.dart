import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/smart_playlist_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AlbumSummary _album(String t) => AlbumSummary(
  albumKey: t,
  title: t,
  artist: 'X',
  variousArtists: false,
  trackCount: 3,
  durationMs: 1,
  year: null,
  coverKey: null,
  lastPlayedAt: null,
  addedAt: 0,
);

void main() {
  test('switching tab and back reuses the sorted list', () async {
    final c = ProviderContainer(
      overrides: [
        playlistsProvider.overrideWith((_) => Stream.value([])),
        albumsProvider.overrideWith((_) => Stream.value([_album('B'), _album('A')])),
        artistsProvider.overrideWith((_) => Stream.value([])),
        smartPlaylistsProvider.overrideWith((_) => Stream.value([])),
      ],
    );
    addTearDown(c.dispose);
    // Keep the sources alive and wait for their first value.
    for (final p in [playlistsProvider, albumsProvider, artistsProvider, smartPlaylistsProvider]) {
      c.listen(p, (_, _) {});
      await c.read(p.future);
    }
    const all = (null, LibrarySort.alpha);
    const albums = (LibraryKind.album, LibrarySort.alpha);
    final first = c.read(libraryEntriesProvider(all)).value!;
    expect([for (final e in first) e.title], ['A', 'B']);
    c.read(libraryEntriesProvider(albums));
    expect(identical(c.read(libraryEntriesProvider(all)).value, first), isTrue);
  });

  test('favourite count ignores the Favourites search text', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var i = 0; i < 3; i++) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/m/$i.mp3',
        title: 'Song $i',
        albumKey: 'k',
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 0,
        isFavorite: Value(i < 2),
      ));
    }
    final c = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(c.dispose);
    c.listen(favoriteCountProvider, (_, _) {});
    c.read(trackQueryProvider(true).notifier).update((q) => q.copyWith(text: 'zzz'));
    expect(await c.read(favoriteCountProvider.future), 2);
  });

  test('keepWhileLoading keeps the old value only while the new one loads', () {
    const old = AsyncData<int>(1);
    expect(keepWhileLoading<int>(const AsyncLoading(), old), old);
    expect(keepWhileLoading<int>(const AsyncData(2), old), const AsyncData(2));
    final err = AsyncError<int>('x', StackTrace.empty);
    expect(keepWhileLoading<int>(err, old), err);
    expect(keepWhileLoading<int>(const AsyncLoading(), null).isLoading, isTrue);
  });
}

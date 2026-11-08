import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/artist_all_songs_provider.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ytm.dart';

const _key = (name: 'Pink Floyd', browseId: 'VL1', params: null);

void main() {
  late AppDatabase db;
  var n = 0;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> add(String title, String artist) => db
      .into(db.tracks)
      .insert(
        TracksCompanion.insert(
          path: '/m/${n++}.mp3',
          title: title,
          artist: Value(artist),
          albumKey: 'k',
          durationMs: const Value(1000),
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          hasCover: const Value(false),
          addedAt: 1,
        ),
      );

  Future<ArtistAllSongs> read({bool fails = false}) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        artistSongsProvider.overrideWith((ref, link) async {
          if (fails) throw StateError('offline');
          return CatalogResult([
            ytmSong('a', 'Time'),
            ytmSong('b', 'Money'),
            ytmSong('c', 'Us and Them'),
          ], DateTime(2026));
        }),
      ],
    );
    addTearDown(c.dispose);
    return c.read(artistAllSongsProvider(_key).future);
  }

  test(
    'top order, a downloaded song replaces its online one, rest last',
    () async {
      await add('Money', 'Pink Floyd');
      await add('Echoes', 'Pink Floyd');
      final r = await read();
      expect(r.topMissing, isFalse);
      expect(
        [for (final i in r.items) i.track?.title ?? i.online!.title],
        ['Time', 'Money', 'Us and Them', 'Echoes'],
      );
      expect(
        [for (final i in r.items) i.track != null],
        [false, true, false, true],
      );
    },
  );

  test('catalog error: only the downloaded songs and topMissing', () async {
    await add('Echoes', 'Pink Floyd');
    final r = await read(fails: true);
    expect(r.topMissing, isTrue);
    expect([for (final i in r.items) i.track!.title], ['Echoes']);
  });

  test('only the same main artist, whatever the spelling', () async {
    await add('Echoes', 'pink floyd');
    await add('Hey You', 'Pink Floyd feat. Someone');
    await add('Other', 'Roger Waters');
    final r = await read(fails: true);
    expect([for (final i in r.items) i.track!.title], ['Echoes', 'Hey You']);
  });
}

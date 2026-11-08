import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/artist_all_songs_provider.dart';
import 'package:codecore/providers/artist_shelves_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ytm.dart';

const _key = (name: 'Pink Floyd', ids: 'UCpf');

final _top = [
  ytmSong('a', 'Time'),
  ytmSong('b', 'Money'),
  ytmSong('c', 'Us and Them'),
];

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

  Future<ArtistAllSongs> read({
    bool fails = false,
    List<YtResult>? top,
    YtmBrowseLink? link = const YtmBrowseLink('VL1', null),
    bool noPage = false,
  }) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        groupShelvesProvider.overrideWith(
          (ref, ids) => noPage
              ? null
              : [YtmSongShelf('Top', top ?? _top, allSongs: link)],
        ),
        artistSongsProvider.overrideWith((ref, l) async {
          if (fails) throw StateError('offline');
          return CatalogResult(top ?? _top, DateTime(2026));
        }),
      ],
    );
    addTearDown(c.dispose);
    return c.read(artistAllSongsProvider(_key).future);
  }

  List<String> titles(ArtistAllSongs r) => [
    for (final i in r.items) i.track?.title ?? i.online!.title,
  ];

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

  test('remaster and feat. tags still join the downloaded song', () async {
    await add('Money', 'Pink Floyd');
    final r = await read(top: [ytmSong('b', 'Money (2011 Remaster)')]);
    expect(r.items.single.track!.title, 'Money');
  });

  test('a title repeated in the top enters once', () async {
    final r = await read(top: [ytmSong('a', 'Time'), ytmSong('x', 'Time')]);
    expect(titles(r), ['Time']);
  });

  test('without «show all» the shelf songs are the top', () async {
    final r = await read(link: null, fails: true);
    expect(titles(r), ['Time', 'Money', 'Us and Them']);
    expect(r.topMissing, isFalse);
  });

  test('page not read: only downloaded songs and topMissing', () async {
    await add('Echoes', 'Pink Floyd');
    final r = await read(noPage: true);
    expect(titles(r), ['Echoes']);
    expect(r.topMissing, isTrue);
  });
}

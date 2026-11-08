import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/artist_all_songs_provider.dart';
import 'package:codecore/providers/artist_shelves_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/dislike_store_provider.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
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
  late DislikeStore store;
  var n = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = DislikeStore(file: () async => File('/nonexistent/dislikes.json'));
  });
  tearDown(() => db.close());

  Future<void> add(
    String title,
    String artist, {
    bool missing = false,
    bool ignored = false,
    int kind = 0,
  }) => db
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
          missing: Value(missing),
          ignored: Value(ignored),
          kind: Value(kind),
        ),
      );

  Future<ArtistAllSongs> read({
    bool fails = false,
    List<YtResult>? top,
    YtmBrowseLink? link = const YtmBrowseLink('VL1', null),
    bool noPage = false,
    List<YtmShelf>? shelves,
  }) {
    final c = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dislikeStoreProvider.overrideWithValue(store),
        groupShelvesProvider.overrideWith(
          (ref, ids) => noPage
              ? null
              : shelves ?? [YtmSongShelf('Top', top ?? _top, allSongs: link)],
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

  test(
    'missing, ignored and episode rows stay out; title order ignores case',
    () async {
      await add('c', 'Pink Floyd');
      await add('B', 'Pink Floyd');
      await add('a', 'Pink Floyd');
      await add('gone', 'Pink Floyd', missing: true);
      await add('hidden', 'Pink Floyd', ignored: true);
      await add('episode', 'Pink Floyd', kind: 1);
      final r = await read(fails: true);
      expect(titles(r), ['a', 'B', 'c']);
    },
  );

  test('a name of only symbols matches its exact spelling', () async {
    await add('x', '!!!');
    await add('y', '???');
    final r = await TrackRepository(db).tracksOfArtist('!!!');
    expect([for (final t in r) t.title], ['x']);
  });

  test(
    'two downloaded songs with one title: first in the top, second last',
    () async {
      await add('Time', 'Pink Floyd');
      await add('Time', 'pink floyd');
      final r = await read(top: [ytmSong('a', 'Time')]);
      expect(
        [for (final i in r.items) i.track!.artist],
        ['Pink Floyd', 'pink floyd'],
      );
    },
  );

  test('without «show all» every shelf of the page is the top', () async {
    final r = await read(
      fails: true,
      shelves: [
        YtmSongShelf('A', [ytmSong('a', 'Time')]),
        YtmSongShelf('B', [ytmSong('b', 'Money')]),
      ],
    );
    expect(titles(r), ['Time', 'Money']);
  });

  test('a blocked online song is skipped, the downloaded one is not', () async {
    await add('Money', 'Pink Floyd');
    store.blockTrack(const DislikedTrack(videoId: 'a', title: 'Time', artist: 'Pink Floyd'));
    store.blockTrack(const DislikedTrack(videoId: 'b', title: 'Money', artist: 'Pink Floyd'));
    final r = await read();
    expect(titles(r), ['Us and Them', 'Money']);
    expect(r.items.last.track, isA<Track>(), reason: 'own songs are never filtered');
  });

  test('a blocked artist: only the downloaded songs play (D-468)', () async {
    await add('Echoes', 'Pink Floyd');
    store.blockArtist(const DislikedArtist(key: 'pink floyd', name: 'Pink Floyd'));
    final r = await read();
    expect(titles(r), ['Echoes']);
  });

  test('a row by a blocked artist is skipped even on another artist page', () async {
    store.blockArtist(const DislikedArtist(key: 'guest', name: 'Guest'));
    final r = await read(top: [ytmSong('a', 'Time'), ytmSong('g', 'Duet', artist: 'Guest')]);
    expect(titles(r), ['Time']);
  });
}

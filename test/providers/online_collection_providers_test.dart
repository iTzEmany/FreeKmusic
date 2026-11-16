import 'package:codecore/data/settings/settings_store.dart' show AppSettings;
import 'package:codecore/services/online/source_cooldown.dart';
import 'package:codecore/services/online/request_budget.dart';
import 'package:codecore/services/import/track_matcher.dart' show LibraryIndex;
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/db/app_database.dart' show AppDatabase, Track, TracksCompanion;
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/library_providers.dart' show libraryIndexProvider;
import 'package:codecore/providers/database_providers.dart' show databaseProvider, trackRepositoryProvider;
import 'package:codecore/providers/online_collection_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'dart:io';

import 'package:codecore/providers/online_providers.dart' show appleRssClientProvider, deezerClientProvider;
import 'package:codecore/providers/ytm_catalog_providers.dart' show catalogCacheProvider;
import 'package:codecore/services/online/apple_rss_client.dart';
import 'package:codecore/services/online/catalog_cache.dart';
import 'package:codecore/services/online/chart_genres.dart';
import 'package:codecore/services/online/deezer_client.dart';
import 'package:codecore/services/online/deezer_models.dart';
import 'package:codecore/services/online/collection_matcher.dart';
import 'package:codecore/services/online/external_links.dart';
import 'package:codecore/services/online/short_link_resolver.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'dart:async';
import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart' show SizedBox;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ytm.dart';

class _Matcher implements CollectionMatcher {
  final asked = <List<String>>[];
  var out = StreamController<(int, TrackMatch)>();
  bool cancelled = false;
  @override
  Stream<(int, TrackMatch)> match(List<ExternalTrack> tracks) {
    if (asked.isNotEmpty) out = StreamController(); // one per read, like the real matcher
    asked.add([for (final t in tracks) t.title]);
    return out.stream;
  }

  @override
  void cancel() {
    cancelled = true;
    out.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Reader implements ExternalReader {
  ExternalLink? link;
  CancelToken? token;
  var order = ['One', 'Two', 'Three'];
  int reads = 0;
  @override
  Future<ExternalCollection> read(ExternalLink link, {CancelToken? cancelToken}) async {
    this.link = link;
    reads++;
    token = cancelToken;
    return ExternalCollection(
      title: 'Deezer mix',
      kind: CollectionKind.playlist,
      sourceUrl: 'https://www.deezer.com/playlist/1',
      tracks: [for (final n in order) ExternalTrack(title: n, artists: ['A'], key: 'same')],
    );
  }
}

class _Resolver implements ShortLinkResolver {
  @override
  Future<String> resolve(String url, {CancelToken? cancelToken}) async =>
      'https://www.deezer.com/en/playlist/1';
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  _chartTests();
  const link = ExternalLink(ExternalService.deezer, ExternalLinkKind.playlist, '1');
  late _Matcher matcher;
  late _Reader reader;

  ProviderContainer externalContainer() {
    matcher = _Matcher();
    reader = _Reader();
    final c = ProviderContainer(overrides: [
      externalReaderProvider.overrideWith((ref, s) => reader),
      shortLinkResolverProvider.overrideWithValue(_Resolver()),
      collectionMatcherProvider.overrideWith((ref, page) {
        ref.onDispose(matcher.cancel);
        return matcher;
      }),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<void> turn() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('an external page shows every row pending at once, then one row per match', () async {
    final c = externalContainer();
    const ref = OnlineCollectionRef.external(link);
    final page = await c.read(onlineCollectionProvider(ref).future);
    expect(page.matches.every((m) => m is TrackPending), isTrue);
    expect(page.matches, hasLength(3));
    final rows = <List<TrackMatch>>[];
    c.listen(onlineMatchesProvider(ref), (_, n) => n.whenData(rows.add));
    await turn();
    matcher.out.add((1, const TrackNotFound()));
    await turn();
    expect(rows.last.map((m) => m.runtimeType), [TrackPending, TrackNotFound, TrackPending]);
  });

  test('a short link is resolved before reading', () async {
    final c = externalContainer();
    final page = await c.read(
        onlineCollectionProvider(const OnlineCollectionRef.shortLink('https://link.deezer.com/s/x')).future);
    expect(reader.link, link);
    expect(page.collection.title, 'Deezer mix');
  });

  test('leaving the page stops the matcher and the reads', () async {
    final c = externalContainer();
    final sub = c.listen(onlineMatchesProvider(const OnlineCollectionRef.external(link)), (_, _) {});
    await turn();
    sub.close();
    await turn();
    expect(matcher.cancelled, isTrue);
    expect(reader.token!.isCancelled, isTrue);
  });

  test('reopening goes on with the unresolved rows only', () async {
    final c = externalContainer();
    const ref = OnlineCollectionRef.external(link);
    var sub = c.listen(onlineMatchesProvider(ref), (_, _) {});
    await turn();
    matcher.out.add((1, TrackReady.online(ytmSong('y', 'Two'))));
    await turn();
    sub.close();
    await turn();
    matcher = _Matcher();
    final pages = <List<TrackMatch>>[];
    sub = c.listen(onlineMatchesProvider(ref), (_, n) => n.whenData(pages.add));
    await turn();
    expect(pages.first.map((m) => m.runtimeType), [TrackPending, TrackReadyOnline, TrackPending]);
    expect(matcher.asked, [
      ['One', 'Three']
    ]);
    matcher.out.add((1, const TrackNotFound()));
    await turn();
    expect(pages.last.map((m) => m.runtimeType), [TrackPending, TrackReadyOnline, TrackNotFound]);
  });

  test('a YouTube listing becomes a collection with every row ready', () async {
    final listing = PlaylistListing(
      title: 'Mix',
      owner: 'Chan',
      truncated: true,
      entries: [ytmSong('a', 'One', seconds: 10), ytmSong('b', 'Two', seconds: 20)],
    );
    final c = ProviderContainer(overrides: [
      playlistListingProvider.overrideWith((ref, url) async => listing),
    ]);
    addTearDown(c.dispose);
    final page = await c.read(
        onlineCollectionProvider(const OnlineCollectionRef.youtubeListing('u')).future);
    expect(page.collection.title, 'Mix');
    expect(page.collection.owner, 'Chan');
    expect(page.collection.truncated, isTrue);
    expect(page.collection.tracks.map((t) => t.key), ['a', 'b']);
    expect(page.matches.every((m) => m is TrackReadyOnline), isTrue);
    expect([for (final m in page.matches) (m as TrackReadyOnline).result.id], ['a', 'b']);
  });

  test('a transient not-found is not kept: reopening asks again', () async {
    final c = externalContainer();
    const ref = OnlineCollectionRef.external(link);
    var sub = c.listen(onlineMatchesProvider(ref), (_, _) {});
    await turn();
    matcher.out.add((0, const TrackNotFound(transient: true)));
    matcher.out.add((1, const TrackNotFound()));
    await turn();
    sub.close();
    await turn();
    matcher = _Matcher();
    sub = c.listen(onlineMatchesProvider(ref), (_, _) {});
    await turn();
    expect(matcher.asked, [
      ['One', 'Three']
    ]);
  });

  test('a refresh with a reordered source keeps each match on its own track', () async {
    final c = externalContainer();
    const ref = OnlineCollectionRef.external(link);
    final sub = c.listen(onlineMatchesProvider(ref), (_, _) {});
    await turn();
    matcher.out.add((1, TrackReady.online(ytmSong('y', 'Two'))));
    await turn();
    reader.order = ['Three', 'Two', 'One'];
    final page = await c.refresh(onlineCollectionProvider(ref).future);
    expect(page.collection.tracks.first.title, 'Three');
    await turn();
    final rows = c.read(onlineMatchesProvider(ref)).value!;
    expect(rows.map((m) => m.runtimeType), [TrackPending, TrackReadyOnline, TrackPending]);
    sub.close();
  });

  testWidgets('refreshing an external page waits for the new read', (tester) async {
    final r = _Reader();
    late WidgetRef w;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        externalReaderProvider.overrideWith((ref, s) => r),
        collectionMatcherProvider.overrideWith((ref, page) => _Matcher()),
      ],
      child: Consumer(builder: (_, ref, _) {
        w = ref;
        ref.watch(onlineCollectionProvider(const OnlineCollectionRef.external(link)));
        return const SizedBox();
      }),
    ));
    await tester.pump();
    r.order = ['Z'];
    late bool ok;
    await tester.runAsync(() async => ok = await refreshOnlineCollection(
        w, const OnlineCollectionRef.external(link)));
    expect(ok, isTrue);
    expect(r.reads, 2);
    expect(w.read(onlineCollectionProvider(const OnlineCollectionRef.external(link))).value?.collection.tracks.single.title, 'Z');
  });

  group('save and refresh', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/lib.mp3', title: 'Lib', albumKey: 'a|b', format: 'mp3', sizeBytes: 1,
          mtimeMs: 1, addedAt: 1, durationMs: const Value(1000)));
    });
    tearDown(() => db.close());

    Future<List<String>> titlesOf(int id) async {
      final rows = await db.customSelect(
          'SELECT t.title FROM playlist_tracks p JOIN tracks t ON t.id = p.track_id '
          'WHERE p.playlist_id = ? ORDER BY p.position',
          variables: [Variable<int>(id)]).get();
      return [for (final r in rows) r.read<String>('title')];
    }

    testWidgets('saves the ready rows in page order, library and online mixed', (tester) async {
      late WidgetRef w;
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: Consumer(builder: (_, ref, _) {
          w = ref;
          return const SizedBox();
        }),
      ));
      Track? lib;
      await tester.runAsync(() async => lib = await db.select(db.tracks).getSingle());
      String? name, second;
      await tester.runAsync(() async {
        await PlaylistRepository(db).create('Mix');
        final matches = [
          TrackReady.online(ytmSong('y1', 'Online one')),
          const TrackNotFound(),
          TrackReady.library(lib!),
          const TrackPending(),
          TrackReady.online(ytmSong('y2', 'Online two')),
        ];
        name = await saveToLibrary(w, ' Mix ', matches);
        second = await saveToLibrary(w, 'Mix', const [TrackNotFound()]);
      });
      expect(name, 'Mix (2)');
      expect(second, isNull);
      List<String>? titles;
      await tester.runAsync(() async {
        final lists = await db.select(db.playlists).get();
        titles = await titlesOf(lists.singleWhere((p) => p.name == 'Mix (2)').id);
      });
      expect(titles, ['Online one', 'Lib', 'Online two']);
    });

    testWidgets('a blank page title gives the fallback name; a failure midway leaves no playlist', (tester) async {
      late WidgetRef w;
      await tester.pumpWidget(ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: Consumer(builder: (_, ref, _) {
          w = ref;
          return const SizedBox();
        }),
      ));
      Track? lib;
      String? name;
      Object? failure;
      await tester.runAsync(() async {
        lib = await db.select(db.tracks).getSingle();
        name = await saveToLibrary(w, '   ', [TrackReady.online(ytmSong('y1', 'One'))], fallback: 'Nuova');
        try {
          // A library row that does not exist: the playlist insert fails after the playlist was created.
          await saveToLibrary(w, 'Broken', [TrackReady.library(lib!.copyWith(id: 9999))]);
        } catch (e) {
          failure = e;
        }
      });
      expect(name, 'Nuova');
      expect(failure, isNotNull);
      await tester.runAsync(() async {
        expect([for (final p in await db.select(db.playlists).get()) p.name], ['Nuova']);
      });
    });

    test('Aggiorna with one extra track asks for that one only; gone rows leave the page', () async {
      final c = externalContainer();
      const ref = OnlineCollectionRef.external(link);
      final sub = c.listen(onlineMatchesProvider(ref), (_, _) {});
      await turn();
      matcher.out.add((0, TrackReady.online(ytmSong('a', 'One'))));
      matcher.out.add((1, TrackReady.online(ytmSong('b', 'Two'))));
      matcher.out.add((2, TrackReady.online(ytmSong('c', 'Three'))));
      await turn();
      reader.order = ['One', 'Three', 'Four'];
      await c.refresh(onlineCollectionProvider(ref).future);
      await turn();
      expect(matcher.asked, [
        ['One', 'Two', 'Three'],
        ['Four']
      ]);
      final rows = c.read(onlineMatchesProvider(ref)).value!;
      expect(rows.map((m) => m.runtimeType), [TrackReadyOnline, TrackReadyOnline, TrackPending]);
      sub.close();
    });
  });

  test('the matcher of a page uses the link-match limiter and the shared cooldown', () async {
    final limiter = WindowLimiter(perMinute: 40);
    final cooldown = SourceCooldown();
    final yt = _OneSong();
    final c = ProviderContainer(overrides: [
      linkMatchLimiterProvider.overrideWithValue(limiter),
      sourceCooldownProvider.overrideWithValue(cooldown),
      youtubeServiceProvider.overrideWithValue(yt),
      trackRepositoryProvider.overrideWithValue(_Repo()),
      libraryIndexProvider.overrideWith((ref) => LibraryIndex(const [])),
      settingsProvider.overrideWith(_Settings.new),
    ]);
    addTearDown(c.dispose);
    await c.read(libraryIndexProvider.future);
    final m = c.read(collectionMatcherProvider(Object()));
    expect(m.limiter, same(limiter));
    expect(m.cooldown, same(cooldown));
    await m
        .match(const [ExternalTrack(title: 'Time', artists: ['Pink Floyd'], key: 't')]).toList();
    expect(limiter.recent, greaterThan(0));
  });
}

class _OneSong implements YoutubeService {
  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async => const [];
  @override
  Future<List<YtResult>> search(String query) async => const [];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Repo implements TrackRepository {
  @override
  Future<Track?> getById(int id) async => null;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Settings extends SettingsNotifier {
  @override
  AppSettings build() => AppSettings();
}

class _Deezer implements DeezerClient {
  int calls = 0;
  bool fail = false;
  final asked = <int>[];
  final empty = <int>{}; // chart ids that answer with no songs
  @override
  Future<List<DeezerTrack>> chart(int genreId, {int limit = 20, CancelToken? cancel}) async {
    calls++;
    asked.add(genreId);
    if (fail) throw const SocketException('offline');
    if (empty.contains(genreId)) return const [];
    return [
      for (var i = 1; i <= 2; i++) DeezerTrack(id: i, title: 'Song $i', artist: 'Band', duration: 200),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Apple implements AppleRssClient {
  int calls = 0;
  bool fail = false;
  Iterable<String>? genreIds;
  @override
  Future<List<AppleSong>?> mostPlayed(String country,
      {Iterable<String> genreIds = const [], CancelToken? cancel}) async {
    calls++;
    this.genreIds = genreIds;
    if (fail) throw const SocketException('offline');
    return [for (var i = 0; i < 30; i++) AppleSong(title: 'Hit $i', artist: 'Star', genreIds: const ['21'])];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void _chartTests() {
  final rock = chartGenres.firstWhere((g) => g.id == 'rock');
  final ref = ChartRef(rock);
  var clock = DateTime(2026, 11, 16, 9);
  late CatalogCache cache;
  late _Deezer deezer;
  late _Apple apple;
  late _Matcher matcher;

  setUp(() {
    clock = DateTime(2026, 11, 16, 9);
    final dir = Directory.systemTemp.createTempSync('chart_cache');
    cache = CatalogCache(
        file: () async => File('${dir.path}/c.json'), now: () => clock, writeDelay: Duration.zero);
    addTearDown(() async {
      await cache.dispose();
      dir.deleteSync(recursive: true);
    });
    deezer = _Deezer();
    apple = _Apple();
  });

  // A new container each time: a reopened page, the cache surviving.
  ProviderContainer open() {
    matcher = _Matcher();
    final c = ProviderContainer(overrides: [
      catalogCacheProvider.overrideWithValue(cache),
      deezerClientProvider.overrideWithValue(deezer),
      appleRssClientProvider.overrideWithValue(apple),
      settingsProvider.overrideWith(_Settings.new),
      collectionMatcherProvider.overrideWith((ref, page) => matcher),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  // Listened to, as a page is: an auto-dispose read alone would drop the page mid-read.
  Future<CollectionPage> read(ProviderContainer c) {
    c.listen(onlineCollectionProvider(ref), (_, _) {}, onError: (_, _) {});
    return c.read(onlineCollectionProvider(ref).future);
  }

  Future<void> turn() => Future<void>.delayed(const Duration(milliseconds: 20));

  test('a fresh chart does no client call and no search; its matches come from the cache', () async {
    var c = open();
    final sub = c.listen(onlineMatchesProvider(ref), (_, _) {});
    await turn();
    matcher.out.add((0, TrackReady.online(ytmSong('y1', 'Song 1'))));
    matcher.out.add((1, const TrackNotFound()));
    await turn();
    sub.close();
    expect(deezer.calls, 1);

    clock = clock.add(const Duration(hours: 23));
    c = open();
    final rows = <List<TrackMatch>>[];
    c.listen(onlineMatchesProvider(ref), (_, n) => n.whenData(rows.add));
    await turn();
    expect(deezer.calls, 1);
    expect(apple.calls, 0);
    expect(matcher.asked, isEmpty);
    expect(rows.last.map((m) => m.runtimeType), [TrackReadyOnline, TrackNotFound]);
    // Adding matches did not renew the copy: it is still the 9:00 one.
    expect((await read(c)).chart!.updated, DateTime(2026, 11, 16, 9));
  });

  test('Deezer failing falls back to Apple, filtered by the genre ids, 20 rows', () async {
    deezer.fail = true;
    final page = await read(open());
    expect(apple.genreIds, rock.appleGenreIds);
    expect(page.chart!.apple, isTrue);
    expect(page.collection.tracks, hasLength(20));
    expect(page.collection.tracks.first.durationMs, isNull);
  });

  test('offline, the expired copy opens with its own date', () async {
    await read(open());
    clock = clock.add(const Duration(hours: 25));
    deezer.fail = true;
    apple.fail = true;
    final page = await read(open());
    expect(page.collection.tracks.map((t) => t.title), ['Song 1', 'Song 2']);
    expect(page.chart!.updated, DateTime(2026, 11, 16, 9));
    expect(page.chart!.apple, isFalse);
  });

  test('no copy and no source: the page fails', () async {
    deezer.fail = true;
    apple.fail = true;
    await expectLater(read(open()), throwsA(isA<CollectionUnreadable>()));
  });

  test('an expired copy with the network available is fetched again', () async {
    await read(open());
    clock = clock.add(const Duration(hours: 25));
    await read(open());
    expect(deezer.calls, 2);
  });

  test('Deezer empty for the main chart tries the fallback chart', () async {
    final dance = chartGenres.firstWhere((g) => g.id == 'dance');
    deezer.empty.add(dance.deezer!);
    final c = open();
    final r = OnlineCollectionRef.chart(dance);
    c.listen(onlineCollectionProvider(r), (_, _) {});
    final page = await c.read(onlineCollectionProvider(r).future);
    expect(deezer.asked, [dance.deezer, dance.fallbackDeezer]);
    expect(page.chart!.apple, isFalse);
    expect(page.collection.tracks, hasLength(2));
    expect(apple.calls, 0);
  });

  test('Deezer empty for both charts goes to Apple', () async {
    final dance = chartGenres.firstWhere((g) => g.id == 'dance');
    deezer.empty.addAll([dance.deezer!, dance.fallbackDeezer!]);
    final c = open();
    final r = OnlineCollectionRef.chart(dance);
    c.listen(onlineCollectionProvider(r), (_, _) {});
    final page = await c.read(onlineCollectionProvider(r).future);
    expect(page.chart!.apple, isTrue);
  });

  for (final bad in <String, Object?>{
    'a wrong shape': {'apple': false, 'tracks': {'x': 1}},
    'a wrong duration type': {'apple': false, 'tracks': [{'t': 'Old', 'ms': 'x'}]},
    'no songs': {'apple': false, 'tracks': []},
  }.entries) {
    test('a cached entry with ${bad.key} is fetched again, no exception', () async {
      await cache.put(CatalogKind.chart, 'rock', bad.value);
      final page = await read(open());
      if (bad.key != 'a wrong duration type') {
        expect(deezer.calls, 1);
        expect(page.collection.tracks.map((t) => t.title), ['Song 1', 'Song 2']);
      } else {
        expect(page.collection.tracks.single.durationMs, isNull);
      }
    });
  }

  test('a Deezer chart is cached by genre alone: the country does not change the key', () async {
    await read(open());
    expect(await cache.get(CatalogKind.chart, 'rock'), isNotNull);
  });

  test('a locale country that is not 2 letters falls back to us', () {
    expect(chartCountry('419', rock), 'US');
    expect(chartCountry('it', rock), 'IT');
  });

  test('a re-read keeps the ready matches but asks again for the not-found ones', () async {
    var c = open();
    var sub = c.listen(onlineMatchesProvider(ref), (_, _) {});
    await turn();
    matcher.out.add((0, TrackReady.online(ytmSong('y1', 'Song 1'))));
    matcher.out.add((1, const TrackNotFound()));
    await turn();
    sub.close();
    c = open();
    c.read(chartRefetchProvider).add(ref);
    final rows = <List<TrackMatch>>[];
    sub = c.listen(onlineMatchesProvider(ref), (_, n) => n.whenData(rows.add));
    await turn();
    expect(deezer.calls, 2);
    expect(rows.last.map((m) => m.runtimeType), [TrackReadyOnline, TrackPending]);
    expect(matcher.asked, [
      ['Song 2']
    ]);
    sub.close();
  });

  testWidgets('a refresh that gets no new data says so', (tester) async {
    late WidgetRef w;
    await tester.runAsync(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          catalogCacheProvider.overrideWithValue(cache),
          deezerClientProvider.overrideWithValue(deezer),
          appleRssClientProvider.overrideWithValue(apple),
          settingsProvider.overrideWith(_Settings.new),
          collectionMatcherProvider.overrideWith((ref, page) => _Matcher()),
        ],
        child: Consumer(builder: (_, r, _) {
          w = r;
          r.watch(onlineCollectionProvider(ref));
          return const SizedBox();
        }),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      deezer.fail = true;
      apple.fail = true;
      expect(await refreshOnlineCollection(w, ref), isFalse);
    });
  });
}

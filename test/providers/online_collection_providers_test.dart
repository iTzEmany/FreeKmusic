import 'package:codecore/data/settings/settings_store.dart' show AppSettings;
import 'package:codecore/services/online/source_cooldown.dart';
import 'package:codecore/services/online/request_budget.dart';
import 'package:codecore/services/import/track_matcher.dart' show LibraryIndex;
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/db/app_database.dart' show Track;
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/library_providers.dart' show libraryIndexProvider;
import 'package:codecore/providers/database_providers.dart' show trackRepositoryProvider;
import 'package:codecore/providers/online_collection_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
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
  final out = StreamController<(int, TrackMatch)>();
  bool cancelled = false;
  @override
  Stream<(int, TrackMatch)> match(List<ExternalTrack> tracks) {
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

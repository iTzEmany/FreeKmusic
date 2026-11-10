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
  @override
  Future<ExternalCollection> read(ExternalLink link, {CancelToken? cancelToken}) async {
    this.link = link;
    token = cancelToken;
    return ExternalCollection(
      title: 'Deezer mix',
      kind: CollectionKind.playlist,
      sourceUrl: 'https://www.deezer.com/playlist/1',
      tracks: [for (final n in ['One', 'Two', 'Three']) ExternalTrack(title: n, artists: ['A'], key: 'same')],
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
}

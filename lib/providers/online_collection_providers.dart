import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import 'database_providers.dart' show databaseProvider, playlistRepositoryProvider, trackRepositoryProvider;
import '../services/online/catalog_cache.dart' show CatalogKind;
import '../services/online/chart_genres.dart';
import '../services/online/deezer_client.dart' show DeezerCollectionReader;
import '../services/online/external_collection.dart';
import '../services/online/external_links.dart';
import '../services/online/search_cache.dart' show ytResultFromJson, ytResultToJson;
import '../services/online/short_link_resolver.dart';
import '../services/online/spotify_embed_reader.dart';
import '../services/online/youtube_service.dart' show PlaylistListing;
import 'online_providers.dart' show appleRssClientProvider, deezerClientProvider, webClientProvider;
import 'settings_providers.dart' show settingsProvider;
import 'smart_search_providers.dart' show collectionMatcherProvider;
import 'ytm_catalog_providers.dart' show catalogCacheProvider;
import 'youtube_providers.dart';

/// Where a collection page reads from.
@immutable
sealed class OnlineCollectionRef {
  const OnlineCollectionRef();

  /// A YouTube playlist or channel address (`listingUrl`).
  const factory OnlineCollectionRef.youtubeListing(String url) = YoutubeListingRef;

  /// A Deezer or Spotify page.
  const factory OnlineCollectionRef.external(ExternalLink link) = ExternalRef;

  /// A share link, resolved when the page is read.
  const factory OnlineCollectionRef.shortLink(String url) = ExternalRef.short;

  /// The Top 20 of a macro-genre (Deezer chart, Apple's feed as fallback).
  const factory OnlineCollectionRef.chart(ChartGenre genre) = ChartRef;
}

class ChartRef extends OnlineCollectionRef {
  const ChartRef(this.genre);
  final ChartGenre genre;

  @override
  bool operator ==(Object other) => other is ChartRef && other.genre.id == genre.id;

  @override
  int get hashCode => genre.id.hashCode;
}

/// Where a chart page came from, for the line under its title.
class ChartInfo {
  const ChartInfo({required this.apple, required this.country, required this.updated});

  /// Apple's feed (of [country]); false = Deezer, whose chart follows the caller's IP.
  final bool apple;
  final String country;
  final DateTime updated;
}

class ExternalRef extends OnlineCollectionRef {
  const ExternalRef(ExternalLink this.link) : shortUrl = null;
  const ExternalRef.short(String this.shortUrl) : link = null;

  final ExternalLink? link;
  final String? shortUrl;

  @override
  bool operator ==(Object other) =>
      other is ExternalRef && other.link == link && other.shortUrl == shortUrl;

  @override
  int get hashCode => Object.hash(link, shortUrl);
}

class YoutubeListingRef extends OnlineCollectionRef {
  const YoutubeListingRef(this.url);
  final String url;

  @override
  bool operator ==(Object other) => other is YoutubeListingRef && other.url == url;

  @override
  int get hashCode => url.hashCode;
}

/// The collection and one [TrackMatch] per track, same order.
class CollectionPage {
  const CollectionPage(this.collection, this.matches, {this.chart});
  final ExternalCollection collection;
  final List<TrackMatch> matches;

  /// Set on a chart page only.
  final ChartInfo? chart;
}

CollectionPage _fromListing(String url, PlaylistListing l) => CollectionPage(
      ExternalCollection(
        title: l.title,
        kind: CollectionKind.playlist,
        owner: l.owner,
        coverUrl: l.entries.firstOrNull?.thumbnailUrl,
        sourceUrl: url,
        truncated: l.truncated,
        tracks: [
          for (final r in l.entries)
            ExternalTrack(
              title: r.title,
              artists: r.artists.isEmpty ? [r.channel] : r.artists,
              durationMs: r.duration?.inMilliseconds,
              key: r.id,
            ),
        ],
      ),
      // Every YouTube row is already a playable result: no matching, no network.
      [for (final r in l.entries) TrackReady.online(r)],
    );

final shortLinkResolverProvider = Provider<ShortLinkResolver>((ref) => ShortLinkResolver());

final externalReaderProvider = Provider.family<ExternalReader, ExternalService>(
  (ref, service) => switch (service) {
    ExternalService.deezer => DeezerCollectionReader(ref.watch(deezerClientProvider)),
    ExternalService.spotify => SpotifyEmbedReader(ref.watch(webClientProvider)),
  },
);

/// What each external page has already matched (by [ExternalTrack.fingerprint]), for the whole
/// session: a page left and reopened goes on from there (D-525, D-530). Not
/// autoDispose on purpose; never written to disk.
final resolvedMatchesProvider =
    Provider.family<Map<String, TrackMatch>, OnlineCollectionRef>((ref, r) => {});

final onlineCollectionProvider =
    FutureProvider.autoDispose.family<CollectionPage, OnlineCollectionRef>(
  (ref, r) async => switch (r) {
    YoutubeListingRef(:final url) =>
      _fromListing(url, await ref.watch(playlistListingProvider(url).future)),
    ExternalRef() => await _readExternal(ref, r),
    ChartRef() => await _readChart(ref, r),
  },
  // A failure is shown with its own «Riprova».
  retry: (_, _) => null,
);

/// An external page as soon as it is read: every row not matched yet is
/// pending. Dropping it cancels the reads.
Future<CollectionPage> _readExternal(Ref ref, ExternalRef r) async {
  final cancel = CancelToken();
  ref.onDispose(cancel.cancel);
  final link = r.link ??
      parseExternalLink(
          await ref.read(shortLinkResolverProvider).resolve(r.shortUrl!, cancelToken: cancel));
  if (link == null) throw const CollectionNotFound();
  final c = await ref.read(externalReaderProvider(link.service)).read(link, cancelToken: cancel);
  final done = ref.read(resolvedMatchesProvider(r));
  return CollectionPage(c, [
    for (var i = 0; i < c.tracks.length; i++) done[c.tracks[i].fingerprint] ?? const TrackPending(),
  ]);
}

/// Charts to read from the clients on the next read even if the cache is fresh (pull to refresh).
final chartRefetchProvider = Provider<Set<ChartRef>>((ref) => {});

/// The country of a chart: the genre's own, else the chosen one, else the device's.
String chartCountry(String chosen, ChartGenre g) {
  final c = g.fixedCountry ?? (chosen.isNotEmpty ? chosen : PlatformDispatcher.instance.locale.countryCode ?? '');
  // Only a 2-letter code makes a valid Apple URL (a locale may give «419»).
  return (RegExp(r'^[A-Za-z]{2}$').hasMatch(c) ? c : 'us').toUpperCase();
}

/// A chart page: the fresh cached copy as is (RNF-02: no client call, and the matches
/// stored with it mean no search either); else Deezer, then Deezer's fallback chart, then
/// Apple's feed; offline, the expired copy with its date.
Future<CollectionPage> _readChart(Ref ref, ChartRef r) async {
  final g = r.genre;
  final country = chartCountry(ref.read(settingsProvider).chartCountry, g);
  final cache = ref.read(catalogCacheProvider);
  final key = _chartKey(g, country);
  final cached = await cache.get(CatalogKind.chart, key);
  var json = _readableChart(cached?.json) ? cached!.json as Map : null;
  var updated = cached?.storedAt;
  final refetch = ref.read(chartRefetchProvider).remove(r);
  if (json == null || cached!.expired || refetch) {
    final cancel = CancelToken();
    ref.onDispose(cancel.cancel);
    final fresh = await _fetchChart(ref, g, country, cancel);
    if (fresh != null) {
      // Matches made for the same songs stay valid.
      final old = json?['m'];
      final keep = {
        if (old is Map)
          for (final t in fresh.tracks)
            if (_matchFromJson(old[t.fingerprint]) is TrackReadyOnline) t.fingerprint: old[t.fingerprint],
      };
      json = {'apple': fresh.apple, 'tracks': [for (final t in fresh.tracks) _trackToJson(t)], 'm': keep};
      updated = DateTime.now();
      await cache.put(CatalogKind.chart, key, json);
    } else if (json == null) {
      throw const CollectionUnreadable();
    }
  }
  final tracks = [for (final t in (json['tracks'] as List? ?? const [])) ?_trackFromJson(t)];
  final stored = json['m'] is Map ? json['m'] as Map : const {};
  final done = ref.read(resolvedMatchesProvider(r));
  return CollectionPage(
    ExternalCollection(
      title: 'Top 20 ${g.id}', // the page titles itself from the genre label
      kind: CollectionKind.playlist,
      sourceUrl: 'chart:$key',
      tracks: tracks,
    ),
    [for (final t in tracks) done[t.fingerprint] ?? _matchFromJson(stored[t.fingerprint]) ?? const TrackPending()],
    chart: ChartInfo(apple: json['apple'] == true, country: country, updated: updated!),
  );
}

// Key: «genre» (Deezer follows the IP) or «genre:COUNTRY» (Apple feed or a genre with its own country).
String _chartKey(ChartGenre g, String country) =>
    g.fixedCountry != null || g.deezer == null ? '${g.id}:$country' : g.id;

/// A cached entry that can be shown: a map with a non-empty list of well-formed tracks.
bool _readableChart(Object? j) =>
    j is Map && j['tracks'] is List && (j['tracks'] as List).isNotEmpty && (j['tracks'] as List).every((t) => _trackFromJson(t) != null);

Future<({bool apple, List<ExternalTrack> tracks})?> _fetchChart(
    Ref ref, ChartGenre g, String country, CancelToken cancel) async {
  for (final id in [?g.deezer, ?g.fallbackDeezer]) {
    try {
      final songs = await ref.read(deezerClientProvider).chart(id, cancel: cancel);
      if (songs.isNotEmpty) {
        return (
          apple: false,
          tracks: [
            for (final t in songs)
              ExternalTrack(
                title: t.title,
                artists: [if (t.artist.isNotEmpty) t.artist],
                durationMs: t.duration > 0 ? t.duration * 1000 : null,
                isrc: t.isrc,
                key: '${t.id}',
              ),
          ],
        );
      }
    } on Object catch (e, st) {
      if (cancel.isCancelled) rethrow;
      AppLog.w('chart ${g.id}: deezer $id failed', e, st);
    }
  }
  try {
    final songs = await ref
        .read(appleRssClientProvider)
        .mostPlayed(country, genreIds: g.appleGenreIds, cancel: cancel);
    if (songs != null && songs.isNotEmpty) {
      return (
        apple: true,
        tracks: [
          for (final (i, t) in songs.take(20).indexed)
            ExternalTrack(title: t.title, artists: [if (t.artist.isNotEmpty) t.artist], key: '$i'),
        ],
      );
    }
  } on Object catch (e, st) {
    if (cancel.isCancelled) rethrow;
    AppLog.w('chart ${g.id}: apple feed failed', e, st);
  }
  return null;
}

Map<String, Object?> _trackToJson(ExternalTrack t) =>
    {'t': t.title, 'a': t.artists, 'ms': t.durationMs, 'i': t.isrc, 'k': t.key};

ExternalTrack? _trackFromJson(Object? j) => j is Map && j['t'] is String
    ? ExternalTrack(
        title: j['t'] as String,
        artists: [for (final a in (j['a'] as List? ?? const [])) '$a'],
        durationMs: j['ms'] is int ? j['ms'] as int : null,
        isrc: j['i'] as String?,
        key: '${j['k']}',
      )
    : null;

/// What is stored of a settled match: a stream result or «non trovato» (a library match
/// depends on the library, so it is asked again).
TrackMatch? _matchFromJson(Object? j) {
  if (j is! Map) return null;
  if (j['nf'] == true) return const TrackNotFound();
  final r = ytResultFromJson(j);
  return r == null ? null : TrackReady.online(r);
}

Future<void> _saveChartMatch(Ref ref, ChartRef r, ChartInfo info, String fingerprint, TrackMatch m) async {
  final j = switch (m) {
    TrackReadyOnline(:final result) => ytResultToJson(result),
    TrackNotFound(transient: false) => {'nf': true},
    _ => null,
  };
  if (j == null) return;
  final cache = ref.read(catalogCacheProvider);
  final key = _chartKey(r.genre, info.country);
  final json = (await cache.get(CatalogKind.chart, key))?.json;
  if (json is! Map) return;
  final stored = json['m'] is Map ? json['m'] as Map : const {};
  await cache.put(CatalogKind.chart, key, {...json, 'm': {...stored, fingerprint: j}}, keepDate: true);
}

/// The rows of an external page, again after each one the matcher settles (the
/// page itself is [onlineCollectionProvider]). Dropping it cancels the matcher.
final onlineMatchesProvider =
    StreamProvider.autoDispose.family<List<TrackMatch>, OnlineCollectionRef>((ref, r) async* {
  final page = await ref.watch(onlineCollectionProvider(r).future);
  final done = ref.read(resolvedMatchesProvider(r));
  final matches = [
    for (var i = 0; i < page.matches.length; i++)
      done[page.collection.tracks[i].fingerprint] ?? page.matches[i],
  ];
  yield List.of(matches);
  final todo = [
    for (var i = 0; i < matches.length; i++)
      if (matches[i] is TrackPending) i,
  ];
  if (todo.isEmpty) return;
  final matcher = ref.watch(collectionMatcherProvider(r));
  await for (final (j, m) in matcher.match([for (final i in todo) page.collection.tracks[i]])) {
    final fingerprint = page.collection.tracks[todo[j]].fingerprint;
    if (!(m is TrackNotFound && m.transient)) done[fingerprint] = m;
    if (r is ChartRef) await _saveChartMatch(ref, r, page.chart!, fingerprint, m);
    matches[todo[j]] = m;
    yield List.of(matches);
  }
});

/// Pull to refresh: waits for the new read; on failure the old rows stay, it is
/// logged and false is returned.
Future<bool> refreshOnlineCollection(WidgetRef ref, OnlineCollectionRef r) async {
  try {
    switch (r) {
      case YoutubeListingRef(:final url):
        final _ = await ref.refresh(playlistListingProvider(url).future);
      case ExternalRef() || ChartRef():
        if (r is ChartRef) ref.read(chartRefetchProvider).add(r);
        // Matches already made are kept: only the unresolved rows are asked again.
        // The matches provider rebuilds by itself from the new page.
        final start = DateTime.now();
        final page = await ref.refresh(onlineCollectionProvider(r).future);
        // No new data (the sources failed): the old copy came back.
        if (page.chart case final c? when c.updated.isBefore(start)) return false;
    }
    return true;
  } on Object catch (e, st) {
    AppLog.w('online collection: refresh failed', e, st);
    return false;
  }
}

/// «Riprova»: asks the source again (invalidating the page alone would reuse its error).
void retryOnlineCollection(WidgetRef ref, OnlineCollectionRef r) => switch (r) {
      YoutubeListingRef(:final url) => ref.invalidate(playlistListingProvider(url)),
      ExternalRef() || ChartRef() => {ref.invalidate(onlineCollectionProvider(r)), ref.invalidate(onlineMatchesProvider(r))},
    };

/// «Salva in Libreria»: a playlist called like the page (« (2)», « (3)»… if the name is
/// taken) with the `ready` rows in page order; online rows become shadow rows, so the copy
/// streams and no longer depends on the page (D-524). Returns the playlist name and uuid, or null
/// when no row is ready yet (nothing is created). A blank [title] becomes [fallback].
Future<({String name, String? uuid})?> saveToLibrary(WidgetRef ref, String title, List<TrackMatch> matches, {String fallback = 'Playlist'}) async {
  final ready = matches.whereType<TrackReady>().toList();
  if (ready.isEmpty) return null;
  final playlists = ref.read(playlistRepositoryProvider);
  final tracks = ref.read(trackRepositoryProvider);
  final base = title.trim().isEmpty ? fallback : title.trim();
  return ref.read(databaseProvider).transaction(() async {
    var name = base, n = 1;
    while (await playlists.nameTaken(name)) {
      name = '$base (${++n})';
    }
    final id = await playlists.create(name);
    final ids = <int>[
      for (final m in ready)
        switch (m) {
          TrackReadyLibrary(:final track) => track.id,
          TrackReadyOnline(:final result) => await tracks.ensureStreamRow(result),
        },
    ];
    await playlists.addStreamTracks(id, ids);
    return (name: name, uuid: await playlists.uuidOf(id));
  });
}

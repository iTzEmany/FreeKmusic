import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../services/online/deezer_client.dart' show DeezerCollectionReader;
import '../services/online/external_collection.dart';
import '../services/online/external_links.dart';
import '../services/online/short_link_resolver.dart';
import '../services/online/spotify_embed_reader.dart';
import '../services/online/youtube_service.dart' show PlaylistListing;
import 'online_providers.dart' show deezerClientProvider, webClientProvider;
import 'smart_search_providers.dart' show collectionMatcherProvider;
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
  const CollectionPage(this.collection, this.matches);
  final ExternalCollection collection;
  final List<TrackMatch> matches;
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

/// What each external page has already matched (by row index), for the whole
/// session: a page left and reopened goes on from there (D-525, D-530). Not
/// autoDispose on purpose; never written to disk.
final resolvedMatchesProvider =
    Provider.family<Map<int, TrackMatch>, OnlineCollectionRef>((ref, r) => {});

final onlineCollectionProvider =
    FutureProvider.autoDispose.family<CollectionPage, OnlineCollectionRef>(
  (ref, r) async => switch (r) {
    YoutubeListingRef(:final url) =>
      _fromListing(url, await ref.watch(playlistListingProvider(url).future)),
    ExternalRef() => await _readExternal(ref, r),
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
    for (var i = 0; i < c.tracks.length; i++) done[i] ?? const TrackPending(),
  ]);
}

/// The rows of an external page, again after each one the matcher settles (the
/// page itself is [onlineCollectionProvider]). Dropping it cancels the matcher.
final onlineMatchesProvider =
    StreamProvider.autoDispose.family<List<TrackMatch>, OnlineCollectionRef>((ref, r) async* {
  final page = await ref.watch(onlineCollectionProvider(r).future);
  final matches = List.of(page.matches);
  yield List.of(matches);
  final todo = [
    for (var i = 0; i < matches.length; i++)
      if (matches[i] is TrackPending) i,
  ];
  if (todo.isEmpty) return;
  final done = ref.read(resolvedMatchesProvider(r));
  final matcher = ref.watch(collectionMatcherProvider(r));
  await for (final (j, m) in matcher.match([for (final i in todo) page.collection.tracks[i]])) {
    done[todo[j]] = m;
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
      case ExternalRef():
        // Matches already made are kept: only the unresolved rows are asked again.
        ref.invalidate(onlineCollectionProvider(r));
        ref.invalidate(onlineMatchesProvider(r));
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
      ExternalRef() => {ref.invalidate(onlineCollectionProvider(r)), ref.invalidate(onlineMatchesProvider(r))},
    };

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../services/online/external_collection.dart';
import '../services/online/youtube_service.dart' show PlaylistListing;
import 'youtube_providers.dart';

/// Where a collection page reads from.
@immutable
sealed class OnlineCollectionRef {
  const OnlineCollectionRef();

  /// A YouTube playlist or channel address (`listingUrl`).
  const factory OnlineCollectionRef.youtubeListing(String url) = YoutubeListingRef;
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

final onlineCollectionProvider =
    FutureProvider.autoDispose.family<CollectionPage, OnlineCollectionRef>(
  (ref, r) async => switch (r) {
    YoutubeListingRef(:final url) =>
      _fromListing(url, await ref.watch(playlistListingProvider(url).future)),
  },
  // A failure is shown with its own «Riprova».
  retry: (_, _) => null,
);

/// Pull to refresh: waits for the new read; on failure the old rows stay, it is
/// logged and false is returned.
Future<bool> refreshOnlineCollection(WidgetRef ref, OnlineCollectionRef r) async {
  try {
    switch (r) {
      case YoutubeListingRef(:final url):
        final _ = await ref.refresh(playlistListingProvider(url).future);
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
    };

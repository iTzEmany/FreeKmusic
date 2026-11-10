import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../services/import/track_matcher.dart' show MatchThresholds;
import '../services/online/collection_matcher.dart';
import '../services/online/merge_results.dart';
import '../services/online/request_budget.dart';
import '../services/online/query_match.dart' show libraryArtistKey;
import '../services/online/smart_search.dart';
import '../services/online/source_cooldown.dart';
import 'database_providers.dart' show trackRepositoryProvider;
import 'library_providers.dart' show artistsProvider, libraryIndexProvider;
import 'settings_providers.dart' show settingsProvider;
import 'youtube_providers.dart';
import 'ytm_catalog_providers.dart';

/// The pauses of the sources that said «too many requests», kept for the session.
final sourceCooldownProvider = Provider<SourceCooldown>((ref) => SourceCooldown());

/// The 20-per-minute budget of the artist/album rows, shared with the merge suggestions (D-425).
final searchRowsLimiterProvider =
    Provider<WindowLimiter>((ref) => WindowLimiter(perMinute: kSearchRowsPerMinute));

/// The 40-per-minute budget of the link-page matching: its own, so a long
/// collection never uses up Cerca's (D-526). Only the 429 pause is shared.
final linkMatchLimiterProvider =
    Provider<WindowLimiter>((ref) => WindowLimiter(perMinute: kLinkMatchPerMinute));

/// Matches the songs of a link page; cancelled when the provider is dropped.
final collectionMatcherProvider = Provider.autoDispose<CollectionMatcher>((ref) {
  final tracks = ref.watch(trackRepositoryProvider);
  final matcher = CollectionMatcher(
    youtube: ref.watch(youtubeServiceProvider),
    cooldown: ref.watch(sourceCooldownProvider),
    limiter: ref.watch(linkMatchLimiterProvider),
    library: () => ref.read(libraryIndexProvider).value,
    trackById: tracks.getById,
    thresholds: () {
      final s = ref.read(settingsProvider);
      return MatchThresholds(sure: s.importSureThreshold, review: s.importReviewThreshold)
          .clamped();
    },
  );
  ref.onDispose(matcher.cancel);
  return matcher;
});

/// Keys of the artists in the library, rebuilt only when the library's artists
/// change; the online search favours their results for a phrase with no artist.
final libraryArtistKeysProvider = Provider<Set<String>>((ref) {
  final artists = ref.watch(artistsProvider).value ?? const [];
  final keys = {for (final a in artists) libraryArtistKey(a.name ?? '')};
  return keys..remove('');
});

/// The engine; holds the 10-minute copy of recent searches.
final smartSearchEngineProvider = Provider<SmartSearch>((ref) => SmartSearch(
      youtube: ref.watch(youtubeServiceProvider),
      catalog: ref.watch(ytmCatalogProvider),
      cooldown: ref.watch(sourceCooldownProvider),
      rowsLimiter: ref.watch(searchRowsLimiterProvider),
      libraryArtists: () => ref.read(libraryArtistKeysProvider),
    ));

/// One online search. [serial] makes a new submit of the same text a new
/// request (the page counts them); with `refresh` the saved copy is skipped.
/// Leaving a request (the page asks for another one) disposes it, which
/// cancels the stream and so drops the answers still on their way.
typedef SmartSearchRequest = ({String query, bool refresh, int serial});

final smartSearchProvider = StreamProvider.autoDispose
    .family<SmartSearchState, SmartSearchRequest>((ref, request) {
  return ref.watch(smartSearchEngineProvider).run(
        request.query,
        ref.read(ytmLanguageProvider),
        refresh: request.refresh,
      );
});

/// D-399: the page without the songs the library already has (or has
/// downloaded), worked out once per result and per read of the library or of the
/// download index (the key is the state itself), not at every build. Null while
/// the library index is not ready or the page is not a song search.
final ownedSplitProvider = Provider.autoDispose.family<OwnedSplit?, SmartSearchState>((ref, s) {
  if (!s.showsLibrary) return null;
  final index = ref.watch(libraryIndexProvider).value;
  if (index == null) return null;
  final downloads = ref.watch(downloadIndexProvider).value;
  return OwnedSplit(s.best, s.others, index,
      downloadPath: (r) => downloads?.pathFor(r.id, source: r.source));
});

/// The library tracks the hidden online rows stand for.
final ownedTracksProvider = FutureProvider.autoDispose.family<List<Track>, OwnedSplit>(
  (ref, owned) => ref.watch(trackRepositoryProvider).getByIds(owned.matchIds),
);

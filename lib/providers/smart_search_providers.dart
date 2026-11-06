import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../services/online/merge_results.dart';
import '../services/online/query_intent.dart' show QueryKind;
import '../services/online/query_match.dart' show libraryArtistKey;
import '../services/online/smart_search.dart';
import '../services/online/source_cooldown.dart';
import 'database_providers.dart' show trackRepositoryProvider;
import 'library_providers.dart' show artistsProvider, libraryIndexProvider;
import 'youtube_providers.dart';
import 'ytm_catalog_providers.dart';

/// The pauses of the sources that said «too many requests», kept for the session.
final sourceCooldownProvider = Provider<SourceCooldown>((ref) => SourceCooldown());

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

/// D-399: the page without the songs the library already has, worked out once
/// per result and per read of the library (the key is the state itself), not
/// at every build. Null while the index is not ready or the text is not a song.
final ownedSplitProvider = Provider.autoDispose.family<OwnedSplit?, SmartSearchState>((ref, s) {
  if (s.queryKind != QueryKind.text || !libraryAppliesTo(s.intent)) return null;
  final index = ref.watch(libraryIndexProvider).value;
  return index == null ? null : OwnedSplit(s.best, s.others, index);
});

/// The library tracks the hidden online rows stand for.
final ownedTracksProvider = FutureProvider.autoDispose.family<List<Track>, OwnedSplit>(
  (ref, owned) => ref.watch(trackRepositoryProvider).getByIds(owned.matchIds),
);

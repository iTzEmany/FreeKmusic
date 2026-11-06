import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/repositories/artist_alias_repository.dart' show ArtistAliasRepository;
import '../services/import/track_matcher.dart' show matchKey;
import '../services/online/query_match.dart' show MediaKind;
import '../services/online/youtube_service.dart' show YtErrorKind, YtException;
import '../services/online/ytm_artist.dart';
import '../services/online/ytm_artist_resolver.dart' show artistNameKeys;
import 'database_providers.dart';
import 'smart_search_providers.dart';
import 'ytm_catalog_providers.dart';

export 'database_providers.dart' show artistAliasRepositoryProvider;

/// The group of [id] (main profile first, then aliases); follows merges and splits.
final artistGroupProvider = StreamProvider.autoDispose.family<List<String>, String>((ref, id) async* {
  final repo = ref.watch(artistAliasRepositoryProvider);
  // The drift watch emits at once, so no first read of its own.
  await for (final _ in repo.watchAliases()) {
    yield await repo.groupOf(id);
  }
});

/// Bumped after a merge or a «diversi» mark so the suggestions are asked again.
class ArtistMergeEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final artistMergeEpochProvider = NotifierProvider<ArtistMergeEpoch, int>(ArtistMergeEpoch.new);

/// Artist search for the suggestions, cached by name for the session; null when over budget.
final artistMergeSearchProvider = Provider<Future<List<YtmArtistRef>>? Function(String)>((ref) {
  final cache = <String, Future<List<YtmArtistRef>>>{};
  return (name) {
    final key = matchKey(name);
    final hit = cache[key];
    if (hit != null) return hit;
    // Same budget and 429 pause as the search rows (D-425).
    if (ref.read(sourceCooldownProvider).isPaused(MediaKind.ytmSong) ||
        !ref.read(searchRowsLimiterProvider).tryAcquire()) {
      return null;
    }
    return cache[key] = ref
        .read(ytmCatalogProvider)
        .searchArtists(name, ref.read(ytmLanguageProvider))
        .catchError((Object e, StackTrace st) {
      cache.remove(key);
      if (e is YtException && e.kind == YtErrorKind.rateLimited) ref.read(sourceCooldownProvider).trip(MediaKind.ytmSong);
      AppLog.w('Artist merge search failed', e, st);
      return <YtmArtistRef>[];
    });
  };
});

/// Another YouTube Music profile with the same name as [id]/[name], not yet in its
/// group and not marked «diversi»; null when there is none.
final artistMergeSuggestionProvider =
    FutureProvider.autoDispose.family<YtmArtistRef?, ({String id, String name})>((ref, a) async {
  ref.watch(artistMergeEpochProvider);
  try {
    // Watching the group asks again after a merge or a split; a «diversi» mark needs the epoch.
    final group = await ref.watch(artistGroupProvider(a.id).future);
    final found = await ref.read(artistMergeSearchProvider)(a.name);
    if (found == null) return null;
    final repo = ref.read(artistAliasRepositoryProvider);
    final keys = artistNameKeys(a.name);
    for (final c in found) {
      if (c.id == a.id || group.contains(c.id) || !keys.contains(matchKey(c.name))) continue;
      // D-414: a «diversi» pair holds for any member of either group.
      final theirs = await repo.groupOf(c.id);
      if (await _anyNotSame(repo, group, theirs)) continue;
      return c;
    }
  } catch (e, st) {
    AppLog.w('Artist merge suggestion failed', e, st);
  }
  return null;
});

Future<bool> _anyNotSame(ArtistAliasRepository repo, List<String> xs, List<String> ys) async {
  for (final x in xs) {
    for (final y in ys) {
      if (await repo.isNotSame(x, y)) return true;
    }
  }
  return false;
}

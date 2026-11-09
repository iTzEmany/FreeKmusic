import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart' show Track;
import '../services/import/track_matcher.dart' show libraryTitleKey;
import '../services/online/ytm_artist.dart' show YtmSongShelf;
import 'artist_shelves_providers.dart';
import '../services/online/youtube_service.dart' show YtResult;
import '../core/artist_key.dart';
import '../services/shuffle_plus/suggestion_pool.dart' show suggestionArtistKey;
import 'database_providers.dart';
import 'dislike_store_provider.dart';
import 'player_providers.dart' show MixItem;
import 'ytm_catalog_providers.dart';

/// The artist to play and the group ids of its page joined by «|»
/// (the key of [groupShelvesProvider]).
typedef ArtistAllSongsKey = ({String name, String ids});

/// What Play / Shuffle of an artist page plays (D-430, D-447, D-466).
typedef ArtistAllSongs = ({List<MixItem> items, bool topMissing});

MixItem _item({Track? track, YtResult? online}) =>
    (track: track, online: online, seedTitle: null);

/// The top songs in order (a downloaded one replaces its online version),
/// then the other downloaded songs of the artist. Page or catalog error: only
/// the downloaded ones, `topMissing` set. A page without «show all» link
/// uses the songs of its shelves.
final artistAllSongsProvider = FutureProvider.autoDispose
    .family<ArtistAllSongs, ArtistAllSongsKey>((ref, key) async {
      // A new block or an unblock: the list is worked out again.
      final store = ref.read(dislikeStoreProvider);
      final changes = store.changes.listen((_) => ref.invalidateSelf());
      ref.onDispose(changes.cancel);
      final local = await ref
          .read(trackRepositoryProvider)
          .tracksOfArtist(key.name);
      final shelves = ref.watch(groupShelvesProvider(key.ids));
      var top = const <YtResult>[];
      var missing = shelves == null;
      if (shelves != null) {
        final songShelves = shelves.whereType<YtmSongShelf>().toList();
        final link = songShelves.map((s) => s.allSongs).nonNulls.firstOrNull;
        if (link == null) {
          top = [for (final s in songShelves) ...s.songs];
        } else {
          try {
            top = (await ref.watch(
              artistSongsProvider((
                browseId: link.browseId,
                params: link.params,
              )).future,
            )).value;
          } on Object catch (e, st) {
            AppLog.w('artist top songs not read', e, st);
            missing = true;
          }
        }
      }
      // Blocked online songs (and all of a blocked artist's) are not played;
      // the user's own downloaded ones always are (D-468).
      await store.load();
      final pageArtist = artistKey(key.name);
      top = [
        for (final r in top)
          if (!store.trackBlocked(r.id) &&
              !store.artistBlocked(pageArtist) &&
              !store.artistBlocked(suggestionArtistKey(r)))
            r,
      ];
      final byTitle = <String, Track>{};
      for (final t in local.reversed) {
        byTitle[libraryTitleKey(t.title)] = t; // first of the list wins
      }
      final used = <int>{};
      final seen = <String>{};
      final items = <MixItem>[];
      for (final r in top) {
        final k = libraryTitleKey(r.title);
        if (!seen.add(k)) continue;
        final t = byTitle[k];
        if (t == null) {
          items.add(_item(online: r));
        } else if (used.add(t.id)) {
          items.add(_item(track: t));
        }
      }
      items.addAll([
        for (final t in local)
          if (!used.contains(t.id)) _item(track: t),
      ]);
      return (items: items, topMissing: missing);
    });

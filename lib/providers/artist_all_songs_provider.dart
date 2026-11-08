import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart' show Track;
import '../data/repositories/artist_info_repository.dart';
import '../data/repositories/light_tracks.dart';
import '../services/import/track_matcher.dart' show libraryTitleKey;
import '../services/library/rules/rule_country.dart';
import '../services/online/youtube_service.dart' show YtResult;
import 'database_providers.dart';
import 'player_providers.dart' show MixItem;
import 'ytm_catalog_providers.dart';

/// The artist to play and the link of its top songs (null: no top).
typedef ArtistAllSongsKey = ({String name, String? browseId, String? params});

/// What Play / Shuffle of an artist page plays (D-430, D-447, D-466).
typedef ArtistAllSongs = ({List<MixItem> items, bool topMissing});

MixItem _item({Track? track, YtResult? online}) =>
    (track: track, online: online, seedTitle: null);

/// The top songs in order (a downloaded one replaces its online version),
/// then the other downloaded songs of the artist. Catalog error: only the
/// downloaded ones, `topMissing` set.
final artistAllSongsProvider = FutureProvider.autoDispose
    .family<ArtistAllSongs, ArtistAllSongsKey>((ref, key) async {
      final db = ref.read(databaseProvider);
      final spellings = await spellingsOf(
        db,
        ArtistInfoRepository.keyOf(key.name),
      );
      final local = spellings.isEmpty
          ? const <Track>[]
          : await db
                .customSelect(
                  'SELECT ${lightTrackColumns(db)} FROM tracks WHERE missing = 0 '
                  'AND ignored = 0 AND kind = 0 AND artist IN '
                  '(${List.filled(spellings.length, '?').join(',')}) '
                  'ORDER BY title COLLATE NOCASE',
                  variables: [for (final s in spellings) Variable<String>(s)],
                  readsFrom: {db.tracks},
                )
                .map((r) => db.tracks.map(r.data))
                .get();
      var top = const <YtResult>[];
      var missing = false;
      final id = key.browseId;
      if (id != null) {
        try {
          top = (await ref.watch(
            artistSongsProvider((browseId: id, params: key.params)).future,
          )).value;
        } on Object catch (e, st) {
          AppLog.w('artist top songs not read', e, st);
          missing = true;
        }
      }
      final byTitle = <String, Track>{};
      for (final t in local.reversed) {
        byTitle[libraryTitleKey(t.title)] = t; // first of the list wins
      }
      final used = <int>{};
      final items = <MixItem>[];
      for (final r in top) {
        final t = byTitle[libraryTitleKey(r.title)];
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

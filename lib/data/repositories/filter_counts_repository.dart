import 'package:drift/drift.dart';

import '../../core/text_utils.dart';
import '../db/app_database.dart';
import 'artist_info_repository.dart';
import 'enrich_filter_queries.dart';

/// The lists of values the filter editor offers (F-91, D-393).
enum FilterList { artists, albumArtists, genres, countries, labels }

/// One value of a list and how many visible tracks carry it. [value] is what
/// goes into the rule (artist name, genre, ISO country code, label).
class ValueCount {
  const ValueCount(this.value, this.count);
  final String value;
  final int count;

  @override
  bool operator ==(Object other) => other is ValueCount && other.value == value && other.count == count;
  @override
  int get hashCode => Object.hash(value, count);
  @override
  String toString() => '$value:$count';
}

// Visible music tracks, as in the rest of the library.
const _visible = "t.missing = 0 AND t.ignored = 0 AND t.kind = 0";

/// A value of a list with the key its search and sort use, computed once.
typedef KeyedCount = ({ValueCount value, String key});

/// Aggregate counts for the editor's lists (D-394). Everything is SQL over the
/// database executor (off the UI thread). Each value is grouped the way the rule
/// `campo:"V"` compares it (`TRIM` + `NOCASE` in SQL), so a count is exactly the
/// number of tracks the rule selects; only the countries go through Dart, because
/// their key is the main artist's `matchKey`.
class FilterCountsRepository {
  FilterCountsRepository(this._db);

  final AppDatabase _db;

  /// Values of [list] with their track counts, most tracks first then by name;
  /// [query] keeps those whose name contains it (case, accents, spaces ignored).
  Future<List<ValueCount>> counts(FilterList list, {String query = ''}) async =>
      [for (final k in filterKeyed(await load(list), query)) k.value];

  /// [all] narrowed to the names containing [query]; in memory, no query.
  static List<KeyedCount> filterKeyed(List<KeyedCount> all, String query) {
    final q = normalize(query);
    return q.isEmpty ? all : [for (final k in all) if (k.key.contains(q)) k];
  }

  /// The whole list, sorted, with the normalised name of each value.
  Future<List<KeyedCount>> load(FilterList list) async {
    final all = switch (list) {
      FilterList.artists => await _artists(),
      FilterList.albumArtists => await _albumArtists(),
      FilterList.genres => await _genres(),
      FilterList.countries => await _countries(),
      FilterList.labels => await _labels(),
    };
    final keyed = [for (final v in all) (value: v, key: normalize(v.value))];
    keyed.sort((a, b) {
      final c = b.value.count.compareTo(a.value.count);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
    return keyed;
  }

  Future<List<ValueCount>> _grouped(String sql, Set<TableInfo> from) async {
    final rows = await _db.customSelect(sql, readsFrom: from).get();
    return [for (final r in rows) ValueCount(r.read<String>('v'), r.read<int>('n'))];
  }

  // `artista:"X"` is TRIM(artist) COLLATE NOCASE = X.
  Future<List<ValueCount>> _artists() => _grouped(
        "SELECT MIN(trim(t.artist)) AS v, COUNT(*) AS n FROM tracks t WHERE $_visible "
        "AND trim(COALESCE(t.artist, '')) <> '' GROUP BY trim(t.artist) COLLATE NOCASE",
        {_db.tracks},
      );

  // `artistaalbum:"X"` is TRIM(album_artist) COLLATE NOCASE = X.
  Future<List<ValueCount>> _albumArtists() => _grouped(
        "SELECT MIN(trim(t.album_artist)) AS v, COUNT(*) AS n FROM tracks t WHERE $_visible "
        "AND trim(COALESCE(t.album_artist, '')) <> '' GROUP BY trim(t.album_artist) COLLATE NOCASE",
        {_db.tracks},
      );

  // `genere:"X"`: any genre of track_genres, or the old tracks.genre column.
  Future<List<ValueCount>> _genres() => _grouped(
        "SELECT MIN(trim(g)) AS v, COUNT(DISTINCT x.id) AS n FROM ("
        "SELECT g.track_id AS id, g.genre AS g FROM track_genres g "
        "UNION SELECT t.id, t.genre FROM tracks t WHERE t.genre IS NOT NULL) x "
        "JOIN tracks t ON t.id = x.id WHERE $_visible AND trim(g) <> '' "
        "GROUP BY trim(g) COLLATE NOCASE",
        {_db.trackGenres, _db.tracks},
      );

  Future<List<ValueCount>> _labels() => _grouped(
        "SELECT MIN(trim(l)) AS v, COUNT(*) AS n FROM (SELECT ${labelSql()} AS l FROM track_enrich e "
        "JOIN tracks t ON t.id = e.track_id WHERE $_visible) "
        "WHERE typeof(l) = 'text' AND trim(l) <> '' GROUP BY trim(l) COLLATE NOCASE",
        {_db.trackEnrich, _db.tracks},
      );

  // Only countries that were found; `nazionalita` matches tracks by their exact
  // artist spelling, whose main artist has the country.
  Future<List<ValueCount>> _countries() async {
    final byKey = {
      for (final c in await _db.select(_db.artistCountries).get())
        if (c.country != null) c.artistKey: c.country!.toUpperCase(),
    };
    if (byKey.isEmpty) return [];
    final perCountry = <String, int>{};
    for (final a in await _grouped(
      "SELECT t.artist AS v, COUNT(*) AS n FROM tracks t WHERE $_visible "
      "AND trim(COALESCE(t.artist, '')) <> '' GROUP BY t.artist",
      {_db.tracks},
    )) {
      final c = byKey[ArtistInfoRepository.keyOf(a.value)];
      if (c != null) perCountry.update(c, (o) => o + a.count, ifAbsent: () => a.count);
    }
    return [for (final e in perCountry.entries) ValueCount(e.key, e.value)];
  }
}

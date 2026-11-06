import 'dart:async';

import 'package:drift/drift.dart';

import '../../core/text_utils.dart';
import '../../services/library/rules/rule_parser.dart';
import '../db/app_database.dart';
import 'artist_info_repository.dart';
import 'enrich_filter_queries.dart';
import 'track_repository.dart';

/// The lists of values the filter editor offers (F-91, D-393).
enum FilterList { artists, genres, countries, labels }

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

/// Aggregate counts for the editor's lists and the live rule count (D-394).
/// Everything is SQL over the database executor (off the UI thread); only the
/// folding of spellings of one value runs in Dart, over the grouped rows.
class FilterCountsRepository {
  FilterCountsRepository(this._db, this._tracks);

  final AppDatabase _db;
  final TrackRepository _tracks;
  int _generation = 0;

  /// Values of [list] with their track counts, most tracks first then by name;
  /// [query] keeps those whose name contains it (case, accents, spaces ignored).
  Future<List<ValueCount>> counts(FilterList list, {String query = ''}) async {
    final all = switch (list) {
      FilterList.artists => await _artists(),
      FilterList.genres => await _genres(),
      FilterList.countries => await _countries(),
      FilterList.labels => await _labels(),
    };
    final q = normalize(query);
    final out = q.isEmpty ? all : [for (final v in all) if (normalize(v.value).contains(q)) v];
    out.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : normalize(a.value).compareTo(normalize(b.value));
    });
    return out;
  }

  /// Sums the counts of rows whose [keyOf] is the same, keeping the first
  /// spelling (rows come biggest first).
  List<ValueCount> _fold(Iterable<(String, int)> rows, String Function(String) keyOf) {
    final byKey = <String, ValueCount>{};
    for (final (v, n) in rows) {
      final k = keyOf(v);
      if (k.isEmpty) continue;
      final old = byKey[k];
      byKey[k] = ValueCount(old?.value ?? v, (old?.count ?? 0) + n);
    }
    return byKey.values.toList();
  }

  Future<List<(String, int)>> _grouped(String sql, Set<TableInfo> from) async {
    final rows = await _db.customSelect(sql, readsFrom: from).get();
    return [for (final r in rows) (r.read<String>('v'), r.read<int>('n'))];
  }

  /// Artist spellings of visible tracks with their track count.
  Future<List<(String, int)>> _artistRows() => _grouped(
        "SELECT t.artist AS v, COUNT(*) AS n FROM tracks t WHERE $_visible "
        "AND trim(COALESCE(t.artist, '')) <> '' GROUP BY t.artist ORDER BY n DESC, v",
        {_db.tracks},
      );

  // The main artist, as the app names it ("Queen feat. X" -> "Queen").
  Future<List<ValueCount>> _artists() async =>
      _fold(await _artistRows(), ArtistInfoRepository.keyOf);

  Future<List<ValueCount>> _genres() async => _fold(
        await _grouped(
          "SELECT MIN(g.genre) AS v, COUNT(DISTINCT g.track_id) AS n FROM track_genres g "
          "JOIN tracks t ON t.id = g.track_id WHERE $_visible AND trim(g.genre) <> '' "
          "GROUP BY g.genre COLLATE NOCASE ORDER BY n DESC, v",
          {_db.trackGenres, _db.tracks},
        ),
        normalize,
      );

  Future<List<ValueCount>> _labels() async => _fold(
        await _grouped(
          "SELECT l AS v, COUNT(*) AS n FROM (SELECT ${labelSql()} AS l FROM track_enrich e "
          "JOIN tracks t ON t.id = e.track_id WHERE $_visible) "
          "WHERE typeof(l) = 'text' AND trim(l) <> '' GROUP BY l ORDER BY n DESC, v",
          {_db.trackEnrich, _db.tracks},
        ),
        normalize,
      );

  // Only countries that were found; the artist's country is by its main artist.
  Future<List<ValueCount>> _countries() async {
    final byKey = {
      for (final c in await _db.select(_db.artistCountries).get())
        if (c.country != null) c.artistKey: c.country!,
    };
    if (byKey.isEmpty) return [];
    final perCountry = <String, int>{};
    final seen = <String, int>{};
    for (final (artist, n) in await _artistRows()) {
      seen.update(ArtistInfoRepository.keyOf(artist), (o) => o + n, ifAbsent: () => n);
    }
    seen.forEach((key, n) {
      final c = byKey[key];
      if (c != null) perCountry.update(c, (o) => o + n, ifAbsent: () => n);
    });
    return [for (final e in perCountry.entries) ValueCount(e.key, e.value)];
  }

  /// How many tracks [rules] select (capped by [limit]), or null when a newer
  /// call arrived before this one answered, or during its [debounce]: only the
  /// latest request is ever answered. Sort does not change the count.
  Future<int?> liveCount(
    String rules, {
    int? limit,
    Duration debounce = const Duration(milliseconds: 250),
  }) async {
    final mine = ++_generation;
    await Future<void>.delayed(debounce);
    if (mine != _generation) return null;
    final n = await _tracks.countByRules(parseRules(rules).expr);
    if (mine != _generation) return null;
    return limit != null && n > limit ? limit : n;
  }
}

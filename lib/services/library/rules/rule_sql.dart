import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/repositories/enrich_filter_queries.dart';
import '../../tags/tag_reader.dart' show splitGenres;
import 'rule_ast.dart';

const _dayMs = 86400000;

/// `%…%` for a LIKE with the special characters of [s] escaped (`\` is the
/// escape character, as in `TrackRepository`).
String likeContains(String s) => '%${s.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_')}%';

/// A `WHERE` clause (without the keyword) and its variables, in the order the
/// `?` appear. The text of a rule is **never** pasted into the SQL: only
/// `Variable`s carry it.
typedef RuleSql = ({String where, List<Variable> vars});

/// Turns [e] into SQL on the `tracks` table. Missing and hidden tracks and
/// podcast episodes are always left out. [nowMs] is the moment «added <30g» counts back from.
///
/// [countryArtists] maps an upper-case country code to the `tracks.artist`
/// spellings of that country: the key of `artist_countries` is a Dart
/// normalisation of the main artist (`ArtistInfoRepository.keyOf`) that SQL
/// cannot reproduce, so the caller resolves it first (`countryArtistsOf`).
RuleSql toSql(
  RuleExpr e, {
  required int nowMs,
  Map<String, List<String>> countryArtists = const {},
}) {
  final vars = <Variable>[];
  final sql = _expr(e, nowMs, vars, countryArtists);
  return (where: 'missing = 0 AND ignored = 0 AND kind = 0 AND ($sql)', vars: vars);
}

// Every leaf is wrapped so that a NULL column reads as «no» instead of
// «unknown»: that way a negated term keeps the tracks without that tag.
String _leaf(String predicate) => 'COALESCE(($predicate), 0)';

String _expr(RuleExpr e, int now, List<Variable> vars, Map<String, List<String>> ca) {
  switch (e) {
    case RuleAnd(:final terms):
      if (terms.isEmpty) return '1';
      return terms.map((t) => '(${_expr(t, now, vars, ca)})').join(' AND ');
    case RuleOr(:final left, :final right):
      final l = _expr(left, now, vars, ca);
      final r = _expr(right, now, vars, ca);
      return '($l) OR ($r)';
    case RuleNot(:final inner):
      return 'NOT (${_expr(inner, now, vars, ca)})';
    case RuleText(:final text):
      final p = likeContains(text);
      vars.addAll([Variable<String>(p), Variable<String>(p), Variable<String>(p)]);
      return _leaf(
        r"title LIKE ? ESCAPE '\' OR COALESCE(artist, '') LIKE ? ESCAPE '\' "
        r"OR COALESCE(album, '') LIKE ? ESCAPE '\'",
      );
    case RuleFlag(:final kind):
      return switch (kind) {
        RuleFlagKind.favorites => 'is_favorite = 1',
        RuleFlagKind.neverPlayed => 'play_count = 0',
        RuleFlagKind.hasLyrics =>
          "COALESCE(lyrics_plain, '') <> '' OR COALESCE(lyrics_synced, '') <> ''",
      };
    case RuleContains():
      return _contains(e, vars, ca);
    case RuleIn():
      return _in(e, vars, ca);
    case RuleNumber():
      return _number(e, now, vars);
  }
}

/// The artists of a country, as a single JSON variable (no variable limit).
/// All [values] as one JSON variable: no limit on the number of variables.
String _jsonList(List<String> values, List<Variable> vars) {
  vars.add(Variable<String>(jsonEncode(values)));
  return '(SELECT value FROM json_each(?))';
}

/// Integer for a SQL variable; never throws on huge or non-finite values.
int _int(double x) => x.isNaN ? 0 : x.clamp(-9e15, 9e15).round();

String _countrySql(String code, List<Variable> vars, Map<String, List<String>> ca) {
  vars.add(Variable<String>(jsonEncode(ca[code.toUpperCase()] ?? const <String>[])));
  return 'artist IN (SELECT value FROM json_each(?))';
}

/// Genres: any of `track_genres`, or the old single column (tracks not read
/// again yet), so every track the old rule found is still found.
///
/// [joined] is a genre with separators («Hip-Hop/Rap») read whole before the split into
/// `track_genres`: it also matches the track's genres joined back with `/` (D-397).
String _genreSql(String cmp, List<Variable> vars, List<String> params, String oldCmp, {(String, String)? joined}) {
  vars
    ..addAll(params.map((p) => Variable<String>(p)))
    ..addAll(params.map((p) => Variable<String>(p)));
  if (joined != null) vars.add(Variable<String>(joined.$2));
  final whole = joined == null
      ? ''
      : " OR (SELECT group_concat(genre, '/' ORDER BY position) FROM track_genres "
          'WHERE track_id = tracks.id) ${joined.$1}';
  return _leaf('EXISTS (SELECT 1 FROM track_genres g WHERE g.track_id = tracks.id AND $cmp) OR $oldCmp$whole');
}

/// The genres of [s] joined with `/` when it has several (`Rock; Pop` -> `Rock/Pop`).
String? _joinedGenres(String s) {
  final parts = splitGenres([s]);
  return parts.length > 1 ? parts.join('/') : null;
}

String _in(RuleIn e, List<Variable> vars, Map<String, List<String>> ca) {
  final values = e.values;
  switch (e.field) {
    case RuleField.country:
      final artists = {for (final v in values) ...?ca[v.toUpperCase()]}.toList();
      return _leaf('artist IN ${_jsonList(artists, vars)}');
    case RuleField.genre:
      final list = jsonEncode(values);
      const sub = '(SELECT value FROM json_each(?))';
      final multi = [for (final v in values) ?_joinedGenres(v)];
      return _genreSql(
        'TRIM(g.genre) COLLATE NOCASE IN $sub',
        vars,
        [list],
        'TRIM(genre) COLLATE NOCASE IN $sub',
        joined: multi.isEmpty ? null : ('COLLATE NOCASE IN $sub', jsonEncode(multi)),
      );
    case RuleField.tag:
      final marks = _jsonList(values, vars);
      return _leaf(
        'EXISTS (SELECT 1 FROM track_tags tt JOIN user_tags u ON u.id = tt.tag_id '
        'WHERE tt.track_id = tracks.id AND u.name COLLATE NOCASE IN $marks)',
      );
    case RuleField.recordLabel:
      final marks = _jsonList(values, vars);
      return _leaf(
        'EXISTS (SELECT 1 FROM track_enrich e WHERE e.track_id = tracks.id '
        'AND TRIM(${labelSql()}) COLLATE NOCASE IN $marks)',
      );
    default:
      final column = switch (e.field) {
        RuleField.artist => 'artist',
        RuleField.album => 'album',
        RuleField.albumArtist => 'album_artist',
        _ => 'format',
      };
      return _leaf('TRIM($column) COLLATE NOCASE IN ${_jsonList(values, vars)}');
  }
}

String _contains(RuleContains e, List<Variable> vars, Map<String, List<String>> ca) {
  switch (e.field) {
    case RuleField.country:
      return _leaf(_countrySql(e.value, vars, ca));
    case RuleField.recordLabel:
      vars.add(Variable<String>(likeContains(e.value)));
      return _leaf(
        'EXISTS (SELECT 1 FROM track_enrich e WHERE e.track_id = tracks.id '
        "AND COALESCE(${labelSql()}, '') LIKE ? ESCAPE '\\')",
      );
    case RuleField.genre:
      final p = likeContains(e.value);
      return _genreSql(
        r"g.genre LIKE ? ESCAPE '\'",
        vars,
        [p],
        r"COALESCE(genre, '') LIKE ? ESCAPE '\'",
        joined: switch (_joinedGenres(e.value)) {
          final j? => (r"LIKE ? ESCAPE '\'", likeContains(j)),
          _ => null,
        },
      );
    case RuleField.tag:
      vars.add(Variable<String>(e.value));
      return _leaf(
        'EXISTS (SELECT 1 FROM track_tags tt JOIN user_tags u ON u.id = tt.tag_id '
        'WHERE tt.track_id = tracks.id AND u.name = ? COLLATE NOCASE)',
      );
    case RuleField.format:
      vars.add(Variable<String>(e.value));
      return _leaf('lower(format) = lower(?)');
    default:
      final column = switch (e.field) {
        RuleField.artist => 'artist',
        RuleField.album => 'album',
        RuleField.albumArtist => 'album_artist',
        _ => 'path', // folder
      };
      vars.add(Variable<String>(likeContains(e.value)));
      return _leaf("COALESCE($column, '') LIKE ? ESCAPE '\\'");
  }
}

String _number(RuleNumber e, int now, List<Variable> vars) {
  if (e.field.isAge) return _added(e, now, vars);
  if (e.field == RuleField.bpm) return _bpm(e, vars);
  final column = switch (e.field) {
    RuleField.year => 'year',
    RuleField.plays => 'play_count',
    RuleField.bitrate => 'bitrate_kbps',
    _ => 'duration_ms', // duration: seconds in the rule, ms in the column
  };
  final scale = e.field == RuleField.duration ? 1000.0 : 1.0;
  Variable v(double x) => e.field == RuleField.duration
      ? Variable<double>(x * scale)
      : Variable<int>(_int(x));
  switch (e.op) {
    case NumOp.range:
      final parts = <String>[];
      if (e.a != null) {
        parts.add('$column >= ?');
        vars.add(v(e.a!));
      }
      if (e.b != null) {
        parts.add('$column <= ?');
        vars.add(v(e.b!));
      }
      return _leaf(parts.isEmpty ? '1' : parts.join(' AND '));
    default:
      final op = switch (e.op) {
        NumOp.eq => '=',
        NumOp.gt => '>',
        NumOp.ge => '>=',
        NumOp.lt => '<',
        _ => '<=',
      };
      vars.add(v(e.a!));
      return _leaf('$column $op ?');
  }
}

/// BPM is a real number read from the enrichment JSON; only enriched tracks
/// have one. Same comparisons as the other numbers, on `track_enrich`.
String _bpm(RuleNumber e, List<Variable> vars) {
  final col = bpmSql();
  final parts = <String>[];
  void cmp(String op, double x) {
    // Equality rounds both sides: `bpm:120` finds a stored 120.4.
    parts.add(op == '=' ? 'ROUND($col) = ROUND(?)' : '$col $op ?');
    vars.add(Variable<double>(x));
  }

  switch (e.op) {
    case NumOp.range:
      if (e.a != null) cmp('>=', e.a!);
      if (e.b != null) cmp('<=', e.b!);
    case NumOp.eq:
      cmp('=', e.a!);
    case NumOp.gt:
      cmp('>', e.a!);
    case NumOp.ge:
      cmp('>=', e.a!);
    case NumOp.lt:
      cmp('<', e.a!);
    case NumOp.le:
      cmp('<=', e.a!);
  }
  return _leaf(
    'EXISTS (SELECT 1 FROM track_enrich e WHERE e.track_id = tracks.id AND '
    '${parts.isEmpty ? '$col IS NOT NULL' : parts.join(' AND ')})',
  );
}

/// «aggiunto» speaks of age: `<30g` is newer than 30 days, so `added_at` is
/// *after* the moment 30 days ago.
String _added(RuleNumber e, int now, List<Variable> vars) {
  final sql = _addedCore(e, now, vars);
  // A track never played counts as played infinitely long ago: it is «older than N»
  // (`>`, `>=`, an open-ended range) and never «in the last N days».
  final older = e.op == NumOp.gt || e.op == NumOp.ge || (e.op == NumOp.range && e.a != null && e.b == null);
  return e.field == RuleField.lastPlayed && older ? '(last_played_at IS NULL OR $sql)' : sql;
}

String _addedCore(RuleNumber e, int now, List<Variable> vars) {
  final c = e.field == RuleField.lastPlayed ? 'last_played_at' : 'added_at';
  int ago(double days) => now - _int(days * _dayMs);
  switch (e.op) {
    case NumOp.range:
      final parts = <String>[];
      if (e.a != null) {
        parts.add('$c <= ?'); // at least a days old
        vars.add(Variable<int>(ago(e.a!)));
      }
      if (e.b != null) {
        parts.add('$c >= ?'); // at most b days old
        vars.add(Variable<int>(ago(e.b!)));
      }
      return _leaf(parts.isEmpty ? '1' : parts.join(' AND '));
    case NumOp.eq:
      vars
        ..add(Variable<int>(ago(e.a!)))
        ..add(Variable<int>(ago(e.a! + 1)));
      return _leaf('$c <= ? AND $c > ?');
    case NumOp.lt:
      vars.add(Variable<int>(ago(e.a!)));
      return _leaf('$c > ?');
    case NumOp.le:
      vars.add(Variable<int>(ago(e.a!)));
      return _leaf('$c >= ?');
    case NumOp.gt:
      vars.add(Variable<int>(ago(e.a!)));
      return _leaf('$c < ?');
    case NumOp.ge:
      vars.add(Variable<int>(ago(e.a!)));
      return _leaf('$c <= ?');
  }
}

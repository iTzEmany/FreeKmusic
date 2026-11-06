import 'rule_ast.dart';

/// Why a term was not understood as an operator. The term still counts as
/// free text (or is skipped when empty): searching never breaks while typing.
enum RuleWarningKind { unknownField, badNumber, badRange, badUnit, emptyValue, danglingOr }

class RuleWarning {
  const RuleWarning(this.term, this.kind);

  final String term;
  final RuleWarningKind kind;

  @override
  String toString() => '$term: ${kind.name}';
}

typedef ParsedRules = ({RuleExpr expr, List<RuleWarning> warnings});

/// Field names and their English aliases.
const _fields = <String, RuleField>{
  'artista': RuleField.artist,
  'artist': RuleField.artist,
  'album': RuleField.album,
  'anno': RuleField.year,
  'year': RuleField.year,
  'genere': RuleField.genre,
  'genre': RuleField.genre,
  'tag': RuleField.tag,
  'durata': RuleField.duration,
  'duration': RuleField.duration,
  'aggiunto': RuleField.added,
  'added': RuleField.added,
  'ascolti': RuleField.plays,
  'plays': RuleField.plays,
  'formato': RuleField.format,
  'format': RuleField.format,
  'cartella': RuleField.folder,
  'folder': RuleField.folder,
  'ultimoascolto': RuleField.lastPlayed,
  'last-played': RuleField.lastPlayed,
  'artistaalbum': RuleField.albumArtist,
  'album-artist': RuleField.albumArtist,
  'nazionalita': RuleField.country,
  'country': RuleField.country,
  'etichetta': RuleField.recordLabel,
  'label': RuleField.recordLabel,
  'bpm': RuleField.bpm,
  'bitrate': RuleField.bitrate,
};

const _flags = <String, RuleFlagKind>{
  'preferiti': RuleFlagKind.favorites,
  'favorites': RuleFlagKind.favorites,
  'mai-ascoltati': RuleFlagKind.neverPlayed,
  'never-played': RuleFlagKind.neverPlayed,
  'con-testo': RuleFlagKind.hasLyrics,
  'has-lyrics': RuleFlagKind.hasLyrics,
};

/// Splits on spaces, keeping what is inside double quotes together (an
/// unterminated quote runs to the end: the user is still typing).
List<String> _tokens(String text) {
  final out = <String>[];
  final cur = StringBuffer();
  var quoted = false;
  final chars = text.split('');
  for (var i = 0; i < chars.length; i++) {
    final ch = chars[i];
    if (quoted &&
        ch == r'\' &&
        i + 2 < chars.length &&
        (chars[i + 1] == '"' || chars[i + 1] == r'\') &&
        chars[i + 2].trim().isNotEmpty &&
        chars[i + 2] != ',' &&
        _escapes(cur.toString())) {
      // `\"` and `\\` inside a list value (see RuleIn.canonical). Only when more of the
      // token follows, so `cartella:"D:\Music\"` and old `artista:"A\",` read as before.
      cur..write(ch)..write(chars[++i]);
    } else if (ch == '"') {
      quoted = !quoted;
      cur.write(ch);
    } else if (!quoted && ch.trim().isEmpty) {
      // `campo:"A", "B"`: spaces after the comma of a quoted list stay inside it.
      var j = i;
      while (j < chars.length && chars[j].trim().isEmpty) {
        j++;
      }
      final s = cur.toString();
      if (s.endsWith(',') && j < chars.length && chars[j] == '"' && _listStart.hasMatch(s)) {
        i = j - 1;
        continue;
      }
      if (cur.isNotEmpty) out.add(s);
      cur.clear();
    } else {
      cur.write(ch);
    }
  }
  if (cur.isNotEmpty) out.add(cur.toString());
  return out;
}

final _listStart = RegExp(r'^-?[^\s:<>"]+:"');

/// Whether [cur] (the token so far) is a list-capable field: not `cartella`, a path.
bool _escapes(String cur) {
  final m = _listStart.firstMatch(cur);
  if (m == null) return false;
  final name = cur.substring(0, cur.indexOf(':')).replaceFirst('-', '').toLowerCase();
  return _fields[name] != RuleField.folder;
}

String _unquote(String v) {
  var s = v;
  if (s.startsWith('"')) s = s.substring(1);
  if (s.endsWith('"')) s = s.substring(0, s.length - 1);
  return s;
}

/// A number with an optional unit, in the field's own measure (seconds for the
/// length, days for «added»); null when it is not one.
double? _number(RuleField field, String raw, {required Set<RuleWarningKind> bad}) {
  final m = RegExp(r'^(\d+(?:[.,]\d+)?)([a-zA-Z]*)$').firstMatch(raw.trim());
  if (m == null) {
    bad.add(RuleWarningKind.badNumber);
    return null;
  }
  final n = double.parse(m[1]!.replaceAll(',', '.'));
  if (!isValidRuleNumber(n)) {
    bad.add(RuleWarningKind.badNumber);
    return null;
  }
  final unit = m[2]!.toLowerCase();
  switch (field) {
    case RuleField.year || RuleField.plays || RuleField.bitrate:
      if (unit.isNotEmpty) {
        bad.add(RuleWarningKind.badUnit);
        return null;
      }
      return n;
    case RuleField.duration:
      return switch (unit) {
        '' || 'm' || 'min' => n * 60,
        's' || 'sec' => n,
        _ => () {
            bad.add(RuleWarningKind.badUnit);
            return null;
          }(),
      };
    case RuleField.bpm:
      if (unit.isNotEmpty) {
        bad.add(RuleWarningKind.badUnit);
        return null;
      }
      return n;
    case RuleField.added || RuleField.lastPlayed:
      return switch (unit) {
        '' || 'g' || 'd' => n,
        'sett' || 'w' => n * 7,
        'mesi' || 'mese' || 'mo' => n * 30,
        _ => () {
            bad.add(RuleWarningKind.badUnit);
            return null;
          }(),
      };
    default:
      return null;
  }
}

/// Reads [text] into a tree. It never throws: a term that does not make sense
/// becomes free text and is reported in `warnings` (an empty `campo:` is
/// skipped, as the user is probably still typing it).
ParsedRules parseRules(String text) {
  final warnings = <RuleWarning>[];
  final terms = <RuleExpr>[];
  var orPending = false;
  String? orToken;

  void add(RuleExpr e) {
    if (orPending && terms.isNotEmpty) {
      terms[terms.length - 1] = RuleOr(terms.last, e);
    } else {
      if (orPending) warnings.add(RuleWarning(orToken!, RuleWarningKind.danglingOr));
      terms.add(e);
    }
    orPending = false;
  }

  for (final raw in _tokens(text)) {
    if (raw == 'OR') {
      if (terms.isEmpty || orPending) {
        warnings.add(const RuleWarning('OR', RuleWarningKind.danglingOr));
        if (terms.isEmpty) continue;
      }
      orPending = true;
      orToken = raw;
      continue;
    }
    final negated = raw.length > 1 && raw.startsWith('-');
    final body = negated ? raw.substring(1) : raw;
    final term = _term(body, warnings);
    if (term == null) continue; // skipped (empty value)
    add(negated ? RuleNot(term) : term);
  }
  if (orPending) warnings.add(RuleWarning(orToken ?? 'OR', RuleWarningKind.danglingOr));
  final expr = terms.length == 1 ? terms.single : RuleAnd(terms);
  return (expr: expr, warnings: warnings);
}

RuleExpr? _term(String body, List<RuleWarning> warnings) {
  final m = RegExp(r'^([^\s:<>"]+)(:|>=|<=|>|<)(.*)$').firstMatch(body);
  if (m != null) {
    final field = _fields[m[1]!.toLowerCase()];
    if (field == null) {
      warnings.add(RuleWarning(body, RuleWarningKind.unknownField));
      return RuleText(_unquote(body));
    }
    if (m[2] == ':' && !field.isNumeric && field != RuleField.folder && m[3]!.startsWith('"')) {
      final list = _quotedList(m[3]!);
      if (list != null) {
        if (list.any((v) => v.trim().isEmpty)) {
          warnings.add(RuleWarning(body, RuleWarningKind.emptyValue));
          return null;
        }
        return RuleIn(field, [for (final v in list) v.trim()]);
      }
    }
    return _fieldTerm(body, field, m[2]!, _unquote(m[3]!), warnings);
  }
  final flag = _flags[body.toLowerCase()];
  if (flag != null) return RuleFlag(flag);
  final text = _unquote(body);
  return text.isEmpty ? null : RuleText(text);
}

/// `"A","B"` (optionally ending with a comma) as its values; null when [v] is
/// not that: a lone `"pink floyd"`, or an unterminated quote, stays a plain
/// substring value.
List<String>? _quotedList(String v) {
  var m = RegExp(r'^"(?:[^"\\]|\\.)*"(?:,"(?:[^"\\]|\\.)*")*(,?)$').firstMatch(v);
  var item = RegExp(r'"((?:[^"\\]|\\.)*)"');
  var unescape = true;
  if (m == null) {
    // Lists saved before escapes existed: a value may end with a backslash.
    m = RegExp(r'^"[^"]*"(?:,"[^"]*")*(,?)$').firstMatch(v);
    if (m == null) return null;
    item = RegExp(r'"([^"]*)"');
    unescape = false;
  }
  final items = [
    for (final x in item.allMatches(v))
      unescape ? x[1]!.replaceAllMapped(RegExp(r'\\(["\\])'), (e) => e[1]!) : x[1]!,
  ];
  return items.length == 1 && m[1]!.isEmpty ? null : items;
}

RuleExpr? _fieldTerm(
  String body,
  RuleField field,
  String op,
  String value,
  List<RuleWarning> warnings,
) {
  if (value.trim().isEmpty) {
    warnings.add(RuleWarning(body, RuleWarningKind.emptyValue));
    return null;
  }
  RuleExpr asText(RuleWarningKind why) {
    warnings.add(RuleWarning(body, why));
    return RuleText(_unquote(body));
  }

  if (!field.isNumeric) {
    // Text fields only know «:».
    return op == ':' ? RuleContains(field, value.trim()) : asText(RuleWarningKind.badNumber);
  }
  final bad = <RuleWarningKind>{};
  if (op == ':' && value.contains('..')) {
    final parts = value.split('..');
    if (parts.length != 2 || (parts[0].trim().isEmpty && parts[1].trim().isEmpty)) {
      return asText(RuleWarningKind.badRange);
    }
    final a = parts[0].trim().isEmpty ? null : _number(field, parts[0], bad: bad);
    final b = parts[1].trim().isEmpty ? null : _number(field, parts[1], bad: bad);
    if (bad.isNotEmpty) return asText(bad.first);
    if (a != null && b != null && a > b) return asText(RuleWarningKind.badRange);
    return RuleNumber(field, NumOp.range, a, b);
  }
  final n = _number(field, value, bad: bad);
  if (n == null) return asText(bad.first);
  return RuleNumber(field, switch (op) {
    ':' => NumOp.eq,
    '>' => NumOp.gt,
    '>=' => NumOp.ge,
    '<' => NumOp.lt,
    _ => NumOp.le,
  }, n);
}

/// The canonical text of a tree, the one a saved rule is stored as.
String formatRules(RuleExpr e) => e.canonical;

/// The plain words of a rule (the ones at the top level, not negated), joined
/// by a space: what the artist, album and playlist sections of the search
/// still filter on.
String freeTextOf(String text) {
  final e = parseRules(text).expr;
  final terms = e is RuleAnd ? e.terms : [e];
  return [for (final t in terms) if (t is RuleText) t.text].join(' ');
}

/// True when [text] uses at least one operator (a field, a flag, `-`, `OR`)
/// rather than plain words: the search then runs as rules.
bool hasOperators(String text) {
  final parsed = parseRules(text).expr;
  bool plain(RuleExpr e) => switch (e) {
        RuleText() => true,
        RuleAnd(:final terms) => terms.every(plain),
        _ => false,
      };
  return !plain(parsed);
}

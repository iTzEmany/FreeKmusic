/// The rule language shared by the search box and the smart playlists:
/// `artista:"pink floyd" -live anno:1970..1979 preferiti`. This is its tree.
///
/// Every node can print itself in canonical form ([canonical]); two nodes are
/// equal when they print the same, which is what the parse → format → parse
/// round trip relies on.
enum RuleField {
  artist,
  album,
  year,
  genre,
  tag,
  duration,
  added,
  plays,
  format,
  folder,
  lastPlayed,
  albumArtist,
  country,
  recordLabel,
  bpm,
  bitrate;

  /// The canonical (Italian) name used when a rule is printed.
  String get label => switch (this) {
        RuleField.artist => 'artista',
        RuleField.album => 'album',
        RuleField.year => 'anno',
        RuleField.genre => 'genere',
        RuleField.tag => 'tag',
        RuleField.duration => 'durata',
        RuleField.added => 'aggiunto',
        RuleField.plays => 'ascolti',
        RuleField.format => 'formato',
        RuleField.folder => 'cartella',
        RuleField.lastPlayed => 'ultimoascolto',
        RuleField.albumArtist => 'artistaalbum',
        RuleField.country => 'nazionalita',
        RuleField.recordLabel => 'etichetta',
        RuleField.bpm => 'bpm',
        RuleField.bitrate => 'bitrate',
      };

  bool get isNumeric =>
      this == year ||
      this == duration ||
      this == added ||
      this == plays ||
      this == lastPlayed ||
      this == bpm ||
      this == bitrate;

  /// Ages in days («added», «lastPlayed»): `<30g` means newer than 30 days.
  bool get isAge => this == added || this == lastPlayed;
}

enum RuleFlagKind { favorites, neverPlayed, hasLyrics }

enum NumOp { eq, gt, ge, lt, le, range }

sealed class RuleExpr {
  const RuleExpr();

  String get canonical;

  @override
  bool operator ==(Object other) =>
      other is RuleExpr &&
      other.runtimeType == runtimeType &&
      other.canonical == canonical;

  @override
  int get hashCode => canonical.hashCode;

  @override
  String toString() => canonical;
}

/// Every term must hold (an empty list holds for every track).
final class RuleAnd extends RuleExpr {
  const RuleAnd(this.terms);

  final List<RuleExpr> terms;

  @override
  String get canonical => terms.map((t) => t.canonical).join(' ');
}

/// `a OR b`.
final class RuleOr extends RuleExpr {
  const RuleOr(this.left, this.right);

  final RuleExpr left, right;

  @override
  String get canonical => '${left.canonical} OR ${right.canonical}';
}

/// `-term`.
final class RuleNot extends RuleExpr {
  const RuleNot(this.inner);

  final RuleExpr inner;

  @override
  String get canonical => '-${inner.canonical}';
}

/// A free word or phrase: matched against title, artist and album.
final class RuleText extends RuleExpr {
  const RuleText(this.text);

  final String text;

  @override
  String get canonical => quoteIfNeeded(text);
}

/// `preferiti`, `mai-ascoltati`, `con-testo`.
final class RuleFlag extends RuleExpr {
  const RuleFlag(this.kind);

  final RuleFlagKind kind;

  @override
  String get canonical => switch (kind) {
        RuleFlagKind.favorites => 'preferiti',
        RuleFlagKind.neverPlayed => 'mai-ascoltati',
        RuleFlagKind.hasLyrics => 'con-testo',
      };
}

/// `artista:x`, `album:x`, `genere:x`, `cartella:x` (the text is contained)
/// and `tag:x`, `formato:x` (the whole value, ignoring case).
final class RuleContains extends RuleExpr {
  const RuleContains(this.field, this.value);

  final RuleField field;
  final String value;

  bool get exact => field == RuleField.tag || field == RuleField.format;

  @override
  String get canonical => '${field.label}:${quoteIfNeeded(value)}';
}

/// `artista:"A","B"`: the field equals one of [values] (whole value, ignoring
/// case; no substring). A single value prints with a trailing comma
/// (`artista:"A",`) so it stays distinct from `artista:"A"`, a substring.
/// Not for numeric fields, nor for `cartella` (a path is never equal to a folder).
final class RuleIn extends RuleExpr {
  const RuleIn(this.field, this.values);

  final RuleField field;
  final List<String> values;

  @override
  String get canonical =>
      '${field.label}:${values.map((v) => '"${v.replaceAll('"', '')}"').join(',')}${values.length == 1 ? ',' : ''}';
}

/// A comparison on a number: the year, the length (in seconds), how long ago
/// it was added (in days) or how many times it was played.
///
/// For [NumOp.range] either end may be null (open); for the other operators
/// only [a] is used.
final class RuleNumber extends RuleExpr {
  const RuleNumber(this.field, this.op, this.a, [this.b]);

  final RuleField field;
  final NumOp op;
  final double? a, b;

  String _fmt(double v) {
    final whole = v == v.roundToDouble();
    switch (field) {
      case RuleField.duration:
        if (whole && v % 60 == 0) return '${(v / 60).round()}m';
        return whole ? '${v.round()}s' : '${v}s';
      case RuleField.added || RuleField.lastPlayed:
        return whole ? '${v.round()}g' : '${v}g';
      default:
        return whole ? '${v.round()}' : '$v';
    }
  }

  @override
  String get canonical {
    final name = field.label;
    return switch (op) {
      NumOp.eq => '$name:${_fmt(a!)}',
      NumOp.gt => '$name>${_fmt(a!)}',
      NumOp.ge => '$name>=${_fmt(a!)}',
      NumOp.lt => '$name<${_fmt(a!)}',
      NumOp.le => '$name<=${_fmt(a!)}',
      NumOp.range => '$name:${a == null ? '' : _fmt(a!)}..${b == null ? '' : _fmt(b!)}',
    };
  }
}

/// Wraps a value in quotes when it has spaces or characters the parser would
/// read as something else.
String quoteIfNeeded(String v) {
  final plain = RegExp(r'^[^\s":<>]+$').hasMatch(v) && !v.startsWith('-') && v != 'OR';
  return plain ? v : '"${v.replaceAll('"', '')}"';
}

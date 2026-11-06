import '../../../services/library/rules/rule_ast.dart';

/// How a card is edited.
enum FilterKind { list, text, number, age, flag }

/// One field (or flag) the «Aggiungi filtro» sheet can add.
class FilterSpec {
  const FilterSpec.field(RuleField this.field) : flag = null;
  const FilterSpec.flag(RuleFlagKind this.flag) : field = null;

  final RuleField? field;
  final RuleFlagKind? flag;

  /// Country, label and BPM only exist for enriched tracks.
  bool get enrichedOnly =>
      field == RuleField.country || field == RuleField.recordLabel || field == RuleField.bpm;

  FilterKind get kind => flag != null
      ? FilterKind.flag
      : field!.isAge
          ? FilterKind.age
          : field == RuleField.folder
              ? FilterKind.text
              : field!.isNumeric
              ? FilterKind.number
              : FilterKind.list;
}

/// Groups of the «Aggiungi filtro» sheet, in order: music, listening, file, tags.
enum FilterGroup { music, listening, file, tags }

const filterGroups = <FilterGroup, List<FilterSpec>>{
  FilterGroup.music: [
    FilterSpec.field(RuleField.artist),
    FilterSpec.field(RuleField.album),
    FilterSpec.field(RuleField.albumArtist),
    FilterSpec.field(RuleField.genre),
    FilterSpec.field(RuleField.year),
    FilterSpec.field(RuleField.country),
    FilterSpec.field(RuleField.recordLabel),
    FilterSpec.field(RuleField.bpm),
  ],
  FilterGroup.listening: [
    FilterSpec.flag(RuleFlagKind.favorites),
    FilterSpec.flag(RuleFlagKind.neverPlayed),
    FilterSpec.field(RuleField.plays),
    FilterSpec.field(RuleField.lastPlayed),
  ],
  FilterGroup.file: [
    FilterSpec.field(RuleField.duration),
    FilterSpec.field(RuleField.added),
    FilterSpec.field(RuleField.bitrate),
    FilterSpec.field(RuleField.format),
    FilterSpec.field(RuleField.folder),
    FilterSpec.flag(RuleFlagKind.hasLyrics),
  ],
  FilterGroup.tags: [FilterSpec.field(RuleField.tag)],
};

/// One filter card. The fields are the raw edits; [toExpr] says whether they
/// make a complete filter.
class FilterCard {
  FilterCard(
    this.kind, {
    this.field,
    this.flag,
    this.exclude = false,
    List<String>? values,
    this.text = '',
    this.from = '',
    this.to = '',
    this.op = NumOp.range,
  }) : values = values ?? [],
       loadedOp = op;

  factory FilterCard.fromSpec(FilterSpec s) => FilterCard(
        s.kind,
        field: s.field,
        flag: s.flag,
        // A new age filter reads «Negli ultimi N giorni».
        op: s.kind == FilterKind.age ? NumOp.lt : NumOp.range,
      );

  final FilterKind kind;
  final RuleField? field;
  final RuleFlagKind? flag;
  bool exclude;
  List<String> values;

  /// [FilterKind.text]: the substring.
  String text;

  /// [FilterKind.number]: the two ends; [FilterKind.age]: [from] holds the days.
  String from, to;

  /// Operator kept from a loaded rule (`ascolti>0`) so it is written back as it was.
  NumOp op;

  /// The operator the rule was loaded with: back in force when only one end is left.
  final NumOp loadedOp;

  /// Both ends filled make a «da…a» range; with one left the loaded operator returns.
  void syncOp() => op = _num(from) != null && _num(to) != null ? NumOp.range : loadedOp;

  /// tag and formato compare the whole value (RuleContains.exact).
  bool get exact => field == RuleField.tag || field == RuleField.format;

  /// Age filter: «Negli ultimi» (newer than) rather than «Da più di».
  bool get recent => op == NumOp.lt || op == NumOp.le;

  bool get isDuration => field == RuleField.duration;

  double? _num(String s) {
    final t = s.trim();
    if (isDuration && t.contains(':')) {
      final p = t.split(':');
      final m = p.length == 2 ? int.tryParse(p[0]) : null;
      final sec = p.length == 2 ? int.tryParse(p[1]) : null;
      return m == null || sec == null || sec < 0 || sec > 59 ? null : (m * 60 + sec).toDouble();
    }
    final v = double.tryParse(t.replaceAll(',', '.'));
    return v == null ? null : (isDuration ? v * 60 : v);
  }

  /// The filter as a rule, or null while it is incomplete.
  RuleExpr? toExpr() {
    final RuleExpr? e = switch (kind) {
      FilterKind.flag => RuleFlag(flag!),
      FilterKind.list => values.isEmpty ? null : RuleIn(field!, List.of(values)),
      FilterKind.text => text.trim().isEmpty ? null : RuleContains(field!, text.trim()),
      FilterKind.age => () {
          final n = int.tryParse(from.trim());
          return n == null || n <= 0 ? null : RuleNumber(field!, op, n.toDouble());
        }(),
      FilterKind.number => _number(),
    };
    return e == null ? null : (exclude ? RuleNot(e) : e);
  }

  RuleExpr? _number() {
    final f = _num(from), t = _num(to);
    if (f == null && t == null) return null;
    if (f != null && t != null) return f > t ? null : RuleNumber(field!, NumOp.range, f, t);
    if (f != null) {
      return op == NumOp.eq || op == NumOp.gt || op == NumOp.ge
          ? RuleNumber(field!, op, f)
          : RuleNumber(field!, NumOp.range, f, null);
    }
    return op == NumOp.lt || op == NumOp.le
        ? RuleNumber(field!, op, t)
        : RuleNumber(field!, NumOp.range, null, t);
  }

  static String _fmt(double v, RuleField f) {
    if (f == RuleField.duration && v % 60 != 0 && v == v.roundToDouble()) {
      return '${v ~/ 60}:${(v % 60).round().toString().padLeft(2, '0')}';
    }
    final x = f == RuleField.duration ? v / 60 : v;
    return x == x.roundToDouble() ? '${x.round()}' : '$x';
  }

  /// The card for one term of a rule, or null when the editor cannot show it.
  static FilterCard? fromExpr(RuleExpr e) {
    var x = e;
    final exclude = x is RuleNot;
    if (x is RuleNot) x = x.inner;
    final c = switch (x) {
      RuleIn(:final field, :final values) => FilterCard(FilterKind.list, field: field, values: List.of(values)),
      RuleContains(:final field, :final value) => FilterCard(FilterKind.text, field: field, text: value),
      RuleFlag(:final kind) => FilterCard(FilterKind.flag, flag: kind),
      RuleNumber n when n.field.isAge =>
        n.a == null || n.a != n.a!.roundToDouble() || n.op == NumOp.eq || n.op == NumOp.range
            ? null
            : FilterCard(FilterKind.age, field: n.field, op: n.op, from: '${n.a!.round()}'),
      RuleNumber n => () {
          final lt = n.op == NumOp.lt || n.op == NumOp.le;
          final a = n.a == null ? '' : _fmt(n.a!, n.field);
          final b = n.b == null ? '' : _fmt(n.b!, n.field);
          return FilterCard(FilterKind.number, field: n.field, op: n.op, from: lt ? '' : a, to: lt ? a : b);
        }(),
      _ => null,
    };
    c?.exclude = exclude;
    return c;
  }
}

/// All / any of the cards.
class FilterModel {
  FilterModel({this.any = false, List<FilterCard>? cards}) : cards = cards ?? [];

  bool any;
  final List<FilterCard> cards;

  /// The complete cards joined by AND (space) or OR.
  RuleExpr get expr {
    final es = [for (final c in cards) ?c.toExpr()];
    if (any && es.length > 1) return es.skip(1).fold(es.first, (a, b) => RuleOr(a, b));
    return RuleAnd(es);
  }

  String get rules => expr.canonical;

  bool get hasComplete => cards.any((c) => c.toExpr() != null);

  bool get hasIncomplete => cards.any((c) => c.toExpr() == null);

  /// The cards of [e], or null when the rule is not a flat «all» / «any» of
  /// cards (nested OR, free words...) or would not print back identically.
  static FilterModel? fromExpr(RuleExpr e) {
    final leaves = <RuleExpr>[];
    var any = false;
    void walk(RuleExpr x) {
      if (x is RuleOr) {
        walk(x.left);
        leaves.add(x.right);
      } else {
        leaves.add(x);
      }
    }

    if (e is RuleOr) {
      any = true;
      walk(e);
    } else if (e is RuleAnd) {
      leaves.addAll(e.terms);
    } else {
      leaves.add(e);
    }
    final cards = <FilterCard>[];
    for (final l in leaves) {
      final c = FilterCard.fromExpr(l);
      if (c == null) return null;
      cards.add(c);
    }
    final m = FilterModel(any: any, cards: cards);
    return m.rules == e.canonical ? m : null;
  }
}

import '../../../core/text_utils.dart';
import '../../online/youtube_service.dart';
import 'rule_ast.dart';

/// Does the online song [r] respect the smart playlist [rules] (D-756)? Only
/// artist, album, length and free text can be checked on a result; every other
/// rule (genre, year, plays, folder...) counts as satisfied, also under `-`.
bool onlineMatches(RuleExpr rules, YtResult r) => _eval(rules, r) ?? true;

/// null: nothing to check here (the rule is ignored).
bool? _eval(RuleExpr e, YtResult r) {
  switch (e) {
    case RuleAnd(:final terms):
      for (final t in terms) {
        if (_eval(t, r) == false) return false;
      }
      return null; // all held or ignored: the caller reads null as satisfied
    case RuleOr(:final left, :final right):
      final l = _eval(left, r), rt = _eval(right, r);
      return l == null || rt == null ? null : l || rt; // an ignored side holds
    case RuleNot(:final inner):
      final v = _eval(inner, r);
      return v == null ? null : !v;
    case RuleText(:final text):
      final n = searchFold(text);
      return [r.title, ..._artists(r), r.album ?? ''].any((s) => searchFold(s).contains(n));
    case RuleContains(:final field, :final value):
      final n = searchFold(value);
      return _texts(field, r)?.any((s) => searchFold(s).contains(n));
    case RuleIn(:final field, :final values):
      final ns = {for (final v in values) searchFold(v)};
      return _texts(field, r)?.any((s) => ns.contains(searchFold(s)));
    case RuleNumber(:final field, :final op, :final a, :final b):
      final d = r.duration;
      if (field != RuleField.duration || d == null) return null;
      final s = d.inMilliseconds / 1000;
      return switch (op) {
        NumOp.eq => s.round() == a!.round(),
        NumOp.gt => s > a!,
        NumOp.ge => s >= a!,
        NumOp.lt => s < a!,
        NumOp.le => s <= a!,
        NumOp.range => (a == null || s >= a) && (b == null || s <= b),
      };
    case RuleFlag():
      return null;
  }
}

List<String> _artists(YtResult r) => r.artists.isEmpty ? [r.channel] : r.artists;

List<String>? _texts(RuleField f, YtResult r) => switch (f) {
      RuleField.artist || RuleField.albumArtist => _artists(r),
      RuleField.album => [r.album ?? ''],
      _ => null,
    };

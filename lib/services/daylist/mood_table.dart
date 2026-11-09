import 'dart:convert';

import '../../core/app_log.dart';
import '../../core/artist_key.dart' show matchKey;

/// Moods of a genre (D-439). Order is the one of the settings screen.
enum Mood { energetic, cheerful, calm, relaxing, melancholic, focus }

/// Genre -> moods. Genres are compared by [matchKey] (case, accents, hyphens).
/// An unknown genre has no mood. Pure: persistence is [toJsonString] /
/// [MoodTable.fromJsonString] (only what differs from the defaults is saved).
class MoodTable {
  MoodTable._(this._entries);

  /// The table as shipped.
  factory MoodTable.defaults() => MoodTable._({
    for (final e in _defaults.entries)
      matchKey(e.key): Set.unmodifiable(e.value),
  });

  static const _defaults = <String, Set<Mood>>{
    'ambient': {Mood.calm, Mood.relaxing, Mood.focus},
    'bossa nova': {Mood.calm, Mood.relaxing, Mood.cheerful},
    'blues': {Mood.melancholic, Mood.calm},
    'cantautorato': {Mood.melancholic, Mood.calm},
    'classica': {Mood.relaxing, Mood.focus, Mood.calm},
    'disco': {Mood.energetic, Mood.cheerful},
    'elettronica': {Mood.energetic, Mood.focus},
    'folk': {Mood.calm, Mood.melancholic},
    'funk': {Mood.cheerful, Mood.energetic},
    'hip hop': {Mood.energetic, Mood.focus},
    'indie': {Mood.cheerful, Mood.melancholic},
    'jazz': {Mood.relaxing, Mood.focus, Mood.melancholic},
    'lo-fi': {Mood.relaxing, Mood.focus},
    'metal': {Mood.energetic},
    'pop': {Mood.cheerful, Mood.energetic},
    'punk': {Mood.energetic},
    'r&b': {Mood.relaxing, Mood.melancholic},
    'reggae': {Mood.calm, Mood.cheerful},
    'rock': {Mood.energetic, Mood.cheerful},
    'soul': {Mood.relaxing, Mood.melancholic},
  };

  final Map<String, Set<Mood>> _entries;

  /// Moods of [genre]; empty when unknown.
  Set<Mood> moodsOf(String genre) => _entries[matchKey(genre)] ?? const {};

  /// Moods of a genre field that may list several genres.
  Set<Mood> moodsOfAll(Iterable<String> genres) => {
    for (final g in genres) ...moodsOf(g),
  };

  /// Genres with an entry, normalized, sorted.
  List<String> get genres => _entries.keys.toList()..sort();

  /// A copy where [genre] has [moods] (an empty set means «no mood» on purpose).
  MoodTable withMoods(String genre, Set<Mood> moods) =>
      MoodTable._({..._entries, matchKey(genre): Set.unmodifiable(moods)});

  /// User changes only: `{genre: [mood names]}`.
  String toJsonString() {
    final base = MoodTable.defaults()._entries;
    final diff = {
      for (final e in _entries.entries)
        if (!_same(e.value, base[e.key]))
          e.key: [for (final m in e.value) m.name],
    };
    return jsonEncode(diff);
  }

  /// Defaults plus the changes in [raw]; unreadable data means the defaults.
  factory MoodTable.fromJsonString(String? raw) {
    final t = MoodTable.defaults();
    if (raw == null) return t;
    try {
      final m = jsonDecode(raw);
      if (m is! Map) throw const FormatException('not a map');
      for (final e in m.entries) {
        final names = e.value;
        if (names is! List) continue;
        final moods = {
          for (final n in names)
            for (final mood in Mood.values)
              if (mood.name == n) mood,
        };
        if (names.isNotEmpty && moods.isEmpty) {
          continue; // only unknown names: not «no mood»
        }
        t._entries[matchKey('${e.key}')] = Set.unmodifiable(moods);
      }
    } on FormatException catch (e) {
      AppLog.w('mood table unreadable, back to the defaults', e);
      return MoodTable.defaults();
    }
    return t;
  }

  static bool _same(Set<Mood> a, Set<Mood>? b) =>
      b != null && a.length == b.length && a.containsAll(b);
}

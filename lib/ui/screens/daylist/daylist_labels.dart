import '../../../core/artist_key.dart' show matchKey;
import '../../../l10n/app_localizations.dart';
import '../../../services/daylist/mood_table.dart';

/// Name of the slot at [i] (0 early morning ... 7 late night).
String daylistSlotName(AppLocalizations l, int i) => switch (i) {
  0 => l.daylistSlot0,
  1 => l.daylistSlot1,
  2 => l.daylistSlot2,
  3 => l.daylistSlot3,
  4 => l.daylistSlot4,
  5 => l.daylistSlot5,
  6 => l.daylistSlot6,
  _ => l.daylistSlot7,
};

String daylistMoodName(AppLocalizations l, Mood m) => switch (m) {
  Mood.energetic => l.daylistMoodEnergetic,
  Mood.cheerful => l.daylistMoodCheerful,
  Mood.calm => l.daylistMoodCalm,
  Mood.relaxing => l.daylistMoodRelaxing,
  Mood.melancholic => l.daylistMoodMelancholic,
  Mood.focus => l.daylistMoodFocus,
};

/// «HH:00».
String daylistHour(int h) => '${(h % 24).toString().padLeft(2, '0')}:00';

/// The slot name and up to 3 genres, joined by commas (D-440).
String daylistName(AppLocalizations l, int slotIndex, List<String> genres) =>
    [daylistSlotName(l, slotIndex), ...genres.take(3).map(genreDisplay)].join(', ');

const _genreNames = {
  'bossa nova': 'Bossa nova',
  'hip hop': 'Hip hop',
  'lo fi': 'Lo-Fi',
  'r and b': 'R&B',
};

/// Readable genre name for a [matchKey] key or a user spelling.
String genreDisplay(String g) {
  final k = matchKey(g);
  return _genreNames[k] ?? (g == k && g.isNotEmpty ? g[0].toUpperCase() + g.substring(1) : g);
}

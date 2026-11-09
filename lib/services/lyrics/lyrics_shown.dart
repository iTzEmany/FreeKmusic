import 'package:drift/drift.dart' show Value;

import '../../data/db/app_database.dart';
import '../online/lrc_parser.dart';

/// Plain text of lyrics held as [plain] and/or [synced], or null.
String? plainTextOf(String? plain, String? synced) {
  if (plain != null) return plain;
  if (synced == null) return null;
  final lines = parseLrc(synced);
  return lines.isEmpty ? null : lines.map((e) => e.text).join('\n');
}

/// Plain text of a track's lyrics (copy action), or null.
String? lyricsPlainText(Track t) => plainTextOf(t.lyricsPlain, t.lyricsSynced);

/// [t] as shown: with the sync switched off for it (D-472) only the plain text
/// is left, the synced one stays stored.
Track lyricsAsShown(Track t, Set<int> unsynced) =>
    unsynced.contains(t.id) && t.lyricsSynced != null
    ? t.copyWith(
        lyricsPlain: Value(lyricsPlainText(t)),
        lyricsSynced: const Value(null),
      )
    : t;

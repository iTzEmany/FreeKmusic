import '../../data/db/app_database.dart';
import '../../data/repositories/track_kinds.dart';

/// The parts [EnrichmentService.completeOne] can fill.
enum EnrichPart { meta, lyrics, synced, curio, credits }

/// What one part of [EnrichmentService.completeOne] came to. [failed]: a source
/// did not answer; [limited]: a source refused (too many requests). Neither
/// writes a «searched, nothing» mark. [skipped]: off, not due, or no source
/// reachable (no call made).
enum PartOutcome {
  found,
  none,
  failed,
  limited,
  skipped;

  /// The sources gave an answer, empty or not.
  bool get answered => this == found || this == none;
}

/// The `tracks` fields online enrichment can write.
enum EnrichField {
  title,
  artist,
  album,
  year,
  genre,
  trackNumber,
  cover,
  lyrics,
  curiosity
}

/// How a part is asked for. [due]: only when empty and not marked «nothing»
/// in the last 30 days. [retryNone]: also over such a mark (the part must
/// still be empty). [force]: also over a full curiosities column; only the
/// credits card «Aggiorna» uses it.
enum AskMode { due, retryNone, force }

final _instrumentalTitle = RegExp(
  r'[(\[]\s*instrumental\s*[)\]]|instrumental version|-\s*instrumental\b',
  caseSensitive: false,
);

/// Fallback when LRCLIB did not say: the title announces an instrumental (D-684).
bool isInstrumentalTitle(String title) => _instrumentalTitle.hasMatch(title);

/// A «searched, nothing» answer is asked again after this long.
const retryNoneAfter = Duration(days: 30);

/// Whether [part] of [track] is empty and worth asking for at [now]: never
/// searched, or searched with an empty answer more than 30 days ago.
/// [hasCredits] says whether `track_credits` has rows for the track.
/// `synced` is due only with a plain text the user did not write and no synced one.
/// [mode] other than [AskMode.due] ignores a recent «searched, nothing» mark
/// (the part must still be empty, except `curio` under [AskMode.force]).
/// [dueSql] is the same rule in SQL.
bool isDue(
  EnrichPart part,
  Track track,
  TrackEnrichData? enrich,
  DateTime now, {
  bool hasCredits = false,
  AskMode mode = AskMode.due,
}) {
  final byUser = enrich?.lyricsByUser ?? false;
  // An instrumental has no text to look for.
  if ((part == EnrichPart.lyrics || part == EnrichPart.synced) &&
      (enrich?.instrumental == true || isInstrumentalTitle(track.title))) {
    return false;
  }
  final (empty, noneAt) = switch (part) {
    EnrichPart.meta => (
      fillableFields(track).intersection(_metaFields).isNotEmpty ||
          !track.hasCover,
      enrich?.metaNoneAt,
    ),
    EnrichPart.lyrics => (
      !byUser && track.lyricsPlain == null && track.lyricsSynced == null,
      enrich?.lyricsNoneAt,
    ),
    EnrichPart.synced => (
      !byUser && track.lyricsPlain != null && track.lyricsSynced == null,
      enrich?.syncedNoneAt,
    ),
    // A refresh replaces the curiosities, so force asks over a full column too.
    EnrichPart.curio => (mode == AskMode.force || track.curiosities == null, enrich?.curioNoneAt),
    EnrichPart.credits => (!hasCredits, enrich?.creditsNoneAt),
  };
  if (!empty) return false;
  return mode != AskMode.due ||
      noneAt == null ||
      now.difference(DateTime.fromMillisecondsSinceEpoch(noneAt)) >
          retryNoneAfter;
}

const _metaFields = {
  EnrichField.album,
  EnrichField.year,
  EnrichField.genre,
  EnrichField.trackNumber,
};

/// The fields enrichment may fill on [t]: the empty ones; a `userEdited`
/// track keeps its album empty.
Set<EnrichField> fillableFields(Track t) => {
  if (t.album == null && !t.userEdited) EnrichField.album,
  if (t.year == null) EnrichField.year,
  if (t.genre == null) EnrichField.genre,
  if (t.trackNumber == null) EnrichField.trackNumber,
  EnrichField.lyrics,
};

/// The tracks enrichment looks at (library and stream, not missing or hidden),
/// with their `track_enrich` row as `e`.
const eligibleSql =
    'tracks t LEFT JOIN track_enrich e ON e.track_id = t.id '
    'WHERE t.kind IN ($kMusicKind, $kStreamKind) AND t.missing = 0 AND t.ignored = 0';

/// The SQL form of [isDue] for [parts] under [mode]: true when any part is
/// due. `?1` is the instant before which a «nothing» mark no longer holds
/// (now minus [retryNoneAfter] in milliseconds); not used outside [AskMode.due].
String dueSql(Set<EnrichPart> parts, AskMode mode) {
  String due(String empty, String mark) => mode == AskMode.due
      ? '($empty AND (e.$mark IS NULL OR e.$mark < ?1))'
      : '($empty)';
  // The title heuristic is approximate here; [isDue] and the engine decide again.
  const askable = "COALESCE(e.lyrics_by_user, 0) = 0 AND COALESCE(e.instrumental, 0) = 0 "
      "AND LOWER(t.title) NOT LIKE '%instrumental%'";
  return [
    for (final p in parts)
      switch (p) {
        EnrichPart.meta => due(
          '((t.album IS NULL AND t.user_edited = 0) OR t.year IS NULL '
              'OR t.genre IS NULL OR t.track_number IS NULL OR t.has_cover = 0)',
          'meta_none_at',
        ),
        EnrichPart.lyrics => due(
          '$askable AND t.lyrics_plain IS NULL AND t.lyrics_synced IS NULL',
          'lyrics_none_at',
        ),
        EnrichPart.synced => due(
          '$askable AND t.lyrics_plain IS NOT NULL AND t.lyrics_synced IS NULL',
          'synced_none_at',
        ),
        EnrichPart.curio => due(
          mode == AskMode.force ? '1' : 't.curiosities IS NULL',
          'curio_none_at',
        ),
        EnrichPart.credits => due(
          'NOT EXISTS (SELECT 1 FROM track_credits c WHERE c.track_id = t.id)',
          'credits_none_at',
        ),
      },
  ].join(' OR ');
}

/// `tracks.enrich_status`: 0, 1, 2 in the database.
enum EnrichStatus {
  untried(0),
  found(1),
  nothing(2);

  const EnrichStatus(this.code);

  final int code;

  static EnrichStatus fromCode(int code) =>
      values.firstWhere((s) => s.code == code, orElse: () => untried);
}

/// The status a track gets from what [out] says its parts came to (D-279,
/// D-285), or null to leave it as it is. `found` if any part found something;
/// `nothing` only from `untried`, when metadata was asked and came out `none`
/// and so did every other part asked.
/// A part that failed or was refused, a `found` track and credits never lower it.
EnrichStatus? statusAfter(
  EnrichStatus before,
  Map<EnrichPart, PartOutcome> out,
) {
  final asked = [
    for (final MapEntry(key: p, value: o) in out.entries)
      if (p != EnrichPart.credits && o != PartOutcome.skipped) o,
  ];
  if (asked.contains(PartOutcome.found)) return EnrichStatus.found;
  if (before == EnrichStatus.untried &&
      out[EnrichPart.meta] == PartOutcome.none &&
      asked.every((o) => o == PartOutcome.none)) {
    return EnrichStatus.nothing;
  }
  return null;
}

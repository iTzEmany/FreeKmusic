import '../../core/import_row.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/import_repository.dart' show PlaylistImportItemX;
import 'track_matcher.dart';
import '../../core/artist_key.dart';

export '../../core/playlist_order.dart';

/// What a refreshed file changes in a playlist that was imported before.
class ImportDiff {
  const ImportDiff({
    this.added = const [],
    this.removed = const [],
    this.kept = const [],
    this.parked = const [],
  });

  /// Rows of the new file that match nothing already in the playlist.
  final List<ImportRow> added;

  /// Tracks of the playlist whose row is gone from the file.
  final List<PlaylistImportItem> removed;

  /// Rows that are still there, with the old item (and so the track) they match.
  final List<({PlaylistImportItem old, ImportRow fresh})> kept;

  /// Rows that an earlier import left «not found» or «skipped»: not new, and
  /// a sync leaves them as they were («Riprova» on the import searches again).
  final List<({PlaylistImportItem old, ImportRow fresh})> parked;
}

String _titleArtistKey(String title, String primaryArtist) =>
    '${matchTitleKey(title)}|${matchKey(primaryArtist)}';

/// Matches [fresh] rows to the [old] items of a playlist, one to one: first by
/// ISRC, then by title and main artist (so a new ISRC for the same song, as
/// when a service re-releases it, still counts as the same song).
ImportDiff diffImport(
  List<PlaylistImportItem> old,
  List<ImportRow> fresh, {
  List<PlaylistImportItem> parked = const [],
}) {
  final freeOld = List.of(old);
  final matched = <int, PlaylistImportItem>{};

  PlaylistImportItem? take(bool Function(PlaylistImportItem) test) {
    final i = freeOld.indexWhere(test);
    return i < 0 ? null : freeOld.removeAt(i);
  }

  for (final r in fresh) {
    final isrc = r.isrc;
    if (isrc == null || isrc.isEmpty) continue;
    final hit = take((o) => o.isrc == isrc);
    if (hit != null) matched[r.index] = hit;
  }
  for (final r in fresh) {
    if (matched.containsKey(r.index)) continue;
    final key = _titleArtistKey(r.title, r.primaryArtist);
    final hit = take(
        (o) => _titleArtistKey(o.title, o.toRow().primaryArtist) == key);
    if (hit != null) matched[r.index] = hit;
  }
  // Whatever is still unmatched may be a row parked by an earlier import.
  final freeParked = List.of(parked);
  final parkedHit = <int, PlaylistImportItem>{};
  for (final r in fresh) {
    if (matched.containsKey(r.index)) continue;
    final isrc = r.isrc;
    final key = _titleArtistKey(r.title, r.primaryArtist);
    final i = freeParked.indexWhere((o) =>
        (isrc != null && isrc.isNotEmpty && o.isrc == isrc) ||
        _titleArtistKey(o.title, o.toRow().primaryArtist) == key);
    if (i >= 0) parkedHit[r.index] = freeParked.removeAt(i);
  }
  return ImportDiff(
    added: [
      for (final r in fresh)
        if (!matched.containsKey(r.index) && !parkedHit.containsKey(r.index)) r,
    ],
    parked: [
      for (final r in fresh)
        if (parkedHit.containsKey(r.index)) (old: parkedHit[r.index]!, fresh: r),
    ],
    removed: freeOld,
    kept: [
      for (final r in fresh)
        if (matched.containsKey(r.index)) (old: matched[r.index]!, fresh: r),
    ],
  );
}

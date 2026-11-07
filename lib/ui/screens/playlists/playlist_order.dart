import '../../../data/db/app_database.dart';
import '../../../data/repositories/library_entries.dart';

/// How a playlist is shown. [personal] is `playlist_tracks.position`, which a
/// view order never rewrites (D-424).
enum PlaylistSort {
  personal,
  title,
  artist,
  album,
  year,
  added,
  recent,
  plays,
  duration;

  bool get ascendingByDefault =>
      this != year && this != added && this != duration && this != recent && this != plays;
}

/// A playlist's saved order, read from «criterion:asc|desc».
class PlaylistOrder {
  const PlaylistOrder(this.sort, this.ascending);

  static const personal = PlaylistOrder(PlaylistSort.personal, true);

  final PlaylistSort sort;
  final bool ascending;

  factory PlaylistOrder.parse(String? raw) {
    final parts = raw?.split(':') ?? const <String>[];
    final sort = PlaylistSort.values
        .where((s) => s.name == (parts.isEmpty ? null : parts[0]))
        .firstOrNull;
    if (sort == null || sort == PlaylistSort.personal) return personal;
    return PlaylistOrder(sort, parts.length < 2 || parts[1] != 'desc');
  }

  String encode() => '${sort.name}:${ascending ? 'asc' : 'desc'}';

  /// [tracks] (already in personal order) shown in this order; a stable sort,
  /// so equal keys keep their personal order.
  List<Track> apply(List<Track> tracks) {
    if (sort == PlaylistSort.personal) return tracks;
    // Same folding as the Library; a missing value (empty text, 0) comes last
    // in both directions.
    Comparable<dynamic>? text(String? v) =>
        v == null || v.trim().isEmpty ? null : sortKeyOfText(v);
    Comparable<dynamic>? number(int? v) => v == null || v == 0 ? null : v;
    final fields = switch (sort) {
      PlaylistSort.title => <Comparable<dynamic>? Function(Track)>[(t) => text(t.title)],
      PlaylistSort.artist => [(t) => text(t.artist), (t) => text(t.title)],
      PlaylistSort.album => [
        (t) => text(t.album),
        (t) => number(t.discNumber),
        (t) => number(t.trackNumber),
      ],
      PlaylistSort.year => [(t) => number(t.year)],
      PlaylistSort.added => [(t) => number(t.addedAt)],
      // Never played comes last, as in the Library.
      PlaylistSort.recent => [(t) => t.lastPlayedAt],
      PlaylistSort.plays => [(t) => t.playCount],
      _ => [(t) => number(t.durationMs)],
    };
    // Keys computed once per track, not once per comparison.
    final keys = [
      for (final t in tracks) [for (final f in fields) f(t)],
    ];
    int cmp(int i, int j) {
      for (var k = 0; k < fields.length; k++) {
        final a = keys[i][k], b = keys[j][k];
        if (a == null || b == null) {
          if (a != b) return a == null ? 1 : -1;
          continue;
        }
        final c = a.compareTo(b);
        if (c != 0) return ascending ? c : -c;
      }
      return i.compareTo(j);
    }

    final order = [for (var i = 0; i < tracks.length; i++) i]..sort(cmp);
    return [for (final i in order) tracks[i]];
  }
}

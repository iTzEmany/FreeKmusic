import '../../../data/db/app_database.dart';

/// How a playlist is shown. [personal] is `playlist_tracks.position`, which a
/// view order never rewrites (D-424).
enum PlaylistSort {
  personal,
  title,
  artist,
  album,
  year,
  added,
  duration;

  bool get ascendingByDefault =>
      this != year && this != added && this != duration;
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
    int cmpText(String? a, String? b) =>
        (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());
    int cmpInt(int? a, int? b) => (a ?? 0).compareTo(b ?? 0);
    final cmp = switch (sort) {
      PlaylistSort.title => (Track a, Track b) => cmpText(a.title, b.title),
      PlaylistSort.artist => (Track a, Track b) {
        final c = cmpText(a.artist, b.artist);
        return c != 0 ? c : cmpText(a.title, b.title);
      },
      PlaylistSort.album => (Track a, Track b) {
        final c = cmpText(a.album, b.album);
        if (c != 0) return c;
        final d = cmpInt(a.discNumber, b.discNumber);
        return d != 0 ? d : cmpInt(a.trackNumber, b.trackNumber);
      },
      PlaylistSort.year => (Track a, Track b) => cmpInt(a.year, b.year),
      PlaylistSort.added => (Track a, Track b) => cmpInt(a.addedAt, b.addedAt),
      _ => (Track a, Track b) => cmpInt(a.durationMs, b.durationMs),
    };
    final indexed = [for (var i = 0; i < tracks.length; i++) (i, tracks[i])];
    indexed.sort((x, y) {
      final c = cmp(x.$2, y.$2);
      return c != 0 ? (ascending ? c : -c) : x.$1.compareTo(y.$1);
    });
    return [for (final e in indexed) e.$2];
  }
}

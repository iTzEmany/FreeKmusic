import '../db/app_database.dart';
import 'library_entries.dart';
import 'library_queries.dart';
import 'track_kinds.dart';

enum Greeting { morning, afternoon, evening }

/// 05–11 morning, 12–17 afternoon, otherwise evening (late nights too).
Greeting greetingForHour(int hour) {
  if (hour >= 5 && hour < 12) return Greeting.morning;
  if (hour >= 12 && hour < 18) return Greeting.afternoon;
  return Greeting.evening;
}

/// Albums played a lot but not for a while, most played first.
List<AlbumSummary> rediscoverAlbums(
  List<AlbumSummary> albums,
  DateTime now, {
  int minPlays = 3,
  Duration idle = const Duration(days: 60),
  int limit = 10,
}) {
  final cutoff = now.subtract(idle).millisecondsSinceEpoch;
  final out = [
    for (final a in albums)
      if (a.playCount >= minPlays &&
          a.lastPlayedAt != null &&
          a.lastPlayedAt! < cutoff)
        a,
  ]..sort((a, b) => b.playCount.compareTo(a.playCount));
  return out.take(limit).toList();
}

/// Albums by latest `addedAt`.
List<AlbumSummary> recentlyAddedAlbums(
  List<AlbumSummary> albums, {
  int limit = 10,
}) {
  final out = [...albums]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
  return out.take(limit).toList();
}

/// The areas of «Riprendi»: at most one item each (D-671).
enum ResumeArea { track, podcast, album, playlist, radio, daylist }

/// One tile of «Riprendi». Which field is set depends on [area]: [track]
/// (track, podcast), [entry] (album, playlist), [radio]; the daylist has none.
/// [queueIndex]/[queueLength] are set when [track] is what the queue plays now.
class ResumeItem {
  const ResumeItem(
    this.area,
    this.at, {
    this.track,
    this.entry,
    this.radio,
    this.queueIndex,
    this.queueLength,
  });
  final ResumeArea area;
  final int at;
  final Track? track;
  final LibraryEntry? entry;
  final SavedRadio? radio;
  final int? queueIndex, queueLength;
}

/// The latest of each area, the most recent first. [plays] are the latest
/// play per area; an album or playlist play (with its context [name]) finds its
/// entry in [entries], and without one the area falls back to the entry played
/// last (a track of it, in any context). The playing queue wins its own area
/// ([queueArea]) when that is track, podcast or daylist.
List<ResumeItem> lastPerArea({
  Track? current,
  List<Track> queue = const [],
  ResumeArea? queueArea,
  List<({ResumeArea area, Track track, int at, String? name})> plays = const [],
  List<Track> resumable = const [],
  List<LibraryEntry> entries = const [],
  List<SavedRadio> radios = const [],
}) {
  ResumeArea ofTrack(Track t) =>
      t.kind == kEpisodeKind ? ResumeArea.podcast : ResumeArea.track;
  final index = current == null
      ? -1
      : queue.indexWhere((t) => t.id == current.id);
  final best = <ResumeArea, ResumeItem>{};
  void offer(ResumeItem i) {
    final b = best[i.area];
    if (b == null || i.at > b.at) best[i.area] = i;
  }

  // Album, playlist and radio tiles need their entry/station: they come from [entries]/[radios].
  final fromPlays = <ResumeArea>{};
  final playingArea = queueArea ?? (current == null ? null : ofTrack(current));
  if (current != null &&
      index >= 0 &&
      (playingArea == ResumeArea.track ||
          playingArea == ResumeArea.podcast ||
          playingArea == ResumeArea.daylist)) {
    offer(
      ResumeItem(
        playingArea!,
        1 << 62,
        track: current,
        queueIndex: index,
        queueLength: queue.length,
      ),
    );
  }
  LibraryEntry? entryOf(ResumeArea area, Track t, String? name) {
    for (final e in entries) {
      if (area == ResumeArea.album
          ? e.kind == LibraryKind.album && e.id == t.albumKey
          : e.kind == LibraryKind.playlist && name != null && e.title == name) {
        return e;
      }
    }
    return null;
  }

  for (final p in plays) {
    if (p.area == ResumeArea.album || p.area == ResumeArea.playlist) {
      final e = entryOf(p.area, p.track, p.name);
      if (e == null) continue;
      fromPlays.add(p.area);
      offer(ResumeItem(p.area, p.at, entry: e));
      continue;
    }
    if (index >= 0 && p.track.id == current!.id) continue;
    offer(
      ResumeItem(
        p.area,
        p.at,
        track: p.area == ResumeArea.track || p.area == ResumeArea.podcast
            ? p.track
            : null,
      ),
    );
  }
  for (final t in resumable) {
    if (index >= 0 && t.id == current!.id) continue;
    offer(ResumeItem(ofTrack(t), t.lastPlayedAt ?? 0, track: t));
  }
  for (final e in entries) {
    final at = e.lastPlayedAt;
    if (at == null) continue;
    switch (e.kind) {
      case LibraryKind.album when !fromPlays.contains(ResumeArea.album):
        offer(ResumeItem(ResumeArea.album, at, entry: e));
      case LibraryKind.playlist when !fromPlays.contains(ResumeArea.playlist):
        offer(ResumeItem(ResumeArea.playlist, at, entry: e));
      case LibraryKind.album || LibraryKind.playlist:
        break;
      case LibraryKind.artist:
        break;
    }
  }
  for (final r in radios) {
    final at = r.lastPlayedAt;
    if (at != null) offer(ResumeItem(ResumeArea.radio, at, radio: r));
  }
  return best.values.toList()..sort((a, b) => b.at.compareTo(a.at));
}

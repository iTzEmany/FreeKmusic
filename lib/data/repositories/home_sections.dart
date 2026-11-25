import '../db/app_database.dart';
import '../play_context_kind.dart';
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

/// The kinds of item of «Riprendi» (D-725).
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

/// The area a play context belongs to; radio is read from the stations (null). A kind this version does not know reads as the library.
ResumeArea? resumeAreaOf(PlayContextKind kind) => switch (kind) {
  PlayContextKind.album => ResumeArea.album,
  PlayContextKind.playlist => ResumeArea.playlist,
  PlayContextKind.radio => null,
  PlayContextKind.podcast => ResumeArea.podcast,
  PlayContextKind.daylist => ResumeArea.daylist,
  _ => ResumeArea.track,
};

/// The latest distinct things played, the most recent first, at most [limit] (D-725). Distinct means
/// one item per track, album, playlist or station; the daylist is one item, left out when [daylist]
/// is false (its card is on Home). [plays] are the latest play per context kind (radio plays are
/// left out: [radios] give the station); an album or playlist play (with its context [name]) finds
/// its entry in [entries]. The playing queue wins its own track, podcast or daylist item.
List<ResumeItem> recentResumeItems({
  Track? current,
  List<Track> queue = const [],
  PlayContextKind? queueKind,
  List<({PlayContextKind kind, Track track, int at, String? name})> plays =
      const [],
  List<Track> resumable = const [],
  List<LibraryEntry> entries = const [],
  List<SavedRadio> radios = const [],
  bool daylist = true,
  int limit = 8,
}) {
  ResumeArea ofTrack(Track t) =>
      t.kind == kEpisodeKind ? ResumeArea.podcast : ResumeArea.track;
  final index = current == null
      ? -1
      : queue.indexWhere((t) => t.id == current.id);
  final best = <String, ResumeItem>{};
  void offer(ResumeItem i, String id) {
    final b = best[id];
    if (b == null || i.at > b.at) best[id] = i;
  }

  final queueArea = queueKind == PlayContextKind.radio
      ? ResumeArea.radio
      : queueKind == null
      ? null
      : resumeAreaOf(queueKind);
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
      playingArea == ResumeArea.daylist ? 'd' : 't${current.id}',
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

  for (final play in plays) {
    final area = resumeAreaOf(play.kind);
    if (area == null) continue;
    if (area == ResumeArea.album || area == ResumeArea.playlist) {
      final e = entryOf(area, play.track, play.name);
      if (e != null) {
        offer(ResumeItem(area, play.at, entry: e), '${e.kind.name}${e.id}');
      }
      continue;
    }
    if (area == ResumeArea.daylist) {
      if (index < 0 || play.track.id != current!.id) {
        offer(ResumeItem(area, play.at), 'd');
      }
      continue;
    }
    if (index >= 0 && play.track.id == current!.id) continue;
    offer(ResumeItem(area, play.at, track: play.track), 't${play.track.id}');
  }
  for (final t in resumable) {
    if (index >= 0 && t.id == current!.id) continue;
    offer(ResumeItem(ofTrack(t), t.lastPlayedAt ?? 0, track: t), 't${t.id}');
  }
  for (final e in entries) {
    final at = e.lastPlayedAt;
    if (at == null) continue;
    final area = switch (e.kind) {
      LibraryKind.album => ResumeArea.album,
      LibraryKind.playlist => ResumeArea.playlist,
      LibraryKind.artist => null,
    };
    if (area != null) {
      offer(ResumeItem(area, at, entry: e), '${e.kind.name}${e.id}');
    }
  }
  for (final r in radios) {
    final at = r.lastPlayedAt;
    if (at != null) {
      offer(ResumeItem(ResumeArea.radio, at, radio: r), 'r${r.stationId}');
    }
  }
  final out = [
    for (final i in best.values)
      if (daylist || i.area != ResumeArea.daylist) i,
  ]..sort((a, b) => b.at.compareTo(a.at));
  return out.take(limit).toList();
}

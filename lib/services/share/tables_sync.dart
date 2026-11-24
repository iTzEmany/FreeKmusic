import 'dart:convert' show jsonEncode;

import '../backup/backup_db_reader.dart' show BackupDbData;
import '../backup/user_data.dart';
import '../stream/stream_key.dart' show isStreamKey;
import 'playlist_sync.dart' show RemotePlaylist;

/// Longest lyrics, synced lyrics or curiosities text read from another device; a longer one is dropped.
const kMaxTextLength = 100000;

/// Texts sent in one answer of `POST /sync/texts`; the caller asks again after the last track id.
const kTextsPerPage = 200;

/// Longest list of tags of one track read from another device.
const kMaxTagsPerTrack = 100;

/// Most (track, tag) pairs in one answer of `GET /sync/collections`, on both sides.
const kMaxTaggedPairs = 20000;

/// Most characters of lyrics and curiosities kept from one sync (the rest is not read): memory is bounded.
const kMaxSyncTextChars = 20000000;

/// [tagged] cut so that the total of pairs is at most [kMaxTaggedPairs] (the last track may lose some tags).
List<TaggedTrack> limitTagged(List<TaggedTrack> tagged) {
  final out = <TaggedTrack>[];
  var left = kMaxTaggedPairs;
  for (final t in tagged) {
    if (left <= 0) break;
    out.add(t.tags.length <= left ? t : TaggedTrack(ref: t.ref, tags: t.tags.take(left).toList()));
    left -= t.tags.length;
  }
  return out;
}

/// Stable key of a track reference: [TrackRef] has no equality.
String refKey(TrackRef r) => jsonEncode(r.toJson());

TrackRef? _ref(Object? j, {required bool stream}) {
  try {
    final r = RemotePlaylist.parseTrackRef(j);
    final key = r.streamKey;
    return (key == null ? true : stream && isStreamKey(key)) ? r : null;
  } on FormatException {
    return null; // a malformed entry is dropped, the rest is read
  }
}

String? _text(Object? v) =>
    v is String && v.trim().isNotEmpty && v.length <= kMaxTextLength ? v : null;

String? _name(Object? v) =>
    v is String && v.trim().isNotEmpty && v.length <= kMaxKeyLength
    ? v.trim()
    : null;

/// Lyrics, synced lyrics and curiosities of a track of the library (no streamed track: its row is not made by a sync).
class TextEntry {
  const TextEntry({
    required this.ref,
    this.plain,
    this.synced,
    this.curiosities,
  });

  final TrackRef ref;
  final String? plain, synced, curiosities;

  Map<String, Object?> toJson() => {
    'ref': ref.toJson(),
    if (plain != null) 'plain': plain,
    if (synced != null) 'synced': synced,
    if (curiosities != null) 'curiosities': curiosities,
  };

  /// Null for a malformed entry, a streamed track, or one without any text.
  static TextEntry? tryParse(Object? j) {
    if (j is! Map) return null;
    final ref = _ref(j['ref'], stream: false);
    if (ref == null) return null;
    final e = TextEntry(
      ref: ref,
      plain: _text(j['plain']),
      synced: _text(j['synced']),
      curiosities: _text(j['curiosities']),
    );
    return e.plain == null && e.synced == null && e.curiosities == null
        ? null
        : e;
  }
}

/// A listen: the key is the track and the moment (`playedAt`), as in a backup's merge.
class PlayEntry {
  const PlayEntry({
    required this.ref,
    required this.playedAt,
    this.msPlayed = 0,
    this.context,
    this.contextName,
  });

  final TrackRef ref;
  final int playedAt, msPlayed;

  /// `PlayContextKind.index` as the other device wrote it: may be one this version does not know (read as the library).
  final int? context;
  final String? contextName;

  Map<String, Object?> toJson() => {
    'ref': ref.toJson(),
    'playedAt': playedAt,
    'msPlayed': msPlayed,
    if (context != null) 'context': context,
    if (contextName != null) 'contextName': contextName,
  };

  /// Null for a malformed entry or an impossible date (the moment of a listen is never in the future).
  static PlayEntry? tryParse(Object? j) {
    if (j is! Map) return null;
    final ref = _ref(j['ref'], stream: true), at = sanePastDate(j['playedAt']);
    if (ref == null || at == null) return null;
    final ms = j['msPlayed'], ctx = j['context'], name = j['contextName'];
    return PlayEntry(
      ref: ref,
      playedAt: at,
      msPlayed: ms is int && ms >= 0 && ms <= 86400000 ? ms : 0,
      context: ctx is int && ctx >= 0 && ctx < 1000 ? ctx : null,
      contextName: name is String && name.length <= kMaxKeyLength ? name : null,
    );
  }
}

/// A tag of the user; [color] is the index of an accent (0-7).
class TagEntry {
  const TagEntry({required this.name, this.color});

  final String name;
  final int? color;

  Map<String, Object?> toJson() => {
    'name': name,
    if (color != null) 'color': color,
  };

  static TagEntry? tryParse(Object? j) {
    final name = j is Map ? _name(j['name']) : null,
        color = j is Map ? j['color'] : null;
    return name == null
        ? null
        : TagEntry(
            name: name,
            color: color is int && color >= 0 && color < 8 ? color : null,
          );
  }
}

/// The tags (by name) of one track.
class TaggedTrack {
  const TaggedTrack({required this.ref, required this.tags});

  final TrackRef ref;
  final List<String> tags;

  Map<String, Object?> toJson() => {'ref': ref.toJson(), 'tags': tags};

  static TaggedTrack? tryParse(Object? j) {
    if (j is! Map || j['tags'] is! List) return null;
    final ref = _ref(j['ref'], stream: true);
    final tags = [
      for (final t in (j['tags'] as List).take(kMaxTagsPerTrack)) ?_name(t),
    ];
    return ref == null || tags.isEmpty
        ? null
        : TaggedTrack(ref: ref, tags: tags);
  }
}

/// What a device sends besides playlists and collections, or what a sync would add here (the plan keeps only the
/// news): lyrics and curiosities, listens and tags. Merged with the rules of a backup's merge: nothing is lost.
class TablesBundle {
  const TablesBundle({
    this.texts = const [],
    this.plays = const [],
    this.tags = const [],
    this.tagged = const [],
  });

  final List<TextEntry> texts;
  final List<PlayEntry> plays;
  final List<TagEntry> tags;
  final List<TaggedTrack> tagged;

  bool get isEmpty =>
      texts.isEmpty && plays.isEmpty && tags.isEmpty && tagged.isEmpty;

  /// How many (track, tag) pairs.
  int get taggedCount => tagged.fold(0, (n, t) => n + t.tags.length);

  /// The listens and tags as the rows of a backup's database, so `mergeTablesData` can merge them. A tag named by a
  /// tagged track but not in [tags] is made too (without a colour: one that exists here keeps its own).
  BackupDbData toBackupData() {
    final refs = <int, TrackRef>{};
    final ids = <String, int>{}; // one backup id per distinct track
    int refId(TrackRef r) => ids.putIfAbsent(refKey(r), () {
      refs[refs.length] = r;
      return refs.length - 1;
    });
    final tagRows = <Map<String, Object?>>[];
    final tagId = <String, int>{};
    int tag(String name, int? color) =>
        tagId.putIfAbsent(name.toLowerCase(), () {
          tagRows.add({'id': tagRows.length, 'name': name, 'color': color});
          return tagRows.length - 1;
        });
    for (final t in tags) {
      tag(t.name, t.color);
    }
    final rows = <Map<String, Object?>>[];
    for (final p in plays) {
      rows.add({
        'track_id': refId(p.ref),
        'played_at': p.playedAt,
        'ms_played': p.msPlayed,
        'context': p.context,
        'context_name': p.contextName,
      });
    }
    final pairs = <Map<String, Object?>>[];
    for (final t in tagged) {
      final id = refId(t.ref);
      for (final name in t.tags) {
        pairs.add({'track_id': id, 'tag_id': tag(name, null)});
      }
    }
    return BackupDbData(
      plays: rows,
      userTags: tagRows,
      trackTags: pairs,
      refs: refs,
    );
  }
}

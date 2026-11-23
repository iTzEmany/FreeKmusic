import 'dart:async';

import '../../data/db/app_database.dart';
import '../../data/repositories/track_kinds.dart';
import '../radio/radio_station.dart';
import '../stream/stream_key.dart' show displayArtist;
import '../online/youtube_service.dart';

/// Online entries in the queue have negative ids; library tracks are > 0.
bool isOnlineId(int id) => id < 0;

/// A track that plays from the stream cache: a registry entry or a shadow row.
bool isStreamTrack(Track t) => isOnlineId(t.id) || t.kind == kStreamKind;

/// One streamed (not owned) track: what to play and why it is there.
class OnlineEntry {
  const OnlineEntry({
    required this.id,
    required this.result,
    required this.addedAt,
    this.seedTitle,
    this.trackId,
    this.suggested = false,
  });

  final int id;

  /// The shadow row (`kind = 2`) of this track, once the preparer made it.
  final int? trackId;
  final YtResult result;

  /// Put in the queue by Shuffle+ (not chosen by the user).
  final bool suggested;

  /// The library track this one is «similar to», if any.
  final String? seedTitle;
  final DateTime addedAt;
}

/// One radio station in the queue: a live stream, with no length.
class RadioEntry {
  const RadioEntry({required this.id, required this.station, required this.addedAt});

  final int id;
  final RadioStation station;
  final DateTime addedAt;
}

/// In-memory registry of the online entries of this session. Never written to
/// the database; ids are never reused, even after [forget].
class OnlineEntries {
  OnlineEntries({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<int, OnlineEntry> _entries = {};
  final Map<int, RadioEntry> _radios = {};
  final Map<String, int> _radioIds = {};
  int _last = 0;

  int register(YtResult result, {String? seedTitle, bool suggested = false}) {
    final id = --_last;
    _entries[id] = OnlineEntry(
      id: id,
      result: result,
      seedTitle: seedTitle,
      suggested: suggested,
      addedAt: _now(),
    );
    return id;
  }

  /// Registers [station] and returns its id; the same station keeps its id
  /// for the session, so a queue built twice from one list stays the same.
  int registerRadio(RadioStation station) {
    final known = _radioIds[station.id];
    if (known != null) {
      _radios[known] = RadioEntry(id: known, station: station, addedAt: _radios[known]!.addedAt);
      return known;
    }
    final id = --_last;
    _radioIds[station.id] = id;
    _radios[id] = RadioEntry(id: id, station: station, addedAt: _now());
    return id;
  }

  bool isRadioId(int id) => _radios.containsKey(id);

  RadioEntry? radioOf(int id) => _radios[id];

  final _bound = StreamController<int>.broadcast();

  /// Ids of the entries that just got their shadow row.
  Stream<int> get bound => _bound.stream;

  void bindRow(int id, int rowId) {
    final e = _entries[id];
    if (e == null) return;
    _entries[id] = OnlineEntry(
        id: id, result: e.result, addedAt: e.addedAt, seedTitle: e.seedTitle, trackId: rowId, suggested: e.suggested);
    _bound.add(id);
  }

  /// The row [from] was merged into [to]: its entries follow.
  void rebindRow(int from, int to) {
    for (final e in _entries.values.toList()) {
      if (e.trackId == from) bindRow(e.id, to);
    }
  }

  /// The rows [ids] were deleted: entries bound to them are streams again, not tied to a dead id.
  void unbindRows(Set<int> ids) {
    for (final e in _entries.values.toList()) {
      if (e.trackId == null || !ids.contains(e.trackId)) continue;
      _entries[e.id] = OnlineEntry(id: e.id, result: e.result, addedAt: e.addedAt, seedTitle: e.seedTitle, suggested: e.suggested);
    }
  }

  OnlineEntry? operator [](int id) => _entries[id];

  /// The ids of the stream entries registered for [r] (one video can be
  /// suggested, and so registered, more than once).
  List<int> idsOf(YtResult r) => [
        for (final e in _entries.values)
          if (e.result.indexKey == r.indexKey) e.id
      ];

  /// Same as `[]`, readable after a `?.` or `?` in an expression.
  OnlineEntry? entryOf(int id) => _entries[id];

  void forget(int id) {
    _entries.remove(id);
    final radio = _radios.remove(id);
    if (radio != null) _radioIds.remove(radio.station.id);
  }

  /// A synthetic track for screens, notification and MPRIS. Never stored.
  Track? trackOf(int id) {
    final radio = _radios[id];
    if (radio != null) return _radioTrack(radio);
    final e = _entries[id];
    if (e == null) return null;
    final r = e.result;
    return Track(saved: false, coverSource: 0, 
      id: id,
      path: 'online:${r.source.name}:${r.id}',
      title: r.title,
      artist: displayArtist(r),
      album: r.album,
      albumKey: '',
      durationMs: r.duration?.inMilliseconds ?? 0,
      format: 'online',
      sizeBytes: 0,
      mtimeMs: 0,
      hasCover: false,
      coverKey: null,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false,
      kind: 0,
      addedAt: e.addedAt.millisecondsSinceEpoch,
      playCount: 0,
    );
  }

  Track _radioTrack(RadioEntry e) => Track(saved: false, coverSource: 0, 
        id: e.id,
        path: 'online:radio:${e.station.id}',
        title: e.station.name,
        artist: '',
        album: '',
        albumKey: '',
        durationMs: 0,
        format: 'online',
        sizeBytes: 0,
        mtimeMs: 0,
        hasCover: false,
        coverKey: null,
        isFavorite: false,
        enrichStatus: 0,
        userEdited: false,
        missing: false,
        ignored: false,
        kind: 0,
        addedAt: e.addedAt.millisecondsSinceEpoch,
        playCount: 0,
      );
}

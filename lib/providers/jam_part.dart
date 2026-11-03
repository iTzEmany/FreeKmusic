import 'dart:math' show Random;

import 'package:path/path.dart' as p;

import '../data/db/app_database.dart';
import '../data/repositories/library_queries.dart';
import '../data/repositories/track_repository.dart';
import '../services/jam/jam_models.dart';
import '../services/jam/jam_part_feeder.dart';
import '../services/jam/remote/jam_remote_items.dart';
import '../services/online/download_index.dart';
import '../services/jam/jam_suggestion.dart';

/// The Jam item of library track [t] owned by [ownId]; null when its format cannot go in a Jam.
JamItem? jamItemOfTrack(Track t, String ownId,
    {bool inherited = false, String? partKey, bool suggested = false, String? videoId}) {
  final ext = p.extension(t.path).replaceFirst('.', '').toLowerCase();
  if (!jamExts.contains(ext)) return null;
  return JamItem(
    id: 0,
    ownerDeviceId: ownId,
    title: t.title,
    artist: t.artist,
    album: t.album,
    durationMs: t.durationMs,
    ext: ext,
    sizeBytes: t.sizeBytes,
    ref: t.id.toString(),
    videoId: videoId, // not `yt:`: still not selfFetchable, D-93 keeps treating it as a file
    inherited: inherited,
    suggested: suggested,
    partKey: partKey,
  );
}

/// Our part of «Coda insieme» (R-99) for one Jam: the feeder, the queue from before the
/// Jam (genres of the suggestions, R-102) and the part worked out on «Esci».
class JamPart {
  JamPart({
    required this.ownId,
    required this.tracks,
    required this.queries,
    required this.downloads,
    required this.remoteItems,
  });

  final String Function() ownId;
  final TrackRepository Function() tracks;
  final LibraryQueries Function() queries;
  final Future<DownloadIndex> Function() downloads;
  final JamRemoteItems Function() remoteItems;
  var _remote = false;

  JamPartFeeder? feeder;
  var _beforeIds = const <int>[];
  Map<String, int>? _genres;
  final _random = Random();

  // Played in this Jam: the host trims old entries, so the state alone forgets them.
  final _playedIds = <int>{};
  final _playedKeys = <String>{};

  /// Our part worked out when the guest presses «Esci», before the host drops our tracks.
  List<int>? exitPart;

  /// A fresh feeder for the queue [ids] (the old one, if any, is stopped). [remote]: items
  /// go as video ids (R-153); a track not found online is skipped.
  void start(
    List<int> ids,
    Future<JamResult> Function(JamCommand) send, {
    bool remote = false,
  }) {
    _remote = remote;
    feeder?.dispose();
    _beforeIds = ids;
    _genres = null;
    _playedIds.clear();
    _playedKeys.clear();
    feeder = JamPartFeeder(
      ownId: ownId(),
      part: jamPartKeys(ids),
      send: send,
      itemOf: _item,
      suggest: _suggestion,
      keepUnavailable: remote,
    );
  }

  /// Library ids to give back on leaving: the part worked out on «Esci», else what is left now.
  List<int> unplayed(JamState? js) => exitPart ?? remaining(js);

  /// Library ids left of our part in [js] (empty without a feeder).
  List<int> remaining(JamState? js) =>
      js == null ? const [] : (feeder?.remaining(js) ?? const []);

  /// Stops the feeder; the rest stays readable until [clear].
  void stop() => feeder?.dispose();

  void clear() {
    feeder = null;
    _beforeIds = const [];
    _genres = null;
    _playedIds.clear();
    _playedKeys.clear();
    exitPart = null;
    _remote = false;
  }

  /// The part key of our own item that [cmd] removes in [js], if any.
  String? ownPartKey(JamState? js, JamCommand cmd) {
    if (cmd.type != JamCommandType.remove) return null;
    final i = js?.items.where((i) => i.id == cmd.itemId).firstOrNull;
    return i?.ownerDeviceId == ownId() ? i?.partKey : null;
  }

  Future<JamItem?> _item(String key) async {
    final id = jamPartKeyId(key);
    final t = id == null ? null : await tracks().getById(id);
    return t == null || t.missing ? null : itemOfTrack(t, partKey: key, rethrowErrors: true);
  }

  /// The Jam item of [t]: a video id when [remote] (default: this Jam's mode), else the
  /// library item with the video id of its download. Null: not found online / format.
  Future<JamItem?> itemOfTrack(
    Track t, {
    String? partKey,
    bool suggested = false,
    bool inherited = false,
    bool? remote,
    bool rethrowErrors = false,
  }) async {
    if (remote ?? _remote) {
      return remoteItems().of(t, ownId(),
          partKey: partKey, suggested: suggested, rethrowErrors: rethrowErrors);
    }
    return jamItemOfTrack(t, ownId(),
        inherited: inherited,
        partKey: partKey,
        suggested: suggested,
        videoId: (await downloads()).idForPath(t.path));
  }

  /// A track for a part that ran out: by the genres of our queue from before, none played in this Jam.
  Future<JamItem?> _suggestion(JamState s) async {
    final q = queries(), own = ownId();
    final genres = _genres ??= await q.genreCounts(_beforeIds);
    final played = s.items.take(s.currentIndex + 1);
    for (final i in played) {
      if (i.ownerDeviceId == own) _playedIds.addAll([?int.tryParse(i.ref ?? '')]);
      _playedKeys.add(suggestionKey(i.title, i.artist));
    }
    final t = await pickSuggestion<Track>(
      genreWeights: genres,
      random: _random,
      candidates: (g) async => [
        for (final t in await q.randomTracks(genre: g))
          if (jamItemOfTrack(t, own) != null) t,
      ],
      isPlayed: (t) => _playedIds.contains(t.id) || _playedKeys.contains(suggestionKey(t.title, t.artist)),
    );
    return t == null ? null : itemOfTrack(t, suggested: true, rethrowErrors: true);
  }
}

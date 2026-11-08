import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../core/app_log.dart';
import 'suggestion_log.dart';

class DislikedTrack {
  const DislikedTrack({
    required this.videoId,
    required this.title,
    required this.artist,
    this.at,
  });
  final String videoId, title, artist;

  /// When it was blocked (epoch ms); null for old and migrated entries.
  final int? at;

  DislikedTrack withAt(int at) =>
      DislikedTrack(videoId: videoId, title: title, artist: artist, at: at);

  Map<String, Object?> toJson() => {
    'id': videoId,
    'title': title,
    'artist': artist,
    'at': ?at,
  };

  static DislikedTrack? fromJson(Object? j) => j is Map && j['id'] is String
      ? DislikedTrack(
          videoId: j['id'] as String,
          title: '${j['title'] ?? ''}',
          artist: '${j['artist'] ?? ''}',
          at: j['at'] is int ? j['at'] as int : null,
        )
      : null;
}

class DislikedArtist {
  const DislikedArtist({required this.key, required this.name, this.at});

  /// `artistKey(name)`.
  final String key, name;

  /// When it was blocked (epoch ms); null for old entries.
  final int? at;

  DislikedArtist withAt(int at) => DislikedArtist(key: key, name: name, at: at);

  Map<String, Object?> toJson() => {'key': key, 'name': name, 'at': ?at};

  static DislikedArtist? fromJson(Object? j) => j is Map && j['key'] is String
      ? DislikedArtist(
          key: j['key'] as String,
          name: '${j['name'] ?? ''}',
          at: j['at'] is int ? j['at'] as int : null,
        )
      : null;
}

/// `dislikes.json`: the songs and artists the user said «Non mi piace» to.
/// User choices, not a cache: never trimmed, not touched by
/// `SuggestionLog.clear`. Queries are synchronous once [load] is done.
class DislikeStore {
  DislikeStore({
    required this.file,
    this.writeDelay = const Duration(seconds: 1),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  final Future<File> Function() file;
  final Duration writeDelay;

  final List<DislikedTrack> _tracks = []; // oldest first
  final List<DislikedArtist> _artists = [];
  bool _migrated = false;
  Future<void>? _loading;
  Timer? _timer;
  Future<void> _writing = Future.value();
  final _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  /// Reads the file once; later calls wait for the same read.
  Future<void> load() => _loading ??= _read();

  Future<void> _read() async {
    try {
      final f = await file();
      if (await f.exists()) {
        final raw = jsonDecode(await f.readAsString());
        if (raw is! Map) {
          throw const FormatException('dislikes.json is not an object');
        }
        _migrated = raw['migrated'] == true;
        var dropped = 0;
        final tracks = <DislikedTrack>[];
        final artists = <DislikedArtist>[];
        if (raw['tracks'] case final List l) {
          for (final j in l) {
            final t = DislikedTrack.fromJson(j);
            if (t == null) {
              dropped++;
            } else if (!tracks.any((x) => x.videoId == t.videoId)) {
              tracks.add(t);
            }
          }
        }
        if (raw['artists'] case final List l) {
          for (final j in l) {
            final a = DislikedArtist.fromJson(j);
            if (a == null || a.key.isEmpty) {
              dropped++;
            } else if (!artists.any((x) => x.key == a.key)) {
              artists.add(a);
            }
          }
        }
        // Blocks made while the file was being read come after the old ones.
        final mem = [..._tracks];
        final memArtists = [..._artists];
        _tracks
          ..clear()
          ..addAll(tracks);
        _artists
          ..clear()
          ..addAll(artists);
        for (final t in mem) {
          if (!trackBlocked(t.videoId)) _tracks.add(t);
        }
        for (final a in memArtists) {
          if (!artistBlocked(a.key)) _artists.add(a);
        }
        // Entries we could not read are lost on the next write: keep a copy.
        if (dropped > 0) await f.copy('${f.path}.bad');
      }
    } on Object catch (e, st) {
      AppLog.w('dislikes unreadable, starting empty', e, st);
      // Keep the bad file: the next write must not destroy it.
      try {
        final f = await file();
        if (await f.exists()) await f.rename('${f.path}.bad');
      } on Object catch (e2, st2) {
        AppLog.w('dislikes.json.bad not saved', e2, st2);
      }
    }
  }

  /// Adds what [json] (the content of a `dislikes.json`) blocks; nothing is removed.
  void mergeJson(Object? json) {
    if (json is! Map) return;
    if (json['tracks'] case final List l) {
      for (final t in [for (final j in l) ?DislikedTrack.fromJson(j)]) {
        if (!trackBlocked(t.videoId)) _tracks.add(t);
      }
    }
    if (json['artists'] case final List l) {
      for (final a in [for (final j in l) ?DislikedArtist.fromJson(j)]) {
        if (a.key.isNotEmpty && !artistBlocked(a.key)) _artists.add(a);
      }
    }
    _changed();
  }

  /// Turns the old `disliked` records of [log] into blocked songs, once.
  /// Later [load] calls wait for it too.
  Future<void> migrateFrom(SuggestionLog log) {
    final read = load();
    return _loading = () async {
      await read;
      if (_migrated) return;
      await log.load();
      _migrated = true;
      for (final r in log.recent.reversed) {
        if (r.outcome == SuggestionOutcome.disliked &&
            !trackBlocked(r.videoId)) {
          _tracks.add(
            DislikedTrack(videoId: r.videoId, title: r.title, artist: r.artist),
          );
        }
      }
      _changed();
    }();
  }

  bool trackBlocked(String videoId) => _tracks.any((t) => t.videoId == videoId);

  /// An empty key (a name with no letters) is never blocked.
  bool artistBlocked(String artistKey) =>
      artistKey.isNotEmpty && _artists.any((a) => a.key == artistKey);

  /// Newest first.
  List<DislikedTrack> get tracks => _tracks.reversed.toList();
  List<DislikedArtist> get artists => _artists.reversed.toList();

  void blockTrack(DislikedTrack t) {
    if (trackBlocked(t.videoId)) return;
    _tracks.add(t.at == null ? t.withAt(_now().millisecondsSinceEpoch) : t);
    _changed();
  }

  void unblockTrack(String videoId) {
    _tracks.removeWhere((t) => t.videoId == videoId);
    _changed();
  }

  void blockArtist(DislikedArtist a) {
    if (a.key.isEmpty || artistBlocked(a.key)) return;
    _artists.add(a.at == null ? a.withAt(_now().millisecondsSinceEpoch) : a);
    _changed();
  }

  void unblockArtist(String key) {
    _artists.removeWhere((a) => a.key == key);
    _changed();
  }

  void _changed() {
    if (!_changes.isClosed) _changes.add(null);
    _timer?.cancel();
    _timer = Timer(writeDelay, () => unawaited(flush()));
  }

  Future<void> flush() {
    _timer?.cancel();
    // Serialized: a write never starts before the previous one ends.
    return _writing = _writing.then((_) => _writeNow());
  }

  Future<void> _writeNow() async {
    // Before load ends the lists are incomplete: writing would wipe the file.
    final loading = _loading;
    if (loading == null) return;
    try {
      await loading;
      final f = await file();
      await f.parent.create(recursive: true);
      // Write beside, then rename: a crash never leaves a half file.
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({
          'migrated': _migrated,
          'tracks': [for (final t in _tracks) t.toJson()],
          'artists': [for (final a in _artists) a.toJson()],
        }),
      );
      await tmp.rename(f.path);
    } on Object catch (e, st) {
      AppLog.w('dislikes write failed', e, st);
    }
  }
}

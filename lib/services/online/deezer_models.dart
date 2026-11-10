/// Only the Deezer fields phase 36 reads.
class DeezerAlbumRef {
  const DeezerAlbumRef({
    required this.id,
    required this.title,
    this.coverXl,
    this.releaseDate,
  });

  factory DeezerAlbumRef.fromJson(Map<dynamic, dynamic> j) => DeezerAlbumRef(
    id: j['id'] as int,
    title: '${j['title'] ?? ''}',
    coverXl: j['cover_xl'] as String?,
    releaseDate: j['release_date'] as String?,
  );

  final int id;
  final String title;
  final String? coverXl, releaseDate;
}

class DeezerTrack {
  const DeezerTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.isrc,
    this.trackPosition,
    this.diskNumber,
    this.album,
  });

  factory DeezerTrack.fromJson(Map<dynamic, dynamic> j) {
    final artist = j['artist'], album = j['album'];
    return DeezerTrack(
      id: j['id'] as int,
      title: '${j['title'] ?? ''}',
      artist: artist is Map ? '${artist['name'] ?? ''}' : '',
      duration: (j['duration'] as num?)?.toInt() ?? 0,
      isrc: j['isrc'] as String?,
      trackPosition: j['track_position'] as int?,
      diskNumber: j['disk_number'] as int?,
      album: album is Map ? DeezerAlbumRef.fromJson(album) : null,
    );
  }

  final int id;
  final String title, artist;

  /// Seconds.
  final int duration;
  final String? isrc;
  final int? trackPosition, diskNumber;
  final DeezerAlbumRef? album;
}

class DeezerAlbum {
  const DeezerAlbum({
    required this.id,
    required this.title,
    required this.recordType,
    required this.nbTracks,
    this.releaseDate,
    this.genres = const [],
    this.coverXl,
    this.label,
    this.fans,
  });

  factory DeezerAlbum.fromJson(Map<dynamic, dynamic> j) {
    final genres = j['genres'];
    final data = genres is Map ? genres['data'] : null;
    return DeezerAlbum(
      id: j['id'] as int,
      title: '${j['title'] ?? ''}',
      recordType: '${j['record_type'] ?? ''}',
      nbTracks: (j['nb_tracks'] as num?)?.toInt() ?? 0,
      releaseDate: j['release_date'] as String?,
      genres: [
        if (data is List)
          for (final g in data)
            if (g is Map && g['name'] is String) g['name'] as String,
      ],
      coverXl: j['cover_xl'] as String?,
      label: j['label'] as String?,
      fans: (j['fans'] as num?)?.toInt(),
    );
  }

  final int id;
  final String title, recordType;
  final int nbTracks;
  final String? releaseDate, coverXl, label;
  final int? fans;
  final List<String> genres;
}

/// What a Deezer link points at: a title, a cover and its songs.
class DeezerList {
  const DeezerList({
    required this.title,
    required this.tracks,
    this.coverUrl,
    this.owner,
    this.declaredTotal,
  });

  final String title;
  final String? coverUrl, owner;
  final int? declaredTotal;
  final List<DeezerTrack> tracks;
}

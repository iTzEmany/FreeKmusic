import '../online/credits.dart';

/// Portable user data: everything the user created, with tracks referenced by
/// relative path + title/artist/duration instead of the local DB id.
const kUserDataFormat = 1;

Map<String, Object?> _nonNull(Map<String, Object?> m) =>
    {for (final e in m.entries) if (e.value != null) e.key: e.value};

class TrackRef {
  const TrackRef({
    required this.title,
    this.folder,
    this.relPath,
    this.artist,
    this.durationMs = 0,
    this.sha256,
  });

  /// Root folder the track was found under. For a track outside every folder
  /// it holds the absolute file path and [relPath] is null.
  final String? folder;

  /// Path relative to [folder] (`/` separators).
  final String? relPath;
  final String title;
  final String? artist;
  final int durationMs;
  final String? sha256;

  Map<String, Object?> toJson() => _nonNull({
        'folder': folder,
        'relPath': relPath,
        'title': title,
        'artist': artist,
        'durationMs': durationMs,
        'sha256': sha256,
      });

  factory TrackRef.fromJson(Map<String, dynamic> j) => TrackRef(
        folder: j['folder'] as String?,
        relPath: j['relPath'] as String?,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String?,
        durationMs: (j['durationMs'] as num?)?.toInt() ?? 0,
        sha256: j['sha256'] as String?,
      );
}

/// Title and tags the user changed by hand (`userEdited`).
class TrackEditData {
  const TrackEditData({
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.trackNumber,
    this.genre,
  });

  final String title;
  final String? artist, album, albumArtist, genre;
  final int? year, trackNumber;

  Map<String, Object?> toJson() => _nonNull({
        'title': title,
        'artist': artist,
        'album': album,
        'albumArtist': albumArtist,
        'year': year,
        'trackNumber': trackNumber,
        'genre': genre,
      });

  factory TrackEditData.fromJson(Map<String, dynamic> j) => TrackEditData(
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String?,
        album: j['album'] as String?,
        albumArtist: j['albumArtist'] as String?,
        year: (j['year'] as num?)?.toInt(),
        trackNumber: (j['trackNumber'] as num?)?.toInt(),
        genre: j['genre'] as String?,
      );
}

class TrackUserData {
  const TrackUserData({
    required this.ref,
    this.favorite = false,
    this.edit,
    this.lyricsPlain,
    this.lyricsSynced,
    this.curiosities,
    this.playCount = 0,
    this.lastPlayedAt,
    this.credits = const [],
    this.details,
    this.genres = const [],
    this.coverSource = 0,
    this.coverKey,
  });

  final TrackRef ref;
  final bool favorite;
  final TrackEditData? edit;
  final String? lyricsPlain, lyricsSynced, curiosities;
  final int playCount;
  final int? lastPlayedAt;

  /// Enrichment: written only when the track has them.
  final List<TrackCredit> credits;
  final TrackDetails? details;

  /// `track_genres` in order (absent in older backups = none).
  final List<String> genres;

  /// Hand-set cover (1 album, 2 track) and its file key in the covers folder;
  /// written only when the cover is by hand.
  final int coverSource;
  final String? coverKey;

  Map<String, Object?> toJson() => _nonNull({
        'ref': ref.toJson(),
        'favorite': favorite ? true : null,
        'edit': edit?.toJson(),
        'lyricsPlain': lyricsPlain,
        'lyricsSynced': lyricsSynced,
        'curiosities': curiosities,
        'playCount': playCount == 0 ? null : playCount,
        'lastPlayedAt': lastPlayedAt,
        'credits': credits.isEmpty ? null : [for (final c in credits) c.toJson()],
        'details': details?.toJson(),
        'genres': genres.isEmpty ? null : genres,
        'coverSource': coverSource == 0 ? null : coverSource,
        'coverKey': coverSource == 0 ? null : coverKey,
      });

  factory TrackUserData.fromJson(Map<String, dynamic> j) => TrackUserData(
        ref: TrackRef.fromJson(j['ref'] as Map<String, dynamic>),
        favorite: j['favorite'] as bool? ?? false,
        edit: j['edit'] == null
            ? null
            : TrackEditData.fromJson(j['edit'] as Map<String, dynamic>),
        lyricsPlain: j['lyricsPlain'] as String?,
        lyricsSynced: j['lyricsSynced'] as String?,
        curiosities: j['curiosities'] as String?,
        playCount: (j['playCount'] as num?)?.toInt() ?? 0,
        lastPlayedAt: (j['lastPlayedAt'] as num?)?.toInt(),
        credits: parseCreditList(j['credits'], max: 2000),
        details: j['details'] is Map ? TrackDetails.fromJson(j['details'] as Map) : null,
        genres: [for (final g in (j['genres'] as List? ?? const [])) if (g is String && g.trim().isNotEmpty) g],
        coverSource: switch (j['coverSource']) { final num n when n == 1 || n == 2 => n.toInt(), _ => 0 },
        coverKey: j['coverKey'] is String ? j['coverKey'] as String : null,
      );
}

class PlaylistData {
  const PlaylistData({
    required this.name,
    required this.createdAt,
    this.coverKey,
    this.uuid,
    this.items = const [],
  });

  final String name;
  final int createdAt;
  final String? coverKey;

  /// Stable identity of the playlist (absent in older backups).
  final String? uuid;

  /// In playlist order.
  final List<TrackRef> items;

  Map<String, Object?> toJson() => _nonNull({
        'name': name,
        'createdAt': createdAt,
        'coverKey': coverKey,
        'uuid': uuid,
        'items': [for (final i in items) i.toJson()],
      });

  factory PlaylistData.fromJson(Map<String, dynamic> j) => PlaylistData(
        name: j['name'] as String? ?? '',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        coverKey: j['coverKey'] as String?,
        uuid: j['uuid'] as String?,
        items: [
          for (final i in (j['items'] as List? ?? const []))
            TrackRef.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// A CSV import and its rows. Kept for reference only: imports depend on the
/// downloads of the device that made them, so a restore never merges them.
class ImportData {
  const ImportData({
    required this.playlistName,
    required this.sourceName,
    required this.createdAt,
    required this.status,
    this.rows = const [],
  });

  final String playlistName, sourceName;
  final int createdAt, status;
  final List<ImportRowData> rows;

  Map<String, Object?> toJson() => {
        'playlistName': playlistName,
        'sourceName': sourceName,
        'createdAt': createdAt,
        'status': status,
        'rows': [for (final r in rows) r.toJson()],
      };

  factory ImportData.fromJson(Map<String, dynamic> j) => ImportData(
        playlistName: j['playlistName'] as String? ?? '',
        sourceName: j['sourceName'] as String? ?? '',
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        status: (j['status'] as num?)?.toInt() ?? 0,
        rows: [
          for (final r in (j['rows'] as List? ?? const []))
            ImportRowData.fromJson(r as Map<String, dynamic>),
        ],
      );
}

class ImportRowData {
  const ImportRowData({
    required this.rowIndex,
    required this.title,
    required this.artists,
    required this.status,
    this.album,
    this.durationMs,
    this.isrc,
    this.videoId,
  });

  final int rowIndex, status;
  final String title, artists;
  final String? album, isrc, videoId;
  final int? durationMs;

  Map<String, Object?> toJson() => _nonNull({
        'rowIndex': rowIndex,
        'title': title,
        'artists': artists,
        'status': status,
        'album': album,
        'durationMs': durationMs,
        'isrc': isrc,
        'videoId': videoId,
      });

  factory ImportRowData.fromJson(Map<String, dynamic> j) => ImportRowData(
        rowIndex: (j['rowIndex'] as num?)?.toInt() ?? 0,
        title: j['title'] as String? ?? '',
        artists: j['artists'] as String? ?? '',
        status: (j['status'] as num?)?.toInt() ?? 0,
        album: j['album'] as String?,
        durationMs: (j['durationMs'] as num?)?.toInt(),
        isrc: j['isrc'] as String?,
        videoId: j['videoId'] as String?,
      );
}

/// A saved radio station («Le mie radio»); the backup lists them in order.
class RadioData {
  const RadioData({
    required this.stationId,
    required this.name,
    required this.streamUrl,
    this.homepage = '',
    this.faviconUrl = '',
    this.countryCode = '',
    this.state = '',
    this.tags = '',
    this.codec = '',
    this.bitrate = 0,
    this.hls = false,
    this.addedAt,
    this.lastPlayedAt,
  });

  final String stationId, name, streamUrl;
  final String homepage, faviconUrl, countryCode, state, tags, codec;
  final int bitrate;
  final bool hls;
  final int? addedAt, lastPlayedAt;

  bool get isManual => stationId.startsWith('manual:');

  Map<String, Object?> toJson() => _nonNull({
        'stationId': stationId,
        'name': name,
        'streamUrl': streamUrl,
        'homepage': homepage.isEmpty ? null : homepage,
        'faviconUrl': faviconUrl.isEmpty ? null : faviconUrl,
        'countryCode': countryCode.isEmpty ? null : countryCode,
        'state': state.isEmpty ? null : state,
        'tags': tags.isEmpty ? null : tags,
        'codec': codec.isEmpty ? null : codec,
        'bitrate': bitrate == 0 ? null : bitrate,
        'hls': hls ? true : null,
        'addedAt': addedAt,
        'lastPlayedAt': lastPlayedAt,
      });

  factory RadioData.fromJson(Map<String, dynamic> j) => RadioData(
        stationId: j['stationId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        streamUrl: j['streamUrl'] as String? ?? '',
        homepage: j['homepage'] as String? ?? '',
        faviconUrl: j['faviconUrl'] as String? ?? '',
        countryCode: j['countryCode'] as String? ?? '',
        state: j['state'] as String? ?? '',
        tags: j['tags'] as String? ?? '',
        codec: j['codec'] as String? ?? '',
        bitrate: (j['bitrate'] as num?)?.toInt() ?? 0,
        hls: j['hls'] as bool? ?? false,
        addedAt: (j['addedAt'] as num?)?.toInt(),
        lastPlayedAt: (j['lastPlayedAt'] as num?)?.toInt(),
      );
}

/// A followed artist of «Nuove uscite» (releases are not exported: after a
/// merge the first check stores them as seen).
class FollowedArtistData {
  const FollowedArtistData({
    required this.ytmId,
    required this.name,
    this.thumbUrl,
    this.origin = 0,
    this.excluded = false,
    this.muted = false,
  });

  /// `UC…` channel id of the YouTube Music artist page.
  final String ytmId, name;
  final String? thumbUrl;

  /// 0 followed by hand, 1 followed automatically (most listened).
  final int origin;
  final bool excluded, muted;

  Map<String, Object?> toJson() => _nonNull({
        'ytmId': ytmId,
        'name': name,
        'thumbUrl': thumbUrl,
        'origin': origin == 0 ? null : origin,
        'excluded': excluded ? true : null,
        'muted': muted ? true : null,
      });

  factory FollowedArtistData.fromJson(Map<String, dynamic> j) => FollowedArtistData(
        ytmId: j['ytmId'] as String? ?? '',
        name: j['name'] as String? ?? '',
        thumbUrl: j['thumbUrl'] as String?,
        origin: (j['origin'] as num?)?.toInt() ?? 0,
        excluded: j['excluded'] as bool? ?? false,
        muted: j['muted'] as bool? ?? false,
      );
}

/// The country found for an artist (`artist_countries`); [country] null means
/// "searched, not found".
class ArtistCountryData {
  const ArtistCountryData({required this.artistKey, this.country, this.source, required this.checkedAt});

  final String artistKey;
  final String? country, source;
  final int checkedAt;

  Map<String, Object?> toJson() =>
      _nonNull({'artistKey': artistKey, 'country': country, 'source': source, 'checkedAt': checkedAt});

  factory ArtistCountryData.fromJson(Map<String, dynamic> j) => ArtistCountryData(
        artistKey: j['artistKey'] as String? ?? '',
        country: j['country'] as String?,
        source: j['source'] as String?,
        checkedAt: (j['checkedAt'] as num?)?.toInt() ?? 0,
      );
}

class UserData {
  const UserData({
    required this.createdAt,
    this.tracks = const [],
    this.playlists = const [],
    this.imports = const [],
    this.radios = const [],
    this.followedArtists = const [],
    this.artistCountries = const [],
  });

  final int createdAt;
  final List<TrackUserData> tracks;
  final List<PlaylistData> playlists;
  final List<ImportData> imports;

  /// «Le mie radio» in their order (absent in older backups = none).
  final List<RadioData> radios;

  /// Artists followed for new releases (absent in older backups = none).
  final List<FollowedArtistData> followedArtists;

  /// Where artists come from (absent in older backups = none).
  final List<ArtistCountryData> artistCountries;

  Map<String, Object?> toJson() => {
        'format': kUserDataFormat,
        'createdAt': createdAt,
        'tracks': [for (final t in tracks) t.toJson()],
        'playlists': [for (final p in playlists) p.toJson()],
        'imports': [for (final i in imports) i.toJson()],
        if (radios.isNotEmpty) 'radios': [for (final r in radios) r.toJson()],
        if (followedArtists.isNotEmpty)
          'followedArtists': [for (final a in followedArtists) a.toJson()],
        if (artistCountries.isNotEmpty) 'artistCountries': [for (final a in artistCountries) a.toJson()],
      };

  /// Unknown fields are ignored; a newer `format` is refused.
  factory UserData.fromJson(Map<String, dynamic> j) {
    final format = (j['format'] as num?)?.toInt() ?? 0;
    if (format < 1 || format > kUserDataFormat) {
      throw FormatException('user_data format $format not supported');
    }
    return UserData(
      createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
      tracks: [
        for (final t in (j['tracks'] as List? ?? const []))
          TrackUserData.fromJson(t as Map<String, dynamic>),
      ],
      playlists: [
        for (final p in (j['playlists'] as List? ?? const []))
          PlaylistData.fromJson(p as Map<String, dynamic>),
      ],
      imports: [
        for (final i in (j['imports'] as List? ?? const []))
          ImportData.fromJson(i as Map<String, dynamic>),
      ],
      radios: [
        for (final r in (j['radios'] as List? ?? const []))
          RadioData.fromJson(r as Map<String, dynamic>),
      ],
      followedArtists: [
        for (final a in (j['followedArtists'] as List? ?? const []))
          FollowedArtistData.fromJson(a as Map<String, dynamic>),
      ],
      artistCountries: [
        for (final a in (j['artistCountries'] as List? ?? const []))
          ArtistCountryData.fromJson(a as Map<String, dynamic>),
      ],
    );
  }
}

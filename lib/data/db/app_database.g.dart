// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TracksTable extends Tracks with TableInfo<$TracksTable, Track> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
    'artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumArtistMeta = const VerificationMeta(
    'albumArtist',
  );
  @override
  late final GeneratedColumn<String> albumArtist = GeneratedColumn<String>(
    'album_artist',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _albumKeyMeta = const VerificationMeta(
    'albumKey',
  );
  @override
  late final GeneratedColumn<String> albumKey = GeneratedColumn<String>(
    'album_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trackNumberMeta = const VerificationMeta(
    'trackNumber',
  );
  @override
  late final GeneratedColumn<int> trackNumber = GeneratedColumn<int>(
    'track_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _discNumberMeta = const VerificationMeta(
    'discNumber',
  );
  @override
  late final GeneratedColumn<int> discNumber = GeneratedColumn<int>(
    'disc_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleRateHzMeta = const VerificationMeta(
    'sampleRateHz',
  );
  @override
  late final GeneratedColumn<int> sampleRateHz = GeneratedColumn<int>(
    'sample_rate_hz',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitDepthMeta = const VerificationMeta(
    'bitDepth',
  );
  @override
  late final GeneratedColumn<int> bitDepth = GeneratedColumn<int>(
    'bit_depth',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bitrateKbpsMeta = const VerificationMeta(
    'bitrateKbps',
  );
  @override
  late final GeneratedColumn<int> bitrateKbps = GeneratedColumn<int>(
    'bitrate_kbps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _channelsMeta = const VerificationMeta(
    'channels',
  );
  @override
  late final GeneratedColumn<int> channels = GeneratedColumn<int>(
    'channels',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<int> mtimeMs = GeneratedColumn<int>(
    'mtime_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hasCoverMeta = const VerificationMeta(
    'hasCover',
  );
  @override
  late final GeneratedColumn<bool> hasCover = GeneratedColumn<bool>(
    'has_cover',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("has_cover" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _coverKeyMeta = const VerificationMeta(
    'coverKey',
  );
  @override
  late final GeneratedColumn<String> coverKey = GeneratedColumn<String>(
    'cover_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lyricsPlainMeta = const VerificationMeta(
    'lyricsPlain',
  );
  @override
  late final GeneratedColumn<String> lyricsPlain = GeneratedColumn<String>(
    'lyrics_plain',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsSyncedMeta = const VerificationMeta(
    'lyricsSynced',
  );
  @override
  late final GeneratedColumn<String> lyricsSynced = GeneratedColumn<String>(
    'lyrics_synced',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _curiositiesMeta = const VerificationMeta(
    'curiosities',
  );
  @override
  late final GeneratedColumn<String> curiosities = GeneratedColumn<String>(
    'curiosities',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrichStatusMeta = const VerificationMeta(
    'enrichStatus',
  );
  @override
  late final GeneratedColumn<int> enrichStatus = GeneratedColumn<int>(
    'enrich_status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _userEditedMeta = const VerificationMeta(
    'userEdited',
  );
  @override
  late final GeneratedColumn<bool> userEdited = GeneratedColumn<bool>(
    'user_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("user_edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _missingMeta = const VerificationMeta(
    'missing',
  );
  @override
  late final GeneratedColumn<bool> missing = GeneratedColumn<bool>(
    'missing',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("missing" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ignoredMeta = const VerificationMeta(
    'ignored',
  );
  @override
  late final GeneratedColumn<bool> ignored = GeneratedColumn<bool>(
    'ignored',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ignored" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playCountMeta = const VerificationMeta(
    'playCount',
  );
  @override
  late final GeneratedColumn<int> playCount = GeneratedColumn<int>(
    'play_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _replayGainDbMeta = const VerificationMeta(
    'replayGainDb',
  );
  @override
  late final GeneratedColumn<double> replayGainDb = GeneratedColumn<double>(
    'replay_gain_db',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resumePositionMsMeta = const VerificationMeta(
    'resumePositionMs',
  );
  @override
  late final GeneratedColumn<int> resumePositionMs = GeneratedColumn<int>(
    'resume_position_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverSourceMeta = const VerificationMeta(
    'coverSource',
  );
  @override
  late final GeneratedColumn<int> coverSource = GeneratedColumn<int>(
    'cover_source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    path,
    folderId,
    title,
    artist,
    albumArtist,
    album,
    albumKey,
    trackNumber,
    discNumber,
    year,
    genre,
    durationMs,
    format,
    sampleRateHz,
    bitDepth,
    bitrateKbps,
    channels,
    sizeBytes,
    mtimeMs,
    hasCover,
    coverKey,
    isFavorite,
    lyricsPlain,
    lyricsSynced,
    curiosities,
    enrichStatus,
    userEdited,
    missing,
    ignored,
    kind,
    sha256,
    addedAt,
    playCount,
    replayGainDb,
    resumePositionMs,
    lastPlayedAt,
    isrc,
    coverSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Track> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(
        _artistMeta,
        artist.isAcceptableOrUnknown(data['artist']!, _artistMeta),
      );
    }
    if (data.containsKey('album_artist')) {
      context.handle(
        _albumArtistMeta,
        albumArtist.isAcceptableOrUnknown(
          data['album_artist']!,
          _albumArtistMeta,
        ),
      );
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('album_key')) {
      context.handle(
        _albumKeyMeta,
        albumKey.isAcceptableOrUnknown(data['album_key']!, _albumKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_albumKeyMeta);
    }
    if (data.containsKey('track_number')) {
      context.handle(
        _trackNumberMeta,
        trackNumber.isAcceptableOrUnknown(
          data['track_number']!,
          _trackNumberMeta,
        ),
      );
    }
    if (data.containsKey('disc_number')) {
      context.handle(
        _discNumberMeta,
        discNumber.isAcceptableOrUnknown(data['disc_number']!, _discNumberMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('format')) {
      context.handle(
        _formatMeta,
        format.isAcceptableOrUnknown(data['format']!, _formatMeta),
      );
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('sample_rate_hz')) {
      context.handle(
        _sampleRateHzMeta,
        sampleRateHz.isAcceptableOrUnknown(
          data['sample_rate_hz']!,
          _sampleRateHzMeta,
        ),
      );
    }
    if (data.containsKey('bit_depth')) {
      context.handle(
        _bitDepthMeta,
        bitDepth.isAcceptableOrUnknown(data['bit_depth']!, _bitDepthMeta),
      );
    }
    if (data.containsKey('bitrate_kbps')) {
      context.handle(
        _bitrateKbpsMeta,
        bitrateKbps.isAcceptableOrUnknown(
          data['bitrate_kbps']!,
          _bitrateKbpsMeta,
        ),
      );
    }
    if (data.containsKey('channels')) {
      context.handle(
        _channelsMeta,
        channels.isAcceptableOrUnknown(data['channels']!, _channelsMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    } else if (isInserting) {
      context.missing(_mtimeMsMeta);
    }
    if (data.containsKey('has_cover')) {
      context.handle(
        _hasCoverMeta,
        hasCover.isAcceptableOrUnknown(data['has_cover']!, _hasCoverMeta),
      );
    }
    if (data.containsKey('cover_key')) {
      context.handle(
        _coverKeyMeta,
        coverKey.isAcceptableOrUnknown(data['cover_key']!, _coverKeyMeta),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    if (data.containsKey('lyrics_plain')) {
      context.handle(
        _lyricsPlainMeta,
        lyricsPlain.isAcceptableOrUnknown(
          data['lyrics_plain']!,
          _lyricsPlainMeta,
        ),
      );
    }
    if (data.containsKey('lyrics_synced')) {
      context.handle(
        _lyricsSyncedMeta,
        lyricsSynced.isAcceptableOrUnknown(
          data['lyrics_synced']!,
          _lyricsSyncedMeta,
        ),
      );
    }
    if (data.containsKey('curiosities')) {
      context.handle(
        _curiositiesMeta,
        curiosities.isAcceptableOrUnknown(
          data['curiosities']!,
          _curiositiesMeta,
        ),
      );
    }
    if (data.containsKey('enrich_status')) {
      context.handle(
        _enrichStatusMeta,
        enrichStatus.isAcceptableOrUnknown(
          data['enrich_status']!,
          _enrichStatusMeta,
        ),
      );
    }
    if (data.containsKey('user_edited')) {
      context.handle(
        _userEditedMeta,
        userEdited.isAcceptableOrUnknown(data['user_edited']!, _userEditedMeta),
      );
    }
    if (data.containsKey('missing')) {
      context.handle(
        _missingMeta,
        missing.isAcceptableOrUnknown(data['missing']!, _missingMeta),
      );
    }
    if (data.containsKey('ignored')) {
      context.handle(
        _ignoredMeta,
        ignored.isAcceptableOrUnknown(data['ignored']!, _ignoredMeta),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('play_count')) {
      context.handle(
        _playCountMeta,
        playCount.isAcceptableOrUnknown(data['play_count']!, _playCountMeta),
      );
    }
    if (data.containsKey('replay_gain_db')) {
      context.handle(
        _replayGainDbMeta,
        replayGainDb.isAcceptableOrUnknown(
          data['replay_gain_db']!,
          _replayGainDbMeta,
        ),
      );
    }
    if (data.containsKey('resume_position_ms')) {
      context.handle(
        _resumePositionMsMeta,
        resumePositionMs.isAcceptableOrUnknown(
          data['resume_position_ms']!,
          _resumePositionMsMeta,
        ),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    }
    if (data.containsKey('cover_source')) {
      context.handle(
        _coverSourceMeta,
        coverSource.isAcceptableOrUnknown(
          data['cover_source']!,
          _coverSourceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Track map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Track(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist'],
      ),
      albumArtist: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_artist'],
      ),
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      albumKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album_key'],
      )!,
      trackNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_number'],
      ),
      discNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}disc_number'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      format: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format'],
      )!,
      sampleRateHz: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sample_rate_hz'],
      ),
      bitDepth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bit_depth'],
      ),
      bitrateKbps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate_kbps'],
      ),
      channels: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}channels'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime_ms'],
      )!,
      hasCover: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}has_cover'],
      )!,
      coverKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_key'],
      ),
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
      lyricsPlain: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics_plain'],
      ),
      lyricsSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lyrics_synced'],
      ),
      curiosities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}curiosities'],
      ),
      enrichStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}enrich_status'],
      )!,
      userEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}user_edited'],
      )!,
      missing: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}missing'],
      )!,
      ignored: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ignored'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      playCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}play_count'],
      )!,
      replayGainDb: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}replay_gain_db'],
      ),
      resumePositionMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resume_position_ms'],
      ),
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      ),
      isrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isrc'],
      ),
      coverSource: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cover_source'],
      )!,
    );
  }

  @override
  $TracksTable createAlias(String alias) {
    return $TracksTable(attachedDatabase, alias);
  }
}

class Track extends DataClass implements Insertable<Track> {
  final int id;
  final String path;
  final int? folderId;
  final String title;
  final String? artist;
  final String? albumArtist;
  final String? album;
  final String albumKey;
  final int? trackNumber;
  final int? discNumber;
  final int? year;
  final String? genre;
  final int durationMs;
  final String format;
  final int? sampleRateHz;
  final int? bitDepth;
  final int? bitrateKbps;
  final int? channels;
  final int sizeBytes;
  final int mtimeMs;
  final bool hasCover;
  final String? coverKey;
  final bool isFavorite;
  final String? lyricsPlain;
  final String? lyricsSynced;
  final String? curiosities;
  final int enrichStatus;
  final bool userEdited;
  final bool missing;

  /// Hidden by the user (a duplicate that was merged away). Unlike `missing`
  /// the scanner never clears it; «Brani nascosti» does.
  final bool ignored;

  /// 0 music · 1 a downloaded podcast episode. Every music view filters
  /// `kind = 0`: episodes never show up in the library.
  final int kind;
  final String? sha256;
  final int addedAt;
  final int playCount;
  final double? replayGainDb;

  /// «Riprendi da qui»: where a long track (≥ 20 min) was left; null = none.
  final int? resumePositionMs;
  final int? lastPlayedAt;

  /// International Standard Recording Code; never overwritten once set.
  final String? isrc;

  /// 0 automatic · 1 chosen by hand for the album · 2 chosen by hand for the track.
  final int coverSource;
  const Track({
    required this.id,
    required this.path,
    this.folderId,
    required this.title,
    this.artist,
    this.albumArtist,
    this.album,
    required this.albumKey,
    this.trackNumber,
    this.discNumber,
    this.year,
    this.genre,
    required this.durationMs,
    required this.format,
    this.sampleRateHz,
    this.bitDepth,
    this.bitrateKbps,
    this.channels,
    required this.sizeBytes,
    required this.mtimeMs,
    required this.hasCover,
    this.coverKey,
    required this.isFavorite,
    this.lyricsPlain,
    this.lyricsSynced,
    this.curiosities,
    required this.enrichStatus,
    required this.userEdited,
    required this.missing,
    required this.ignored,
    required this.kind,
    this.sha256,
    required this.addedAt,
    required this.playCount,
    this.replayGainDb,
    this.resumePositionMs,
    this.lastPlayedAt,
    this.isrc,
    required this.coverSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || albumArtist != null) {
      map['album_artist'] = Variable<String>(albumArtist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    map['album_key'] = Variable<String>(albumKey);
    if (!nullToAbsent || trackNumber != null) {
      map['track_number'] = Variable<int>(trackNumber);
    }
    if (!nullToAbsent || discNumber != null) {
      map['disc_number'] = Variable<int>(discNumber);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    map['duration_ms'] = Variable<int>(durationMs);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || sampleRateHz != null) {
      map['sample_rate_hz'] = Variable<int>(sampleRateHz);
    }
    if (!nullToAbsent || bitDepth != null) {
      map['bit_depth'] = Variable<int>(bitDepth);
    }
    if (!nullToAbsent || bitrateKbps != null) {
      map['bitrate_kbps'] = Variable<int>(bitrateKbps);
    }
    if (!nullToAbsent || channels != null) {
      map['channels'] = Variable<int>(channels);
    }
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['mtime_ms'] = Variable<int>(mtimeMs);
    map['has_cover'] = Variable<bool>(hasCover);
    if (!nullToAbsent || coverKey != null) {
      map['cover_key'] = Variable<String>(coverKey);
    }
    map['is_favorite'] = Variable<bool>(isFavorite);
    if (!nullToAbsent || lyricsPlain != null) {
      map['lyrics_plain'] = Variable<String>(lyricsPlain);
    }
    if (!nullToAbsent || lyricsSynced != null) {
      map['lyrics_synced'] = Variable<String>(lyricsSynced);
    }
    if (!nullToAbsent || curiosities != null) {
      map['curiosities'] = Variable<String>(curiosities);
    }
    map['enrich_status'] = Variable<int>(enrichStatus);
    map['user_edited'] = Variable<bool>(userEdited);
    map['missing'] = Variable<bool>(missing);
    map['ignored'] = Variable<bool>(ignored);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || sha256 != null) {
      map['sha256'] = Variable<String>(sha256);
    }
    map['added_at'] = Variable<int>(addedAt);
    map['play_count'] = Variable<int>(playCount);
    if (!nullToAbsent || replayGainDb != null) {
      map['replay_gain_db'] = Variable<double>(replayGainDb);
    }
    if (!nullToAbsent || resumePositionMs != null) {
      map['resume_position_ms'] = Variable<int>(resumePositionMs);
    }
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<int>(lastPlayedAt);
    }
    if (!nullToAbsent || isrc != null) {
      map['isrc'] = Variable<String>(isrc);
    }
    map['cover_source'] = Variable<int>(coverSource);
    return map;
  }

  TracksCompanion toCompanion(bool nullToAbsent) {
    return TracksCompanion(
      id: Value(id),
      path: Value(path),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      title: Value(title),
      artist: artist == null && nullToAbsent
          ? const Value.absent()
          : Value(artist),
      albumArtist: albumArtist == null && nullToAbsent
          ? const Value.absent()
          : Value(albumArtist),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      albumKey: Value(albumKey),
      trackNumber: trackNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(trackNumber),
      discNumber: discNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(discNumber),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      genre: genre == null && nullToAbsent
          ? const Value.absent()
          : Value(genre),
      durationMs: Value(durationMs),
      format: Value(format),
      sampleRateHz: sampleRateHz == null && nullToAbsent
          ? const Value.absent()
          : Value(sampleRateHz),
      bitDepth: bitDepth == null && nullToAbsent
          ? const Value.absent()
          : Value(bitDepth),
      bitrateKbps: bitrateKbps == null && nullToAbsent
          ? const Value.absent()
          : Value(bitrateKbps),
      channels: channels == null && nullToAbsent
          ? const Value.absent()
          : Value(channels),
      sizeBytes: Value(sizeBytes),
      mtimeMs: Value(mtimeMs),
      hasCover: Value(hasCover),
      coverKey: coverKey == null && nullToAbsent
          ? const Value.absent()
          : Value(coverKey),
      isFavorite: Value(isFavorite),
      lyricsPlain: lyricsPlain == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricsPlain),
      lyricsSynced: lyricsSynced == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricsSynced),
      curiosities: curiosities == null && nullToAbsent
          ? const Value.absent()
          : Value(curiosities),
      enrichStatus: Value(enrichStatus),
      userEdited: Value(userEdited),
      missing: Value(missing),
      ignored: Value(ignored),
      kind: Value(kind),
      sha256: sha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sha256),
      addedAt: Value(addedAt),
      playCount: Value(playCount),
      replayGainDb: replayGainDb == null && nullToAbsent
          ? const Value.absent()
          : Value(replayGainDb),
      resumePositionMs: resumePositionMs == null && nullToAbsent
          ? const Value.absent()
          : Value(resumePositionMs),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      isrc: isrc == null && nullToAbsent ? const Value.absent() : Value(isrc),
      coverSource: Value(coverSource),
    );
  }

  factory Track.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Track(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      albumArtist: serializer.fromJson<String?>(json['albumArtist']),
      album: serializer.fromJson<String?>(json['album']),
      albumKey: serializer.fromJson<String>(json['albumKey']),
      trackNumber: serializer.fromJson<int?>(json['trackNumber']),
      discNumber: serializer.fromJson<int?>(json['discNumber']),
      year: serializer.fromJson<int?>(json['year']),
      genre: serializer.fromJson<String?>(json['genre']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      format: serializer.fromJson<String>(json['format']),
      sampleRateHz: serializer.fromJson<int?>(json['sampleRateHz']),
      bitDepth: serializer.fromJson<int?>(json['bitDepth']),
      bitrateKbps: serializer.fromJson<int?>(json['bitrateKbps']),
      channels: serializer.fromJson<int?>(json['channels']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      mtimeMs: serializer.fromJson<int>(json['mtimeMs']),
      hasCover: serializer.fromJson<bool>(json['hasCover']),
      coverKey: serializer.fromJson<String?>(json['coverKey']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      lyricsPlain: serializer.fromJson<String?>(json['lyricsPlain']),
      lyricsSynced: serializer.fromJson<String?>(json['lyricsSynced']),
      curiosities: serializer.fromJson<String?>(json['curiosities']),
      enrichStatus: serializer.fromJson<int>(json['enrichStatus']),
      userEdited: serializer.fromJson<bool>(json['userEdited']),
      missing: serializer.fromJson<bool>(json['missing']),
      ignored: serializer.fromJson<bool>(json['ignored']),
      kind: serializer.fromJson<int>(json['kind']),
      sha256: serializer.fromJson<String?>(json['sha256']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      playCount: serializer.fromJson<int>(json['playCount']),
      replayGainDb: serializer.fromJson<double?>(json['replayGainDb']),
      resumePositionMs: serializer.fromJson<int?>(json['resumePositionMs']),
      lastPlayedAt: serializer.fromJson<int?>(json['lastPlayedAt']),
      isrc: serializer.fromJson<String?>(json['isrc']),
      coverSource: serializer.fromJson<int>(json['coverSource']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'folderId': serializer.toJson<int?>(folderId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'albumArtist': serializer.toJson<String?>(albumArtist),
      'album': serializer.toJson<String?>(album),
      'albumKey': serializer.toJson<String>(albumKey),
      'trackNumber': serializer.toJson<int?>(trackNumber),
      'discNumber': serializer.toJson<int?>(discNumber),
      'year': serializer.toJson<int?>(year),
      'genre': serializer.toJson<String?>(genre),
      'durationMs': serializer.toJson<int>(durationMs),
      'format': serializer.toJson<String>(format),
      'sampleRateHz': serializer.toJson<int?>(sampleRateHz),
      'bitDepth': serializer.toJson<int?>(bitDepth),
      'bitrateKbps': serializer.toJson<int?>(bitrateKbps),
      'channels': serializer.toJson<int?>(channels),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'mtimeMs': serializer.toJson<int>(mtimeMs),
      'hasCover': serializer.toJson<bool>(hasCover),
      'coverKey': serializer.toJson<String?>(coverKey),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'lyricsPlain': serializer.toJson<String?>(lyricsPlain),
      'lyricsSynced': serializer.toJson<String?>(lyricsSynced),
      'curiosities': serializer.toJson<String?>(curiosities),
      'enrichStatus': serializer.toJson<int>(enrichStatus),
      'userEdited': serializer.toJson<bool>(userEdited),
      'missing': serializer.toJson<bool>(missing),
      'ignored': serializer.toJson<bool>(ignored),
      'kind': serializer.toJson<int>(kind),
      'sha256': serializer.toJson<String?>(sha256),
      'addedAt': serializer.toJson<int>(addedAt),
      'playCount': serializer.toJson<int>(playCount),
      'replayGainDb': serializer.toJson<double?>(replayGainDb),
      'resumePositionMs': serializer.toJson<int?>(resumePositionMs),
      'lastPlayedAt': serializer.toJson<int?>(lastPlayedAt),
      'isrc': serializer.toJson<String?>(isrc),
      'coverSource': serializer.toJson<int>(coverSource),
    };
  }

  Track copyWith({
    int? id,
    String? path,
    Value<int?> folderId = const Value.absent(),
    String? title,
    Value<String?> artist = const Value.absent(),
    Value<String?> albumArtist = const Value.absent(),
    Value<String?> album = const Value.absent(),
    String? albumKey,
    Value<int?> trackNumber = const Value.absent(),
    Value<int?> discNumber = const Value.absent(),
    Value<int?> year = const Value.absent(),
    Value<String?> genre = const Value.absent(),
    int? durationMs,
    String? format,
    Value<int?> sampleRateHz = const Value.absent(),
    Value<int?> bitDepth = const Value.absent(),
    Value<int?> bitrateKbps = const Value.absent(),
    Value<int?> channels = const Value.absent(),
    int? sizeBytes,
    int? mtimeMs,
    bool? hasCover,
    Value<String?> coverKey = const Value.absent(),
    bool? isFavorite,
    Value<String?> lyricsPlain = const Value.absent(),
    Value<String?> lyricsSynced = const Value.absent(),
    Value<String?> curiosities = const Value.absent(),
    int? enrichStatus,
    bool? userEdited,
    bool? missing,
    bool? ignored,
    int? kind,
    Value<String?> sha256 = const Value.absent(),
    int? addedAt,
    int? playCount,
    Value<double?> replayGainDb = const Value.absent(),
    Value<int?> resumePositionMs = const Value.absent(),
    Value<int?> lastPlayedAt = const Value.absent(),
    Value<String?> isrc = const Value.absent(),
    int? coverSource,
  }) => Track(
    id: id ?? this.id,
    path: path ?? this.path,
    folderId: folderId.present ? folderId.value : this.folderId,
    title: title ?? this.title,
    artist: artist.present ? artist.value : this.artist,
    albumArtist: albumArtist.present ? albumArtist.value : this.albumArtist,
    album: album.present ? album.value : this.album,
    albumKey: albumKey ?? this.albumKey,
    trackNumber: trackNumber.present ? trackNumber.value : this.trackNumber,
    discNumber: discNumber.present ? discNumber.value : this.discNumber,
    year: year.present ? year.value : this.year,
    genre: genre.present ? genre.value : this.genre,
    durationMs: durationMs ?? this.durationMs,
    format: format ?? this.format,
    sampleRateHz: sampleRateHz.present ? sampleRateHz.value : this.sampleRateHz,
    bitDepth: bitDepth.present ? bitDepth.value : this.bitDepth,
    bitrateKbps: bitrateKbps.present ? bitrateKbps.value : this.bitrateKbps,
    channels: channels.present ? channels.value : this.channels,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mtimeMs: mtimeMs ?? this.mtimeMs,
    hasCover: hasCover ?? this.hasCover,
    coverKey: coverKey.present ? coverKey.value : this.coverKey,
    isFavorite: isFavorite ?? this.isFavorite,
    lyricsPlain: lyricsPlain.present ? lyricsPlain.value : this.lyricsPlain,
    lyricsSynced: lyricsSynced.present ? lyricsSynced.value : this.lyricsSynced,
    curiosities: curiosities.present ? curiosities.value : this.curiosities,
    enrichStatus: enrichStatus ?? this.enrichStatus,
    userEdited: userEdited ?? this.userEdited,
    missing: missing ?? this.missing,
    ignored: ignored ?? this.ignored,
    kind: kind ?? this.kind,
    sha256: sha256.present ? sha256.value : this.sha256,
    addedAt: addedAt ?? this.addedAt,
    playCount: playCount ?? this.playCount,
    replayGainDb: replayGainDb.present ? replayGainDb.value : this.replayGainDb,
    resumePositionMs: resumePositionMs.present
        ? resumePositionMs.value
        : this.resumePositionMs,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    isrc: isrc.present ? isrc.value : this.isrc,
    coverSource: coverSource ?? this.coverSource,
  );
  Track copyWithCompanion(TracksCompanion data) {
    return Track(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      albumArtist: data.albumArtist.present
          ? data.albumArtist.value
          : this.albumArtist,
      album: data.album.present ? data.album.value : this.album,
      albumKey: data.albumKey.present ? data.albumKey.value : this.albumKey,
      trackNumber: data.trackNumber.present
          ? data.trackNumber.value
          : this.trackNumber,
      discNumber: data.discNumber.present
          ? data.discNumber.value
          : this.discNumber,
      year: data.year.present ? data.year.value : this.year,
      genre: data.genre.present ? data.genre.value : this.genre,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      format: data.format.present ? data.format.value : this.format,
      sampleRateHz: data.sampleRateHz.present
          ? data.sampleRateHz.value
          : this.sampleRateHz,
      bitDepth: data.bitDepth.present ? data.bitDepth.value : this.bitDepth,
      bitrateKbps: data.bitrateKbps.present
          ? data.bitrateKbps.value
          : this.bitrateKbps,
      channels: data.channels.present ? data.channels.value : this.channels,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      hasCover: data.hasCover.present ? data.hasCover.value : this.hasCover,
      coverKey: data.coverKey.present ? data.coverKey.value : this.coverKey,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
      lyricsPlain: data.lyricsPlain.present
          ? data.lyricsPlain.value
          : this.lyricsPlain,
      lyricsSynced: data.lyricsSynced.present
          ? data.lyricsSynced.value
          : this.lyricsSynced,
      curiosities: data.curiosities.present
          ? data.curiosities.value
          : this.curiosities,
      enrichStatus: data.enrichStatus.present
          ? data.enrichStatus.value
          : this.enrichStatus,
      userEdited: data.userEdited.present
          ? data.userEdited.value
          : this.userEdited,
      missing: data.missing.present ? data.missing.value : this.missing,
      ignored: data.ignored.present ? data.ignored.value : this.ignored,
      kind: data.kind.present ? data.kind.value : this.kind,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      playCount: data.playCount.present ? data.playCount.value : this.playCount,
      replayGainDb: data.replayGainDb.present
          ? data.replayGainDb.value
          : this.replayGainDb,
      resumePositionMs: data.resumePositionMs.present
          ? data.resumePositionMs.value
          : this.resumePositionMs,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
      coverSource: data.coverSource.present
          ? data.coverSource.value
          : this.coverSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Track(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('album: $album, ')
          ..write('albumKey: $albumKey, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('durationMs: $durationMs, ')
          ..write('format: $format, ')
          ..write('sampleRateHz: $sampleRateHz, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('bitrateKbps: $bitrateKbps, ')
          ..write('channels: $channels, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('hasCover: $hasCover, ')
          ..write('coverKey: $coverKey, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('lyricsPlain: $lyricsPlain, ')
          ..write('lyricsSynced: $lyricsSynced, ')
          ..write('curiosities: $curiosities, ')
          ..write('enrichStatus: $enrichStatus, ')
          ..write('userEdited: $userEdited, ')
          ..write('missing: $missing, ')
          ..write('ignored: $ignored, ')
          ..write('kind: $kind, ')
          ..write('sha256: $sha256, ')
          ..write('addedAt: $addedAt, ')
          ..write('playCount: $playCount, ')
          ..write('replayGainDb: $replayGainDb, ')
          ..write('resumePositionMs: $resumePositionMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('isrc: $isrc, ')
          ..write('coverSource: $coverSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    path,
    folderId,
    title,
    artist,
    albumArtist,
    album,
    albumKey,
    trackNumber,
    discNumber,
    year,
    genre,
    durationMs,
    format,
    sampleRateHz,
    bitDepth,
    bitrateKbps,
    channels,
    sizeBytes,
    mtimeMs,
    hasCover,
    coverKey,
    isFavorite,
    lyricsPlain,
    lyricsSynced,
    curiosities,
    enrichStatus,
    userEdited,
    missing,
    ignored,
    kind,
    sha256,
    addedAt,
    playCount,
    replayGainDb,
    resumePositionMs,
    lastPlayedAt,
    isrc,
    coverSource,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Track &&
          other.id == this.id &&
          other.path == this.path &&
          other.folderId == this.folderId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.albumArtist == this.albumArtist &&
          other.album == this.album &&
          other.albumKey == this.albumKey &&
          other.trackNumber == this.trackNumber &&
          other.discNumber == this.discNumber &&
          other.year == this.year &&
          other.genre == this.genre &&
          other.durationMs == this.durationMs &&
          other.format == this.format &&
          other.sampleRateHz == this.sampleRateHz &&
          other.bitDepth == this.bitDepth &&
          other.bitrateKbps == this.bitrateKbps &&
          other.channels == this.channels &&
          other.sizeBytes == this.sizeBytes &&
          other.mtimeMs == this.mtimeMs &&
          other.hasCover == this.hasCover &&
          other.coverKey == this.coverKey &&
          other.isFavorite == this.isFavorite &&
          other.lyricsPlain == this.lyricsPlain &&
          other.lyricsSynced == this.lyricsSynced &&
          other.curiosities == this.curiosities &&
          other.enrichStatus == this.enrichStatus &&
          other.userEdited == this.userEdited &&
          other.missing == this.missing &&
          other.ignored == this.ignored &&
          other.kind == this.kind &&
          other.sha256 == this.sha256 &&
          other.addedAt == this.addedAt &&
          other.playCount == this.playCount &&
          other.replayGainDb == this.replayGainDb &&
          other.resumePositionMs == this.resumePositionMs &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.isrc == this.isrc &&
          other.coverSource == this.coverSource);
}

class TracksCompanion extends UpdateCompanion<Track> {
  final Value<int> id;
  final Value<String> path;
  final Value<int?> folderId;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> albumArtist;
  final Value<String?> album;
  final Value<String> albumKey;
  final Value<int?> trackNumber;
  final Value<int?> discNumber;
  final Value<int?> year;
  final Value<String?> genre;
  final Value<int> durationMs;
  final Value<String> format;
  final Value<int?> sampleRateHz;
  final Value<int?> bitDepth;
  final Value<int?> bitrateKbps;
  final Value<int?> channels;
  final Value<int> sizeBytes;
  final Value<int> mtimeMs;
  final Value<bool> hasCover;
  final Value<String?> coverKey;
  final Value<bool> isFavorite;
  final Value<String?> lyricsPlain;
  final Value<String?> lyricsSynced;
  final Value<String?> curiosities;
  final Value<int> enrichStatus;
  final Value<bool> userEdited;
  final Value<bool> missing;
  final Value<bool> ignored;
  final Value<int> kind;
  final Value<String?> sha256;
  final Value<int> addedAt;
  final Value<int> playCount;
  final Value<double?> replayGainDb;
  final Value<int?> resumePositionMs;
  final Value<int?> lastPlayedAt;
  final Value<String?> isrc;
  final Value<int> coverSource;
  const TracksCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.folderId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumKey = const Value.absent(),
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.format = const Value.absent(),
    this.sampleRateHz = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.bitrateKbps = const Value.absent(),
    this.channels = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.hasCover = const Value.absent(),
    this.coverKey = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.lyricsPlain = const Value.absent(),
    this.lyricsSynced = const Value.absent(),
    this.curiosities = const Value.absent(),
    this.enrichStatus = const Value.absent(),
    this.userEdited = const Value.absent(),
    this.missing = const Value.absent(),
    this.ignored = const Value.absent(),
    this.kind = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.playCount = const Value.absent(),
    this.replayGainDb = const Value.absent(),
    this.resumePositionMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.isrc = const Value.absent(),
    this.coverSource = const Value.absent(),
  });
  TracksCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    this.folderId = const Value.absent(),
    required String title,
    this.artist = const Value.absent(),
    this.albumArtist = const Value.absent(),
    this.album = const Value.absent(),
    required String albumKey,
    this.trackNumber = const Value.absent(),
    this.discNumber = const Value.absent(),
    this.year = const Value.absent(),
    this.genre = const Value.absent(),
    this.durationMs = const Value.absent(),
    required String format,
    this.sampleRateHz = const Value.absent(),
    this.bitDepth = const Value.absent(),
    this.bitrateKbps = const Value.absent(),
    this.channels = const Value.absent(),
    required int sizeBytes,
    required int mtimeMs,
    this.hasCover = const Value.absent(),
    this.coverKey = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.lyricsPlain = const Value.absent(),
    this.lyricsSynced = const Value.absent(),
    this.curiosities = const Value.absent(),
    this.enrichStatus = const Value.absent(),
    this.userEdited = const Value.absent(),
    this.missing = const Value.absent(),
    this.ignored = const Value.absent(),
    this.kind = const Value.absent(),
    this.sha256 = const Value.absent(),
    required int addedAt,
    this.playCount = const Value.absent(),
    this.replayGainDb = const Value.absent(),
    this.resumePositionMs = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.isrc = const Value.absent(),
    this.coverSource = const Value.absent(),
  }) : path = Value(path),
       title = Value(title),
       albumKey = Value(albumKey),
       format = Value(format),
       sizeBytes = Value(sizeBytes),
       mtimeMs = Value(mtimeMs),
       addedAt = Value(addedAt);
  static Insertable<Track> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? folderId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? albumArtist,
    Expression<String>? album,
    Expression<String>? albumKey,
    Expression<int>? trackNumber,
    Expression<int>? discNumber,
    Expression<int>? year,
    Expression<String>? genre,
    Expression<int>? durationMs,
    Expression<String>? format,
    Expression<int>? sampleRateHz,
    Expression<int>? bitDepth,
    Expression<int>? bitrateKbps,
    Expression<int>? channels,
    Expression<int>? sizeBytes,
    Expression<int>? mtimeMs,
    Expression<bool>? hasCover,
    Expression<String>? coverKey,
    Expression<bool>? isFavorite,
    Expression<String>? lyricsPlain,
    Expression<String>? lyricsSynced,
    Expression<String>? curiosities,
    Expression<int>? enrichStatus,
    Expression<bool>? userEdited,
    Expression<bool>? missing,
    Expression<bool>? ignored,
    Expression<int>? kind,
    Expression<String>? sha256,
    Expression<int>? addedAt,
    Expression<int>? playCount,
    Expression<double>? replayGainDb,
    Expression<int>? resumePositionMs,
    Expression<int>? lastPlayedAt,
    Expression<String>? isrc,
    Expression<int>? coverSource,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (folderId != null) 'folder_id': folderId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (albumArtist != null) 'album_artist': albumArtist,
      if (album != null) 'album': album,
      if (albumKey != null) 'album_key': albumKey,
      if (trackNumber != null) 'track_number': trackNumber,
      if (discNumber != null) 'disc_number': discNumber,
      if (year != null) 'year': year,
      if (genre != null) 'genre': genre,
      if (durationMs != null) 'duration_ms': durationMs,
      if (format != null) 'format': format,
      if (sampleRateHz != null) 'sample_rate_hz': sampleRateHz,
      if (bitDepth != null) 'bit_depth': bitDepth,
      if (bitrateKbps != null) 'bitrate_kbps': bitrateKbps,
      if (channels != null) 'channels': channels,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (hasCover != null) 'has_cover': hasCover,
      if (coverKey != null) 'cover_key': coverKey,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (lyricsPlain != null) 'lyrics_plain': lyricsPlain,
      if (lyricsSynced != null) 'lyrics_synced': lyricsSynced,
      if (curiosities != null) 'curiosities': curiosities,
      if (enrichStatus != null) 'enrich_status': enrichStatus,
      if (userEdited != null) 'user_edited': userEdited,
      if (missing != null) 'missing': missing,
      if (ignored != null) 'ignored': ignored,
      if (kind != null) 'kind': kind,
      if (sha256 != null) 'sha256': sha256,
      if (addedAt != null) 'added_at': addedAt,
      if (playCount != null) 'play_count': playCount,
      if (replayGainDb != null) 'replay_gain_db': replayGainDb,
      if (resumePositionMs != null) 'resume_position_ms': resumePositionMs,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (isrc != null) 'isrc': isrc,
      if (coverSource != null) 'cover_source': coverSource,
    });
  }

  TracksCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int?>? folderId,
    Value<String>? title,
    Value<String?>? artist,
    Value<String?>? albumArtist,
    Value<String?>? album,
    Value<String>? albumKey,
    Value<int?>? trackNumber,
    Value<int?>? discNumber,
    Value<int?>? year,
    Value<String?>? genre,
    Value<int>? durationMs,
    Value<String>? format,
    Value<int?>? sampleRateHz,
    Value<int?>? bitDepth,
    Value<int?>? bitrateKbps,
    Value<int?>? channels,
    Value<int>? sizeBytes,
    Value<int>? mtimeMs,
    Value<bool>? hasCover,
    Value<String?>? coverKey,
    Value<bool>? isFavorite,
    Value<String?>? lyricsPlain,
    Value<String?>? lyricsSynced,
    Value<String?>? curiosities,
    Value<int>? enrichStatus,
    Value<bool>? userEdited,
    Value<bool>? missing,
    Value<bool>? ignored,
    Value<int>? kind,
    Value<String?>? sha256,
    Value<int>? addedAt,
    Value<int>? playCount,
    Value<double?>? replayGainDb,
    Value<int?>? resumePositionMs,
    Value<int?>? lastPlayedAt,
    Value<String?>? isrc,
    Value<int>? coverSource,
  }) {
    return TracksCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      albumArtist: albumArtist ?? this.albumArtist,
      album: album ?? this.album,
      albumKey: albumKey ?? this.albumKey,
      trackNumber: trackNumber ?? this.trackNumber,
      discNumber: discNumber ?? this.discNumber,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      durationMs: durationMs ?? this.durationMs,
      format: format ?? this.format,
      sampleRateHz: sampleRateHz ?? this.sampleRateHz,
      bitDepth: bitDepth ?? this.bitDepth,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
      channels: channels ?? this.channels,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      hasCover: hasCover ?? this.hasCover,
      coverKey: coverKey ?? this.coverKey,
      isFavorite: isFavorite ?? this.isFavorite,
      lyricsPlain: lyricsPlain ?? this.lyricsPlain,
      lyricsSynced: lyricsSynced ?? this.lyricsSynced,
      curiosities: curiosities ?? this.curiosities,
      enrichStatus: enrichStatus ?? this.enrichStatus,
      userEdited: userEdited ?? this.userEdited,
      missing: missing ?? this.missing,
      ignored: ignored ?? this.ignored,
      kind: kind ?? this.kind,
      sha256: sha256 ?? this.sha256,
      addedAt: addedAt ?? this.addedAt,
      playCount: playCount ?? this.playCount,
      replayGainDb: replayGainDb ?? this.replayGainDb,
      resumePositionMs: resumePositionMs ?? this.resumePositionMs,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      isrc: isrc ?? this.isrc,
      coverSource: coverSource ?? this.coverSource,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (albumArtist.present) {
      map['album_artist'] = Variable<String>(albumArtist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumKey.present) {
      map['album_key'] = Variable<String>(albumKey.value);
    }
    if (trackNumber.present) {
      map['track_number'] = Variable<int>(trackNumber.value);
    }
    if (discNumber.present) {
      map['disc_number'] = Variable<int>(discNumber.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (sampleRateHz.present) {
      map['sample_rate_hz'] = Variable<int>(sampleRateHz.value);
    }
    if (bitDepth.present) {
      map['bit_depth'] = Variable<int>(bitDepth.value);
    }
    if (bitrateKbps.present) {
      map['bitrate_kbps'] = Variable<int>(bitrateKbps.value);
    }
    if (channels.present) {
      map['channels'] = Variable<int>(channels.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<int>(mtimeMs.value);
    }
    if (hasCover.present) {
      map['has_cover'] = Variable<bool>(hasCover.value);
    }
    if (coverKey.present) {
      map['cover_key'] = Variable<String>(coverKey.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (lyricsPlain.present) {
      map['lyrics_plain'] = Variable<String>(lyricsPlain.value);
    }
    if (lyricsSynced.present) {
      map['lyrics_synced'] = Variable<String>(lyricsSynced.value);
    }
    if (curiosities.present) {
      map['curiosities'] = Variable<String>(curiosities.value);
    }
    if (enrichStatus.present) {
      map['enrich_status'] = Variable<int>(enrichStatus.value);
    }
    if (userEdited.present) {
      map['user_edited'] = Variable<bool>(userEdited.value);
    }
    if (missing.present) {
      map['missing'] = Variable<bool>(missing.value);
    }
    if (ignored.present) {
      map['ignored'] = Variable<bool>(ignored.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (playCount.present) {
      map['play_count'] = Variable<int>(playCount.value);
    }
    if (replayGainDb.present) {
      map['replay_gain_db'] = Variable<double>(replayGainDb.value);
    }
    if (resumePositionMs.present) {
      map['resume_position_ms'] = Variable<int>(resumePositionMs.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (coverSource.present) {
      map['cover_source'] = Variable<int>(coverSource.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TracksCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('albumArtist: $albumArtist, ')
          ..write('album: $album, ')
          ..write('albumKey: $albumKey, ')
          ..write('trackNumber: $trackNumber, ')
          ..write('discNumber: $discNumber, ')
          ..write('year: $year, ')
          ..write('genre: $genre, ')
          ..write('durationMs: $durationMs, ')
          ..write('format: $format, ')
          ..write('sampleRateHz: $sampleRateHz, ')
          ..write('bitDepth: $bitDepth, ')
          ..write('bitrateKbps: $bitrateKbps, ')
          ..write('channels: $channels, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('hasCover: $hasCover, ')
          ..write('coverKey: $coverKey, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('lyricsPlain: $lyricsPlain, ')
          ..write('lyricsSynced: $lyricsSynced, ')
          ..write('curiosities: $curiosities, ')
          ..write('enrichStatus: $enrichStatus, ')
          ..write('userEdited: $userEdited, ')
          ..write('missing: $missing, ')
          ..write('ignored: $ignored, ')
          ..write('kind: $kind, ')
          ..write('sha256: $sha256, ')
          ..write('addedAt: $addedAt, ')
          ..write('playCount: $playCount, ')
          ..write('replayGainDb: $replayGainDb, ')
          ..write('resumePositionMs: $resumePositionMs, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('isrc: $isrc, ')
          ..write('coverSource: $coverSource')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, path, addedAt, label];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Folder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final int id;
  final String path;
  final int addedAt;
  final String? label;
  const Folder({
    required this.id,
    required this.path,
    required this.addedAt,
    this.label,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['path'] = Variable<String>(path);
    map['added_at'] = Variable<int>(addedAt);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      path: Value(path),
      addedAt: Value(addedAt),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
    );
  }

  factory Folder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<int>(json['id']),
      path: serializer.fromJson<String>(json['path']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      label: serializer.fromJson<String?>(json['label']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'path': serializer.toJson<String>(path),
      'addedAt': serializer.toJson<int>(addedAt),
      'label': serializer.toJson<String?>(label),
    };
  }

  Folder copyWith({
    int? id,
    String? path,
    int? addedAt,
    Value<String?> label = const Value.absent(),
  }) => Folder(
    id: id ?? this.id,
    path: path ?? this.path,
    addedAt: addedAt ?? this.addedAt,
    label: label.present ? label.value : this.label,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      path: data.path.present ? data.path.value : this.path,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      label: data.label.present ? data.label.value : this.label,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, path, addedAt, label);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.path == this.path &&
          other.addedAt == this.addedAt &&
          other.label == this.label);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<String> path;
  final Value<int> addedAt;
  final Value<String?> label;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.label = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required String path,
    required int addedAt,
    this.label = const Value.absent(),
  }) : path = Value(path),
       addedAt = Value(addedAt);
  static Insertable<Folder> custom({
    Expression<int>? id,
    Expression<String>? path,
    Expression<int>? addedAt,
    Expression<String>? label,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
      if (label != null) 'label': label,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? path,
    Value<int>? addedAt,
    Value<String?>? label,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
      label: label ?? this.label,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('label: $label')
          ..write(')'))
        .toString();
  }
}

class $PlaylistsTable extends Playlists
    with TableInfo<$PlaylistsTable, Playlist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: newUuid,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
    clientDefault: nowMs,
  );
  static const VerificationMeta _coverKeyMeta = const VerificationMeta(
    'coverKey',
  );
  @override
  late final GeneratedColumn<String> coverKey = GeneratedColumn<String>(
    'cover_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    uuid,
    updatedAt,
    coverKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<Playlist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('cover_key')) {
      context.handle(
        _coverKeyMeta,
        coverKey.isAcceptableOrUnknown(data['cover_key']!, _coverKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Playlist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Playlist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      coverKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_key'],
      ),
    );
  }

  @override
  $PlaylistsTable createAlias(String alias) {
    return $PlaylistsTable(attachedDatabase, alias);
  }
}

class Playlist extends DataClass implements Insertable<Playlist> {
  final int id;
  final String name;
  final int createdAt;

  /// Identity of the playlist across devices (schema v10): the same on every
  /// device it is synced to. Nullable only because the migration adds the
  /// column before filling it; every new row gets one.
  final String? uuid;

  /// Epoch ms of the last change to its name, cover, tracks or order: «last
  /// change wins» when playlists are synced.
  final int updatedAt;

  /// File name inside the covers folder; null = use the first track's cover.
  final String? coverKey;
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    this.uuid,
    required this.updatedAt,
    this.coverKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || coverKey != null) {
      map['cover_key'] = Variable<String>(coverKey);
    }
    return map;
  }

  PlaylistsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
      updatedAt: Value(updatedAt),
      coverKey: coverKey == null && nullToAbsent
          ? const Value.absent()
          : Value(coverKey),
    );
  }

  factory Playlist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Playlist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      uuid: serializer.fromJson<String?>(json['uuid']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      coverKey: serializer.fromJson<String?>(json['coverKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
      'uuid': serializer.toJson<String?>(uuid),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'coverKey': serializer.toJson<String?>(coverKey),
    };
  }

  Playlist copyWith({
    int? id,
    String? name,
    int? createdAt,
    Value<String?> uuid = const Value.absent(),
    int? updatedAt,
    Value<String?> coverKey = const Value.absent(),
  }) => Playlist(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    uuid: uuid.present ? uuid.value : this.uuid,
    updatedAt: updatedAt ?? this.updatedAt,
    coverKey: coverKey.present ? coverKey.value : this.coverKey,
  );
  Playlist copyWithCompanion(PlaylistsCompanion data) {
    return Playlist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      coverKey: data.coverKey.present ? data.coverKey.value : this.coverKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Playlist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('uuid: $uuid, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('coverKey: $coverKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, createdAt, uuid, updatedAt, coverKey);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Playlist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.uuid == this.uuid &&
          other.updatedAt == this.updatedAt &&
          other.coverKey == this.coverKey);
}

class PlaylistsCompanion extends UpdateCompanion<Playlist> {
  final Value<int> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<String?> uuid;
  final Value<int> updatedAt;
  final Value<String?> coverKey;
  const PlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.uuid = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.coverKey = const Value.absent(),
  });
  PlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required int createdAt,
    this.uuid = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.coverKey = const Value.absent(),
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Playlist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<String>? uuid,
    Expression<int>? updatedAt,
    Expression<String>? coverKey,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (uuid != null) 'uuid': uuid,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (coverKey != null) 'cover_key': coverKey,
    });
  }

  PlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int>? createdAt,
    Value<String?>? uuid,
    Value<int>? updatedAt,
    Value<String?>? coverKey,
  }) {
    return PlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      uuid: uuid ?? this.uuid,
      updatedAt: updatedAt ?? this.updatedAt,
      coverKey: coverKey ?? this.coverKey,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (coverKey.present) {
      map['cover_key'] = Variable<String>(coverKey.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('uuid: $uuid, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('coverKey: $coverKey')
          ..write(')'))
        .toString();
  }
}

class $PlaylistTracksTable extends PlaylistTracks
    with TableInfo<$PlaylistTracksTable, PlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [playlistId, trackId, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_tracks';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistTrack> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, trackId};
  @override
  PlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistTrack(
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $PlaylistTracksTable createAlias(String alias) {
    return $PlaylistTracksTable(attachedDatabase, alias);
  }
}

class PlaylistTrack extends DataClass implements Insertable<PlaylistTrack> {
  final int playlistId;
  final int trackId;
  final int position;
  const PlaylistTrack({
    required this.playlistId,
    required this.trackId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['track_id'] = Variable<int>(trackId);
    map['position'] = Variable<int>(position);
    return map;
  }

  PlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return PlaylistTracksCompanion(
      playlistId: Value(playlistId),
      trackId: Value(trackId),
      position: Value(position),
    );
  }

  factory PlaylistTrack.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistTrack(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      trackId: serializer.fromJson<int>(json['trackId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'trackId': serializer.toJson<int>(trackId),
      'position': serializer.toJson<int>(position),
    };
  }

  PlaylistTrack copyWith({int? playlistId, int? trackId, int? position}) =>
      PlaylistTrack(
        playlistId: playlistId ?? this.playlistId,
        trackId: trackId ?? this.trackId,
        position: position ?? this.position,
      );
  PlaylistTrack copyWithCompanion(PlaylistTracksCompanion data) {
    return PlaylistTrack(
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTrack(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, trackId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistTrack &&
          other.playlistId == this.playlistId &&
          other.trackId == this.trackId &&
          other.position == this.position);
}

class PlaylistTracksCompanion extends UpdateCompanion<PlaylistTrack> {
  final Value<int> playlistId;
  final Value<int> trackId;
  final Value<int> position;
  final Value<int> rowid;
  const PlaylistTracksCompanion({
    this.playlistId = const Value.absent(),
    this.trackId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistTracksCompanion.insert({
    required int playlistId,
    required int trackId,
    required int position,
    this.rowid = const Value.absent(),
  }) : playlistId = Value(playlistId),
       trackId = Value(trackId),
       position = Value(position);
  static Insertable<PlaylistTrack> custom({
    Expression<int>? playlistId,
    Expression<int>? trackId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackId != null) 'track_id': trackId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistTracksCompanion copyWith({
    Value<int>? playlistId,
    Value<int>? trackId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return PlaylistTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackId: trackId ?? this.trackId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackId: $trackId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaylistImportsTable extends PlaylistImports
    with TableInfo<$PlaylistImportsTable, PlaylistImport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistImportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _playlistIdMeta = const VerificationMeta(
    'playlistId',
  );
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
    'playlist_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlists (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sourceKindMeta = const VerificationMeta(
    'sourceKind',
  );
  @override
  late final GeneratedColumn<String> sourceKind = GeneratedColumn<String>(
    'source_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('exportify'),
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numberFilesMeta = const VerificationMeta(
    'numberFiles',
  );
  @override
  late final GeneratedColumn<bool> numberFiles = GeneratedColumn<bool>(
    'number_files',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("number_files" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _linkOnlyMeta = const VerificationMeta(
    'linkOnly',
  );
  @override
  late final GeneratedColumn<bool> linkOnly = GeneratedColumn<bool>(
    'link_only',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("link_only" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _planFirstMeta = const VerificationMeta(
    'planFirst',
  );
  @override
  late final GeneratedColumn<bool> planFirst = GeneratedColumn<bool>(
    'plan_first',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("plan_first" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _fetchCoversMeta = const VerificationMeta(
    'fetchCovers',
  );
  @override
  late final GeneratedColumn<bool> fetchCovers = GeneratedColumn<bool>(
    'fetch_covers',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fetch_covers" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    playlistId,
    sourceName,
    createdAt,
    status,
    sourceKind,
    folderPath,
    numberFiles,
    linkOnly,
    planFirst,
    fetchCovers,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_imports';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistImport> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('playlist_id')) {
      context.handle(
        _playlistIdMeta,
        playlistId.isAcceptableOrUnknown(data['playlist_id']!, _playlistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('source_kind')) {
      context.handle(
        _sourceKindMeta,
        sourceKind.isAcceptableOrUnknown(data['source_kind']!, _sourceKindMeta),
      );
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    }
    if (data.containsKey('number_files')) {
      context.handle(
        _numberFilesMeta,
        numberFiles.isAcceptableOrUnknown(
          data['number_files']!,
          _numberFilesMeta,
        ),
      );
    }
    if (data.containsKey('link_only')) {
      context.handle(
        _linkOnlyMeta,
        linkOnly.isAcceptableOrUnknown(data['link_only']!, _linkOnlyMeta),
      );
    }
    if (data.containsKey('plan_first')) {
      context.handle(
        _planFirstMeta,
        planFirst.isAcceptableOrUnknown(data['plan_first']!, _planFirstMeta),
      );
    }
    if (data.containsKey('fetch_covers')) {
      context.handle(
        _fetchCoversMeta,
        fetchCovers.isAcceptableOrUnknown(
          data['fetch_covers']!,
          _fetchCoversMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlaylistImport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistImport(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      playlistId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playlist_id'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      sourceKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_kind'],
      )!,
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      ),
      numberFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}number_files'],
      )!,
      linkOnly: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}link_only'],
      )!,
      planFirst: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}plan_first'],
      )!,
      fetchCovers: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fetch_covers'],
      )!,
    );
  }

  @override
  $PlaylistImportsTable createAlias(String alias) {
    return $PlaylistImportsTable(attachedDatabase, alias);
  }
}

class PlaylistImport extends DataClass implements Insertable<PlaylistImport> {
  final int id;
  final int playlistId;
  final String sourceName;
  final int createdAt;

  /// 0 running · 1 paused · 2 finished · 3 cancelled.
  final int status;

  /// Where the rows came from: `exportify` · `tunemymusic` · `soundiiz` ·
  /// `lastfm` · `csv` · `m3u` · `xspf`.
  final String sourceKind;

  /// Sub-folder of the download folder for this import (null = none).
  final String? folderPath;

  /// Prefix downloaded files with their position (`007 - Artist - Title`).
  final bool numberFiles;

  /// Link what the library has and download nothing.
  final bool linkOnly;

  /// Search everything first and wait for the user before downloading.
  final bool planFirst;

  /// Look the album cover up after each download.
  final bool fetchCovers;
  const PlaylistImport({
    required this.id,
    required this.playlistId,
    required this.sourceName,
    required this.createdAt,
    required this.status,
    required this.sourceKind,
    this.folderPath,
    required this.numberFiles,
    required this.linkOnly,
    required this.planFirst,
    required this.fetchCovers,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['playlist_id'] = Variable<int>(playlistId);
    map['source_name'] = Variable<String>(sourceName);
    map['created_at'] = Variable<int>(createdAt);
    map['status'] = Variable<int>(status);
    map['source_kind'] = Variable<String>(sourceKind);
    if (!nullToAbsent || folderPath != null) {
      map['folder_path'] = Variable<String>(folderPath);
    }
    map['number_files'] = Variable<bool>(numberFiles);
    map['link_only'] = Variable<bool>(linkOnly);
    map['plan_first'] = Variable<bool>(planFirst);
    map['fetch_covers'] = Variable<bool>(fetchCovers);
    return map;
  }

  PlaylistImportsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistImportsCompanion(
      id: Value(id),
      playlistId: Value(playlistId),
      sourceName: Value(sourceName),
      createdAt: Value(createdAt),
      status: Value(status),
      sourceKind: Value(sourceKind),
      folderPath: folderPath == null && nullToAbsent
          ? const Value.absent()
          : Value(folderPath),
      numberFiles: Value(numberFiles),
      linkOnly: Value(linkOnly),
      planFirst: Value(planFirst),
      fetchCovers: Value(fetchCovers),
    );
  }

  factory PlaylistImport.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistImport(
      id: serializer.fromJson<int>(json['id']),
      playlistId: serializer.fromJson<int>(json['playlistId']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      status: serializer.fromJson<int>(json['status']),
      sourceKind: serializer.fromJson<String>(json['sourceKind']),
      folderPath: serializer.fromJson<String?>(json['folderPath']),
      numberFiles: serializer.fromJson<bool>(json['numberFiles']),
      linkOnly: serializer.fromJson<bool>(json['linkOnly']),
      planFirst: serializer.fromJson<bool>(json['planFirst']),
      fetchCovers: serializer.fromJson<bool>(json['fetchCovers']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'playlistId': serializer.toJson<int>(playlistId),
      'sourceName': serializer.toJson<String>(sourceName),
      'createdAt': serializer.toJson<int>(createdAt),
      'status': serializer.toJson<int>(status),
      'sourceKind': serializer.toJson<String>(sourceKind),
      'folderPath': serializer.toJson<String?>(folderPath),
      'numberFiles': serializer.toJson<bool>(numberFiles),
      'linkOnly': serializer.toJson<bool>(linkOnly),
      'planFirst': serializer.toJson<bool>(planFirst),
      'fetchCovers': serializer.toJson<bool>(fetchCovers),
    };
  }

  PlaylistImport copyWith({
    int? id,
    int? playlistId,
    String? sourceName,
    int? createdAt,
    int? status,
    String? sourceKind,
    Value<String?> folderPath = const Value.absent(),
    bool? numberFiles,
    bool? linkOnly,
    bool? planFirst,
    bool? fetchCovers,
  }) => PlaylistImport(
    id: id ?? this.id,
    playlistId: playlistId ?? this.playlistId,
    sourceName: sourceName ?? this.sourceName,
    createdAt: createdAt ?? this.createdAt,
    status: status ?? this.status,
    sourceKind: sourceKind ?? this.sourceKind,
    folderPath: folderPath.present ? folderPath.value : this.folderPath,
    numberFiles: numberFiles ?? this.numberFiles,
    linkOnly: linkOnly ?? this.linkOnly,
    planFirst: planFirst ?? this.planFirst,
    fetchCovers: fetchCovers ?? this.fetchCovers,
  );
  PlaylistImport copyWithCompanion(PlaylistImportsCompanion data) {
    return PlaylistImport(
      id: data.id.present ? data.id.value : this.id,
      playlistId: data.playlistId.present
          ? data.playlistId.value
          : this.playlistId,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      status: data.status.present ? data.status.value : this.status,
      sourceKind: data.sourceKind.present
          ? data.sourceKind.value
          : this.sourceKind,
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      numberFiles: data.numberFiles.present
          ? data.numberFiles.value
          : this.numberFiles,
      linkOnly: data.linkOnly.present ? data.linkOnly.value : this.linkOnly,
      planFirst: data.planFirst.present ? data.planFirst.value : this.planFirst,
      fetchCovers: data.fetchCovers.present
          ? data.fetchCovers.value
          : this.fetchCovers,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistImport(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('sourceName: $sourceName, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('folderPath: $folderPath, ')
          ..write('numberFiles: $numberFiles, ')
          ..write('linkOnly: $linkOnly, ')
          ..write('planFirst: $planFirst, ')
          ..write('fetchCovers: $fetchCovers')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    playlistId,
    sourceName,
    createdAt,
    status,
    sourceKind,
    folderPath,
    numberFiles,
    linkOnly,
    planFirst,
    fetchCovers,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistImport &&
          other.id == this.id &&
          other.playlistId == this.playlistId &&
          other.sourceName == this.sourceName &&
          other.createdAt == this.createdAt &&
          other.status == this.status &&
          other.sourceKind == this.sourceKind &&
          other.folderPath == this.folderPath &&
          other.numberFiles == this.numberFiles &&
          other.linkOnly == this.linkOnly &&
          other.planFirst == this.planFirst &&
          other.fetchCovers == this.fetchCovers);
}

class PlaylistImportsCompanion extends UpdateCompanion<PlaylistImport> {
  final Value<int> id;
  final Value<int> playlistId;
  final Value<String> sourceName;
  final Value<int> createdAt;
  final Value<int> status;
  final Value<String> sourceKind;
  final Value<String?> folderPath;
  final Value<bool> numberFiles;
  final Value<bool> linkOnly;
  final Value<bool> planFirst;
  final Value<bool> fetchCovers;
  const PlaylistImportsCompanion({
    this.id = const Value.absent(),
    this.playlistId = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.status = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.numberFiles = const Value.absent(),
    this.linkOnly = const Value.absent(),
    this.planFirst = const Value.absent(),
    this.fetchCovers = const Value.absent(),
  });
  PlaylistImportsCompanion.insert({
    this.id = const Value.absent(),
    required int playlistId,
    required String sourceName,
    required int createdAt,
    this.status = const Value.absent(),
    this.sourceKind = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.numberFiles = const Value.absent(),
    this.linkOnly = const Value.absent(),
    this.planFirst = const Value.absent(),
    this.fetchCovers = const Value.absent(),
  }) : playlistId = Value(playlistId),
       sourceName = Value(sourceName),
       createdAt = Value(createdAt);
  static Insertable<PlaylistImport> custom({
    Expression<int>? id,
    Expression<int>? playlistId,
    Expression<String>? sourceName,
    Expression<int>? createdAt,
    Expression<int>? status,
    Expression<String>? sourceKind,
    Expression<String>? folderPath,
    Expression<bool>? numberFiles,
    Expression<bool>? linkOnly,
    Expression<bool>? planFirst,
    Expression<bool>? fetchCovers,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (playlistId != null) 'playlist_id': playlistId,
      if (sourceName != null) 'source_name': sourceName,
      if (createdAt != null) 'created_at': createdAt,
      if (status != null) 'status': status,
      if (sourceKind != null) 'source_kind': sourceKind,
      if (folderPath != null) 'folder_path': folderPath,
      if (numberFiles != null) 'number_files': numberFiles,
      if (linkOnly != null) 'link_only': linkOnly,
      if (planFirst != null) 'plan_first': planFirst,
      if (fetchCovers != null) 'fetch_covers': fetchCovers,
    });
  }

  PlaylistImportsCompanion copyWith({
    Value<int>? id,
    Value<int>? playlistId,
    Value<String>? sourceName,
    Value<int>? createdAt,
    Value<int>? status,
    Value<String>? sourceKind,
    Value<String?>? folderPath,
    Value<bool>? numberFiles,
    Value<bool>? linkOnly,
    Value<bool>? planFirst,
    Value<bool>? fetchCovers,
  }) {
    return PlaylistImportsCompanion(
      id: id ?? this.id,
      playlistId: playlistId ?? this.playlistId,
      sourceName: sourceName ?? this.sourceName,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      sourceKind: sourceKind ?? this.sourceKind,
      folderPath: folderPath ?? this.folderPath,
      numberFiles: numberFiles ?? this.numberFiles,
      linkOnly: linkOnly ?? this.linkOnly,
      planFirst: planFirst ?? this.planFirst,
      fetchCovers: fetchCovers ?? this.fetchCovers,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (sourceKind.present) {
      map['source_kind'] = Variable<String>(sourceKind.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (numberFiles.present) {
      map['number_files'] = Variable<bool>(numberFiles.value);
    }
    if (linkOnly.present) {
      map['link_only'] = Variable<bool>(linkOnly.value);
    }
    if (planFirst.present) {
      map['plan_first'] = Variable<bool>(planFirst.value);
    }
    if (fetchCovers.present) {
      map['fetch_covers'] = Variable<bool>(fetchCovers.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistImportsCompanion(')
          ..write('id: $id, ')
          ..write('playlistId: $playlistId, ')
          ..write('sourceName: $sourceName, ')
          ..write('createdAt: $createdAt, ')
          ..write('status: $status, ')
          ..write('sourceKind: $sourceKind, ')
          ..write('folderPath: $folderPath, ')
          ..write('numberFiles: $numberFiles, ')
          ..write('linkOnly: $linkOnly, ')
          ..write('planFirst: $planFirst, ')
          ..write('fetchCovers: $fetchCovers')
          ..write(')'))
        .toString();
  }
}

class $PlaylistImportItemsTable extends PlaylistImportItems
    with TableInfo<$PlaylistImportItemsTable, PlaylistImportItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaylistImportItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _importIdMeta = const VerificationMeta(
    'importId',
  );
  @override
  late final GeneratedColumn<int> importId = GeneratedColumn<int>(
    'import_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES playlist_imports (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _rowIndexMeta = const VerificationMeta(
    'rowIndex',
  );
  @override
  late final GeneratedColumn<int> rowIndex = GeneratedColumn<int>(
    'row_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistsMeta = const VerificationMeta(
    'artists',
  );
  @override
  late final GeneratedColumn<String> artists = GeneratedColumn<String>(
    'artists',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
    'album',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isrcMeta = const VerificationMeta('isrc');
  @override
  late final GeneratedColumn<String> isrc = GeneratedColumn<String>(
    'isrc',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _videoIdMeta = const VerificationMeta(
    'videoId',
  );
  @override
  late final GeneratedColumn<String> videoId = GeneratedColumn<String>(
    'video_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _candidatesMeta = const VerificationMeta(
    'candidates',
  );
  @override
  late final GeneratedColumn<String> candidates = GeneratedColumn<String>(
    'candidates',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<double> score = GeneratedColumn<double>(
    'score',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    importId,
    rowIndex,
    title,
    artists,
    album,
    durationMs,
    isrc,
    year,
    status,
    videoId,
    candidates,
    trackId,
    score,
    note,
    location,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playlist_import_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaylistImportItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('import_id')) {
      context.handle(
        _importIdMeta,
        importId.isAcceptableOrUnknown(data['import_id']!, _importIdMeta),
      );
    } else if (isInserting) {
      context.missing(_importIdMeta);
    }
    if (data.containsKey('row_index')) {
      context.handle(
        _rowIndexMeta,
        rowIndex.isAcceptableOrUnknown(data['row_index']!, _rowIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_rowIndexMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artists')) {
      context.handle(
        _artistsMeta,
        artists.isAcceptableOrUnknown(data['artists']!, _artistsMeta),
      );
    } else if (isInserting) {
      context.missing(_artistsMeta);
    }
    if (data.containsKey('album')) {
      context.handle(
        _albumMeta,
        album.isAcceptableOrUnknown(data['album']!, _albumMeta),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('isrc')) {
      context.handle(
        _isrcMeta,
        isrc.isAcceptableOrUnknown(data['isrc']!, _isrcMeta),
      );
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('video_id')) {
      context.handle(
        _videoIdMeta,
        videoId.isAcceptableOrUnknown(data['video_id']!, _videoIdMeta),
      );
    }
    if (data.containsKey('candidates')) {
      context.handle(
        _candidatesMeta,
        candidates.isAcceptableOrUnknown(data['candidates']!, _candidatesMeta),
      );
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {importId, rowIndex};
  @override
  PlaylistImportItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaylistImportItem(
      importId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}import_id'],
      )!,
      rowIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_index'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      artists: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artists'],
      )!,
      album: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}album'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      isrc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}isrc'],
      ),
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      videoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}video_id'],
      ),
      candidates: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}candidates'],
      ),
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      ),
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}score'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
    );
  }

  @override
  $PlaylistImportItemsTable createAlias(String alias) {
    return $PlaylistImportItemsTable(attachedDatabase, alias);
  }
}

class PlaylistImportItem extends DataClass
    implements Insertable<PlaylistImportItem> {
  final int importId;
  final int rowIndex;
  final String title;

  /// Artists joined with `;` (the CSV separator, so never inside a name).
  final String artists;
  final String? album;
  final int? durationMs;
  final String? isrc;
  final int? year;

  /// 0 to search · 1 queued · 2 downloaded · 3 linked (already in library)
  /// · 4 to review · 5 not found · 6 failed · 7 skipped by the user
  /// · 8 planned (chosen, waiting for «Download») · 9 removed from the source.
  final int status;
  final String? videoId;

  /// JSON list of the best candidates, kept while status is 4 (to review).
  final String? candidates;
  final int? trackId;
  final double? score;

  /// Why a row is «not found» or «to review» (shown and exported).
  final String? note;

  /// Path or URL of a local M3U/XSPF entry.
  final String? location;
  const PlaylistImportItem({
    required this.importId,
    required this.rowIndex,
    required this.title,
    required this.artists,
    this.album,
    this.durationMs,
    this.isrc,
    this.year,
    required this.status,
    this.videoId,
    this.candidates,
    this.trackId,
    this.score,
    this.note,
    this.location,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['import_id'] = Variable<int>(importId);
    map['row_index'] = Variable<int>(rowIndex);
    map['title'] = Variable<String>(title);
    map['artists'] = Variable<String>(artists);
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    if (!nullToAbsent || isrc != null) {
      map['isrc'] = Variable<String>(isrc);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || videoId != null) {
      map['video_id'] = Variable<String>(videoId);
    }
    if (!nullToAbsent || candidates != null) {
      map['candidates'] = Variable<String>(candidates);
    }
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<int>(trackId);
    }
    if (!nullToAbsent || score != null) {
      map['score'] = Variable<double>(score);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    return map;
  }

  PlaylistImportItemsCompanion toCompanion(bool nullToAbsent) {
    return PlaylistImportItemsCompanion(
      importId: Value(importId),
      rowIndex: Value(rowIndex),
      title: Value(title),
      artists: Value(artists),
      album: album == null && nullToAbsent
          ? const Value.absent()
          : Value(album),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      isrc: isrc == null && nullToAbsent ? const Value.absent() : Value(isrc),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      status: Value(status),
      videoId: videoId == null && nullToAbsent
          ? const Value.absent()
          : Value(videoId),
      candidates: candidates == null && nullToAbsent
          ? const Value.absent()
          : Value(candidates),
      trackId: trackId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackId),
      score: score == null && nullToAbsent
          ? const Value.absent()
          : Value(score),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
    );
  }

  factory PlaylistImportItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaylistImportItem(
      importId: serializer.fromJson<int>(json['importId']),
      rowIndex: serializer.fromJson<int>(json['rowIndex']),
      title: serializer.fromJson<String>(json['title']),
      artists: serializer.fromJson<String>(json['artists']),
      album: serializer.fromJson<String?>(json['album']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      isrc: serializer.fromJson<String?>(json['isrc']),
      year: serializer.fromJson<int?>(json['year']),
      status: serializer.fromJson<int>(json['status']),
      videoId: serializer.fromJson<String?>(json['videoId']),
      candidates: serializer.fromJson<String?>(json['candidates']),
      trackId: serializer.fromJson<int?>(json['trackId']),
      score: serializer.fromJson<double?>(json['score']),
      note: serializer.fromJson<String?>(json['note']),
      location: serializer.fromJson<String?>(json['location']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'importId': serializer.toJson<int>(importId),
      'rowIndex': serializer.toJson<int>(rowIndex),
      'title': serializer.toJson<String>(title),
      'artists': serializer.toJson<String>(artists),
      'album': serializer.toJson<String?>(album),
      'durationMs': serializer.toJson<int?>(durationMs),
      'isrc': serializer.toJson<String?>(isrc),
      'year': serializer.toJson<int?>(year),
      'status': serializer.toJson<int>(status),
      'videoId': serializer.toJson<String?>(videoId),
      'candidates': serializer.toJson<String?>(candidates),
      'trackId': serializer.toJson<int?>(trackId),
      'score': serializer.toJson<double?>(score),
      'note': serializer.toJson<String?>(note),
      'location': serializer.toJson<String?>(location),
    };
  }

  PlaylistImportItem copyWith({
    int? importId,
    int? rowIndex,
    String? title,
    String? artists,
    Value<String?> album = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    Value<String?> isrc = const Value.absent(),
    Value<int?> year = const Value.absent(),
    int? status,
    Value<String?> videoId = const Value.absent(),
    Value<String?> candidates = const Value.absent(),
    Value<int?> trackId = const Value.absent(),
    Value<double?> score = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<String?> location = const Value.absent(),
  }) => PlaylistImportItem(
    importId: importId ?? this.importId,
    rowIndex: rowIndex ?? this.rowIndex,
    title: title ?? this.title,
    artists: artists ?? this.artists,
    album: album.present ? album.value : this.album,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    isrc: isrc.present ? isrc.value : this.isrc,
    year: year.present ? year.value : this.year,
    status: status ?? this.status,
    videoId: videoId.present ? videoId.value : this.videoId,
    candidates: candidates.present ? candidates.value : this.candidates,
    trackId: trackId.present ? trackId.value : this.trackId,
    score: score.present ? score.value : this.score,
    note: note.present ? note.value : this.note,
    location: location.present ? location.value : this.location,
  );
  PlaylistImportItem copyWithCompanion(PlaylistImportItemsCompanion data) {
    return PlaylistImportItem(
      importId: data.importId.present ? data.importId.value : this.importId,
      rowIndex: data.rowIndex.present ? data.rowIndex.value : this.rowIndex,
      title: data.title.present ? data.title.value : this.title,
      artists: data.artists.present ? data.artists.value : this.artists,
      album: data.album.present ? data.album.value : this.album,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      isrc: data.isrc.present ? data.isrc.value : this.isrc,
      year: data.year.present ? data.year.value : this.year,
      status: data.status.present ? data.status.value : this.status,
      videoId: data.videoId.present ? data.videoId.value : this.videoId,
      candidates: data.candidates.present
          ? data.candidates.value
          : this.candidates,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      score: data.score.present ? data.score.value : this.score,
      note: data.note.present ? data.note.value : this.note,
      location: data.location.present ? data.location.value : this.location,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistImportItem(')
          ..write('importId: $importId, ')
          ..write('rowIndex: $rowIndex, ')
          ..write('title: $title, ')
          ..write('artists: $artists, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('isrc: $isrc, ')
          ..write('year: $year, ')
          ..write('status: $status, ')
          ..write('videoId: $videoId, ')
          ..write('candidates: $candidates, ')
          ..write('trackId: $trackId, ')
          ..write('score: $score, ')
          ..write('note: $note, ')
          ..write('location: $location')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    importId,
    rowIndex,
    title,
    artists,
    album,
    durationMs,
    isrc,
    year,
    status,
    videoId,
    candidates,
    trackId,
    score,
    note,
    location,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaylistImportItem &&
          other.importId == this.importId &&
          other.rowIndex == this.rowIndex &&
          other.title == this.title &&
          other.artists == this.artists &&
          other.album == this.album &&
          other.durationMs == this.durationMs &&
          other.isrc == this.isrc &&
          other.year == this.year &&
          other.status == this.status &&
          other.videoId == this.videoId &&
          other.candidates == this.candidates &&
          other.trackId == this.trackId &&
          other.score == this.score &&
          other.note == this.note &&
          other.location == this.location);
}

class PlaylistImportItemsCompanion extends UpdateCompanion<PlaylistImportItem> {
  final Value<int> importId;
  final Value<int> rowIndex;
  final Value<String> title;
  final Value<String> artists;
  final Value<String?> album;
  final Value<int?> durationMs;
  final Value<String?> isrc;
  final Value<int?> year;
  final Value<int> status;
  final Value<String?> videoId;
  final Value<String?> candidates;
  final Value<int?> trackId;
  final Value<double?> score;
  final Value<String?> note;
  final Value<String?> location;
  final Value<int> rowid;
  const PlaylistImportItemsCompanion({
    this.importId = const Value.absent(),
    this.rowIndex = const Value.absent(),
    this.title = const Value.absent(),
    this.artists = const Value.absent(),
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.isrc = const Value.absent(),
    this.year = const Value.absent(),
    this.status = const Value.absent(),
    this.videoId = const Value.absent(),
    this.candidates = const Value.absent(),
    this.trackId = const Value.absent(),
    this.score = const Value.absent(),
    this.note = const Value.absent(),
    this.location = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaylistImportItemsCompanion.insert({
    required int importId,
    required int rowIndex,
    required String title,
    required String artists,
    this.album = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.isrc = const Value.absent(),
    this.year = const Value.absent(),
    this.status = const Value.absent(),
    this.videoId = const Value.absent(),
    this.candidates = const Value.absent(),
    this.trackId = const Value.absent(),
    this.score = const Value.absent(),
    this.note = const Value.absent(),
    this.location = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : importId = Value(importId),
       rowIndex = Value(rowIndex),
       title = Value(title),
       artists = Value(artists);
  static Insertable<PlaylistImportItem> custom({
    Expression<int>? importId,
    Expression<int>? rowIndex,
    Expression<String>? title,
    Expression<String>? artists,
    Expression<String>? album,
    Expression<int>? durationMs,
    Expression<String>? isrc,
    Expression<int>? year,
    Expression<int>? status,
    Expression<String>? videoId,
    Expression<String>? candidates,
    Expression<int>? trackId,
    Expression<double>? score,
    Expression<String>? note,
    Expression<String>? location,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (importId != null) 'import_id': importId,
      if (rowIndex != null) 'row_index': rowIndex,
      if (title != null) 'title': title,
      if (artists != null) 'artists': artists,
      if (album != null) 'album': album,
      if (durationMs != null) 'duration_ms': durationMs,
      if (isrc != null) 'isrc': isrc,
      if (year != null) 'year': year,
      if (status != null) 'status': status,
      if (videoId != null) 'video_id': videoId,
      if (candidates != null) 'candidates': candidates,
      if (trackId != null) 'track_id': trackId,
      if (score != null) 'score': score,
      if (note != null) 'note': note,
      if (location != null) 'location': location,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaylistImportItemsCompanion copyWith({
    Value<int>? importId,
    Value<int>? rowIndex,
    Value<String>? title,
    Value<String>? artists,
    Value<String?>? album,
    Value<int?>? durationMs,
    Value<String?>? isrc,
    Value<int?>? year,
    Value<int>? status,
    Value<String?>? videoId,
    Value<String?>? candidates,
    Value<int?>? trackId,
    Value<double?>? score,
    Value<String?>? note,
    Value<String?>? location,
    Value<int>? rowid,
  }) {
    return PlaylistImportItemsCompanion(
      importId: importId ?? this.importId,
      rowIndex: rowIndex ?? this.rowIndex,
      title: title ?? this.title,
      artists: artists ?? this.artists,
      album: album ?? this.album,
      durationMs: durationMs ?? this.durationMs,
      isrc: isrc ?? this.isrc,
      year: year ?? this.year,
      status: status ?? this.status,
      videoId: videoId ?? this.videoId,
      candidates: candidates ?? this.candidates,
      trackId: trackId ?? this.trackId,
      score: score ?? this.score,
      note: note ?? this.note,
      location: location ?? this.location,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (importId.present) {
      map['import_id'] = Variable<int>(importId.value);
    }
    if (rowIndex.present) {
      map['row_index'] = Variable<int>(rowIndex.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artists.present) {
      map['artists'] = Variable<String>(artists.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (isrc.present) {
      map['isrc'] = Variable<String>(isrc.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (videoId.present) {
      map['video_id'] = Variable<String>(videoId.value);
    }
    if (candidates.present) {
      map['candidates'] = Variable<String>(candidates.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (score.present) {
      map['score'] = Variable<double>(score.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaylistImportItemsCompanion(')
          ..write('importId: $importId, ')
          ..write('rowIndex: $rowIndex, ')
          ..write('title: $title, ')
          ..write('artists: $artists, ')
          ..write('album: $album, ')
          ..write('durationMs: $durationMs, ')
          ..write('isrc: $isrc, ')
          ..write('year: $year, ')
          ..write('status: $status, ')
          ..write('videoId: $videoId, ')
          ..write('candidates: $candidates, ')
          ..write('trackId: $trackId, ')
          ..write('score: $score, ')
          ..write('note: $note, ')
          ..write('location: $location, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaysTable extends Plays with TableInfo<$PlaysTable, Play> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
    'played_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _msPlayedMeta = const VerificationMeta(
    'msPlayed',
  );
  @override
  late final GeneratedColumn<int> msPlayed = GeneratedColumn<int>(
    'ms_played',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contextMeta = const VerificationMeta(
    'context',
  );
  @override
  late final GeneratedColumn<int> context = GeneratedColumn<int>(
    'context',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contextNameMeta = const VerificationMeta(
    'contextName',
  );
  @override
  late final GeneratedColumn<String> contextName = GeneratedColumn<String>(
    'context_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    trackId,
    playedAt,
    msPlayed,
    context,
    contextName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plays';
  @override
  VerificationContext validateIntegrity(
    Insertable<Play> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    if (data.containsKey('ms_played')) {
      context.handle(
        _msPlayedMeta,
        msPlayed.isAcceptableOrUnknown(data['ms_played']!, _msPlayedMeta),
      );
    }
    if (data.containsKey('context')) {
      context.handle(
        _contextMeta,
        this.context.isAcceptableOrUnknown(data['context']!, _contextMeta),
      );
    }
    if (data.containsKey('context_name')) {
      context.handle(
        _contextNameMeta,
        contextName.isAcceptableOrUnknown(
          data['context_name']!,
          _contextNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Play map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Play(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}played_at'],
      )!,
      msPlayed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ms_played'],
      )!,
      context: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}context'],
      ),
      contextName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}context_name'],
      ),
    );
  }

  @override
  $PlaysTable createAlias(String alias) {
    return $PlaysTable(attachedDatabase, alias);
  }
}

class Play extends DataClass implements Insertable<Play> {
  final int id;
  final int trackId;

  /// Epoch ms of the moment it counted as played.
  final int playedAt;

  /// Time really spent playing it (seeks do not count); grows until the
  /// track changes.
  final int msPlayed;

  /// `PlayContextKind.index` of where it was started from, if known.
  final int? context;
  final String? contextName;
  const Play({
    required this.id,
    required this.trackId,
    required this.playedAt,
    required this.msPlayed,
    this.context,
    this.contextName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_id'] = Variable<int>(trackId);
    map['played_at'] = Variable<int>(playedAt);
    map['ms_played'] = Variable<int>(msPlayed);
    if (!nullToAbsent || context != null) {
      map['context'] = Variable<int>(context);
    }
    if (!nullToAbsent || contextName != null) {
      map['context_name'] = Variable<String>(contextName);
    }
    return map;
  }

  PlaysCompanion toCompanion(bool nullToAbsent) {
    return PlaysCompanion(
      id: Value(id),
      trackId: Value(trackId),
      playedAt: Value(playedAt),
      msPlayed: Value(msPlayed),
      context: context == null && nullToAbsent
          ? const Value.absent()
          : Value(context),
      contextName: contextName == null && nullToAbsent
          ? const Value.absent()
          : Value(contextName),
    );
  }

  factory Play.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Play(
      id: serializer.fromJson<int>(json['id']),
      trackId: serializer.fromJson<int>(json['trackId']),
      playedAt: serializer.fromJson<int>(json['playedAt']),
      msPlayed: serializer.fromJson<int>(json['msPlayed']),
      context: serializer.fromJson<int?>(json['context']),
      contextName: serializer.fromJson<String?>(json['contextName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackId': serializer.toJson<int>(trackId),
      'playedAt': serializer.toJson<int>(playedAt),
      'msPlayed': serializer.toJson<int>(msPlayed),
      'context': serializer.toJson<int?>(context),
      'contextName': serializer.toJson<String?>(contextName),
    };
  }

  Play copyWith({
    int? id,
    int? trackId,
    int? playedAt,
    int? msPlayed,
    Value<int?> context = const Value.absent(),
    Value<String?> contextName = const Value.absent(),
  }) => Play(
    id: id ?? this.id,
    trackId: trackId ?? this.trackId,
    playedAt: playedAt ?? this.playedAt,
    msPlayed: msPlayed ?? this.msPlayed,
    context: context.present ? context.value : this.context,
    contextName: contextName.present ? contextName.value : this.contextName,
  );
  Play copyWithCompanion(PlaysCompanion data) {
    return Play(
      id: data.id.present ? data.id.value : this.id,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
      msPlayed: data.msPlayed.present ? data.msPlayed.value : this.msPlayed,
      context: data.context.present ? data.context.value : this.context,
      contextName: data.contextName.present
          ? data.contextName.value
          : this.contextName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Play(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('msPlayed: $msPlayed, ')
          ..write('context: $context, ')
          ..write('contextName: $contextName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, trackId, playedAt, msPlayed, context, contextName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Play &&
          other.id == this.id &&
          other.trackId == this.trackId &&
          other.playedAt == this.playedAt &&
          other.msPlayed == this.msPlayed &&
          other.context == this.context &&
          other.contextName == this.contextName);
}

class PlaysCompanion extends UpdateCompanion<Play> {
  final Value<int> id;
  final Value<int> trackId;
  final Value<int> playedAt;
  final Value<int> msPlayed;
  final Value<int?> context;
  final Value<String?> contextName;
  const PlaysCompanion({
    this.id = const Value.absent(),
    this.trackId = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.msPlayed = const Value.absent(),
    this.context = const Value.absent(),
    this.contextName = const Value.absent(),
  });
  PlaysCompanion.insert({
    this.id = const Value.absent(),
    required int trackId,
    required int playedAt,
    this.msPlayed = const Value.absent(),
    this.context = const Value.absent(),
    this.contextName = const Value.absent(),
  }) : trackId = Value(trackId),
       playedAt = Value(playedAt);
  static Insertable<Play> custom({
    Expression<int>? id,
    Expression<int>? trackId,
    Expression<int>? playedAt,
    Expression<int>? msPlayed,
    Expression<int>? context,
    Expression<String>? contextName,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackId != null) 'track_id': trackId,
      if (playedAt != null) 'played_at': playedAt,
      if (msPlayed != null) 'ms_played': msPlayed,
      if (context != null) 'context': context,
      if (contextName != null) 'context_name': contextName,
    });
  }

  PlaysCompanion copyWith({
    Value<int>? id,
    Value<int>? trackId,
    Value<int>? playedAt,
    Value<int>? msPlayed,
    Value<int?>? context,
    Value<String?>? contextName,
  }) {
    return PlaysCompanion(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      playedAt: playedAt ?? this.playedAt,
      msPlayed: msPlayed ?? this.msPlayed,
      context: context ?? this.context,
      contextName: contextName ?? this.contextName,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    if (msPlayed.present) {
      map['ms_played'] = Variable<int>(msPlayed.value);
    }
    if (context.present) {
      map['context'] = Variable<int>(context.value);
    }
    if (contextName.present) {
      map['context_name'] = Variable<String>(contextName.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaysCompanion(')
          ..write('id: $id, ')
          ..write('trackId: $trackId, ')
          ..write('playedAt: $playedAt, ')
          ..write('msPlayed: $msPlayed, ')
          ..write('context: $context, ')
          ..write('contextName: $contextName')
          ..write(')'))
        .toString();
  }
}

class $SmartPlaylistsTable extends SmartPlaylists
    with TableInfo<$SmartPlaylistsTable, SmartPlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SmartPlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rulesMeta = const VerificationMeta('rules');
  @override
  late final GeneratedColumn<String> rules = GeneratedColumn<String>(
    'rules',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumn<String> sort = GeneratedColumn<String>(
    'sort',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _limitCountMeta = const VerificationMeta(
    'limitCount',
  );
  @override
  late final GeneratedColumn<int> limitCount = GeneratedColumn<int>(
    'limit_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    rules,
    sort,
    limitCount,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'smart_playlists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SmartPlaylist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('rules')) {
      context.handle(
        _rulesMeta,
        rules.isAcceptableOrUnknown(data['rules']!, _rulesMeta),
      );
    } else if (isInserting) {
      context.missing(_rulesMeta);
    }
    if (data.containsKey('sort')) {
      context.handle(
        _sortMeta,
        sort.isAcceptableOrUnknown(data['sort']!, _sortMeta),
      );
    }
    if (data.containsKey('limit_count')) {
      context.handle(
        _limitCountMeta,
        limitCount.isAcceptableOrUnknown(data['limit_count']!, _limitCountMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SmartPlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SmartPlaylist(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      rules: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rules'],
      )!,
      sort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sort'],
      ),
      limitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}limit_count'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SmartPlaylistsTable createAlias(String alias) {
    return $SmartPlaylistsTable(attachedDatabase, alias);
  }
}

class SmartPlaylist extends DataClass implements Insertable<SmartPlaylist> {
  final int id;
  final String name;
  final String rules;

  /// `SortOption` name, or `random`; null = the default order.
  final String? sort;
  final int? limitCount;
  final int createdAt;
  const SmartPlaylist({
    required this.id,
    required this.name,
    required this.rules,
    this.sort,
    this.limitCount,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['rules'] = Variable<String>(rules);
    if (!nullToAbsent || sort != null) {
      map['sort'] = Variable<String>(sort);
    }
    if (!nullToAbsent || limitCount != null) {
      map['limit_count'] = Variable<int>(limitCount);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SmartPlaylistsCompanion toCompanion(bool nullToAbsent) {
    return SmartPlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      rules: Value(rules),
      sort: sort == null && nullToAbsent ? const Value.absent() : Value(sort),
      limitCount: limitCount == null && nullToAbsent
          ? const Value.absent()
          : Value(limitCount),
      createdAt: Value(createdAt),
    );
  }

  factory SmartPlaylist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SmartPlaylist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      rules: serializer.fromJson<String>(json['rules']),
      sort: serializer.fromJson<String?>(json['sort']),
      limitCount: serializer.fromJson<int?>(json['limitCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'rules': serializer.toJson<String>(rules),
      'sort': serializer.toJson<String?>(sort),
      'limitCount': serializer.toJson<int?>(limitCount),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SmartPlaylist copyWith({
    int? id,
    String? name,
    String? rules,
    Value<String?> sort = const Value.absent(),
    Value<int?> limitCount = const Value.absent(),
    int? createdAt,
  }) => SmartPlaylist(
    id: id ?? this.id,
    name: name ?? this.name,
    rules: rules ?? this.rules,
    sort: sort.present ? sort.value : this.sort,
    limitCount: limitCount.present ? limitCount.value : this.limitCount,
    createdAt: createdAt ?? this.createdAt,
  );
  SmartPlaylist copyWithCompanion(SmartPlaylistsCompanion data) {
    return SmartPlaylist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      rules: data.rules.present ? data.rules.value : this.rules,
      sort: data.sort.present ? data.sort.value : this.sort,
      limitCount: data.limitCount.present
          ? data.limitCount.value
          : this.limitCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SmartPlaylist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rules: $rules, ')
          ..write('sort: $sort, ')
          ..write('limitCount: $limitCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, rules, sort, limitCount, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SmartPlaylist &&
          other.id == this.id &&
          other.name == this.name &&
          other.rules == this.rules &&
          other.sort == this.sort &&
          other.limitCount == this.limitCount &&
          other.createdAt == this.createdAt);
}

class SmartPlaylistsCompanion extends UpdateCompanion<SmartPlaylist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> rules;
  final Value<String?> sort;
  final Value<int?> limitCount;
  final Value<int> createdAt;
  const SmartPlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rules = const Value.absent(),
    this.sort = const Value.absent(),
    this.limitCount = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SmartPlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String rules,
    this.sort = const Value.absent(),
    this.limitCount = const Value.absent(),
    required int createdAt,
  }) : name = Value(name),
       rules = Value(rules),
       createdAt = Value(createdAt);
  static Insertable<SmartPlaylist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? rules,
    Expression<String>? sort,
    Expression<int>? limitCount,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rules != null) 'rules': rules,
      if (sort != null) 'sort': sort,
      if (limitCount != null) 'limit_count': limitCount,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SmartPlaylistsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? rules,
    Value<String?>? sort,
    Value<int?>? limitCount,
    Value<int>? createdAt,
  }) {
    return SmartPlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
      sort: sort ?? this.sort,
      limitCount: limitCount ?? this.limitCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (rules.present) {
      map['rules'] = Variable<String>(rules.value);
    }
    if (sort.present) {
      map['sort'] = Variable<String>(sort.value);
    }
    if (limitCount.present) {
      map['limit_count'] = Variable<int>(limitCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SmartPlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rules: $rules, ')
          ..write('sort: $sort, ')
          ..write('limitCount: $limitCount, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UserTagsTable extends UserTags with TableInfo<$UserTagsTable, UserTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE COLLATE NOCASE',
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}color'],
      ),
    );
  }

  @override
  $UserTagsTable createAlias(String alias) {
    return $UserTagsTable(attachedDatabase, alias);
  }
}

class UserTag extends DataClass implements Insertable<UserTag> {
  final int id;
  final String name;

  /// Index of one of the eight accent tokens; null = none.
  final int? color;
  const UserTag({required this.id, required this.name, this.color});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    return map;
  }

  UserTagsCompanion toCompanion(bool nullToAbsent) {
    return UserTagsCompanion(
      id: Value(id),
      name: Value(name),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
    );
  }

  factory UserTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserTag(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<int?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<int?>(color),
    };
  }

  UserTag copyWith({
    int? id,
    String? name,
    Value<int?> color = const Value.absent(),
  }) => UserTag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color.present ? color.value : this.color,
  );
  UserTag copyWithCompanion(UserTagsCompanion data) {
    return UserTag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserTag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserTag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color);
}

class UserTagsCompanion extends UpdateCompanion<UserTag> {
  final Value<int> id;
  final Value<String> name;
  final Value<int?> color;
  const UserTagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
  });
  UserTagsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.color = const Value.absent(),
  }) : name = Value(name);
  static Insertable<UserTag> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? color,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
    });
  }

  UserTagsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<int?>? color,
  }) {
    return UserTagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserTagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }
}

class $TrackTagsTable extends TrackTags
    with TableInfo<$TrackTagsTable, TrackTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<int> tagId = GeneratedColumn<int>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId, tagId};
  @override
  TrackTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackTag(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TrackTagsTable createAlias(String alias) {
    return $TrackTagsTable(attachedDatabase, alias);
  }
}

class TrackTag extends DataClass implements Insertable<TrackTag> {
  final int trackId;
  final int tagId;
  const TrackTag({required this.trackId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['tag_id'] = Variable<int>(tagId);
    return map;
  }

  TrackTagsCompanion toCompanion(bool nullToAbsent) {
    return TrackTagsCompanion(trackId: Value(trackId), tagId: Value(tagId));
  }

  factory TrackTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackTag(
      trackId: serializer.fromJson<int>(json['trackId']),
      tagId: serializer.fromJson<int>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'tagId': serializer.toJson<int>(tagId),
    };
  }

  TrackTag copyWith({int? trackId, int? tagId}) =>
      TrackTag(trackId: trackId ?? this.trackId, tagId: tagId ?? this.tagId);
  TrackTag copyWithCompanion(TrackTagsCompanion data) {
    return TrackTag(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackTag(')
          ..write('trackId: $trackId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackTag &&
          other.trackId == this.trackId &&
          other.tagId == this.tagId);
}

class TrackTagsCompanion extends UpdateCompanion<TrackTag> {
  final Value<int> trackId;
  final Value<int> tagId;
  final Value<int> rowid;
  const TrackTagsCompanion({
    this.trackId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackTagsCompanion.insert({
    required int trackId,
    required int tagId,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       tagId = Value(tagId);
  static Insertable<TrackTag> custom({
    Expression<int>? trackId,
    Expression<int>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackTagsCompanion copyWith({
    Value<int>? trackId,
    Value<int>? tagId,
    Value<int>? rowid,
  }) {
    return TrackTagsCompanion(
      trackId: trackId ?? this.trackId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<int>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackTagsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PodcastsTable extends Podcasts with TableInfo<$PodcastsTable, Podcast> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _feedUrlMeta = const VerificationMeta(
    'feedUrl',
  );
  @override
  late final GeneratedColumn<String> feedUrl = GeneratedColumn<String>(
    'feed_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageUrlMeta = const VerificationMeta(
    'imageUrl',
  );
  @override
  late final GeneratedColumn<String> imageUrl = GeneratedColumn<String>(
    'image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _coverKeyMeta = const VerificationMeta(
    'coverKey',
  );
  @override
  late final GeneratedColumn<String> coverKey = GeneratedColumn<String>(
    'cover_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastCheckedAtMeta = const VerificationMeta(
    'lastCheckedAt',
  );
  @override
  late final GeneratedColumn<int> lastCheckedAt = GeneratedColumn<int>(
    'last_checked_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoDeleteDaysMeta = const VerificationMeta(
    'autoDeleteDays',
  );
  @override
  late final GeneratedColumn<int> autoDeleteDays = GeneratedColumn<int>(
    'auto_delete_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    feedUrl,
    title,
    author,
    imageUrl,
    coverKey,
    language,
    lastCheckedAt,
    autoDeleteDays,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcasts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Podcast> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('feed_url')) {
      context.handle(
        _feedUrlMeta,
        feedUrl.isAcceptableOrUnknown(data['feed_url']!, _feedUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_feedUrlMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('author')) {
      context.handle(
        _authorMeta,
        author.isAcceptableOrUnknown(data['author']!, _authorMeta),
      );
    }
    if (data.containsKey('image_url')) {
      context.handle(
        _imageUrlMeta,
        imageUrl.isAcceptableOrUnknown(data['image_url']!, _imageUrlMeta),
      );
    }
    if (data.containsKey('cover_key')) {
      context.handle(
        _coverKeyMeta,
        coverKey.isAcceptableOrUnknown(data['cover_key']!, _coverKeyMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('last_checked_at')) {
      context.handle(
        _lastCheckedAtMeta,
        lastCheckedAt.isAcceptableOrUnknown(
          data['last_checked_at']!,
          _lastCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('auto_delete_days')) {
      context.handle(
        _autoDeleteDaysMeta,
        autoDeleteDays.isAcceptableOrUnknown(
          data['auto_delete_days']!,
          _autoDeleteDaysMeta,
        ),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Podcast map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Podcast(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      feedUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}feed_url'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      author: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}author'],
      ),
      imageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_url'],
      ),
      coverKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_key'],
      ),
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      ),
      lastCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_checked_at'],
      ),
      autoDeleteDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_delete_days'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $PodcastsTable createAlias(String alias) {
    return $PodcastsTable(attachedDatabase, alias);
  }
}

class Podcast extends DataClass implements Insertable<Podcast> {
  final int id;
  final String feedUrl;
  final String title;
  final String? author;

  /// Where the cover comes from (the feed's image).
  final String? imageUrl;

  /// File name inside the covers folder, once downloaded.
  final String? coverKey;
  final String? language;

  /// Epoch ms of the last successful refresh; null = never.
  final int? lastCheckedAt;

  /// Delete played episodes after this many days; null = never.
  final int? autoDeleteDays;
  final int addedAt;
  const Podcast({
    required this.id,
    required this.feedUrl,
    required this.title,
    this.author,
    this.imageUrl,
    this.coverKey,
    this.language,
    this.lastCheckedAt,
    this.autoDeleteDays,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['feed_url'] = Variable<String>(feedUrl);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || imageUrl != null) {
      map['image_url'] = Variable<String>(imageUrl);
    }
    if (!nullToAbsent || coverKey != null) {
      map['cover_key'] = Variable<String>(coverKey);
    }
    if (!nullToAbsent || language != null) {
      map['language'] = Variable<String>(language);
    }
    if (!nullToAbsent || lastCheckedAt != null) {
      map['last_checked_at'] = Variable<int>(lastCheckedAt);
    }
    if (!nullToAbsent || autoDeleteDays != null) {
      map['auto_delete_days'] = Variable<int>(autoDeleteDays);
    }
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  PodcastsCompanion toCompanion(bool nullToAbsent) {
    return PodcastsCompanion(
      id: Value(id),
      feedUrl: Value(feedUrl),
      title: Value(title),
      author: author == null && nullToAbsent
          ? const Value.absent()
          : Value(author),
      imageUrl: imageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(imageUrl),
      coverKey: coverKey == null && nullToAbsent
          ? const Value.absent()
          : Value(coverKey),
      language: language == null && nullToAbsent
          ? const Value.absent()
          : Value(language),
      lastCheckedAt: lastCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckedAt),
      autoDeleteDays: autoDeleteDays == null && nullToAbsent
          ? const Value.absent()
          : Value(autoDeleteDays),
      addedAt: Value(addedAt),
    );
  }

  factory Podcast.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Podcast(
      id: serializer.fromJson<int>(json['id']),
      feedUrl: serializer.fromJson<String>(json['feedUrl']),
      title: serializer.fromJson<String>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      imageUrl: serializer.fromJson<String?>(json['imageUrl']),
      coverKey: serializer.fromJson<String?>(json['coverKey']),
      language: serializer.fromJson<String?>(json['language']),
      lastCheckedAt: serializer.fromJson<int?>(json['lastCheckedAt']),
      autoDeleteDays: serializer.fromJson<int?>(json['autoDeleteDays']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'feedUrl': serializer.toJson<String>(feedUrl),
      'title': serializer.toJson<String>(title),
      'author': serializer.toJson<String?>(author),
      'imageUrl': serializer.toJson<String?>(imageUrl),
      'coverKey': serializer.toJson<String?>(coverKey),
      'language': serializer.toJson<String?>(language),
      'lastCheckedAt': serializer.toJson<int?>(lastCheckedAt),
      'autoDeleteDays': serializer.toJson<int?>(autoDeleteDays),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  Podcast copyWith({
    int? id,
    String? feedUrl,
    String? title,
    Value<String?> author = const Value.absent(),
    Value<String?> imageUrl = const Value.absent(),
    Value<String?> coverKey = const Value.absent(),
    Value<String?> language = const Value.absent(),
    Value<int?> lastCheckedAt = const Value.absent(),
    Value<int?> autoDeleteDays = const Value.absent(),
    int? addedAt,
  }) => Podcast(
    id: id ?? this.id,
    feedUrl: feedUrl ?? this.feedUrl,
    title: title ?? this.title,
    author: author.present ? author.value : this.author,
    imageUrl: imageUrl.present ? imageUrl.value : this.imageUrl,
    coverKey: coverKey.present ? coverKey.value : this.coverKey,
    language: language.present ? language.value : this.language,
    lastCheckedAt: lastCheckedAt.present
        ? lastCheckedAt.value
        : this.lastCheckedAt,
    autoDeleteDays: autoDeleteDays.present
        ? autoDeleteDays.value
        : this.autoDeleteDays,
    addedAt: addedAt ?? this.addedAt,
  );
  Podcast copyWithCompanion(PodcastsCompanion data) {
    return Podcast(
      id: data.id.present ? data.id.value : this.id,
      feedUrl: data.feedUrl.present ? data.feedUrl.value : this.feedUrl,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      imageUrl: data.imageUrl.present ? data.imageUrl.value : this.imageUrl,
      coverKey: data.coverKey.present ? data.coverKey.value : this.coverKey,
      language: data.language.present ? data.language.value : this.language,
      lastCheckedAt: data.lastCheckedAt.present
          ? data.lastCheckedAt.value
          : this.lastCheckedAt,
      autoDeleteDays: data.autoDeleteDays.present
          ? data.autoDeleteDays.value
          : this.autoDeleteDays,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Podcast(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('coverKey: $coverKey, ')
          ..write('language: $language, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('autoDeleteDays: $autoDeleteDays, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    feedUrl,
    title,
    author,
    imageUrl,
    coverKey,
    language,
    lastCheckedAt,
    autoDeleteDays,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Podcast &&
          other.id == this.id &&
          other.feedUrl == this.feedUrl &&
          other.title == this.title &&
          other.author == this.author &&
          other.imageUrl == this.imageUrl &&
          other.coverKey == this.coverKey &&
          other.language == this.language &&
          other.lastCheckedAt == this.lastCheckedAt &&
          other.autoDeleteDays == this.autoDeleteDays &&
          other.addedAt == this.addedAt);
}

class PodcastsCompanion extends UpdateCompanion<Podcast> {
  final Value<int> id;
  final Value<String> feedUrl;
  final Value<String> title;
  final Value<String?> author;
  final Value<String?> imageUrl;
  final Value<String?> coverKey;
  final Value<String?> language;
  final Value<int?> lastCheckedAt;
  final Value<int?> autoDeleteDays;
  final Value<int> addedAt;
  const PodcastsCompanion({
    this.id = const Value.absent(),
    this.feedUrl = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.coverKey = const Value.absent(),
    this.language = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.autoDeleteDays = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  PodcastsCompanion.insert({
    this.id = const Value.absent(),
    required String feedUrl,
    required String title,
    this.author = const Value.absent(),
    this.imageUrl = const Value.absent(),
    this.coverKey = const Value.absent(),
    this.language = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.autoDeleteDays = const Value.absent(),
    required int addedAt,
  }) : feedUrl = Value(feedUrl),
       title = Value(title),
       addedAt = Value(addedAt);
  static Insertable<Podcast> custom({
    Expression<int>? id,
    Expression<String>? feedUrl,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? imageUrl,
    Expression<String>? coverKey,
    Expression<String>? language,
    Expression<int>? lastCheckedAt,
    Expression<int>? autoDeleteDays,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (feedUrl != null) 'feed_url': feedUrl,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (imageUrl != null) 'image_url': imageUrl,
      if (coverKey != null) 'cover_key': coverKey,
      if (language != null) 'language': language,
      if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
      if (autoDeleteDays != null) 'auto_delete_days': autoDeleteDays,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  PodcastsCompanion copyWith({
    Value<int>? id,
    Value<String>? feedUrl,
    Value<String>? title,
    Value<String?>? author,
    Value<String?>? imageUrl,
    Value<String?>? coverKey,
    Value<String?>? language,
    Value<int?>? lastCheckedAt,
    Value<int?>? autoDeleteDays,
    Value<int>? addedAt,
  }) {
    return PodcastsCompanion(
      id: id ?? this.id,
      feedUrl: feedUrl ?? this.feedUrl,
      title: title ?? this.title,
      author: author ?? this.author,
      imageUrl: imageUrl ?? this.imageUrl,
      coverKey: coverKey ?? this.coverKey,
      language: language ?? this.language,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      autoDeleteDays: autoDeleteDays ?? this.autoDeleteDays,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (feedUrl.present) {
      map['feed_url'] = Variable<String>(feedUrl.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (imageUrl.present) {
      map['image_url'] = Variable<String>(imageUrl.value);
    }
    if (coverKey.present) {
      map['cover_key'] = Variable<String>(coverKey.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (lastCheckedAt.present) {
      map['last_checked_at'] = Variable<int>(lastCheckedAt.value);
    }
    if (autoDeleteDays.present) {
      map['auto_delete_days'] = Variable<int>(autoDeleteDays.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PodcastsCompanion(')
          ..write('id: $id, ')
          ..write('feedUrl: $feedUrl, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('imageUrl: $imageUrl, ')
          ..write('coverKey: $coverKey, ')
          ..write('language: $language, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('autoDeleteDays: $autoDeleteDays, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $PodcastEpisodesTable extends PodcastEpisodes
    with TableInfo<$PodcastEpisodesTable, PodcastEpisode> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PodcastEpisodesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _podcastIdMeta = const VerificationMeta(
    'podcastId',
  );
  @override
  late final GeneratedColumn<int> podcastId = GeneratedColumn<int>(
    'podcast_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES podcasts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _guidMeta = const VerificationMeta('guid');
  @override
  late final GeneratedColumn<String> guid = GeneratedColumn<String>(
    'guid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _publishedAtMeta = const VerificationMeta(
    'publishedAt',
  );
  @override
  late final GeneratedColumn<int> publishedAt = GeneratedColumn<int>(
    'published_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _audioUrlMeta = const VerificationMeta(
    'audioUrl',
  );
  @override
  late final GeneratedColumn<String> audioUrl = GeneratedColumn<String>(
    'audio_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _playedMeta = const VerificationMeta('played');
  @override
  late final GeneratedColumn<bool> played = GeneratedColumn<bool>(
    'played',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("played" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _playedAtMeta = const VerificationMeta(
    'playedAt',
  );
  @override
  late final GeneratedColumn<int> playedAt = GeneratedColumn<int>(
    'played_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    podcastId,
    guid,
    title,
    publishedAt,
    durationMs,
    audioUrl,
    mimeType,
    sizeBytes,
    description,
    trackId,
    played,
    playedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'podcast_episodes';
  @override
  VerificationContext validateIntegrity(
    Insertable<PodcastEpisode> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('podcast_id')) {
      context.handle(
        _podcastIdMeta,
        podcastId.isAcceptableOrUnknown(data['podcast_id']!, _podcastIdMeta),
      );
    } else if (isInserting) {
      context.missing(_podcastIdMeta);
    }
    if (data.containsKey('guid')) {
      context.handle(
        _guidMeta,
        guid.isAcceptableOrUnknown(data['guid']!, _guidMeta),
      );
    } else if (isInserting) {
      context.missing(_guidMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('published_at')) {
      context.handle(
        _publishedAtMeta,
        publishedAt.isAcceptableOrUnknown(
          data['published_at']!,
          _publishedAtMeta,
        ),
      );
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('audio_url')) {
      context.handle(
        _audioUrlMeta,
        audioUrl.isAcceptableOrUnknown(data['audio_url']!, _audioUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_audioUrlMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('played')) {
      context.handle(
        _playedMeta,
        played.isAcceptableOrUnknown(data['played']!, _playedMeta),
      );
    }
    if (data.containsKey('played_at')) {
      context.handle(
        _playedAtMeta,
        playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {podcastId, guid},
  ];
  @override
  PodcastEpisode map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PodcastEpisode(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      podcastId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}podcast_id'],
      )!,
      guid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}guid'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      publishedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}published_at'],
      ),
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      audioUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_url'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      ),
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      ),
      played: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}played'],
      )!,
      playedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}played_at'],
      ),
    );
  }

  @override
  $PodcastEpisodesTable createAlias(String alias) {
    return $PodcastEpisodesTable(attachedDatabase, alias);
  }
}

class PodcastEpisode extends DataClass implements Insertable<PodcastEpisode> {
  final int id;
  final int podcastId;
  final String guid;
  final String title;
  final int? publishedAt;
  final int? durationMs;
  final String audioUrl;
  final String? mimeType;
  final int? sizeBytes;
  final String? description;
  final int? trackId;
  final bool played;
  final int? playedAt;
  const PodcastEpisode({
    required this.id,
    required this.podcastId,
    required this.guid,
    required this.title,
    this.publishedAt,
    this.durationMs,
    required this.audioUrl,
    this.mimeType,
    this.sizeBytes,
    this.description,
    this.trackId,
    required this.played,
    this.playedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['podcast_id'] = Variable<int>(podcastId);
    map['guid'] = Variable<String>(guid);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || publishedAt != null) {
      map['published_at'] = Variable<int>(publishedAt);
    }
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['audio_url'] = Variable<String>(audioUrl);
    if (!nullToAbsent || mimeType != null) {
      map['mime_type'] = Variable<String>(mimeType);
    }
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || trackId != null) {
      map['track_id'] = Variable<int>(trackId);
    }
    map['played'] = Variable<bool>(played);
    if (!nullToAbsent || playedAt != null) {
      map['played_at'] = Variable<int>(playedAt);
    }
    return map;
  }

  PodcastEpisodesCompanion toCompanion(bool nullToAbsent) {
    return PodcastEpisodesCompanion(
      id: Value(id),
      podcastId: Value(podcastId),
      guid: Value(guid),
      title: Value(title),
      publishedAt: publishedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(publishedAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      audioUrl: Value(audioUrl),
      mimeType: mimeType == null && nullToAbsent
          ? const Value.absent()
          : Value(mimeType),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      trackId: trackId == null && nullToAbsent
          ? const Value.absent()
          : Value(trackId),
      played: Value(played),
      playedAt: playedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(playedAt),
    );
  }

  factory PodcastEpisode.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PodcastEpisode(
      id: serializer.fromJson<int>(json['id']),
      podcastId: serializer.fromJson<int>(json['podcastId']),
      guid: serializer.fromJson<String>(json['guid']),
      title: serializer.fromJson<String>(json['title']),
      publishedAt: serializer.fromJson<int?>(json['publishedAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      audioUrl: serializer.fromJson<String>(json['audioUrl']),
      mimeType: serializer.fromJson<String?>(json['mimeType']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      description: serializer.fromJson<String?>(json['description']),
      trackId: serializer.fromJson<int?>(json['trackId']),
      played: serializer.fromJson<bool>(json['played']),
      playedAt: serializer.fromJson<int?>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'podcastId': serializer.toJson<int>(podcastId),
      'guid': serializer.toJson<String>(guid),
      'title': serializer.toJson<String>(title),
      'publishedAt': serializer.toJson<int?>(publishedAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'audioUrl': serializer.toJson<String>(audioUrl),
      'mimeType': serializer.toJson<String?>(mimeType),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'description': serializer.toJson<String?>(description),
      'trackId': serializer.toJson<int?>(trackId),
      'played': serializer.toJson<bool>(played),
      'playedAt': serializer.toJson<int?>(playedAt),
    };
  }

  PodcastEpisode copyWith({
    int? id,
    int? podcastId,
    String? guid,
    String? title,
    Value<int?> publishedAt = const Value.absent(),
    Value<int?> durationMs = const Value.absent(),
    String? audioUrl,
    Value<String?> mimeType = const Value.absent(),
    Value<int?> sizeBytes = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<int?> trackId = const Value.absent(),
    bool? played,
    Value<int?> playedAt = const Value.absent(),
  }) => PodcastEpisode(
    id: id ?? this.id,
    podcastId: podcastId ?? this.podcastId,
    guid: guid ?? this.guid,
    title: title ?? this.title,
    publishedAt: publishedAt.present ? publishedAt.value : this.publishedAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    audioUrl: audioUrl ?? this.audioUrl,
    mimeType: mimeType.present ? mimeType.value : this.mimeType,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    description: description.present ? description.value : this.description,
    trackId: trackId.present ? trackId.value : this.trackId,
    played: played ?? this.played,
    playedAt: playedAt.present ? playedAt.value : this.playedAt,
  );
  PodcastEpisode copyWithCompanion(PodcastEpisodesCompanion data) {
    return PodcastEpisode(
      id: data.id.present ? data.id.value : this.id,
      podcastId: data.podcastId.present ? data.podcastId.value : this.podcastId,
      guid: data.guid.present ? data.guid.value : this.guid,
      title: data.title.present ? data.title.value : this.title,
      publishedAt: data.publishedAt.present
          ? data.publishedAt.value
          : this.publishedAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      audioUrl: data.audioUrl.present ? data.audioUrl.value : this.audioUrl,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      description: data.description.present
          ? data.description.value
          : this.description,
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      played: data.played.present ? data.played.value : this.played,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PodcastEpisode(')
          ..write('id: $id, ')
          ..write('podcastId: $podcastId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('description: $description, ')
          ..write('trackId: $trackId, ')
          ..write('played: $played, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    podcastId,
    guid,
    title,
    publishedAt,
    durationMs,
    audioUrl,
    mimeType,
    sizeBytes,
    description,
    trackId,
    played,
    playedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PodcastEpisode &&
          other.id == this.id &&
          other.podcastId == this.podcastId &&
          other.guid == this.guid &&
          other.title == this.title &&
          other.publishedAt == this.publishedAt &&
          other.durationMs == this.durationMs &&
          other.audioUrl == this.audioUrl &&
          other.mimeType == this.mimeType &&
          other.sizeBytes == this.sizeBytes &&
          other.description == this.description &&
          other.trackId == this.trackId &&
          other.played == this.played &&
          other.playedAt == this.playedAt);
}

class PodcastEpisodesCompanion extends UpdateCompanion<PodcastEpisode> {
  final Value<int> id;
  final Value<int> podcastId;
  final Value<String> guid;
  final Value<String> title;
  final Value<int?> publishedAt;
  final Value<int?> durationMs;
  final Value<String> audioUrl;
  final Value<String?> mimeType;
  final Value<int?> sizeBytes;
  final Value<String?> description;
  final Value<int?> trackId;
  final Value<bool> played;
  final Value<int?> playedAt;
  const PodcastEpisodesCompanion({
    this.id = const Value.absent(),
    this.podcastId = const Value.absent(),
    this.guid = const Value.absent(),
    this.title = const Value.absent(),
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.audioUrl = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.description = const Value.absent(),
    this.trackId = const Value.absent(),
    this.played = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  PodcastEpisodesCompanion.insert({
    this.id = const Value.absent(),
    required int podcastId,
    required String guid,
    required String title,
    this.publishedAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    required String audioUrl,
    this.mimeType = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.description = const Value.absent(),
    this.trackId = const Value.absent(),
    this.played = const Value.absent(),
    this.playedAt = const Value.absent(),
  }) : podcastId = Value(podcastId),
       guid = Value(guid),
       title = Value(title),
       audioUrl = Value(audioUrl);
  static Insertable<PodcastEpisode> custom({
    Expression<int>? id,
    Expression<int>? podcastId,
    Expression<String>? guid,
    Expression<String>? title,
    Expression<int>? publishedAt,
    Expression<int>? durationMs,
    Expression<String>? audioUrl,
    Expression<String>? mimeType,
    Expression<int>? sizeBytes,
    Expression<String>? description,
    Expression<int>? trackId,
    Expression<bool>? played,
    Expression<int>? playedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (podcastId != null) 'podcast_id': podcastId,
      if (guid != null) 'guid': guid,
      if (title != null) 'title': title,
      if (publishedAt != null) 'published_at': publishedAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (mimeType != null) 'mime_type': mimeType,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (description != null) 'description': description,
      if (trackId != null) 'track_id': trackId,
      if (played != null) 'played': played,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  PodcastEpisodesCompanion copyWith({
    Value<int>? id,
    Value<int>? podcastId,
    Value<String>? guid,
    Value<String>? title,
    Value<int?>? publishedAt,
    Value<int?>? durationMs,
    Value<String>? audioUrl,
    Value<String?>? mimeType,
    Value<int?>? sizeBytes,
    Value<String?>? description,
    Value<int?>? trackId,
    Value<bool>? played,
    Value<int?>? playedAt,
  }) {
    return PodcastEpisodesCompanion(
      id: id ?? this.id,
      podcastId: podcastId ?? this.podcastId,
      guid: guid ?? this.guid,
      title: title ?? this.title,
      publishedAt: publishedAt ?? this.publishedAt,
      durationMs: durationMs ?? this.durationMs,
      audioUrl: audioUrl ?? this.audioUrl,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      description: description ?? this.description,
      trackId: trackId ?? this.trackId,
      played: played ?? this.played,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (podcastId.present) {
      map['podcast_id'] = Variable<int>(podcastId.value);
    }
    if (guid.present) {
      map['guid'] = Variable<String>(guid.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (publishedAt.present) {
      map['published_at'] = Variable<int>(publishedAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (audioUrl.present) {
      map['audio_url'] = Variable<String>(audioUrl.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (played.present) {
      map['played'] = Variable<bool>(played.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<int>(playedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PodcastEpisodesCompanion(')
          ..write('id: $id, ')
          ..write('podcastId: $podcastId, ')
          ..write('guid: $guid, ')
          ..write('title: $title, ')
          ..write('publishedAt: $publishedAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('audioUrl: $audioUrl, ')
          ..write('mimeType: $mimeType, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('description: $description, ')
          ..write('trackId: $trackId, ')
          ..write('played: $played, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }
}

class $ArtistInfosTable extends ArtistInfos
    with TableInfo<$ArtistInfosTable, ArtistInfo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistInfosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _artistKeyMeta = const VerificationMeta(
    'artistKey',
  );
  @override
  late final GeneratedColumn<String> artistKey = GeneratedColumn<String>(
    'artist_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    artistKey,
    body,
    sourceUrl,
    lang,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artist_infos';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtistInfo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('artist_key')) {
      context.handle(
        _artistKeyMeta,
        artistKey.isAcceptableOrUnknown(data['artist_key']!, _artistKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_artistKeyMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceUrlMeta);
    }
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    } else if (isInserting) {
      context.missing(_langMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artistKey};
  @override
  ArtistInfo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistInfo(
      artistKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_key'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $ArtistInfosTable createAlias(String alias) {
    return $ArtistInfosTable(attachedDatabase, alias);
  }
}

class ArtistInfo extends DataClass implements Insertable<ArtistInfo> {
  /// `matchKey` of the main artist's name.
  final String artistKey;
  final String body;
  final String sourceUrl;
  final String lang;
  final int fetchedAt;
  const ArtistInfo({
    required this.artistKey,
    required this.body,
    required this.sourceUrl,
    required this.lang,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['artist_key'] = Variable<String>(artistKey);
    map['body'] = Variable<String>(body);
    map['source_url'] = Variable<String>(sourceUrl);
    map['lang'] = Variable<String>(lang);
    map['fetched_at'] = Variable<int>(fetchedAt);
    return map;
  }

  ArtistInfosCompanion toCompanion(bool nullToAbsent) {
    return ArtistInfosCompanion(
      artistKey: Value(artistKey),
      body: Value(body),
      sourceUrl: Value(sourceUrl),
      lang: Value(lang),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory ArtistInfo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistInfo(
      artistKey: serializer.fromJson<String>(json['artistKey']),
      body: serializer.fromJson<String>(json['body']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      lang: serializer.fromJson<String>(json['lang']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'artistKey': serializer.toJson<String>(artistKey),
      'body': serializer.toJson<String>(body),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'lang': serializer.toJson<String>(lang),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
    };
  }

  ArtistInfo copyWith({
    String? artistKey,
    String? body,
    String? sourceUrl,
    String? lang,
    int? fetchedAt,
  }) => ArtistInfo(
    artistKey: artistKey ?? this.artistKey,
    body: body ?? this.body,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    lang: lang ?? this.lang,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  ArtistInfo copyWithCompanion(ArtistInfosCompanion data) {
    return ArtistInfo(
      artistKey: data.artistKey.present ? data.artistKey.value : this.artistKey,
      body: data.body.present ? data.body.value : this.body,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      lang: data.lang.present ? data.lang.value : this.lang,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistInfo(')
          ..write('artistKey: $artistKey, ')
          ..write('body: $body, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('lang: $lang, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(artistKey, body, sourceUrl, lang, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistInfo &&
          other.artistKey == this.artistKey &&
          other.body == this.body &&
          other.sourceUrl == this.sourceUrl &&
          other.lang == this.lang &&
          other.fetchedAt == this.fetchedAt);
}

class ArtistInfosCompanion extends UpdateCompanion<ArtistInfo> {
  final Value<String> artistKey;
  final Value<String> body;
  final Value<String> sourceUrl;
  final Value<String> lang;
  final Value<int> fetchedAt;
  final Value<int> rowid;
  const ArtistInfosCompanion({
    this.artistKey = const Value.absent(),
    this.body = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.lang = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistInfosCompanion.insert({
    required String artistKey,
    required String body,
    required String sourceUrl,
    required String lang,
    required int fetchedAt,
    this.rowid = const Value.absent(),
  }) : artistKey = Value(artistKey),
       body = Value(body),
       sourceUrl = Value(sourceUrl),
       lang = Value(lang),
       fetchedAt = Value(fetchedAt);
  static Insertable<ArtistInfo> custom({
    Expression<String>? artistKey,
    Expression<String>? body,
    Expression<String>? sourceUrl,
    Expression<String>? lang,
    Expression<int>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (artistKey != null) 'artist_key': artistKey,
      if (body != null) 'body': body,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (lang != null) 'lang': lang,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistInfosCompanion copyWith({
    Value<String>? artistKey,
    Value<String>? body,
    Value<String>? sourceUrl,
    Value<String>? lang,
    Value<int>? fetchedAt,
    Value<int>? rowid,
  }) {
    return ArtistInfosCompanion(
      artistKey: artistKey ?? this.artistKey,
      body: body ?? this.body,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      lang: lang ?? this.lang,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (artistKey.present) {
      map['artist_key'] = Variable<String>(artistKey.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistInfosCompanion(')
          ..write('artistKey: $artistKey, ')
          ..write('body: $body, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('lang: $lang, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RadioStationsTable extends RadioStations
    with TableInfo<$RadioStationsTable, SavedRadio> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RadioStationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stationIdMeta = const VerificationMeta(
    'stationId',
  );
  @override
  late final GeneratedColumn<String> stationId = GeneratedColumn<String>(
    'station_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streamUrlMeta = const VerificationMeta(
    'streamUrl',
  );
  @override
  late final GeneratedColumn<String> streamUrl = GeneratedColumn<String>(
    'stream_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _homepageMeta = const VerificationMeta(
    'homepage',
  );
  @override
  late final GeneratedColumn<String> homepage = GeneratedColumn<String>(
    'homepage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _faviconUrlMeta = const VerificationMeta(
    'faviconUrl',
  );
  @override
  late final GeneratedColumn<String> faviconUrl = GeneratedColumn<String>(
    'favicon_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _countryCodeMeta = const VerificationMeta(
    'countryCode',
  );
  @override
  late final GeneratedColumn<String> countryCode = GeneratedColumn<String>(
    'country_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _codecMeta = const VerificationMeta('codec');
  @override
  late final GeneratedColumn<String> codec = GeneratedColumn<String>(
    'codec',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bitrateMeta = const VerificationMeta(
    'bitrate',
  );
  @override
  late final GeneratedColumn<int> bitrate = GeneratedColumn<int>(
    'bitrate',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hlsMeta = const VerificationMeta('hls');
  @override
  late final GeneratedColumn<bool> hls = GeneratedColumn<bool>(
    'hls',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hls" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: nowMs,
  );
  static const VerificationMeta _lastPlayedAtMeta = const VerificationMeta(
    'lastPlayedAt',
  );
  @override
  late final GeneratedColumn<int> lastPlayedAt = GeneratedColumn<int>(
    'last_played_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastOkAtMeta = const VerificationMeta(
    'lastOkAt',
  );
  @override
  late final GeneratedColumn<int> lastOkAt = GeneratedColumn<int>(
    'last_ok_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unreachableMeta = const VerificationMeta(
    'unreachable',
  );
  @override
  late final GeneratedColumn<bool> unreachable = GeneratedColumn<bool>(
    'unreachable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unreachable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    stationId,
    name,
    streamUrl,
    homepage,
    faviconUrl,
    countryCode,
    state,
    tags,
    codec,
    bitrate,
    hls,
    position,
    addedAt,
    lastPlayedAt,
    lastOkAt,
    unreachable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'radio_stations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SavedRadio> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('station_id')) {
      context.handle(
        _stationIdMeta,
        stationId.isAcceptableOrUnknown(data['station_id']!, _stationIdMeta),
      );
    } else if (isInserting) {
      context.missing(_stationIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('stream_url')) {
      context.handle(
        _streamUrlMeta,
        streamUrl.isAcceptableOrUnknown(data['stream_url']!, _streamUrlMeta),
      );
    } else if (isInserting) {
      context.missing(_streamUrlMeta);
    }
    if (data.containsKey('homepage')) {
      context.handle(
        _homepageMeta,
        homepage.isAcceptableOrUnknown(data['homepage']!, _homepageMeta),
      );
    }
    if (data.containsKey('favicon_url')) {
      context.handle(
        _faviconUrlMeta,
        faviconUrl.isAcceptableOrUnknown(data['favicon_url']!, _faviconUrlMeta),
      );
    }
    if (data.containsKey('country_code')) {
      context.handle(
        _countryCodeMeta,
        countryCode.isAcceptableOrUnknown(
          data['country_code']!,
          _countryCodeMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    if (data.containsKey('codec')) {
      context.handle(
        _codecMeta,
        codec.isAcceptableOrUnknown(data['codec']!, _codecMeta),
      );
    }
    if (data.containsKey('bitrate')) {
      context.handle(
        _bitrateMeta,
        bitrate.isAcceptableOrUnknown(data['bitrate']!, _bitrateMeta),
      );
    }
    if (data.containsKey('hls')) {
      context.handle(
        _hlsMeta,
        hls.isAcceptableOrUnknown(data['hls']!, _hlsMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    }
    if (data.containsKey('last_played_at')) {
      context.handle(
        _lastPlayedAtMeta,
        lastPlayedAt.isAcceptableOrUnknown(
          data['last_played_at']!,
          _lastPlayedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_ok_at')) {
      context.handle(
        _lastOkAtMeta,
        lastOkAt.isAcceptableOrUnknown(data['last_ok_at']!, _lastOkAtMeta),
      );
    }
    if (data.containsKey('unreachable')) {
      context.handle(
        _unreachableMeta,
        unreachable.isAcceptableOrUnknown(
          data['unreachable']!,
          _unreachableMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stationId};
  @override
  SavedRadio map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SavedRadio(
      stationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      streamUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stream_url'],
      )!,
      homepage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}homepage'],
      )!,
      faviconUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}favicon_url'],
      )!,
      countryCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country_code'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
      codec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codec'],
      )!,
      bitrate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bitrate'],
      )!,
      hls: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hls'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      lastPlayedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_played_at'],
      ),
      lastOkAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_ok_at'],
      ),
      unreachable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unreachable'],
      )!,
    );
  }

  @override
  $RadioStationsTable createAlias(String alias) {
    return $RadioStationsTable(attachedDatabase, alias);
  }
}

class SavedRadio extends DataClass implements Insertable<SavedRadio> {
  final String stationId;
  final String name;
  final String streamUrl;
  final String homepage;
  final String faviconUrl;
  final String countryCode;
  final String state;

  /// Comma-separated.
  final String tags;
  final String codec;
  final int bitrate;
  final bool hls;

  /// The order the user chose (0 = first).
  final int position;
  final int addedAt;
  final int? lastPlayedAt;

  /// The last refresh that found the station working.
  final int? lastOkAt;

  /// The last refresh did not find the station, or found it broken. Shown as
  /// «non risponde»; the row is never deleted for it.
  final bool unreachable;
  const SavedRadio({
    required this.stationId,
    required this.name,
    required this.streamUrl,
    required this.homepage,
    required this.faviconUrl,
    required this.countryCode,
    required this.state,
    required this.tags,
    required this.codec,
    required this.bitrate,
    required this.hls,
    required this.position,
    required this.addedAt,
    this.lastPlayedAt,
    this.lastOkAt,
    required this.unreachable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['station_id'] = Variable<String>(stationId);
    map['name'] = Variable<String>(name);
    map['stream_url'] = Variable<String>(streamUrl);
    map['homepage'] = Variable<String>(homepage);
    map['favicon_url'] = Variable<String>(faviconUrl);
    map['country_code'] = Variable<String>(countryCode);
    map['state'] = Variable<String>(state);
    map['tags'] = Variable<String>(tags);
    map['codec'] = Variable<String>(codec);
    map['bitrate'] = Variable<int>(bitrate);
    map['hls'] = Variable<bool>(hls);
    map['position'] = Variable<int>(position);
    map['added_at'] = Variable<int>(addedAt);
    if (!nullToAbsent || lastPlayedAt != null) {
      map['last_played_at'] = Variable<int>(lastPlayedAt);
    }
    if (!nullToAbsent || lastOkAt != null) {
      map['last_ok_at'] = Variable<int>(lastOkAt);
    }
    map['unreachable'] = Variable<bool>(unreachable);
    return map;
  }

  RadioStationsCompanion toCompanion(bool nullToAbsent) {
    return RadioStationsCompanion(
      stationId: Value(stationId),
      name: Value(name),
      streamUrl: Value(streamUrl),
      homepage: Value(homepage),
      faviconUrl: Value(faviconUrl),
      countryCode: Value(countryCode),
      state: Value(state),
      tags: Value(tags),
      codec: Value(codec),
      bitrate: Value(bitrate),
      hls: Value(hls),
      position: Value(position),
      addedAt: Value(addedAt),
      lastPlayedAt: lastPlayedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPlayedAt),
      lastOkAt: lastOkAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOkAt),
      unreachable: Value(unreachable),
    );
  }

  factory SavedRadio.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SavedRadio(
      stationId: serializer.fromJson<String>(json['stationId']),
      name: serializer.fromJson<String>(json['name']),
      streamUrl: serializer.fromJson<String>(json['streamUrl']),
      homepage: serializer.fromJson<String>(json['homepage']),
      faviconUrl: serializer.fromJson<String>(json['faviconUrl']),
      countryCode: serializer.fromJson<String>(json['countryCode']),
      state: serializer.fromJson<String>(json['state']),
      tags: serializer.fromJson<String>(json['tags']),
      codec: serializer.fromJson<String>(json['codec']),
      bitrate: serializer.fromJson<int>(json['bitrate']),
      hls: serializer.fromJson<bool>(json['hls']),
      position: serializer.fromJson<int>(json['position']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      lastPlayedAt: serializer.fromJson<int?>(json['lastPlayedAt']),
      lastOkAt: serializer.fromJson<int?>(json['lastOkAt']),
      unreachable: serializer.fromJson<bool>(json['unreachable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stationId': serializer.toJson<String>(stationId),
      'name': serializer.toJson<String>(name),
      'streamUrl': serializer.toJson<String>(streamUrl),
      'homepage': serializer.toJson<String>(homepage),
      'faviconUrl': serializer.toJson<String>(faviconUrl),
      'countryCode': serializer.toJson<String>(countryCode),
      'state': serializer.toJson<String>(state),
      'tags': serializer.toJson<String>(tags),
      'codec': serializer.toJson<String>(codec),
      'bitrate': serializer.toJson<int>(bitrate),
      'hls': serializer.toJson<bool>(hls),
      'position': serializer.toJson<int>(position),
      'addedAt': serializer.toJson<int>(addedAt),
      'lastPlayedAt': serializer.toJson<int?>(lastPlayedAt),
      'lastOkAt': serializer.toJson<int?>(lastOkAt),
      'unreachable': serializer.toJson<bool>(unreachable),
    };
  }

  SavedRadio copyWith({
    String? stationId,
    String? name,
    String? streamUrl,
    String? homepage,
    String? faviconUrl,
    String? countryCode,
    String? state,
    String? tags,
    String? codec,
    int? bitrate,
    bool? hls,
    int? position,
    int? addedAt,
    Value<int?> lastPlayedAt = const Value.absent(),
    Value<int?> lastOkAt = const Value.absent(),
    bool? unreachable,
  }) => SavedRadio(
    stationId: stationId ?? this.stationId,
    name: name ?? this.name,
    streamUrl: streamUrl ?? this.streamUrl,
    homepage: homepage ?? this.homepage,
    faviconUrl: faviconUrl ?? this.faviconUrl,
    countryCode: countryCode ?? this.countryCode,
    state: state ?? this.state,
    tags: tags ?? this.tags,
    codec: codec ?? this.codec,
    bitrate: bitrate ?? this.bitrate,
    hls: hls ?? this.hls,
    position: position ?? this.position,
    addedAt: addedAt ?? this.addedAt,
    lastPlayedAt: lastPlayedAt.present ? lastPlayedAt.value : this.lastPlayedAt,
    lastOkAt: lastOkAt.present ? lastOkAt.value : this.lastOkAt,
    unreachable: unreachable ?? this.unreachable,
  );
  SavedRadio copyWithCompanion(RadioStationsCompanion data) {
    return SavedRadio(
      stationId: data.stationId.present ? data.stationId.value : this.stationId,
      name: data.name.present ? data.name.value : this.name,
      streamUrl: data.streamUrl.present ? data.streamUrl.value : this.streamUrl,
      homepage: data.homepage.present ? data.homepage.value : this.homepage,
      faviconUrl: data.faviconUrl.present
          ? data.faviconUrl.value
          : this.faviconUrl,
      countryCode: data.countryCode.present
          ? data.countryCode.value
          : this.countryCode,
      state: data.state.present ? data.state.value : this.state,
      tags: data.tags.present ? data.tags.value : this.tags,
      codec: data.codec.present ? data.codec.value : this.codec,
      bitrate: data.bitrate.present ? data.bitrate.value : this.bitrate,
      hls: data.hls.present ? data.hls.value : this.hls,
      position: data.position.present ? data.position.value : this.position,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      lastPlayedAt: data.lastPlayedAt.present
          ? data.lastPlayedAt.value
          : this.lastPlayedAt,
      lastOkAt: data.lastOkAt.present ? data.lastOkAt.value : this.lastOkAt,
      unreachable: data.unreachable.present
          ? data.unreachable.value
          : this.unreachable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SavedRadio(')
          ..write('stationId: $stationId, ')
          ..write('name: $name, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('homepage: $homepage, ')
          ..write('faviconUrl: $faviconUrl, ')
          ..write('countryCode: $countryCode, ')
          ..write('state: $state, ')
          ..write('tags: $tags, ')
          ..write('codec: $codec, ')
          ..write('bitrate: $bitrate, ')
          ..write('hls: $hls, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('lastOkAt: $lastOkAt, ')
          ..write('unreachable: $unreachable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    stationId,
    name,
    streamUrl,
    homepage,
    faviconUrl,
    countryCode,
    state,
    tags,
    codec,
    bitrate,
    hls,
    position,
    addedAt,
    lastPlayedAt,
    lastOkAt,
    unreachable,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SavedRadio &&
          other.stationId == this.stationId &&
          other.name == this.name &&
          other.streamUrl == this.streamUrl &&
          other.homepage == this.homepage &&
          other.faviconUrl == this.faviconUrl &&
          other.countryCode == this.countryCode &&
          other.state == this.state &&
          other.tags == this.tags &&
          other.codec == this.codec &&
          other.bitrate == this.bitrate &&
          other.hls == this.hls &&
          other.position == this.position &&
          other.addedAt == this.addedAt &&
          other.lastPlayedAt == this.lastPlayedAt &&
          other.lastOkAt == this.lastOkAt &&
          other.unreachable == this.unreachable);
}

class RadioStationsCompanion extends UpdateCompanion<SavedRadio> {
  final Value<String> stationId;
  final Value<String> name;
  final Value<String> streamUrl;
  final Value<String> homepage;
  final Value<String> faviconUrl;
  final Value<String> countryCode;
  final Value<String> state;
  final Value<String> tags;
  final Value<String> codec;
  final Value<int> bitrate;
  final Value<bool> hls;
  final Value<int> position;
  final Value<int> addedAt;
  final Value<int?> lastPlayedAt;
  final Value<int?> lastOkAt;
  final Value<bool> unreachable;
  final Value<int> rowid;
  const RadioStationsCompanion({
    this.stationId = const Value.absent(),
    this.name = const Value.absent(),
    this.streamUrl = const Value.absent(),
    this.homepage = const Value.absent(),
    this.faviconUrl = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.state = const Value.absent(),
    this.tags = const Value.absent(),
    this.codec = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.hls = const Value.absent(),
    this.position = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.lastOkAt = const Value.absent(),
    this.unreachable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RadioStationsCompanion.insert({
    required String stationId,
    required String name,
    required String streamUrl,
    this.homepage = const Value.absent(),
    this.faviconUrl = const Value.absent(),
    this.countryCode = const Value.absent(),
    this.state = const Value.absent(),
    this.tags = const Value.absent(),
    this.codec = const Value.absent(),
    this.bitrate = const Value.absent(),
    this.hls = const Value.absent(),
    required int position,
    this.addedAt = const Value.absent(),
    this.lastPlayedAt = const Value.absent(),
    this.lastOkAt = const Value.absent(),
    this.unreachable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : stationId = Value(stationId),
       name = Value(name),
       streamUrl = Value(streamUrl),
       position = Value(position);
  static Insertable<SavedRadio> custom({
    Expression<String>? stationId,
    Expression<String>? name,
    Expression<String>? streamUrl,
    Expression<String>? homepage,
    Expression<String>? faviconUrl,
    Expression<String>? countryCode,
    Expression<String>? state,
    Expression<String>? tags,
    Expression<String>? codec,
    Expression<int>? bitrate,
    Expression<bool>? hls,
    Expression<int>? position,
    Expression<int>? addedAt,
    Expression<int>? lastPlayedAt,
    Expression<int>? lastOkAt,
    Expression<bool>? unreachable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stationId != null) 'station_id': stationId,
      if (name != null) 'name': name,
      if (streamUrl != null) 'stream_url': streamUrl,
      if (homepage != null) 'homepage': homepage,
      if (faviconUrl != null) 'favicon_url': faviconUrl,
      if (countryCode != null) 'country_code': countryCode,
      if (state != null) 'state': state,
      if (tags != null) 'tags': tags,
      if (codec != null) 'codec': codec,
      if (bitrate != null) 'bitrate': bitrate,
      if (hls != null) 'hls': hls,
      if (position != null) 'position': position,
      if (addedAt != null) 'added_at': addedAt,
      if (lastPlayedAt != null) 'last_played_at': lastPlayedAt,
      if (lastOkAt != null) 'last_ok_at': lastOkAt,
      if (unreachable != null) 'unreachable': unreachable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RadioStationsCompanion copyWith({
    Value<String>? stationId,
    Value<String>? name,
    Value<String>? streamUrl,
    Value<String>? homepage,
    Value<String>? faviconUrl,
    Value<String>? countryCode,
    Value<String>? state,
    Value<String>? tags,
    Value<String>? codec,
    Value<int>? bitrate,
    Value<bool>? hls,
    Value<int>? position,
    Value<int>? addedAt,
    Value<int?>? lastPlayedAt,
    Value<int?>? lastOkAt,
    Value<bool>? unreachable,
    Value<int>? rowid,
  }) {
    return RadioStationsCompanion(
      stationId: stationId ?? this.stationId,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      homepage: homepage ?? this.homepage,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      countryCode: countryCode ?? this.countryCode,
      state: state ?? this.state,
      tags: tags ?? this.tags,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      hls: hls ?? this.hls,
      position: position ?? this.position,
      addedAt: addedAt ?? this.addedAt,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      lastOkAt: lastOkAt ?? this.lastOkAt,
      unreachable: unreachable ?? this.unreachable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stationId.present) {
      map['station_id'] = Variable<String>(stationId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (streamUrl.present) {
      map['stream_url'] = Variable<String>(streamUrl.value);
    }
    if (homepage.present) {
      map['homepage'] = Variable<String>(homepage.value);
    }
    if (faviconUrl.present) {
      map['favicon_url'] = Variable<String>(faviconUrl.value);
    }
    if (countryCode.present) {
      map['country_code'] = Variable<String>(countryCode.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (codec.present) {
      map['codec'] = Variable<String>(codec.value);
    }
    if (bitrate.present) {
      map['bitrate'] = Variable<int>(bitrate.value);
    }
    if (hls.present) {
      map['hls'] = Variable<bool>(hls.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (lastPlayedAt.present) {
      map['last_played_at'] = Variable<int>(lastPlayedAt.value);
    }
    if (lastOkAt.present) {
      map['last_ok_at'] = Variable<int>(lastOkAt.value);
    }
    if (unreachable.present) {
      map['unreachable'] = Variable<bool>(unreachable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RadioStationsCompanion(')
          ..write('stationId: $stationId, ')
          ..write('name: $name, ')
          ..write('streamUrl: $streamUrl, ')
          ..write('homepage: $homepage, ')
          ..write('faviconUrl: $faviconUrl, ')
          ..write('countryCode: $countryCode, ')
          ..write('state: $state, ')
          ..write('tags: $tags, ')
          ..write('codec: $codec, ')
          ..write('bitrate: $bitrate, ')
          ..write('hls: $hls, ')
          ..write('position: $position, ')
          ..write('addedAt: $addedAt, ')
          ..write('lastPlayedAt: $lastPlayedAt, ')
          ..write('lastOkAt: $lastOkAt, ')
          ..write('unreachable: $unreachable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FollowedArtistsTable extends FollowedArtists
    with TableInfo<$FollowedArtistsTable, FollowedArtist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FollowedArtistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ytmIdMeta = const VerificationMeta('ytmId');
  @override
  late final GeneratedColumn<String> ytmId = GeneratedColumn<String>(
    'ytm_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _originMeta = const VerificationMeta('origin');
  @override
  late final GeneratedColumn<int> origin = GeneratedColumn<int>(
    'origin',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _excludedMeta = const VerificationMeta(
    'excluded',
  );
  @override
  late final GeneratedColumn<bool> excluded = GeneratedColumn<bool>(
    'excluded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("excluded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _mutedMeta = const VerificationMeta('muted');
  @override
  late final GeneratedColumn<bool> muted = GeneratedColumn<bool>(
    'muted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("muted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _followedAtMeta = const VerificationMeta(
    'followedAt',
  );
  @override
  late final GeneratedColumn<int> followedAt = GeneratedColumn<int>(
    'followed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: nowMs,
  );
  static const VerificationMeta _lastCheckedAtMeta = const VerificationMeta(
    'lastCheckedAt',
  );
  @override
  late final GeneratedColumn<int> lastCheckedAt = GeneratedColumn<int>(
    'last_checked_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checksFailedMeta = const VerificationMeta(
    'checksFailed',
  );
  @override
  late final GeneratedColumn<int> checksFailed = GeneratedColumn<int>(
    'checks_failed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    ytmId,
    name,
    thumbUrl,
    origin,
    excluded,
    muted,
    followedAt,
    lastCheckedAt,
    lastError,
    checksFailed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'followed_artists';
  @override
  VerificationContext validateIntegrity(
    Insertable<FollowedArtist> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ytm_id')) {
      context.handle(
        _ytmIdMeta,
        ytmId.isAcceptableOrUnknown(data['ytm_id']!, _ytmIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ytmIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    if (data.containsKey('origin')) {
      context.handle(
        _originMeta,
        origin.isAcceptableOrUnknown(data['origin']!, _originMeta),
      );
    }
    if (data.containsKey('excluded')) {
      context.handle(
        _excludedMeta,
        excluded.isAcceptableOrUnknown(data['excluded']!, _excludedMeta),
      );
    }
    if (data.containsKey('muted')) {
      context.handle(
        _mutedMeta,
        muted.isAcceptableOrUnknown(data['muted']!, _mutedMeta),
      );
    }
    if (data.containsKey('followed_at')) {
      context.handle(
        _followedAtMeta,
        followedAt.isAcceptableOrUnknown(data['followed_at']!, _followedAtMeta),
      );
    }
    if (data.containsKey('last_checked_at')) {
      context.handle(
        _lastCheckedAtMeta,
        lastCheckedAt.isAcceptableOrUnknown(
          data['last_checked_at']!,
          _lastCheckedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('checks_failed')) {
      context.handle(
        _checksFailedMeta,
        checksFailed.isAcceptableOrUnknown(
          data['checks_failed']!,
          _checksFailedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ytmId};
  @override
  FollowedArtist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FollowedArtist(
      ytmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ytm_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
      origin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}origin'],
      )!,
      excluded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}excluded'],
      )!,
      muted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}muted'],
      )!,
      followedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}followed_at'],
      )!,
      lastCheckedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_checked_at'],
      ),
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      checksFailed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checks_failed'],
      )!,
    );
  }

  @override
  $FollowedArtistsTable createAlias(String alias) {
    return $FollowedArtistsTable(attachedDatabase, alias);
  }
}

class FollowedArtist extends DataClass implements Insertable<FollowedArtist> {
  /// `UC…` channel id of the YouTube Music artist page.
  final String ytmId;
  final String name;
  final String? thumbUrl;
  final int origin;

  /// An automatic artist the user stopped following: never added again.
  final bool excluded;

  /// No notification for this artist; the release still shows in Home.
  final bool muted;
  final int followedAt;

  /// Null until the first check (which marks everything as seen).
  final int? lastCheckedAt;
  final String? lastError;

  /// Checks in a row that did not find the artist page.
  final int checksFailed;
  const FollowedArtist({
    required this.ytmId,
    required this.name,
    this.thumbUrl,
    required this.origin,
    required this.excluded,
    required this.muted,
    required this.followedAt,
    this.lastCheckedAt,
    this.lastError,
    required this.checksFailed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ytm_id'] = Variable<String>(ytmId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    map['origin'] = Variable<int>(origin);
    map['excluded'] = Variable<bool>(excluded);
    map['muted'] = Variable<bool>(muted);
    map['followed_at'] = Variable<int>(followedAt);
    if (!nullToAbsent || lastCheckedAt != null) {
      map['last_checked_at'] = Variable<int>(lastCheckedAt);
    }
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['checks_failed'] = Variable<int>(checksFailed);
    return map;
  }

  FollowedArtistsCompanion toCompanion(bool nullToAbsent) {
    return FollowedArtistsCompanion(
      ytmId: Value(ytmId),
      name: Value(name),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
      origin: Value(origin),
      excluded: Value(excluded),
      muted: Value(muted),
      followedAt: Value(followedAt),
      lastCheckedAt: lastCheckedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckedAt),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      checksFailed: Value(checksFailed),
    );
  }

  factory FollowedArtist.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FollowedArtist(
      ytmId: serializer.fromJson<String>(json['ytmId']),
      name: serializer.fromJson<String>(json['name']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
      origin: serializer.fromJson<int>(json['origin']),
      excluded: serializer.fromJson<bool>(json['excluded']),
      muted: serializer.fromJson<bool>(json['muted']),
      followedAt: serializer.fromJson<int>(json['followedAt']),
      lastCheckedAt: serializer.fromJson<int?>(json['lastCheckedAt']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      checksFailed: serializer.fromJson<int>(json['checksFailed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ytmId': serializer.toJson<String>(ytmId),
      'name': serializer.toJson<String>(name),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
      'origin': serializer.toJson<int>(origin),
      'excluded': serializer.toJson<bool>(excluded),
      'muted': serializer.toJson<bool>(muted),
      'followedAt': serializer.toJson<int>(followedAt),
      'lastCheckedAt': serializer.toJson<int?>(lastCheckedAt),
      'lastError': serializer.toJson<String?>(lastError),
      'checksFailed': serializer.toJson<int>(checksFailed),
    };
  }

  FollowedArtist copyWith({
    String? ytmId,
    String? name,
    Value<String?> thumbUrl = const Value.absent(),
    int? origin,
    bool? excluded,
    bool? muted,
    int? followedAt,
    Value<int?> lastCheckedAt = const Value.absent(),
    Value<String?> lastError = const Value.absent(),
    int? checksFailed,
  }) => FollowedArtist(
    ytmId: ytmId ?? this.ytmId,
    name: name ?? this.name,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
    origin: origin ?? this.origin,
    excluded: excluded ?? this.excluded,
    muted: muted ?? this.muted,
    followedAt: followedAt ?? this.followedAt,
    lastCheckedAt: lastCheckedAt.present
        ? lastCheckedAt.value
        : this.lastCheckedAt,
    lastError: lastError.present ? lastError.value : this.lastError,
    checksFailed: checksFailed ?? this.checksFailed,
  );
  FollowedArtist copyWithCompanion(FollowedArtistsCompanion data) {
    return FollowedArtist(
      ytmId: data.ytmId.present ? data.ytmId.value : this.ytmId,
      name: data.name.present ? data.name.value : this.name,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      origin: data.origin.present ? data.origin.value : this.origin,
      excluded: data.excluded.present ? data.excluded.value : this.excluded,
      muted: data.muted.present ? data.muted.value : this.muted,
      followedAt: data.followedAt.present
          ? data.followedAt.value
          : this.followedAt,
      lastCheckedAt: data.lastCheckedAt.present
          ? data.lastCheckedAt.value
          : this.lastCheckedAt,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      checksFailed: data.checksFailed.present
          ? data.checksFailed.value
          : this.checksFailed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FollowedArtist(')
          ..write('ytmId: $ytmId, ')
          ..write('name: $name, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('origin: $origin, ')
          ..write('excluded: $excluded, ')
          ..write('muted: $muted, ')
          ..write('followedAt: $followedAt, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('lastError: $lastError, ')
          ..write('checksFailed: $checksFailed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ytmId,
    name,
    thumbUrl,
    origin,
    excluded,
    muted,
    followedAt,
    lastCheckedAt,
    lastError,
    checksFailed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FollowedArtist &&
          other.ytmId == this.ytmId &&
          other.name == this.name &&
          other.thumbUrl == this.thumbUrl &&
          other.origin == this.origin &&
          other.excluded == this.excluded &&
          other.muted == this.muted &&
          other.followedAt == this.followedAt &&
          other.lastCheckedAt == this.lastCheckedAt &&
          other.lastError == this.lastError &&
          other.checksFailed == this.checksFailed);
}

class FollowedArtistsCompanion extends UpdateCompanion<FollowedArtist> {
  final Value<String> ytmId;
  final Value<String> name;
  final Value<String?> thumbUrl;
  final Value<int> origin;
  final Value<bool> excluded;
  final Value<bool> muted;
  final Value<int> followedAt;
  final Value<int?> lastCheckedAt;
  final Value<String?> lastError;
  final Value<int> checksFailed;
  final Value<int> rowid;
  const FollowedArtistsCompanion({
    this.ytmId = const Value.absent(),
    this.name = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.origin = const Value.absent(),
    this.excluded = const Value.absent(),
    this.muted = const Value.absent(),
    this.followedAt = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.checksFailed = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FollowedArtistsCompanion.insert({
    required String ytmId,
    required String name,
    this.thumbUrl = const Value.absent(),
    this.origin = const Value.absent(),
    this.excluded = const Value.absent(),
    this.muted = const Value.absent(),
    this.followedAt = const Value.absent(),
    this.lastCheckedAt = const Value.absent(),
    this.lastError = const Value.absent(),
    this.checksFailed = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : ytmId = Value(ytmId),
       name = Value(name);
  static Insertable<FollowedArtist> custom({
    Expression<String>? ytmId,
    Expression<String>? name,
    Expression<String>? thumbUrl,
    Expression<int>? origin,
    Expression<bool>? excluded,
    Expression<bool>? muted,
    Expression<int>? followedAt,
    Expression<int>? lastCheckedAt,
    Expression<String>? lastError,
    Expression<int>? checksFailed,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ytmId != null) 'ytm_id': ytmId,
      if (name != null) 'name': name,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (origin != null) 'origin': origin,
      if (excluded != null) 'excluded': excluded,
      if (muted != null) 'muted': muted,
      if (followedAt != null) 'followed_at': followedAt,
      if (lastCheckedAt != null) 'last_checked_at': lastCheckedAt,
      if (lastError != null) 'last_error': lastError,
      if (checksFailed != null) 'checks_failed': checksFailed,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FollowedArtistsCompanion copyWith({
    Value<String>? ytmId,
    Value<String>? name,
    Value<String?>? thumbUrl,
    Value<int>? origin,
    Value<bool>? excluded,
    Value<bool>? muted,
    Value<int>? followedAt,
    Value<int?>? lastCheckedAt,
    Value<String?>? lastError,
    Value<int>? checksFailed,
    Value<int>? rowid,
  }) {
    return FollowedArtistsCompanion(
      ytmId: ytmId ?? this.ytmId,
      name: name ?? this.name,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      origin: origin ?? this.origin,
      excluded: excluded ?? this.excluded,
      muted: muted ?? this.muted,
      followedAt: followedAt ?? this.followedAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      lastError: lastError ?? this.lastError,
      checksFailed: checksFailed ?? this.checksFailed,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ytmId.present) {
      map['ytm_id'] = Variable<String>(ytmId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (origin.present) {
      map['origin'] = Variable<int>(origin.value);
    }
    if (excluded.present) {
      map['excluded'] = Variable<bool>(excluded.value);
    }
    if (muted.present) {
      map['muted'] = Variable<bool>(muted.value);
    }
    if (followedAt.present) {
      map['followed_at'] = Variable<int>(followedAt.value);
    }
    if (lastCheckedAt.present) {
      map['last_checked_at'] = Variable<int>(lastCheckedAt.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (checksFailed.present) {
      map['checks_failed'] = Variable<int>(checksFailed.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FollowedArtistsCompanion(')
          ..write('ytmId: $ytmId, ')
          ..write('name: $name, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('origin: $origin, ')
          ..write('excluded: $excluded, ')
          ..write('muted: $muted, ')
          ..write('followedAt: $followedAt, ')
          ..write('lastCheckedAt: $lastCheckedAt, ')
          ..write('lastError: $lastError, ')
          ..write('checksFailed: $checksFailed, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistReleasesTable extends ArtistReleases
    with TableInfo<$ArtistReleasesTable, ArtistRelease> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistReleasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _browseIdMeta = const VerificationMeta(
    'browseId',
  );
  @override
  late final GeneratedColumn<String> browseId = GeneratedColumn<String>(
    'browse_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artistIdMeta = const VerificationMeta(
    'artistId',
  );
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
    'artist_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES followed_artists (ytm_id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
    'year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSeenAtMeta = const VerificationMeta(
    'firstSeenAt',
  );
  @override
  late final GeneratedColumn<int> firstSeenAt = GeneratedColumn<int>(
    'first_seen_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isNewMeta = const VerificationMeta('isNew');
  @override
  late final GeneratedColumn<bool> isNew = GeneratedColumn<bool>(
    'is_new',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_new" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<int> openedAt = GeneratedColumn<int>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupKeyMeta = const VerificationMeta(
    'groupKey',
  );
  @override
  late final GeneratedColumn<String> groupKey = GeneratedColumn<String>(
    'group_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    browseId,
    artistId,
    title,
    kind,
    year,
    thumbUrl,
    firstSeenAt,
    isNew,
    openedAt,
    groupKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artist_releases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtistRelease> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('browse_id')) {
      context.handle(
        _browseIdMeta,
        browseId.isAcceptableOrUnknown(data['browse_id']!, _browseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_browseIdMeta);
    }
    if (data.containsKey('artist_id')) {
      context.handle(
        _artistIdMeta,
        artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta),
      );
    } else if (isInserting) {
      context.missing(_artistIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('year')) {
      context.handle(
        _yearMeta,
        year.isAcceptableOrUnknown(data['year']!, _yearMeta),
      );
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    if (data.containsKey('first_seen_at')) {
      context.handle(
        _firstSeenAtMeta,
        firstSeenAt.isAcceptableOrUnknown(
          data['first_seen_at']!,
          _firstSeenAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_firstSeenAtMeta);
    }
    if (data.containsKey('is_new')) {
      context.handle(
        _isNewMeta,
        isNew.isAcceptableOrUnknown(data['is_new']!, _isNewMeta),
      );
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    }
    if (data.containsKey('group_key')) {
      context.handle(
        _groupKeyMeta,
        groupKey.isAcceptableOrUnknown(data['group_key']!, _groupKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_groupKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {browseId};
  @override
  ArtistRelease map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistRelease(
      browseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}browse_id'],
      )!,
      artistId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kind'],
      )!,
      year: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}year'],
      ),
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
      firstSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen_at'],
      )!,
      isNew: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_new'],
      )!,
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_at'],
      ),
      groupKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_key'],
      )!,
    );
  }

  @override
  $ArtistReleasesTable createAlias(String alias) {
    return $ArtistReleasesTable(attachedDatabase, alias);
  }
}

class ArtistRelease extends DataClass implements Insertable<ArtistRelease> {
  /// `MPREb_…`.
  final String browseId;
  final String artistId;
  final String title;

  /// `ReleaseKind.index`: 0 album, 1 single or EP.
  final int kind;
  final int? year;
  final String? thumbUrl;
  final int firstSeenAt;
  final bool isNew;
  final int? openedAt;

  /// Same for the variants and reissues of one title (`releaseGroupKey`).
  final String groupKey;
  const ArtistRelease({
    required this.browseId,
    required this.artistId,
    required this.title,
    required this.kind,
    this.year,
    this.thumbUrl,
    required this.firstSeenAt,
    required this.isNew,
    this.openedAt,
    required this.groupKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['browse_id'] = Variable<String>(browseId);
    map['artist_id'] = Variable<String>(artistId);
    map['title'] = Variable<String>(title);
    map['kind'] = Variable<int>(kind);
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    map['first_seen_at'] = Variable<int>(firstSeenAt);
    map['is_new'] = Variable<bool>(isNew);
    if (!nullToAbsent || openedAt != null) {
      map['opened_at'] = Variable<int>(openedAt);
    }
    map['group_key'] = Variable<String>(groupKey);
    return map;
  }

  ArtistReleasesCompanion toCompanion(bool nullToAbsent) {
    return ArtistReleasesCompanion(
      browseId: Value(browseId),
      artistId: Value(artistId),
      title: Value(title),
      kind: Value(kind),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
      firstSeenAt: Value(firstSeenAt),
      isNew: Value(isNew),
      openedAt: openedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(openedAt),
      groupKey: Value(groupKey),
    );
  }

  factory ArtistRelease.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistRelease(
      browseId: serializer.fromJson<String>(json['browseId']),
      artistId: serializer.fromJson<String>(json['artistId']),
      title: serializer.fromJson<String>(json['title']),
      kind: serializer.fromJson<int>(json['kind']),
      year: serializer.fromJson<int?>(json['year']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
      firstSeenAt: serializer.fromJson<int>(json['firstSeenAt']),
      isNew: serializer.fromJson<bool>(json['isNew']),
      openedAt: serializer.fromJson<int?>(json['openedAt']),
      groupKey: serializer.fromJson<String>(json['groupKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'browseId': serializer.toJson<String>(browseId),
      'artistId': serializer.toJson<String>(artistId),
      'title': serializer.toJson<String>(title),
      'kind': serializer.toJson<int>(kind),
      'year': serializer.toJson<int?>(year),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
      'firstSeenAt': serializer.toJson<int>(firstSeenAt),
      'isNew': serializer.toJson<bool>(isNew),
      'openedAt': serializer.toJson<int?>(openedAt),
      'groupKey': serializer.toJson<String>(groupKey),
    };
  }

  ArtistRelease copyWith({
    String? browseId,
    String? artistId,
    String? title,
    int? kind,
    Value<int?> year = const Value.absent(),
    Value<String?> thumbUrl = const Value.absent(),
    int? firstSeenAt,
    bool? isNew,
    Value<int?> openedAt = const Value.absent(),
    String? groupKey,
  }) => ArtistRelease(
    browseId: browseId ?? this.browseId,
    artistId: artistId ?? this.artistId,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    year: year.present ? year.value : this.year,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    isNew: isNew ?? this.isNew,
    openedAt: openedAt.present ? openedAt.value : this.openedAt,
    groupKey: groupKey ?? this.groupKey,
  );
  ArtistRelease copyWithCompanion(ArtistReleasesCompanion data) {
    return ArtistRelease(
      browseId: data.browseId.present ? data.browseId.value : this.browseId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      title: data.title.present ? data.title.value : this.title,
      kind: data.kind.present ? data.kind.value : this.kind,
      year: data.year.present ? data.year.value : this.year,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      firstSeenAt: data.firstSeenAt.present
          ? data.firstSeenAt.value
          : this.firstSeenAt,
      isNew: data.isNew.present ? data.isNew.value : this.isNew,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      groupKey: data.groupKey.present ? data.groupKey.value : this.groupKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistRelease(')
          ..write('browseId: $browseId, ')
          ..write('artistId: $artistId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('year: $year, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('isNew: $isNew, ')
          ..write('openedAt: $openedAt, ')
          ..write('groupKey: $groupKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    browseId,
    artistId,
    title,
    kind,
    year,
    thumbUrl,
    firstSeenAt,
    isNew,
    openedAt,
    groupKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistRelease &&
          other.browseId == this.browseId &&
          other.artistId == this.artistId &&
          other.title == this.title &&
          other.kind == this.kind &&
          other.year == this.year &&
          other.thumbUrl == this.thumbUrl &&
          other.firstSeenAt == this.firstSeenAt &&
          other.isNew == this.isNew &&
          other.openedAt == this.openedAt &&
          other.groupKey == this.groupKey);
}

class ArtistReleasesCompanion extends UpdateCompanion<ArtistRelease> {
  final Value<String> browseId;
  final Value<String> artistId;
  final Value<String> title;
  final Value<int> kind;
  final Value<int?> year;
  final Value<String?> thumbUrl;
  final Value<int> firstSeenAt;
  final Value<bool> isNew;
  final Value<int?> openedAt;
  final Value<String> groupKey;
  final Value<int> rowid;
  const ArtistReleasesCompanion({
    this.browseId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.title = const Value.absent(),
    this.kind = const Value.absent(),
    this.year = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.firstSeenAt = const Value.absent(),
    this.isNew = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.groupKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistReleasesCompanion.insert({
    required String browseId,
    required String artistId,
    required String title,
    required int kind,
    this.year = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    required int firstSeenAt,
    this.isNew = const Value.absent(),
    this.openedAt = const Value.absent(),
    required String groupKey,
    this.rowid = const Value.absent(),
  }) : browseId = Value(browseId),
       artistId = Value(artistId),
       title = Value(title),
       kind = Value(kind),
       firstSeenAt = Value(firstSeenAt),
       groupKey = Value(groupKey);
  static Insertable<ArtistRelease> custom({
    Expression<String>? browseId,
    Expression<String>? artistId,
    Expression<String>? title,
    Expression<int>? kind,
    Expression<int>? year,
    Expression<String>? thumbUrl,
    Expression<int>? firstSeenAt,
    Expression<bool>? isNew,
    Expression<int>? openedAt,
    Expression<String>? groupKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (browseId != null) 'browse_id': browseId,
      if (artistId != null) 'artist_id': artistId,
      if (title != null) 'title': title,
      if (kind != null) 'kind': kind,
      if (year != null) 'year': year,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (firstSeenAt != null) 'first_seen_at': firstSeenAt,
      if (isNew != null) 'is_new': isNew,
      if (openedAt != null) 'opened_at': openedAt,
      if (groupKey != null) 'group_key': groupKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistReleasesCompanion copyWith({
    Value<String>? browseId,
    Value<String>? artistId,
    Value<String>? title,
    Value<int>? kind,
    Value<int?>? year,
    Value<String?>? thumbUrl,
    Value<int>? firstSeenAt,
    Value<bool>? isNew,
    Value<int?>? openedAt,
    Value<String>? groupKey,
    Value<int>? rowid,
  }) {
    return ArtistReleasesCompanion(
      browseId: browseId ?? this.browseId,
      artistId: artistId ?? this.artistId,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      year: year ?? this.year,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      firstSeenAt: firstSeenAt ?? this.firstSeenAt,
      isNew: isNew ?? this.isNew,
      openedAt: openedAt ?? this.openedAt,
      groupKey: groupKey ?? this.groupKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (browseId.present) {
      map['browse_id'] = Variable<String>(browseId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>(kind.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (firstSeenAt.present) {
      map['first_seen_at'] = Variable<int>(firstSeenAt.value);
    }
    if (isNew.present) {
      map['is_new'] = Variable<bool>(isNew.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<int>(openedAt.value);
    }
    if (groupKey.present) {
      map['group_key'] = Variable<String>(groupKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistReleasesCompanion(')
          ..write('browseId: $browseId, ')
          ..write('artistId: $artistId, ')
          ..write('title: $title, ')
          ..write('kind: $kind, ')
          ..write('year: $year, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('firstSeenAt: $firstSeenAt, ')
          ..write('isNew: $isNew, ')
          ..write('openedAt: $openedAt, ')
          ..write('groupKey: $groupKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistLookupsTable extends ArtistLookups
    with TableInfo<$ArtistLookupsTable, ArtistLookup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistLookupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _artistKeyMeta = const VerificationMeta(
    'artistKey',
  );
  @override
  late final GeneratedColumn<String> artistKey = GeneratedColumn<String>(
    'artist_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ytmIdMeta = const VerificationMeta('ytmId');
  @override
  late final GeneratedColumn<String> ytmId = GeneratedColumn<String>(
    'ytm_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ytmNameMeta = const VerificationMeta(
    'ytmName',
  );
  @override
  late final GeneratedColumn<String> ytmName = GeneratedColumn<String>(
    'ytm_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbUrlMeta = const VerificationMeta(
    'thumbUrl',
  );
  @override
  late final GeneratedColumn<String> thumbUrl = GeneratedColumn<String>(
    'thumb_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<int> checkedAt = GeneratedColumn<int>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    artistKey,
    name,
    status,
    ytmId,
    ytmName,
    thumbUrl,
    checkedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artist_lookups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtistLookup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('artist_key')) {
      context.handle(
        _artistKeyMeta,
        artistKey.isAcceptableOrUnknown(data['artist_key']!, _artistKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_artistKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('ytm_id')) {
      context.handle(
        _ytmIdMeta,
        ytmId.isAcceptableOrUnknown(data['ytm_id']!, _ytmIdMeta),
      );
    }
    if (data.containsKey('ytm_name')) {
      context.handle(
        _ytmNameMeta,
        ytmName.isAcceptableOrUnknown(data['ytm_name']!, _ytmNameMeta),
      );
    }
    if (data.containsKey('thumb_url')) {
      context.handle(
        _thumbUrlMeta,
        thumbUrl.isAcceptableOrUnknown(data['thumb_url']!, _thumbUrlMeta),
      );
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artistKey};
  @override
  ArtistLookup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistLookup(
      artistKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      ytmId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ytm_id'],
      ),
      ytmName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ytm_name'],
      ),
      thumbUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_url'],
      ),
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $ArtistLookupsTable createAlias(String alias) {
    return $ArtistLookupsTable(attachedDatabase, alias);
  }
}

class ArtistLookup extends DataClass implements Insertable<ArtistLookup> {
  /// `matchKey` of the main artist's name.
  final String artistKey;
  final String name;

  /// 0 = one exact artist ([ytmId]), 1 = nobody, 2 = several (to confirm).
  final int status;
  final String? ytmId;
  final String? ytmName;
  final String? thumbUrl;
  final int checkedAt;
  const ArtistLookup({
    required this.artistKey,
    required this.name,
    required this.status,
    this.ytmId,
    this.ytmName,
    this.thumbUrl,
    required this.checkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['artist_key'] = Variable<String>(artistKey);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<int>(status);
    if (!nullToAbsent || ytmId != null) {
      map['ytm_id'] = Variable<String>(ytmId);
    }
    if (!nullToAbsent || ytmName != null) {
      map['ytm_name'] = Variable<String>(ytmName);
    }
    if (!nullToAbsent || thumbUrl != null) {
      map['thumb_url'] = Variable<String>(thumbUrl);
    }
    map['checked_at'] = Variable<int>(checkedAt);
    return map;
  }

  ArtistLookupsCompanion toCompanion(bool nullToAbsent) {
    return ArtistLookupsCompanion(
      artistKey: Value(artistKey),
      name: Value(name),
      status: Value(status),
      ytmId: ytmId == null && nullToAbsent
          ? const Value.absent()
          : Value(ytmId),
      ytmName: ytmName == null && nullToAbsent
          ? const Value.absent()
          : Value(ytmName),
      thumbUrl: thumbUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbUrl),
      checkedAt: Value(checkedAt),
    );
  }

  factory ArtistLookup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistLookup(
      artistKey: serializer.fromJson<String>(json['artistKey']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<int>(json['status']),
      ytmId: serializer.fromJson<String?>(json['ytmId']),
      ytmName: serializer.fromJson<String?>(json['ytmName']),
      thumbUrl: serializer.fromJson<String?>(json['thumbUrl']),
      checkedAt: serializer.fromJson<int>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'artistKey': serializer.toJson<String>(artistKey),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<int>(status),
      'ytmId': serializer.toJson<String?>(ytmId),
      'ytmName': serializer.toJson<String?>(ytmName),
      'thumbUrl': serializer.toJson<String?>(thumbUrl),
      'checkedAt': serializer.toJson<int>(checkedAt),
    };
  }

  ArtistLookup copyWith({
    String? artistKey,
    String? name,
    int? status,
    Value<String?> ytmId = const Value.absent(),
    Value<String?> ytmName = const Value.absent(),
    Value<String?> thumbUrl = const Value.absent(),
    int? checkedAt,
  }) => ArtistLookup(
    artistKey: artistKey ?? this.artistKey,
    name: name ?? this.name,
    status: status ?? this.status,
    ytmId: ytmId.present ? ytmId.value : this.ytmId,
    ytmName: ytmName.present ? ytmName.value : this.ytmName,
    thumbUrl: thumbUrl.present ? thumbUrl.value : this.thumbUrl,
    checkedAt: checkedAt ?? this.checkedAt,
  );
  ArtistLookup copyWithCompanion(ArtistLookupsCompanion data) {
    return ArtistLookup(
      artistKey: data.artistKey.present ? data.artistKey.value : this.artistKey,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      ytmId: data.ytmId.present ? data.ytmId.value : this.ytmId,
      ytmName: data.ytmName.present ? data.ytmName.value : this.ytmName,
      thumbUrl: data.thumbUrl.present ? data.thumbUrl.value : this.thumbUrl,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistLookup(')
          ..write('artistKey: $artistKey, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('ytmId: $ytmId, ')
          ..write('ytmName: $ytmName, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(artistKey, name, status, ytmId, ytmName, thumbUrl, checkedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistLookup &&
          other.artistKey == this.artistKey &&
          other.name == this.name &&
          other.status == this.status &&
          other.ytmId == this.ytmId &&
          other.ytmName == this.ytmName &&
          other.thumbUrl == this.thumbUrl &&
          other.checkedAt == this.checkedAt);
}

class ArtistLookupsCompanion extends UpdateCompanion<ArtistLookup> {
  final Value<String> artistKey;
  final Value<String> name;
  final Value<int> status;
  final Value<String?> ytmId;
  final Value<String?> ytmName;
  final Value<String?> thumbUrl;
  final Value<int> checkedAt;
  final Value<int> rowid;
  const ArtistLookupsCompanion({
    this.artistKey = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.ytmId = const Value.absent(),
    this.ytmName = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistLookupsCompanion.insert({
    required String artistKey,
    required String name,
    required int status,
    this.ytmId = const Value.absent(),
    this.ytmName = const Value.absent(),
    this.thumbUrl = const Value.absent(),
    required int checkedAt,
    this.rowid = const Value.absent(),
  }) : artistKey = Value(artistKey),
       name = Value(name),
       status = Value(status),
       checkedAt = Value(checkedAt);
  static Insertable<ArtistLookup> custom({
    Expression<String>? artistKey,
    Expression<String>? name,
    Expression<int>? status,
    Expression<String>? ytmId,
    Expression<String>? ytmName,
    Expression<String>? thumbUrl,
    Expression<int>? checkedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (artistKey != null) 'artist_key': artistKey,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (ytmId != null) 'ytm_id': ytmId,
      if (ytmName != null) 'ytm_name': ytmName,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistLookupsCompanion copyWith({
    Value<String>? artistKey,
    Value<String>? name,
    Value<int>? status,
    Value<String?>? ytmId,
    Value<String?>? ytmName,
    Value<String?>? thumbUrl,
    Value<int>? checkedAt,
    Value<int>? rowid,
  }) {
    return ArtistLookupsCompanion(
      artistKey: artistKey ?? this.artistKey,
      name: name ?? this.name,
      status: status ?? this.status,
      ytmId: ytmId ?? this.ytmId,
      ytmName: ytmName ?? this.ytmName,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      checkedAt: checkedAt ?? this.checkedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (artistKey.present) {
      map['artist_key'] = Variable<String>(artistKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (ytmId.present) {
      map['ytm_id'] = Variable<String>(ytmId.value);
    }
    if (ytmName.present) {
      map['ytm_name'] = Variable<String>(ytmName.value);
    }
    if (thumbUrl.present) {
      map['thumb_url'] = Variable<String>(thumbUrl.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<int>(checkedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistLookupsCompanion(')
          ..write('artistKey: $artistKey, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('ytmId: $ytmId, ')
          ..write('ytmName: $ytmName, ')
          ..write('thumbUrl: $thumbUrl, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackCreditsTable extends TrackCredits
    with TableInfo<$TrackCreditsTable, TrackCreditRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackCreditsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameKeyMeta = const VerificationMeta(
    'nameKey',
  );
  @override
  late final GeneratedColumn<String> nameKey = GeneratedColumn<String>(
    'name_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, name, nameKey, role, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_credits';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackCreditRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('name_key')) {
      context.handle(
        _nameKeyMeta,
        nameKey.isAcceptableOrUnknown(data['name_key']!, _nameKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_nameKeyMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId, nameKey, role};
  @override
  TrackCreditRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackCreditRow(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      nameKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name_key'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $TrackCreditsTable createAlias(String alias) {
    return $TrackCreditsTable(attachedDatabase, alias);
  }
}

class TrackCreditRow extends DataClass implements Insertable<TrackCreditRow> {
  final int trackId;
  final String name;
  final String nameKey;
  final String role;
  final String source;
  const TrackCreditRow({
    required this.trackId,
    required this.name,
    required this.nameKey,
    required this.role,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['name'] = Variable<String>(name);
    map['name_key'] = Variable<String>(nameKey);
    map['role'] = Variable<String>(role);
    map['source'] = Variable<String>(source);
    return map;
  }

  TrackCreditsCompanion toCompanion(bool nullToAbsent) {
    return TrackCreditsCompanion(
      trackId: Value(trackId),
      name: Value(name),
      nameKey: Value(nameKey),
      role: Value(role),
      source: Value(source),
    );
  }

  factory TrackCreditRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackCreditRow(
      trackId: serializer.fromJson<int>(json['trackId']),
      name: serializer.fromJson<String>(json['name']),
      nameKey: serializer.fromJson<String>(json['nameKey']),
      role: serializer.fromJson<String>(json['role']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'name': serializer.toJson<String>(name),
      'nameKey': serializer.toJson<String>(nameKey),
      'role': serializer.toJson<String>(role),
      'source': serializer.toJson<String>(source),
    };
  }

  TrackCreditRow copyWith({
    int? trackId,
    String? name,
    String? nameKey,
    String? role,
    String? source,
  }) => TrackCreditRow(
    trackId: trackId ?? this.trackId,
    name: name ?? this.name,
    nameKey: nameKey ?? this.nameKey,
    role: role ?? this.role,
    source: source ?? this.source,
  );
  TrackCreditRow copyWithCompanion(TrackCreditsCompanion data) {
    return TrackCreditRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      name: data.name.present ? data.name.value : this.name,
      nameKey: data.nameKey.present ? data.nameKey.value : this.nameKey,
      role: data.role.present ? data.role.value : this.role,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackCreditRow(')
          ..write('trackId: $trackId, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('role: $role, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, name, nameKey, role, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackCreditRow &&
          other.trackId == this.trackId &&
          other.name == this.name &&
          other.nameKey == this.nameKey &&
          other.role == this.role &&
          other.source == this.source);
}

class TrackCreditsCompanion extends UpdateCompanion<TrackCreditRow> {
  final Value<int> trackId;
  final Value<String> name;
  final Value<String> nameKey;
  final Value<String> role;
  final Value<String> source;
  final Value<int> rowid;
  const TrackCreditsCompanion({
    this.trackId = const Value.absent(),
    this.name = const Value.absent(),
    this.nameKey = const Value.absent(),
    this.role = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackCreditsCompanion.insert({
    required int trackId,
    required String name,
    required String nameKey,
    required String role,
    required String source,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       name = Value(name),
       nameKey = Value(nameKey),
       role = Value(role),
       source = Value(source);
  static Insertable<TrackCreditRow> custom({
    Expression<int>? trackId,
    Expression<String>? name,
    Expression<String>? nameKey,
    Expression<String>? role,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (name != null) 'name': name,
      if (nameKey != null) 'name_key': nameKey,
      if (role != null) 'role': role,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackCreditsCompanion copyWith({
    Value<int>? trackId,
    Value<String>? name,
    Value<String>? nameKey,
    Value<String>? role,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return TrackCreditsCompanion(
      trackId: trackId ?? this.trackId,
      name: name ?? this.name,
      nameKey: nameKey ?? this.nameKey,
      role: role ?? this.role,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (nameKey.present) {
      map['name_key'] = Variable<String>(nameKey.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackCreditsCompanion(')
          ..write('trackId: $trackId, ')
          ..write('name: $name, ')
          ..write('nameKey: $nameKey, ')
          ..write('role: $role, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrackEnrichTable extends TrackEnrich
    with TableInfo<$TrackEnrichTable, TrackEnrichData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackEnrichTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deezerIdMeta = const VerificationMeta(
    'deezerId',
  );
  @override
  late final GeneratedColumn<int> deezerId = GeneratedColumn<int>(
    'deezer_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mbidMeta = const VerificationMeta('mbid');
  @override
  late final GeneratedColumn<String> mbid = GeneratedColumn<String>(
    'mbid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metaNoneAtMeta = const VerificationMeta(
    'metaNoneAt',
  );
  @override
  late final GeneratedColumn<int> metaNoneAt = GeneratedColumn<int>(
    'meta_none_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsNoneAtMeta = const VerificationMeta(
    'lyricsNoneAt',
  );
  @override
  late final GeneratedColumn<int> lyricsNoneAt = GeneratedColumn<int>(
    'lyrics_none_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedNoneAtMeta = const VerificationMeta(
    'syncedNoneAt',
  );
  @override
  late final GeneratedColumn<int> syncedNoneAt = GeneratedColumn<int>(
    'synced_none_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _curioNoneAtMeta = const VerificationMeta(
    'curioNoneAt',
  );
  @override
  late final GeneratedColumn<int> curioNoneAt = GeneratedColumn<int>(
    'curio_none_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditsNoneAtMeta = const VerificationMeta(
    'creditsNoneAt',
  );
  @override
  late final GeneratedColumn<int> creditsNoneAt = GeneratedColumn<int>(
    'credits_none_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lyricsByUserMeta = const VerificationMeta(
    'lyricsByUser',
  );
  @override
  late final GeneratedColumn<bool> lyricsByUser = GeneratedColumn<bool>(
    'lyrics_by_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lyrics_by_user" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    trackId,
    details,
    deezerId,
    mbid,
    metaNoneAt,
    lyricsNoneAt,
    syncedNoneAt,
    curioNoneAt,
    creditsNoneAt,
    lyricsByUser,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_enrich';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackEnrichData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('deezer_id')) {
      context.handle(
        _deezerIdMeta,
        deezerId.isAcceptableOrUnknown(data['deezer_id']!, _deezerIdMeta),
      );
    }
    if (data.containsKey('mbid')) {
      context.handle(
        _mbidMeta,
        mbid.isAcceptableOrUnknown(data['mbid']!, _mbidMeta),
      );
    }
    if (data.containsKey('meta_none_at')) {
      context.handle(
        _metaNoneAtMeta,
        metaNoneAt.isAcceptableOrUnknown(
          data['meta_none_at']!,
          _metaNoneAtMeta,
        ),
      );
    }
    if (data.containsKey('lyrics_none_at')) {
      context.handle(
        _lyricsNoneAtMeta,
        lyricsNoneAt.isAcceptableOrUnknown(
          data['lyrics_none_at']!,
          _lyricsNoneAtMeta,
        ),
      );
    }
    if (data.containsKey('synced_none_at')) {
      context.handle(
        _syncedNoneAtMeta,
        syncedNoneAt.isAcceptableOrUnknown(
          data['synced_none_at']!,
          _syncedNoneAtMeta,
        ),
      );
    }
    if (data.containsKey('curio_none_at')) {
      context.handle(
        _curioNoneAtMeta,
        curioNoneAt.isAcceptableOrUnknown(
          data['curio_none_at']!,
          _curioNoneAtMeta,
        ),
      );
    }
    if (data.containsKey('credits_none_at')) {
      context.handle(
        _creditsNoneAtMeta,
        creditsNoneAt.isAcceptableOrUnknown(
          data['credits_none_at']!,
          _creditsNoneAtMeta,
        ),
      );
    }
    if (data.containsKey('lyrics_by_user')) {
      context.handle(
        _lyricsByUserMeta,
        lyricsByUser.isAcceptableOrUnknown(
          data['lyrics_by_user']!,
          _lyricsByUserMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId};
  @override
  TrackEnrichData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackEnrichData(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
      deezerId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deezer_id'],
      ),
      mbid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mbid'],
      ),
      metaNoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meta_none_at'],
      ),
      lyricsNoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lyrics_none_at'],
      ),
      syncedNoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}synced_none_at'],
      ),
      curioNoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}curio_none_at'],
      ),
      creditsNoneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credits_none_at'],
      ),
      lyricsByUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lyrics_by_user'],
      )!,
    );
  }

  @override
  $TrackEnrichTable createAlias(String alias) {
    return $TrackEnrichTable(attachedDatabase, alias);
  }
}

class TrackEnrichData extends DataClass implements Insertable<TrackEnrichData> {
  final int trackId;
  final String? details;
  final int? deezerId;
  final String? mbid;
  final int? metaNoneAt;
  final int? lyricsNoneAt;
  final int? syncedNoneAt;
  final int? curioNoneAt;
  final int? creditsNoneAt;
  final bool lyricsByUser;
  const TrackEnrichData({
    required this.trackId,
    this.details,
    this.deezerId,
    this.mbid,
    this.metaNoneAt,
    this.lyricsNoneAt,
    this.syncedNoneAt,
    this.curioNoneAt,
    this.creditsNoneAt,
    required this.lyricsByUser,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    if (!nullToAbsent || deezerId != null) {
      map['deezer_id'] = Variable<int>(deezerId);
    }
    if (!nullToAbsent || mbid != null) {
      map['mbid'] = Variable<String>(mbid);
    }
    if (!nullToAbsent || metaNoneAt != null) {
      map['meta_none_at'] = Variable<int>(metaNoneAt);
    }
    if (!nullToAbsent || lyricsNoneAt != null) {
      map['lyrics_none_at'] = Variable<int>(lyricsNoneAt);
    }
    if (!nullToAbsent || syncedNoneAt != null) {
      map['synced_none_at'] = Variable<int>(syncedNoneAt);
    }
    if (!nullToAbsent || curioNoneAt != null) {
      map['curio_none_at'] = Variable<int>(curioNoneAt);
    }
    if (!nullToAbsent || creditsNoneAt != null) {
      map['credits_none_at'] = Variable<int>(creditsNoneAt);
    }
    map['lyrics_by_user'] = Variable<bool>(lyricsByUser);
    return map;
  }

  TrackEnrichCompanion toCompanion(bool nullToAbsent) {
    return TrackEnrichCompanion(
      trackId: Value(trackId),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      deezerId: deezerId == null && nullToAbsent
          ? const Value.absent()
          : Value(deezerId),
      mbid: mbid == null && nullToAbsent ? const Value.absent() : Value(mbid),
      metaNoneAt: metaNoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(metaNoneAt),
      lyricsNoneAt: lyricsNoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lyricsNoneAt),
      syncedNoneAt: syncedNoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedNoneAt),
      curioNoneAt: curioNoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(curioNoneAt),
      creditsNoneAt: creditsNoneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(creditsNoneAt),
      lyricsByUser: Value(lyricsByUser),
    );
  }

  factory TrackEnrichData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackEnrichData(
      trackId: serializer.fromJson<int>(json['trackId']),
      details: serializer.fromJson<String?>(json['details']),
      deezerId: serializer.fromJson<int?>(json['deezerId']),
      mbid: serializer.fromJson<String?>(json['mbid']),
      metaNoneAt: serializer.fromJson<int?>(json['metaNoneAt']),
      lyricsNoneAt: serializer.fromJson<int?>(json['lyricsNoneAt']),
      syncedNoneAt: serializer.fromJson<int?>(json['syncedNoneAt']),
      curioNoneAt: serializer.fromJson<int?>(json['curioNoneAt']),
      creditsNoneAt: serializer.fromJson<int?>(json['creditsNoneAt']),
      lyricsByUser: serializer.fromJson<bool>(json['lyricsByUser']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'details': serializer.toJson<String?>(details),
      'deezerId': serializer.toJson<int?>(deezerId),
      'mbid': serializer.toJson<String?>(mbid),
      'metaNoneAt': serializer.toJson<int?>(metaNoneAt),
      'lyricsNoneAt': serializer.toJson<int?>(lyricsNoneAt),
      'syncedNoneAt': serializer.toJson<int?>(syncedNoneAt),
      'curioNoneAt': serializer.toJson<int?>(curioNoneAt),
      'creditsNoneAt': serializer.toJson<int?>(creditsNoneAt),
      'lyricsByUser': serializer.toJson<bool>(lyricsByUser),
    };
  }

  TrackEnrichData copyWith({
    int? trackId,
    Value<String?> details = const Value.absent(),
    Value<int?> deezerId = const Value.absent(),
    Value<String?> mbid = const Value.absent(),
    Value<int?> metaNoneAt = const Value.absent(),
    Value<int?> lyricsNoneAt = const Value.absent(),
    Value<int?> syncedNoneAt = const Value.absent(),
    Value<int?> curioNoneAt = const Value.absent(),
    Value<int?> creditsNoneAt = const Value.absent(),
    bool? lyricsByUser,
  }) => TrackEnrichData(
    trackId: trackId ?? this.trackId,
    details: details.present ? details.value : this.details,
    deezerId: deezerId.present ? deezerId.value : this.deezerId,
    mbid: mbid.present ? mbid.value : this.mbid,
    metaNoneAt: metaNoneAt.present ? metaNoneAt.value : this.metaNoneAt,
    lyricsNoneAt: lyricsNoneAt.present ? lyricsNoneAt.value : this.lyricsNoneAt,
    syncedNoneAt: syncedNoneAt.present ? syncedNoneAt.value : this.syncedNoneAt,
    curioNoneAt: curioNoneAt.present ? curioNoneAt.value : this.curioNoneAt,
    creditsNoneAt: creditsNoneAt.present
        ? creditsNoneAt.value
        : this.creditsNoneAt,
    lyricsByUser: lyricsByUser ?? this.lyricsByUser,
  );
  TrackEnrichData copyWithCompanion(TrackEnrichCompanion data) {
    return TrackEnrichData(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      details: data.details.present ? data.details.value : this.details,
      deezerId: data.deezerId.present ? data.deezerId.value : this.deezerId,
      mbid: data.mbid.present ? data.mbid.value : this.mbid,
      metaNoneAt: data.metaNoneAt.present
          ? data.metaNoneAt.value
          : this.metaNoneAt,
      lyricsNoneAt: data.lyricsNoneAt.present
          ? data.lyricsNoneAt.value
          : this.lyricsNoneAt,
      syncedNoneAt: data.syncedNoneAt.present
          ? data.syncedNoneAt.value
          : this.syncedNoneAt,
      curioNoneAt: data.curioNoneAt.present
          ? data.curioNoneAt.value
          : this.curioNoneAt,
      creditsNoneAt: data.creditsNoneAt.present
          ? data.creditsNoneAt.value
          : this.creditsNoneAt,
      lyricsByUser: data.lyricsByUser.present
          ? data.lyricsByUser.value
          : this.lyricsByUser,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackEnrichData(')
          ..write('trackId: $trackId, ')
          ..write('details: $details, ')
          ..write('deezerId: $deezerId, ')
          ..write('mbid: $mbid, ')
          ..write('metaNoneAt: $metaNoneAt, ')
          ..write('lyricsNoneAt: $lyricsNoneAt, ')
          ..write('syncedNoneAt: $syncedNoneAt, ')
          ..write('curioNoneAt: $curioNoneAt, ')
          ..write('creditsNoneAt: $creditsNoneAt, ')
          ..write('lyricsByUser: $lyricsByUser')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trackId,
    details,
    deezerId,
    mbid,
    metaNoneAt,
    lyricsNoneAt,
    syncedNoneAt,
    curioNoneAt,
    creditsNoneAt,
    lyricsByUser,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackEnrichData &&
          other.trackId == this.trackId &&
          other.details == this.details &&
          other.deezerId == this.deezerId &&
          other.mbid == this.mbid &&
          other.metaNoneAt == this.metaNoneAt &&
          other.lyricsNoneAt == this.lyricsNoneAt &&
          other.syncedNoneAt == this.syncedNoneAt &&
          other.curioNoneAt == this.curioNoneAt &&
          other.creditsNoneAt == this.creditsNoneAt &&
          other.lyricsByUser == this.lyricsByUser);
}

class TrackEnrichCompanion extends UpdateCompanion<TrackEnrichData> {
  final Value<int> trackId;
  final Value<String?> details;
  final Value<int?> deezerId;
  final Value<String?> mbid;
  final Value<int?> metaNoneAt;
  final Value<int?> lyricsNoneAt;
  final Value<int?> syncedNoneAt;
  final Value<int?> curioNoneAt;
  final Value<int?> creditsNoneAt;
  final Value<bool> lyricsByUser;
  const TrackEnrichCompanion({
    this.trackId = const Value.absent(),
    this.details = const Value.absent(),
    this.deezerId = const Value.absent(),
    this.mbid = const Value.absent(),
    this.metaNoneAt = const Value.absent(),
    this.lyricsNoneAt = const Value.absent(),
    this.syncedNoneAt = const Value.absent(),
    this.curioNoneAt = const Value.absent(),
    this.creditsNoneAt = const Value.absent(),
    this.lyricsByUser = const Value.absent(),
  });
  TrackEnrichCompanion.insert({
    this.trackId = const Value.absent(),
    this.details = const Value.absent(),
    this.deezerId = const Value.absent(),
    this.mbid = const Value.absent(),
    this.metaNoneAt = const Value.absent(),
    this.lyricsNoneAt = const Value.absent(),
    this.syncedNoneAt = const Value.absent(),
    this.curioNoneAt = const Value.absent(),
    this.creditsNoneAt = const Value.absent(),
    this.lyricsByUser = const Value.absent(),
  });
  static Insertable<TrackEnrichData> custom({
    Expression<int>? trackId,
    Expression<String>? details,
    Expression<int>? deezerId,
    Expression<String>? mbid,
    Expression<int>? metaNoneAt,
    Expression<int>? lyricsNoneAt,
    Expression<int>? syncedNoneAt,
    Expression<int>? curioNoneAt,
    Expression<int>? creditsNoneAt,
    Expression<bool>? lyricsByUser,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (details != null) 'details': details,
      if (deezerId != null) 'deezer_id': deezerId,
      if (mbid != null) 'mbid': mbid,
      if (metaNoneAt != null) 'meta_none_at': metaNoneAt,
      if (lyricsNoneAt != null) 'lyrics_none_at': lyricsNoneAt,
      if (syncedNoneAt != null) 'synced_none_at': syncedNoneAt,
      if (curioNoneAt != null) 'curio_none_at': curioNoneAt,
      if (creditsNoneAt != null) 'credits_none_at': creditsNoneAt,
      if (lyricsByUser != null) 'lyrics_by_user': lyricsByUser,
    });
  }

  TrackEnrichCompanion copyWith({
    Value<int>? trackId,
    Value<String?>? details,
    Value<int?>? deezerId,
    Value<String?>? mbid,
    Value<int?>? metaNoneAt,
    Value<int?>? lyricsNoneAt,
    Value<int?>? syncedNoneAt,
    Value<int?>? curioNoneAt,
    Value<int?>? creditsNoneAt,
    Value<bool>? lyricsByUser,
  }) {
    return TrackEnrichCompanion(
      trackId: trackId ?? this.trackId,
      details: details ?? this.details,
      deezerId: deezerId ?? this.deezerId,
      mbid: mbid ?? this.mbid,
      metaNoneAt: metaNoneAt ?? this.metaNoneAt,
      lyricsNoneAt: lyricsNoneAt ?? this.lyricsNoneAt,
      syncedNoneAt: syncedNoneAt ?? this.syncedNoneAt,
      curioNoneAt: curioNoneAt ?? this.curioNoneAt,
      creditsNoneAt: creditsNoneAt ?? this.creditsNoneAt,
      lyricsByUser: lyricsByUser ?? this.lyricsByUser,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (deezerId.present) {
      map['deezer_id'] = Variable<int>(deezerId.value);
    }
    if (mbid.present) {
      map['mbid'] = Variable<String>(mbid.value);
    }
    if (metaNoneAt.present) {
      map['meta_none_at'] = Variable<int>(metaNoneAt.value);
    }
    if (lyricsNoneAt.present) {
      map['lyrics_none_at'] = Variable<int>(lyricsNoneAt.value);
    }
    if (syncedNoneAt.present) {
      map['synced_none_at'] = Variable<int>(syncedNoneAt.value);
    }
    if (curioNoneAt.present) {
      map['curio_none_at'] = Variable<int>(curioNoneAt.value);
    }
    if (creditsNoneAt.present) {
      map['credits_none_at'] = Variable<int>(creditsNoneAt.value);
    }
    if (lyricsByUser.present) {
      map['lyrics_by_user'] = Variable<bool>(lyricsByUser.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackEnrichCompanion(')
          ..write('trackId: $trackId, ')
          ..write('details: $details, ')
          ..write('deezerId: $deezerId, ')
          ..write('mbid: $mbid, ')
          ..write('metaNoneAt: $metaNoneAt, ')
          ..write('lyricsNoneAt: $lyricsNoneAt, ')
          ..write('syncedNoneAt: $syncedNoneAt, ')
          ..write('curioNoneAt: $curioNoneAt, ')
          ..write('creditsNoneAt: $creditsNoneAt, ')
          ..write('lyricsByUser: $lyricsByUser')
          ..write(')'))
        .toString();
  }
}

class $ActivityLogRowsTable extends ActivityLogRows
    with TableInfo<$ActivityLogRowsTable, ActivityLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ActivityLogRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<int> at = GeneratedColumn<int>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doneMeta = const VerificationMeta('done');
  @override
  late final GeneratedColumn<int> done = GeneratedColumn<int>(
    'done',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _failedMeta = const VerificationMeta('failed');
  @override
  late final GeneratedColumn<int> failed = GeneratedColumn<int>(
    'failed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _detailMeta = const VerificationMeta('detail');
  @override
  late final GeneratedColumn<String> detail = GeneratedColumn<String>(
    'detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    at,
    kind,
    name,
    done,
    total,
    failed,
    detail,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'activity_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ActivityLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('done')) {
      context.handle(
        _doneMeta,
        done.isAcceptableOrUnknown(data['done']!, _doneMeta),
      );
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    }
    if (data.containsKey('failed')) {
      context.handle(
        _failedMeta,
        failed.isAcceptableOrUnknown(data['failed']!, _failedMeta),
      );
    }
    if (data.containsKey('detail')) {
      context.handle(
        _detailMeta,
        detail.isAcceptableOrUnknown(data['detail']!, _detailMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ActivityLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ActivityLogRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}at'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      done: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      failed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failed'],
      )!,
      detail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detail'],
      ),
    );
  }

  @override
  $ActivityLogRowsTable createAlias(String alias) {
    return $ActivityLogRowsTable(attachedDatabase, alias);
  }
}

class ActivityLogRow extends DataClass implements Insertable<ActivityLogRow> {
  final int id;
  final int at;
  final String kind;
  final String name;
  final int done;
  final int total;
  final int failed;
  final String? detail;
  const ActivityLogRow({
    required this.id,
    required this.at,
    required this.kind,
    required this.name,
    required this.done,
    required this.total,
    required this.failed,
    this.detail,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['at'] = Variable<int>(at);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    map['done'] = Variable<int>(done);
    map['total'] = Variable<int>(total);
    map['failed'] = Variable<int>(failed);
    if (!nullToAbsent || detail != null) {
      map['detail'] = Variable<String>(detail);
    }
    return map;
  }

  ActivityLogRowsCompanion toCompanion(bool nullToAbsent) {
    return ActivityLogRowsCompanion(
      id: Value(id),
      at: Value(at),
      kind: Value(kind),
      name: Value(name),
      done: Value(done),
      total: Value(total),
      failed: Value(failed),
      detail: detail == null && nullToAbsent
          ? const Value.absent()
          : Value(detail),
    );
  }

  factory ActivityLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ActivityLogRow(
      id: serializer.fromJson<int>(json['id']),
      at: serializer.fromJson<int>(json['at']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      done: serializer.fromJson<int>(json['done']),
      total: serializer.fromJson<int>(json['total']),
      failed: serializer.fromJson<int>(json['failed']),
      detail: serializer.fromJson<String?>(json['detail']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'at': serializer.toJson<int>(at),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'done': serializer.toJson<int>(done),
      'total': serializer.toJson<int>(total),
      'failed': serializer.toJson<int>(failed),
      'detail': serializer.toJson<String?>(detail),
    };
  }

  ActivityLogRow copyWith({
    int? id,
    int? at,
    String? kind,
    String? name,
    int? done,
    int? total,
    int? failed,
    Value<String?> detail = const Value.absent(),
  }) => ActivityLogRow(
    id: id ?? this.id,
    at: at ?? this.at,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    done: done ?? this.done,
    total: total ?? this.total,
    failed: failed ?? this.failed,
    detail: detail.present ? detail.value : this.detail,
  );
  ActivityLogRow copyWithCompanion(ActivityLogRowsCompanion data) {
    return ActivityLogRow(
      id: data.id.present ? data.id.value : this.id,
      at: data.at.present ? data.at.value : this.at,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      done: data.done.present ? data.done.value : this.done,
      total: data.total.present ? data.total.value : this.total,
      failed: data.failed.present ? data.failed.value : this.failed,
      detail: data.detail.present ? data.detail.value : this.detail,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLogRow(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('done: $done, ')
          ..write('total: $total, ')
          ..write('failed: $failed, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, at, kind, name, done, total, failed, detail);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ActivityLogRow &&
          other.id == this.id &&
          other.at == this.at &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.done == this.done &&
          other.total == this.total &&
          other.failed == this.failed &&
          other.detail == this.detail);
}

class ActivityLogRowsCompanion extends UpdateCompanion<ActivityLogRow> {
  final Value<int> id;
  final Value<int> at;
  final Value<String> kind;
  final Value<String> name;
  final Value<int> done;
  final Value<int> total;
  final Value<int> failed;
  final Value<String?> detail;
  const ActivityLogRowsCompanion({
    this.id = const Value.absent(),
    this.at = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.done = const Value.absent(),
    this.total = const Value.absent(),
    this.failed = const Value.absent(),
    this.detail = const Value.absent(),
  });
  ActivityLogRowsCompanion.insert({
    this.id = const Value.absent(),
    required int at,
    required String kind,
    required String name,
    this.done = const Value.absent(),
    this.total = const Value.absent(),
    this.failed = const Value.absent(),
    this.detail = const Value.absent(),
  }) : at = Value(at),
       kind = Value(kind),
       name = Value(name);
  static Insertable<ActivityLogRow> custom({
    Expression<int>? id,
    Expression<int>? at,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? done,
    Expression<int>? total,
    Expression<int>? failed,
    Expression<String>? detail,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (at != null) 'at': at,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (done != null) 'done': done,
      if (total != null) 'total': total,
      if (failed != null) 'failed': failed,
      if (detail != null) 'detail': detail,
    });
  }

  ActivityLogRowsCompanion copyWith({
    Value<int>? id,
    Value<int>? at,
    Value<String>? kind,
    Value<String>? name,
    Value<int>? done,
    Value<int>? total,
    Value<int>? failed,
    Value<String?>? detail,
  }) {
    return ActivityLogRowsCompanion(
      id: id ?? this.id,
      at: at ?? this.at,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      done: done ?? this.done,
      total: total ?? this.total,
      failed: failed ?? this.failed,
      detail: detail ?? this.detail,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (at.present) {
      map['at'] = Variable<int>(at.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (done.present) {
      map['done'] = Variable<int>(done.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (failed.present) {
      map['failed'] = Variable<int>(failed.value);
    }
    if (detail.present) {
      map['detail'] = Variable<String>(detail.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ActivityLogRowsCompanion(')
          ..write('id: $id, ')
          ..write('at: $at, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('done: $done, ')
          ..write('total: $total, ')
          ..write('failed: $failed, ')
          ..write('detail: $detail')
          ..write(')'))
        .toString();
  }
}

class $TrackGenresTable extends TrackGenres
    with TableInfo<$TrackGenresTable, TrackGenreRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackGenresTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackIdMeta = const VerificationMeta(
    'trackId',
  );
  @override
  late final GeneratedColumn<int> trackId = GeneratedColumn<int>(
    'track_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tracks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
    'genre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL COLLATE NOCASE',
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trackId, genre, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_genres';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrackGenreRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_id')) {
      context.handle(
        _trackIdMeta,
        trackId.isAcceptableOrUnknown(data['track_id']!, _trackIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trackIdMeta);
    }
    if (data.containsKey('genre')) {
      context.handle(
        _genreMeta,
        genre.isAcceptableOrUnknown(data['genre']!, _genreMeta),
      );
    } else if (isInserting) {
      context.missing(_genreMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackId, position};
  @override
  TrackGenreRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackGenreRow(
      trackId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}track_id'],
      )!,
      genre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}genre'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $TrackGenresTable createAlias(String alias) {
    return $TrackGenresTable(attachedDatabase, alias);
  }
}

class TrackGenreRow extends DataClass implements Insertable<TrackGenreRow> {
  final int trackId;

  /// Trimmed, as in the tag; compared ignoring case (the index too).
  final String genre;
  final int position;
  const TrackGenreRow({
    required this.trackId,
    required this.genre,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_id'] = Variable<int>(trackId);
    map['genre'] = Variable<String>(genre);
    map['position'] = Variable<int>(position);
    return map;
  }

  TrackGenresCompanion toCompanion(bool nullToAbsent) {
    return TrackGenresCompanion(
      trackId: Value(trackId),
      genre: Value(genre),
      position: Value(position),
    );
  }

  factory TrackGenreRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackGenreRow(
      trackId: serializer.fromJson<int>(json['trackId']),
      genre: serializer.fromJson<String>(json['genre']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackId': serializer.toJson<int>(trackId),
      'genre': serializer.toJson<String>(genre),
      'position': serializer.toJson<int>(position),
    };
  }

  TrackGenreRow copyWith({int? trackId, String? genre, int? position}) =>
      TrackGenreRow(
        trackId: trackId ?? this.trackId,
        genre: genre ?? this.genre,
        position: position ?? this.position,
      );
  TrackGenreRow copyWithCompanion(TrackGenresCompanion data) {
    return TrackGenreRow(
      trackId: data.trackId.present ? data.trackId.value : this.trackId,
      genre: data.genre.present ? data.genre.value : this.genre,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackGenreRow(')
          ..write('trackId: $trackId, ')
          ..write('genre: $genre, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackId, genre, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackGenreRow &&
          other.trackId == this.trackId &&
          other.genre == this.genre &&
          other.position == this.position);
}

class TrackGenresCompanion extends UpdateCompanion<TrackGenreRow> {
  final Value<int> trackId;
  final Value<String> genre;
  final Value<int> position;
  final Value<int> rowid;
  const TrackGenresCompanion({
    this.trackId = const Value.absent(),
    this.genre = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackGenresCompanion.insert({
    required int trackId,
    required String genre,
    required int position,
    this.rowid = const Value.absent(),
  }) : trackId = Value(trackId),
       genre = Value(genre),
       position = Value(position);
  static Insertable<TrackGenreRow> custom({
    Expression<int>? trackId,
    Expression<String>? genre,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackId != null) 'track_id': trackId,
      if (genre != null) 'genre': genre,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackGenresCompanion copyWith({
    Value<int>? trackId,
    Value<String>? genre,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return TrackGenresCompanion(
      trackId: trackId ?? this.trackId,
      genre: genre ?? this.genre,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackId.present) {
      map['track_id'] = Variable<int>(trackId.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackGenresCompanion(')
          ..write('trackId: $trackId, ')
          ..write('genre: $genre, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistCountriesTable extends ArtistCountries
    with TableInfo<$ArtistCountriesTable, ArtistCountry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistCountriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _artistKeyMeta = const VerificationMeta(
    'artistKey',
  );
  @override
  late final GeneratedColumn<String> artistKey = GeneratedColumn<String>(
    'artist_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countryMeta = const VerificationMeta(
    'country',
  );
  @override
  late final GeneratedColumn<String> country = GeneratedColumn<String>(
    'country',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<int> checkedAt = GeneratedColumn<int>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [artistKey, country, source, checkedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artist_countries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtistCountry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('artist_key')) {
      context.handle(
        _artistKeyMeta,
        artistKey.isAcceptableOrUnknown(data['artist_key']!, _artistKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_artistKeyMeta);
    }
    if (data.containsKey('country')) {
      context.handle(
        _countryMeta,
        country.isAcceptableOrUnknown(data['country']!, _countryMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {artistKey};
  @override
  ArtistCountry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistCountry(
      artistKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}artist_key'],
      )!,
      country: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}country'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      ),
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $ArtistCountriesTable createAlias(String alias) {
    return $ArtistCountriesTable(attachedDatabase, alias);
  }
}

class ArtistCountry extends DataClass implements Insertable<ArtistCountry> {
  final String artistKey;

  /// ISO 3166-1 alpha-2.
  final String? country;

  /// `musicbrainz` / `wikidata`; null when nothing answered.
  final String? source;
  final int checkedAt;
  const ArtistCountry({
    required this.artistKey,
    this.country,
    this.source,
    required this.checkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['artist_key'] = Variable<String>(artistKey);
    if (!nullToAbsent || country != null) {
      map['country'] = Variable<String>(country);
    }
    if (!nullToAbsent || source != null) {
      map['source'] = Variable<String>(source);
    }
    map['checked_at'] = Variable<int>(checkedAt);
    return map;
  }

  ArtistCountriesCompanion toCompanion(bool nullToAbsent) {
    return ArtistCountriesCompanion(
      artistKey: Value(artistKey),
      country: country == null && nullToAbsent
          ? const Value.absent()
          : Value(country),
      source: source == null && nullToAbsent
          ? const Value.absent()
          : Value(source),
      checkedAt: Value(checkedAt),
    );
  }

  factory ArtistCountry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistCountry(
      artistKey: serializer.fromJson<String>(json['artistKey']),
      country: serializer.fromJson<String?>(json['country']),
      source: serializer.fromJson<String?>(json['source']),
      checkedAt: serializer.fromJson<int>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'artistKey': serializer.toJson<String>(artistKey),
      'country': serializer.toJson<String?>(country),
      'source': serializer.toJson<String?>(source),
      'checkedAt': serializer.toJson<int>(checkedAt),
    };
  }

  ArtistCountry copyWith({
    String? artistKey,
    Value<String?> country = const Value.absent(),
    Value<String?> source = const Value.absent(),
    int? checkedAt,
  }) => ArtistCountry(
    artistKey: artistKey ?? this.artistKey,
    country: country.present ? country.value : this.country,
    source: source.present ? source.value : this.source,
    checkedAt: checkedAt ?? this.checkedAt,
  );
  ArtistCountry copyWithCompanion(ArtistCountriesCompanion data) {
    return ArtistCountry(
      artistKey: data.artistKey.present ? data.artistKey.value : this.artistKey,
      country: data.country.present ? data.country.value : this.country,
      source: data.source.present ? data.source.value : this.source,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistCountry(')
          ..write('artistKey: $artistKey, ')
          ..write('country: $country, ')
          ..write('source: $source, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(artistKey, country, source, checkedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistCountry &&
          other.artistKey == this.artistKey &&
          other.country == this.country &&
          other.source == this.source &&
          other.checkedAt == this.checkedAt);
}

class ArtistCountriesCompanion extends UpdateCompanion<ArtistCountry> {
  final Value<String> artistKey;
  final Value<String?> country;
  final Value<String?> source;
  final Value<int> checkedAt;
  final Value<int> rowid;
  const ArtistCountriesCompanion({
    this.artistKey = const Value.absent(),
    this.country = const Value.absent(),
    this.source = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistCountriesCompanion.insert({
    required String artistKey,
    this.country = const Value.absent(),
    this.source = const Value.absent(),
    required int checkedAt,
    this.rowid = const Value.absent(),
  }) : artistKey = Value(artistKey),
       checkedAt = Value(checkedAt);
  static Insertable<ArtistCountry> custom({
    Expression<String>? artistKey,
    Expression<String>? country,
    Expression<String>? source,
    Expression<int>? checkedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (artistKey != null) 'artist_key': artistKey,
      if (country != null) 'country': country,
      if (source != null) 'source': source,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistCountriesCompanion copyWith({
    Value<String>? artistKey,
    Value<String?>? country,
    Value<String?>? source,
    Value<int>? checkedAt,
    Value<int>? rowid,
  }) {
    return ArtistCountriesCompanion(
      artistKey: artistKey ?? this.artistKey,
      country: country ?? this.country,
      source: source ?? this.source,
      checkedAt: checkedAt ?? this.checkedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (artistKey.present) {
      map['artist_key'] = Variable<String>(artistKey.value);
    }
    if (country.present) {
      map['country'] = Variable<String>(country.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<int>(checkedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistCountriesCompanion(')
          ..write('artistKey: $artistKey, ')
          ..write('country: $country, ')
          ..write('source: $source, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistAliasesTable extends ArtistAliases
    with TableInfo<$ArtistAliasesTable, ArtistAliase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistAliasesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _aliasIdMeta = const VerificationMeta(
    'aliasId',
  );
  @override
  late final GeneratedColumn<String> aliasId = GeneratedColumn<String>(
    'alias_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mainIdMeta = const VerificationMeta('mainId');
  @override
  late final GeneratedColumn<String> mainId = GeneratedColumn<String>(
    'main_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: nowMs,
  );
  @override
  List<GeneratedColumn> get $columns => [aliasId, mainId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artist_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtistAliase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('alias_id')) {
      context.handle(
        _aliasIdMeta,
        aliasId.isAcceptableOrUnknown(data['alias_id']!, _aliasIdMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasIdMeta);
    }
    if (data.containsKey('main_id')) {
      context.handle(
        _mainIdMeta,
        mainId.isAcceptableOrUnknown(data['main_id']!, _mainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mainIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {aliasId};
  @override
  ArtistAliase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistAliase(
      aliasId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias_id'],
      )!,
      mainId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}main_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ArtistAliasesTable createAlias(String alias) {
    return $ArtistAliasesTable(attachedDatabase, alias);
  }
}

class ArtistAliase extends DataClass implements Insertable<ArtistAliase> {
  final String aliasId;
  final String mainId;
  final int createdAt;
  const ArtistAliase({
    required this.aliasId,
    required this.mainId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['alias_id'] = Variable<String>(aliasId);
    map['main_id'] = Variable<String>(mainId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ArtistAliasesCompanion toCompanion(bool nullToAbsent) {
    return ArtistAliasesCompanion(
      aliasId: Value(aliasId),
      mainId: Value(mainId),
      createdAt: Value(createdAt),
    );
  }

  factory ArtistAliase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistAliase(
      aliasId: serializer.fromJson<String>(json['aliasId']),
      mainId: serializer.fromJson<String>(json['mainId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'aliasId': serializer.toJson<String>(aliasId),
      'mainId': serializer.toJson<String>(mainId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ArtistAliase copyWith({String? aliasId, String? mainId, int? createdAt}) =>
      ArtistAliase(
        aliasId: aliasId ?? this.aliasId,
        mainId: mainId ?? this.mainId,
        createdAt: createdAt ?? this.createdAt,
      );
  ArtistAliase copyWithCompanion(ArtistAliasesCompanion data) {
    return ArtistAliase(
      aliasId: data.aliasId.present ? data.aliasId.value : this.aliasId,
      mainId: data.mainId.present ? data.mainId.value : this.mainId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistAliase(')
          ..write('aliasId: $aliasId, ')
          ..write('mainId: $mainId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(aliasId, mainId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistAliase &&
          other.aliasId == this.aliasId &&
          other.mainId == this.mainId &&
          other.createdAt == this.createdAt);
}

class ArtistAliasesCompanion extends UpdateCompanion<ArtistAliase> {
  final Value<String> aliasId;
  final Value<String> mainId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ArtistAliasesCompanion({
    this.aliasId = const Value.absent(),
    this.mainId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistAliasesCompanion.insert({
    required String aliasId,
    required String mainId,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : aliasId = Value(aliasId),
       mainId = Value(mainId);
  static Insertable<ArtistAliase> custom({
    Expression<String>? aliasId,
    Expression<String>? mainId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (aliasId != null) 'alias_id': aliasId,
      if (mainId != null) 'main_id': mainId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistAliasesCompanion copyWith({
    Value<String>? aliasId,
    Value<String>? mainId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ArtistAliasesCompanion(
      aliasId: aliasId ?? this.aliasId,
      mainId: mainId ?? this.mainId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (aliasId.present) {
      map['alias_id'] = Variable<String>(aliasId.value);
    }
    if (mainId.present) {
      map['main_id'] = Variable<String>(mainId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistAliasesCompanion(')
          ..write('aliasId: $aliasId, ')
          ..write('mainId: $mainId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtistNotSameTable extends ArtistNotSame
    with TableInfo<$ArtistNotSameTable, ArtistNotSameData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtistNotSameTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _aMeta = const VerificationMeta('a');
  @override
  late final GeneratedColumn<String> a = GeneratedColumn<String>(
    'a',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bMeta = const VerificationMeta('b');
  @override
  late final GeneratedColumn<String> b = GeneratedColumn<String>(
    'b',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    clientDefault: nowMs,
  );
  @override
  List<GeneratedColumn> get $columns => [a, b, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artist_not_same';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtistNotSameData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('a')) {
      context.handle(_aMeta, a.isAcceptableOrUnknown(data['a']!, _aMeta));
    } else if (isInserting) {
      context.missing(_aMeta);
    }
    if (data.containsKey('b')) {
      context.handle(_bMeta, b.isAcceptableOrUnknown(data['b']!, _bMeta));
    } else if (isInserting) {
      context.missing(_bMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {a, b};
  @override
  ArtistNotSameData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtistNotSameData(
      a: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}a'],
      )!,
      b: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}b'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ArtistNotSameTable createAlias(String alias) {
    return $ArtistNotSameTable(attachedDatabase, alias);
  }
}

class ArtistNotSameData extends DataClass
    implements Insertable<ArtistNotSameData> {
  final String a;
  final String b;
  final int createdAt;
  const ArtistNotSameData({
    required this.a,
    required this.b,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['a'] = Variable<String>(a);
    map['b'] = Variable<String>(b);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ArtistNotSameCompanion toCompanion(bool nullToAbsent) {
    return ArtistNotSameCompanion(
      a: Value(a),
      b: Value(b),
      createdAt: Value(createdAt),
    );
  }

  factory ArtistNotSameData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtistNotSameData(
      a: serializer.fromJson<String>(json['a']),
      b: serializer.fromJson<String>(json['b']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'a': serializer.toJson<String>(a),
      'b': serializer.toJson<String>(b),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ArtistNotSameData copyWith({String? a, String? b, int? createdAt}) =>
      ArtistNotSameData(
        a: a ?? this.a,
        b: b ?? this.b,
        createdAt: createdAt ?? this.createdAt,
      );
  ArtistNotSameData copyWithCompanion(ArtistNotSameCompanion data) {
    return ArtistNotSameData(
      a: data.a.present ? data.a.value : this.a,
      b: data.b.present ? data.b.value : this.b,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtistNotSameData(')
          ..write('a: $a, ')
          ..write('b: $b, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(a, b, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtistNotSameData &&
          other.a == this.a &&
          other.b == this.b &&
          other.createdAt == this.createdAt);
}

class ArtistNotSameCompanion extends UpdateCompanion<ArtistNotSameData> {
  final Value<String> a;
  final Value<String> b;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ArtistNotSameCompanion({
    this.a = const Value.absent(),
    this.b = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtistNotSameCompanion.insert({
    required String a,
    required String b,
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : a = Value(a),
       b = Value(b);
  static Insertable<ArtistNotSameData> custom({
    Expression<String>? a,
    Expression<String>? b,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (a != null) 'a': a,
      if (b != null) 'b': b,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtistNotSameCompanion copyWith({
    Value<String>? a,
    Value<String>? b,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ArtistNotSameCompanion(
      a: a ?? this.a,
      b: b ?? this.b,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (a.present) {
      map['a'] = Variable<String>(a.value);
    }
    if (b.present) {
      map['b'] = Variable<String>(b.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtistNotSameCompanion(')
          ..write('a: $a, ')
          ..write('b: $b, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TracksTable tracks = $TracksTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $PlaylistsTable playlists = $PlaylistsTable(this);
  late final $PlaylistTracksTable playlistTracks = $PlaylistTracksTable(this);
  late final $PlaylistImportsTable playlistImports = $PlaylistImportsTable(
    this,
  );
  late final $PlaylistImportItemsTable playlistImportItems =
      $PlaylistImportItemsTable(this);
  late final $PlaysTable plays = $PlaysTable(this);
  late final $SmartPlaylistsTable smartPlaylists = $SmartPlaylistsTable(this);
  late final $UserTagsTable userTags = $UserTagsTable(this);
  late final $TrackTagsTable trackTags = $TrackTagsTable(this);
  late final $PodcastsTable podcasts = $PodcastsTable(this);
  late final $PodcastEpisodesTable podcastEpisodes = $PodcastEpisodesTable(
    this,
  );
  late final $ArtistInfosTable artistInfos = $ArtistInfosTable(this);
  late final $RadioStationsTable radioStations = $RadioStationsTable(this);
  late final $FollowedArtistsTable followedArtists = $FollowedArtistsTable(
    this,
  );
  late final $ArtistReleasesTable artistReleases = $ArtistReleasesTable(this);
  late final $ArtistLookupsTable artistLookups = $ArtistLookupsTable(this);
  late final $TrackCreditsTable trackCredits = $TrackCreditsTable(this);
  late final $TrackEnrichTable trackEnrich = $TrackEnrichTable(this);
  late final $ActivityLogRowsTable activityLogRows = $ActivityLogRowsTable(
    this,
  );
  late final $TrackGenresTable trackGenres = $TrackGenresTable(this);
  late final $ArtistCountriesTable artistCountries = $ArtistCountriesTable(
    this,
  );
  late final $ArtistAliasesTable artistAliases = $ArtistAliasesTable(this);
  late final $ArtistNotSameTable artistNotSame = $ArtistNotSameTable(this);
  late final Index tracksAlbumKey = Index(
    'tracks_album_key',
    'CREATE INDEX tracks_album_key ON tracks (album_key)',
  );
  late final Index tracksArtist = Index(
    'tracks_artist',
    'CREATE INDEX tracks_artist ON tracks (artist)',
  );
  late final Index tracksFavorite = Index(
    'tracks_favorite',
    'CREATE INDEX tracks_favorite ON tracks (is_favorite)',
  );
  late final Index tracksIsrc = Index(
    'tracks_isrc',
    'CREATE INDEX tracks_isrc ON tracks (isrc)',
  );
  late final Index tracksKind = Index(
    'tracks_kind',
    'CREATE INDEX tracks_kind ON tracks (kind)',
  );
  late final Index tracksMissing = Index(
    'tracks_missing',
    'CREATE INDEX tracks_missing ON tracks (missing)',
  );
  late final Index tracksTitle = Index(
    'tracks_title',
    'CREATE INDEX tracks_title ON tracks (title)',
  );
  late final Index playlistsUuid = Index(
    'playlists_uuid',
    'CREATE UNIQUE INDEX playlists_uuid ON playlists (uuid)',
  );
  late final Index playlistTracksTrack = Index(
    'playlist_tracks_track',
    'CREATE INDEX playlist_tracks_track ON playlist_tracks (track_id)',
  );
  late final Index playsTrack = Index(
    'plays_track',
    'CREATE INDEX plays_track ON plays (track_id, played_at, ms_played)',
  );
  late final Index playsAt = Index(
    'plays_at',
    'CREATE INDEX plays_at ON plays (played_at)',
  );
  late final Index podcastEpisodesPodcast = Index(
    'podcast_episodes_podcast',
    'CREATE INDEX podcast_episodes_podcast ON podcast_episodes (podcast_id, published_at)',
  );
  late final Index trackCreditsNameKey = Index(
    'track_credits_name_key',
    'CREATE INDEX track_credits_name_key ON track_credits (name_key)',
  );
  late final Index activityLogAt = Index(
    'activity_log_at',
    'CREATE INDEX activity_log_at ON activity_log (at)',
  );
  late final Index trackGenresGenre = Index(
    'track_genres_genre',
    'CREATE INDEX track_genres_genre ON track_genres (genre)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tracks,
    folders,
    playlists,
    playlistTracks,
    playlistImports,
    playlistImportItems,
    plays,
    smartPlaylists,
    userTags,
    trackTags,
    podcasts,
    podcastEpisodes,
    artistInfos,
    radioStations,
    followedArtists,
    artistReleases,
    artistLookups,
    trackCredits,
    trackEnrich,
    activityLogRows,
    trackGenres,
    artistCountries,
    artistAliases,
    artistNotSame,
    tracksAlbumKey,
    tracksArtist,
    tracksFavorite,
    tracksIsrc,
    tracksKind,
    tracksMissing,
    tracksTitle,
    playlistsUuid,
    playlistTracksTrack,
    playsTrack,
    playsAt,
    podcastEpisodesPodcast,
    trackCreditsNameKey,
    activityLogAt,
    trackGenresGenre,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_tracks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_imports', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'playlist_imports',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_import_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('playlist_import_items', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('plays', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'podcasts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('podcast_episodes', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('podcast_episodes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'followed_artists',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('artist_releases', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_credits', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_enrich', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tracks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('track_genres', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TracksTableCreateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  required String path,
  Value<int?> folderId,
  required String title,
  Value<String?> artist,
  Value<String?> albumArtist,
  Value<String?> album,
  required String albumKey,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int?> year,
  Value<String?> genre,
  Value<int> durationMs,
  required String format,
  Value<int?> sampleRateHz,
  Value<int?> bitDepth,
  Value<int?> bitrateKbps,
  Value<int?> channels,
  required int sizeBytes,
  required int mtimeMs,
  Value<bool> hasCover,
  Value<String?> coverKey,
  Value<bool> isFavorite,
  Value<String?> lyricsPlain,
  Value<String?> lyricsSynced,
  Value<String?> curiosities,
  Value<int> enrichStatus,
  Value<bool> userEdited,
  Value<bool> missing,
  Value<bool> ignored,
  Value<int> kind,
  Value<String?> sha256,
  required int addedAt,
  Value<int> playCount,
  Value<double?> replayGainDb,
  Value<int?> resumePositionMs,
  Value<int?> lastPlayedAt,
  Value<String?> isrc,
  Value<int> coverSource,
});
typedef $$TracksTableUpdateCompanionBuilder = TracksCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<int?> folderId,
  Value<String> title,
  Value<String?> artist,
  Value<String?> albumArtist,
  Value<String?> album,
  Value<String> albumKey,
  Value<int?> trackNumber,
  Value<int?> discNumber,
  Value<int?> year,
  Value<String?> genre,
  Value<int> durationMs,
  Value<String> format,
  Value<int?> sampleRateHz,
  Value<int?> bitDepth,
  Value<int?> bitrateKbps,
  Value<int?> channels,
  Value<int> sizeBytes,
  Value<int> mtimeMs,
  Value<bool> hasCover,
  Value<String?> coverKey,
  Value<bool> isFavorite,
  Value<String?> lyricsPlain,
  Value<String?> lyricsSynced,
  Value<String?> curiosities,
  Value<int> enrichStatus,
  Value<bool> userEdited,
  Value<bool> missing,
  Value<bool> ignored,
  Value<int> kind,
  Value<String?> sha256,
  Value<int> addedAt,
  Value<int> playCount,
  Value<double?> replayGainDb,
  Value<int?> resumePositionMs,
  Value<int?> lastPlayedAt,
  Value<String?> isrc,
  Value<int> coverSource,
});

final class $$TracksTableReferences
    extends BaseReferences<_$AppDatabase, $TracksTable, Track> {
  $$TracksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
  _playlistTracksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistTracks,
    aliasName: 'tracks__id__playlist_tracks__track_id',
  );

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager(
      $_db,
      $_db.playlistTracks,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $PlaylistImportItemsTable,
    List<PlaylistImportItem>
  >
  _playlistImportItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playlistImportItems,
        aliasName: 'tracks__id__playlist_import_items__track_id',
      );

  $$PlaylistImportItemsTableProcessedTableManager get playlistImportItemsRefs {
    final manager = $$PlaylistImportItemsTableTableManager(
      $_db,
      $_db.playlistImportItems,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistImportItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaysTable, List<Play>> _playsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.plays,
    aliasName: 'tracks__id__plays__track_id',
  );

  $$PlaysTableProcessedTableManager get playsRefs {
    final manager = $$PlaysTableTableManager(
      $_db,
      $_db.plays,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TrackTagsTable, List<TrackTag>>
  _trackTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackTags,
    aliasName: 'tracks__id__track_tags__track_id',
  );

  $$TrackTagsTableProcessedTableManager get trackTagsRefs {
    final manager = $$TrackTagsTableTableManager(
      $_db,
      $_db.trackTags,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PodcastEpisodesTable, List<PodcastEpisode>>
  _podcastEpisodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.podcastEpisodes,
    aliasName: 'tracks__id__podcast_episodes__track_id',
  );

  $$PodcastEpisodesTableProcessedTableManager get podcastEpisodesRefs {
    final manager = $$PodcastEpisodesTableTableManager(
      $_db,
      $_db.podcastEpisodes,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _podcastEpisodesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TrackCreditsTable, List<TrackCreditRow>>
  _trackCreditsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackCredits,
    aliasName: 'tracks__id__track_credits__track_id',
  );

  $$TrackCreditsTableProcessedTableManager get trackCreditsRefs {
    final manager = $$TrackCreditsTableTableManager(
      $_db,
      $_db.trackCredits,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackCreditsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TrackEnrichTable, List<TrackEnrichData>>
  _trackEnrichRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackEnrich,
    aliasName: 'tracks__id__track_enrich__track_id',
  );

  $$TrackEnrichTableProcessedTableManager get trackEnrichRefs {
    final manager = $$TrackEnrichTableTableManager(
      $_db,
      $_db.trackEnrich,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackEnrichRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TrackGenresTable, List<TrackGenreRow>>
  _trackGenresRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackGenres,
    aliasName: 'tracks__id__track_genres__track_id',
  );

  $$TrackGenresTableProcessedTableManager get trackGenresRefs {
    final manager = $$TrackGenresTableTableManager(
      $_db,
      $_db.trackGenres,
    ).filter((f) => f.trackId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackGenresRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TracksTableFilterComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get albumKey => $composableBuilder(
    column: $table.albumKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sampleRateHz => $composableBuilder(
    column: $table.sampleRateHz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrateKbps => $composableBuilder(
    column: $table.bitrateKbps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hasCover => $composableBuilder(
    column: $table.hasCover,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyricsPlain => $composableBuilder(
    column: $table.lyricsPlain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lyricsSynced => $composableBuilder(
    column: $table.lyricsSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get curiosities => $composableBuilder(
    column: $table.curiosities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get enrichStatus => $composableBuilder(
    column: $table.enrichStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ignored => $composableBuilder(
    column: $table.ignored,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get replayGainDb => $composableBuilder(
    column: $table.replayGainDb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resumePositionMs => $composableBuilder(
    column: $table.resumePositionMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistTracksRefs(
    Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playlistImportItemsRefs(
    Expression<bool> Function($$PlaylistImportItemsTableFilterComposer f) f,
  ) {
    final $$PlaylistImportItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistImportItems,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistImportItemsTableFilterComposer(
            $db: $db,
            $table: $db.playlistImportItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playsRefs(
    Expression<bool> Function($$PlaysTableFilterComposer f) f,
  ) {
    final $$PlaysTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.plays,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaysTableFilterComposer(
            $db: $db,
            $table: $db.plays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> trackTagsRefs(
    Expression<bool> Function($$TrackTagsTableFilterComposer f) f,
  ) {
    final $$TrackTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackTags,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackTagsTableFilterComposer(
            $db: $db,
            $table: $db.trackTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> podcastEpisodesRefs(
    Expression<bool> Function($$PodcastEpisodesTableFilterComposer f) f,
  ) {
    final $$PodcastEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> trackCreditsRefs(
    Expression<bool> Function($$TrackCreditsTableFilterComposer f) f,
  ) {
    final $$TrackCreditsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackCredits,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackCreditsTableFilterComposer(
            $db: $db,
            $table: $db.trackCredits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> trackEnrichRefs(
    Expression<bool> Function($$TrackEnrichTableFilterComposer f) f,
  ) {
    final $$TrackEnrichTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackEnrich,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackEnrichTableFilterComposer(
            $db: $db,
            $table: $db.trackEnrich,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> trackGenresRefs(
    Expression<bool> Function($$TrackGenresTableFilterComposer f) f,
  ) {
    final $$TrackGenresTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackGenres,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackGenresTableFilterComposer(
            $db: $db,
            $table: $db.trackGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableOrderingComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get folderId => $composableBuilder(
    column: $table.folderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artist => $composableBuilder(
    column: $table.artist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get albumKey => $composableBuilder(
    column: $table.albumKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get format => $composableBuilder(
    column: $table.format,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sampleRateHz => $composableBuilder(
    column: $table.sampleRateHz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitDepth => $composableBuilder(
    column: $table.bitDepth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrateKbps => $composableBuilder(
    column: $table.bitrateKbps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get channels => $composableBuilder(
    column: $table.channels,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hasCover => $composableBuilder(
    column: $table.hasCover,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyricsPlain => $composableBuilder(
    column: $table.lyricsPlain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lyricsSynced => $composableBuilder(
    column: $table.lyricsSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get curiosities => $composableBuilder(
    column: $table.curiosities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get enrichStatus => $composableBuilder(
    column: $table.enrichStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get missing => $composableBuilder(
    column: $table.missing,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ignored => $composableBuilder(
    column: $table.ignored,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playCount => $composableBuilder(
    column: $table.playCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get replayGainDb => $composableBuilder(
    column: $table.replayGainDb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resumePositionMs => $composableBuilder(
    column: $table.resumePositionMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $TracksTable> {
  $$TracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get albumArtist => $composableBuilder(
    column: $table.albumArtist,
    builder: (column) => column,
  );

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumKey =>
      $composableBuilder(column: $table.albumKey, builder: (column) => column);

  GeneratedColumn<int> get trackNumber => $composableBuilder(
    column: $table.trackNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get discNumber => $composableBuilder(
    column: $table.discNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<int> get sampleRateHz => $composableBuilder(
    column: $table.sampleRateHz,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bitDepth =>
      $composableBuilder(column: $table.bitDepth, builder: (column) => column);

  GeneratedColumn<int> get bitrateKbps => $composableBuilder(
    column: $table.bitrateKbps,
    builder: (column) => column,
  );

  GeneratedColumn<int> get channels =>
      $composableBuilder(column: $table.channels, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<bool> get hasCover =>
      $composableBuilder(column: $table.hasCover, builder: (column) => column);

  GeneratedColumn<String> get coverKey =>
      $composableBuilder(column: $table.coverKey, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lyricsPlain => $composableBuilder(
    column: $table.lyricsPlain,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lyricsSynced => $composableBuilder(
    column: $table.lyricsSynced,
    builder: (column) => column,
  );

  GeneratedColumn<String> get curiosities => $composableBuilder(
    column: $table.curiosities,
    builder: (column) => column,
  );

  GeneratedColumn<int> get enrichStatus => $composableBuilder(
    column: $table.enrichStatus,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get userEdited => $composableBuilder(
    column: $table.userEdited,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get missing =>
      $composableBuilder(column: $table.missing, builder: (column) => column);

  GeneratedColumn<bool> get ignored =>
      $composableBuilder(column: $table.ignored, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get playCount =>
      $composableBuilder(column: $table.playCount, builder: (column) => column);

  GeneratedColumn<double> get replayGainDb => $composableBuilder(
    column: $table.replayGainDb,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resumePositionMs => $composableBuilder(
    column: $table.resumePositionMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);

  GeneratedColumn<int> get coverSource => $composableBuilder(
    column: $table.coverSource,
    builder: (column) => column,
  );

  Expression<T> playlistTracksRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playlistImportItemsRefs<T extends Object>(
    Expression<T> Function($$PlaylistImportItemsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistImportItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playlistImportItems,
          getReferencedColumn: (t) => t.trackId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaylistImportItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.playlistImportItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> playsRefs<T extends Object>(
    Expression<T> Function($$PlaysTableAnnotationComposer a) f,
  ) {
    final $$PlaysTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.plays,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaysTableAnnotationComposer(
            $db: $db,
            $table: $db.plays,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> trackTagsRefs<T extends Object>(
    Expression<T> Function($$TrackTagsTableAnnotationComposer a) f,
  ) {
    final $$TrackTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackTags,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> podcastEpisodesRefs<T extends Object>(
    Expression<T> Function($$PodcastEpisodesTableAnnotationComposer a) f,
  ) {
    final $$PodcastEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> trackCreditsRefs<T extends Object>(
    Expression<T> Function($$TrackCreditsTableAnnotationComposer a) f,
  ) {
    final $$TrackCreditsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackCredits,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackCreditsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackCredits,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> trackEnrichRefs<T extends Object>(
    Expression<T> Function($$TrackEnrichTableAnnotationComposer a) f,
  ) {
    final $$TrackEnrichTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackEnrich,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackEnrichTableAnnotationComposer(
            $db: $db,
            $table: $db.trackEnrich,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> trackGenresRefs<T extends Object>(
    Expression<T> Function($$TrackGenresTableAnnotationComposer a) f,
  ) {
    final $$TrackGenresTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackGenres,
      getReferencedColumn: (t) => t.trackId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackGenresTableAnnotationComposer(
            $db: $db,
            $table: $db.trackGenres,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TracksTable,
          Track,
          $$TracksTableFilterComposer,
          $$TracksTableOrderingComposer,
          $$TracksTableAnnotationComposer,
          $$TracksTableCreateCompanionBuilder,
          $$TracksTableUpdateCompanionBuilder,
          (Track, $$TracksTableReferences),
          Track,
          PrefetchHooks Function({
            bool playlistTracksRefs,
            bool playlistImportItemsRefs,
            bool playsRefs,
            bool trackTagsRefs,
            bool podcastEpisodesRefs,
            bool trackCreditsRefs,
            bool trackEnrichRefs,
            bool trackGenresRefs,
          })
        > {
  $$TracksTableTableManager(_$AppDatabase db, $TracksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> artist = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<String> albumKey = const Value.absent(),
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<int?> sampleRateHz = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> bitrateKbps = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<bool> hasCover = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> lyricsPlain = const Value.absent(),
                Value<String?> lyricsSynced = const Value.absent(),
                Value<String?> curiosities = const Value.absent(),
                Value<int> enrichStatus = const Value.absent(),
                Value<bool> userEdited = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<bool> ignored = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int> playCount = const Value.absent(),
                Value<double?> replayGainDb = const Value.absent(),
                Value<int?> resumePositionMs = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int> coverSource = const Value.absent(),
              }) => TracksCompanion(
                id: id,
                path: path,
                folderId: folderId,
                title: title,
                artist: artist,
                albumArtist: albumArtist,
                album: album,
                albumKey: albumKey,
                trackNumber: trackNumber,
                discNumber: discNumber,
                year: year,
                genre: genre,
                durationMs: durationMs,
                format: format,
                sampleRateHz: sampleRateHz,
                bitDepth: bitDepth,
                bitrateKbps: bitrateKbps,
                channels: channels,
                sizeBytes: sizeBytes,
                mtimeMs: mtimeMs,
                hasCover: hasCover,
                coverKey: coverKey,
                isFavorite: isFavorite,
                lyricsPlain: lyricsPlain,
                lyricsSynced: lyricsSynced,
                curiosities: curiosities,
                enrichStatus: enrichStatus,
                userEdited: userEdited,
                missing: missing,
                ignored: ignored,
                kind: kind,
                sha256: sha256,
                addedAt: addedAt,
                playCount: playCount,
                replayGainDb: replayGainDb,
                resumePositionMs: resumePositionMs,
                lastPlayedAt: lastPlayedAt,
                isrc: isrc,
                coverSource: coverSource,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                Value<int?> folderId = const Value.absent(),
                required String title,
                Value<String?> artist = const Value.absent(),
                Value<String?> albumArtist = const Value.absent(),
                Value<String?> album = const Value.absent(),
                required String albumKey,
                Value<int?> trackNumber = const Value.absent(),
                Value<int?> discNumber = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> genre = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                required String format,
                Value<int?> sampleRateHz = const Value.absent(),
                Value<int?> bitDepth = const Value.absent(),
                Value<int?> bitrateKbps = const Value.absent(),
                Value<int?> channels = const Value.absent(),
                required int sizeBytes,
                required int mtimeMs,
                Value<bool> hasCover = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<String?> lyricsPlain = const Value.absent(),
                Value<String?> lyricsSynced = const Value.absent(),
                Value<String?> curiosities = const Value.absent(),
                Value<int> enrichStatus = const Value.absent(),
                Value<bool> userEdited = const Value.absent(),
                Value<bool> missing = const Value.absent(),
                Value<bool> ignored = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<String?> sha256 = const Value.absent(),
                required int addedAt,
                Value<int> playCount = const Value.absent(),
                Value<double?> replayGainDb = const Value.absent(),
                Value<int?> resumePositionMs = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int> coverSource = const Value.absent(),
              }) => TracksCompanion.insert(
                id: id,
                path: path,
                folderId: folderId,
                title: title,
                artist: artist,
                albumArtist: albumArtist,
                album: album,
                albumKey: albumKey,
                trackNumber: trackNumber,
                discNumber: discNumber,
                year: year,
                genre: genre,
                durationMs: durationMs,
                format: format,
                sampleRateHz: sampleRateHz,
                bitDepth: bitDepth,
                bitrateKbps: bitrateKbps,
                channels: channels,
                sizeBytes: sizeBytes,
                mtimeMs: mtimeMs,
                hasCover: hasCover,
                coverKey: coverKey,
                isFavorite: isFavorite,
                lyricsPlain: lyricsPlain,
                lyricsSynced: lyricsSynced,
                curiosities: curiosities,
                enrichStatus: enrichStatus,
                userEdited: userEdited,
                missing: missing,
                ignored: ignored,
                kind: kind,
                sha256: sha256,
                addedAt: addedAt,
                playCount: playCount,
                replayGainDb: replayGainDb,
                resumePositionMs: resumePositionMs,
                lastPlayedAt: lastPlayedAt,
                isrc: isrc,
                coverSource: coverSource,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TracksTable, Track>(table),
                  $$TracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                playlistTracksRefs = false,
                playlistImportItemsRefs = false,
                playsRefs = false,
                trackTagsRefs = false,
                podcastEpisodesRefs = false,
                trackCreditsRefs = false,
                trackEnrichRefs = false,
                trackGenresRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistTracksRefs) db.playlistTracks,
                    if (playlistImportItemsRefs) db.playlistImportItems,
                    if (playsRefs) db.plays,
                    if (trackTagsRefs) db.trackTags,
                    if (podcastEpisodesRefs) db.podcastEpisodes,
                    if (trackCreditsRefs) db.trackCredits,
                    if (trackEnrichRefs) db.trackEnrich,
                    if (trackGenresRefs) db.trackGenres,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistTracksRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          PlaylistTrack
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playlistTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playlistImportItemsRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          PlaylistImportItem
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playlistImportItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistImportItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playsRefs)
                        await $_getPrefetchedData<Track, $TracksTable, Play>(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._playsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(db, table, p0).playsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (trackTagsRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          TrackTag
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._trackTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (podcastEpisodesRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          PodcastEpisode
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._podcastEpisodesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).podcastEpisodesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (trackCreditsRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          TrackCreditRow
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._trackCreditsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackCreditsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (trackEnrichRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          TrackEnrichData
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._trackEnrichRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackEnrichRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (trackGenresRefs)
                        await $_getPrefetchedData<
                          Track,
                          $TracksTable,
                          TrackGenreRow
                        >(
                          currentTable: table,
                          referencedTable: $$TracksTableReferences
                              ._trackGenresRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TracksTableReferences(
                                db,
                                table,
                                p0,
                              ).trackGenresRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.trackId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TracksTable,
      Track,
      $$TracksTableFilterComposer,
      $$TracksTableOrderingComposer,
      $$TracksTableAnnotationComposer,
      $$TracksTableCreateCompanionBuilder,
      $$TracksTableUpdateCompanionBuilder,
      (Track, $$TracksTableReferences),
      Track,
      PrefetchHooks Function({
        bool playlistTracksRefs,
        bool playlistImportItemsRefs,
        bool playsRefs,
        bool trackTagsRefs,
        bool podcastEpisodesRefs,
        bool trackCreditsRefs,
        bool trackEnrichRefs,
        bool trackGenresRefs,
      })
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  required String path,
  required int addedAt,
  Value<String?> label,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  Value<String> path,
  Value<int> addedAt,
  Value<String?> label,
});

class $$FoldersTableFilterComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
          Folder,
          PrefetchHooks Function()
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<String?> label = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                path: path,
                addedAt: addedAt,
                label: label,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String path,
                required int addedAt,
                Value<String?> label = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                path: path,
                addedAt: addedAt,
                label: label,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FoldersTable, Folder>(table),
                  BaseReferences<_$AppDatabase, $FoldersTable, Folder>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, BaseReferences<_$AppDatabase, $FoldersTable, Folder>),
      Folder,
      PrefetchHooks Function()
    >;
typedef $$PlaylistsTableCreateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  required String name,
  required int createdAt,
  Value<String?> uuid,
  Value<int> updatedAt,
  Value<String?> coverKey,
});
typedef $$PlaylistsTableUpdateCompanionBuilder = PlaylistsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int> createdAt,
  Value<String?> uuid,
  Value<int> updatedAt,
  Value<String?> coverKey,
});

final class $$PlaylistsTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistsTable, Playlist> {
  $$PlaylistsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PlaylistTracksTable, List<PlaylistTrack>>
  _playlistTracksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistTracks,
    aliasName: 'playlists__id__playlist_tracks__playlist_id',
  );

  $$PlaylistTracksTableProcessedTableManager get playlistTracksRefs {
    final manager = $$PlaylistTracksTableTableManager(
      $_db,
      $_db.playlistTracks,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_playlistTracksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PlaylistImportsTable, List<PlaylistImport>>
  _playlistImportsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playlistImports,
    aliasName: 'playlists__id__playlist_imports__playlist_id',
  );

  $$PlaylistImportsTableProcessedTableManager get playlistImportsRefs {
    final manager = $$PlaylistImportsTableTableManager(
      $_db,
      $_db.playlistImports,
    ).filter((f) => f.playlistId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistImportsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> playlistTracksRefs(
    Expression<bool> Function($$PlaylistTracksTableFilterComposer f) f,
  ) {
    final $$PlaylistTracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableFilterComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> playlistImportsRefs(
    Expression<bool> Function($$PlaylistImportsTableFilterComposer f) f,
  ) {
    final $$PlaylistImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistImports,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistImportsTableFilterComposer(
            $db: $db,
            $table: $db.playlistImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistsTable> {
  $$PlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get coverKey =>
      $composableBuilder(column: $table.coverKey, builder: (column) => column);

  Expression<T> playlistTracksRefs<T extends Object>(
    Expression<T> Function($$PlaylistTracksTableAnnotationComposer a) f,
  ) {
    final $$PlaylistTracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistTracks,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistTracksTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistTracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> playlistImportsRefs<T extends Object>(
    Expression<T> Function($$PlaylistImportsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistImports,
      getReferencedColumn: (t) => t.playlistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistsTable,
          Playlist,
          $$PlaylistsTableFilterComposer,
          $$PlaylistsTableOrderingComposer,
          $$PlaylistsTableAnnotationComposer,
          $$PlaylistsTableCreateCompanionBuilder,
          $$PlaylistsTableUpdateCompanionBuilder,
          (Playlist, $$PlaylistsTableReferences),
          Playlist,
          PrefetchHooks Function({
            bool playlistTracksRefs,
            bool playlistImportsRefs,
          })
        > {
  $$PlaylistsTableTableManager(_$AppDatabase db, $PlaylistsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
              }) => PlaylistsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                uuid: uuid,
                updatedAt: updatedAt,
                coverKey: coverKey,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required int createdAt,
                Value<String?> uuid = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
              }) => PlaylistsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                uuid: uuid,
                updatedAt: updatedAt,
                coverKey: coverKey,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistsTable, Playlist>(table),
                  $$PlaylistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistTracksRefs = false, playlistImportsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistTracksRefs) db.playlistTracks,
                    if (playlistImportsRefs) db.playlistImports,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistTracksRefs)
                        await $_getPrefetchedData<
                          Playlist,
                          $PlaylistsTable,
                          PlaylistTrack
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._playlistTracksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistTracksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (playlistImportsRefs)
                        await $_getPrefetchedData<
                          Playlist,
                          $PlaylistsTable,
                          PlaylistImport
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistsTableReferences
                              ._playlistImportsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistImportsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.playlistId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistsTable,
      Playlist,
      $$PlaylistsTableFilterComposer,
      $$PlaylistsTableOrderingComposer,
      $$PlaylistsTableAnnotationComposer,
      $$PlaylistsTableCreateCompanionBuilder,
      $$PlaylistsTableUpdateCompanionBuilder,
      (Playlist, $$PlaylistsTableReferences),
      Playlist,
      PrefetchHooks Function({
        bool playlistTracksRefs,
        bool playlistImportsRefs,
      })
    >;
typedef $$PlaylistTracksTableCreateCompanionBuilder =
    PlaylistTracksCompanion Function({
      required int playlistId,
      required int trackId,
      required int position,
      Value<int> rowid,
    });
typedef $$PlaylistTracksTableUpdateCompanionBuilder =
    PlaylistTracksCompanion Function({
      Value<int> playlistId,
      Value<int> trackId,
      Value<int> position,
      Value<int> rowid,
    });

final class $$PlaylistTracksTableReferences
    extends BaseReferences<_$AppDatabase, $PlaylistTracksTable, PlaylistTrack> {
  $$PlaylistTracksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_tracks__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('playlist_tracks__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistTracksTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistTracksTable> {
  $$PlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistTracksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistTracksTable,
          PlaylistTrack,
          $$PlaylistTracksTableFilterComposer,
          $$PlaylistTracksTableOrderingComposer,
          $$PlaylistTracksTableAnnotationComposer,
          $$PlaylistTracksTableCreateCompanionBuilder,
          $$PlaylistTracksTableUpdateCompanionBuilder,
          (PlaylistTrack, $$PlaylistTracksTableReferences),
          PlaylistTrack,
          PrefetchHooks Function({bool playlistId, bool trackId})
        > {
  $$PlaylistTracksTableTableManager(
    _$AppDatabase db,
    $PlaylistTracksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> playlistId = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksCompanion(
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int playlistId,
                required int trackId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => PlaylistTracksCompanion.insert(
                playlistId: playlistId,
                trackId: trackId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistTracksTable, PlaylistTrack>(table),
                  $$PlaylistTracksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({playlistId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (playlistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.playlistId,
                        referencedTable: $$PlaylistTracksTableReferences
                            ._playlistIdTable(db),
                        referencedColumn: $$PlaylistTracksTableReferences
                            ._playlistIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlaylistTracksTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlaylistTracksTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistTracksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistTracksTable,
      PlaylistTrack,
      $$PlaylistTracksTableFilterComposer,
      $$PlaylistTracksTableOrderingComposer,
      $$PlaylistTracksTableAnnotationComposer,
      $$PlaylistTracksTableCreateCompanionBuilder,
      $$PlaylistTracksTableUpdateCompanionBuilder,
      (PlaylistTrack, $$PlaylistTracksTableReferences),
      PlaylistTrack,
      PrefetchHooks Function({bool playlistId, bool trackId})
    >;
typedef $$PlaylistImportsTableCreateCompanionBuilder =
    PlaylistImportsCompanion Function({
      Value<int> id,
      required int playlistId,
      required String sourceName,
      required int createdAt,
      Value<int> status,
      Value<String> sourceKind,
      Value<String?> folderPath,
      Value<bool> numberFiles,
      Value<bool> linkOnly,
      Value<bool> planFirst,
      Value<bool> fetchCovers,
    });
typedef $$PlaylistImportsTableUpdateCompanionBuilder =
    PlaylistImportsCompanion Function({
      Value<int> id,
      Value<int> playlistId,
      Value<String> sourceName,
      Value<int> createdAt,
      Value<int> status,
      Value<String> sourceKind,
      Value<String?> folderPath,
      Value<bool> numberFiles,
      Value<bool> linkOnly,
      Value<bool> planFirst,
      Value<bool> fetchCovers,
    });

final class $$PlaylistImportsTableReferences
    extends
        BaseReferences<_$AppDatabase, $PlaylistImportsTable, PlaylistImport> {
  $$PlaylistImportsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistsTable _playlistIdTable(_$AppDatabase db) =>
      db.playlists.createAlias('playlist_imports__playlist_id__playlists__id');

  $$PlaylistsTableProcessedTableManager get playlistId {
    final $_column = $_itemColumn<int>('playlist_id')!;

    final manager = $$PlaylistsTableTableManager(
      $_db,
      $_db.playlists,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $PlaylistImportItemsTable,
    List<PlaylistImportItem>
  >
  _playlistImportItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.playlistImportItems,
        aliasName: 'playlist_imports__id__playlist_import_items__import_id',
      );

  $$PlaylistImportItemsTableProcessedTableManager get playlistImportItemsRefs {
    final manager = $$PlaylistImportItemsTableTableManager(
      $_db,
      $_db.playlistImportItems,
    ).filter((f) => f.importId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playlistImportItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PlaylistImportsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistImportsTable> {
  $$PlaylistImportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get numberFiles => $composableBuilder(
    column: $table.numberFiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get linkOnly => $composableBuilder(
    column: $table.linkOnly,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get planFirst => $composableBuilder(
    column: $table.planFirst,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fetchCovers => $composableBuilder(
    column: $table.fetchCovers,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistsTableFilterComposer get playlistId {
    final $$PlaylistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableFilterComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> playlistImportItemsRefs(
    Expression<bool> Function($$PlaylistImportItemsTableFilterComposer f) f,
  ) {
    final $$PlaylistImportItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playlistImportItems,
      getReferencedColumn: (t) => t.importId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistImportItemsTableFilterComposer(
            $db: $db,
            $table: $db.playlistImportItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PlaylistImportsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistImportsTable> {
  $$PlaylistImportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get numberFiles => $composableBuilder(
    column: $table.numberFiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get linkOnly => $composableBuilder(
    column: $table.linkOnly,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get planFirst => $composableBuilder(
    column: $table.planFirst,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fetchCovers => $composableBuilder(
    column: $table.fetchCovers,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistsTableOrderingComposer get playlistId {
    final $$PlaylistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableOrderingComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistImportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistImportsTable> {
  $$PlaylistImportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get sourceKind => $composableBuilder(
    column: $table.sourceKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get numberFiles => $composableBuilder(
    column: $table.numberFiles,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get linkOnly =>
      $composableBuilder(column: $table.linkOnly, builder: (column) => column);

  GeneratedColumn<bool> get planFirst =>
      $composableBuilder(column: $table.planFirst, builder: (column) => column);

  GeneratedColumn<bool> get fetchCovers => $composableBuilder(
    column: $table.fetchCovers,
    builder: (column) => column,
  );

  $$PlaylistsTableAnnotationComposer get playlistId {
    final $$PlaylistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.playlistId,
      referencedTable: $db.playlists,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> playlistImportItemsRefs<T extends Object>(
    Expression<T> Function($$PlaylistImportItemsTableAnnotationComposer a) f,
  ) {
    final $$PlaylistImportItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.playlistImportItems,
          getReferencedColumn: (t) => t.importId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PlaylistImportItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.playlistImportItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$PlaylistImportsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistImportsTable,
          PlaylistImport,
          $$PlaylistImportsTableFilterComposer,
          $$PlaylistImportsTableOrderingComposer,
          $$PlaylistImportsTableAnnotationComposer,
          $$PlaylistImportsTableCreateCompanionBuilder,
          $$PlaylistImportsTableUpdateCompanionBuilder,
          (PlaylistImport, $$PlaylistImportsTableReferences),
          PlaylistImport,
          PrefetchHooks Function({
            bool playlistId,
            bool playlistImportItemsRefs,
          })
        > {
  $$PlaylistImportsTableTableManager(
    _$AppDatabase db,
    $PlaylistImportsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistImportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistImportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaylistImportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> playlistId = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> folderPath = const Value.absent(),
                Value<bool> numberFiles = const Value.absent(),
                Value<bool> linkOnly = const Value.absent(),
                Value<bool> planFirst = const Value.absent(),
                Value<bool> fetchCovers = const Value.absent(),
              }) => PlaylistImportsCompanion(
                id: id,
                playlistId: playlistId,
                sourceName: sourceName,
                createdAt: createdAt,
                status: status,
                sourceKind: sourceKind,
                folderPath: folderPath,
                numberFiles: numberFiles,
                linkOnly: linkOnly,
                planFirst: planFirst,
                fetchCovers: fetchCovers,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int playlistId,
                required String sourceName,
                required int createdAt,
                Value<int> status = const Value.absent(),
                Value<String> sourceKind = const Value.absent(),
                Value<String?> folderPath = const Value.absent(),
                Value<bool> numberFiles = const Value.absent(),
                Value<bool> linkOnly = const Value.absent(),
                Value<bool> planFirst = const Value.absent(),
                Value<bool> fetchCovers = const Value.absent(),
              }) => PlaylistImportsCompanion.insert(
                id: id,
                playlistId: playlistId,
                sourceName: sourceName,
                createdAt: createdAt,
                status: status,
                sourceKind: sourceKind,
                folderPath: folderPath,
                numberFiles: numberFiles,
                linkOnly: linkOnly,
                planFirst: planFirst,
                fetchCovers: fetchCovers,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistImportsTable, PlaylistImport>(table),
                  $$PlaylistImportsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({playlistId = false, playlistImportItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playlistImportItemsRefs) db.playlistImportItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (playlistId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.playlistId,
                            referencedTable: $$PlaylistImportsTableReferences
                                ._playlistIdTable(db),
                            referencedColumn: $$PlaylistImportsTableReferences
                                ._playlistIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playlistImportItemsRefs)
                        await $_getPrefetchedData<
                          PlaylistImport,
                          $PlaylistImportsTable,
                          PlaylistImportItem
                        >(
                          currentTable: table,
                          referencedTable: $$PlaylistImportsTableReferences
                              ._playlistImportItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PlaylistImportsTableReferences(
                                db,
                                table,
                                p0,
                              ).playlistImportItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.importId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PlaylistImportsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistImportsTable,
      PlaylistImport,
      $$PlaylistImportsTableFilterComposer,
      $$PlaylistImportsTableOrderingComposer,
      $$PlaylistImportsTableAnnotationComposer,
      $$PlaylistImportsTableCreateCompanionBuilder,
      $$PlaylistImportsTableUpdateCompanionBuilder,
      (PlaylistImport, $$PlaylistImportsTableReferences),
      PlaylistImport,
      PrefetchHooks Function({bool playlistId, bool playlistImportItemsRefs})
    >;
typedef $$PlaylistImportItemsTableCreateCompanionBuilder =
    PlaylistImportItemsCompanion Function({
      required int importId,
      required int rowIndex,
      required String title,
      required String artists,
      Value<String?> album,
      Value<int?> durationMs,
      Value<String?> isrc,
      Value<int?> year,
      Value<int> status,
      Value<String?> videoId,
      Value<String?> candidates,
      Value<int?> trackId,
      Value<double?> score,
      Value<String?> note,
      Value<String?> location,
      Value<int> rowid,
    });
typedef $$PlaylistImportItemsTableUpdateCompanionBuilder =
    PlaylistImportItemsCompanion Function({
      Value<int> importId,
      Value<int> rowIndex,
      Value<String> title,
      Value<String> artists,
      Value<String?> album,
      Value<int?> durationMs,
      Value<String?> isrc,
      Value<int?> year,
      Value<int> status,
      Value<String?> videoId,
      Value<String?> candidates,
      Value<int?> trackId,
      Value<double?> score,
      Value<String?> note,
      Value<String?> location,
      Value<int> rowid,
    });

final class $$PlaylistImportItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaylistImportItemsTable,
          PlaylistImportItem
        > {
  $$PlaylistImportItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PlaylistImportsTable _importIdTable(_$AppDatabase db) => db
      .playlistImports
      .createAlias('playlist_import_items__import_id__playlist_imports__id');

  $$PlaylistImportsTableProcessedTableManager get importId {
    final $_column = $_itemColumn<int>('import_id')!;

    final manager = $$PlaylistImportsTableTableManager(
      $_db,
      $_db.playlistImports,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_importIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('playlist_import_items__track_id__tracks__id');

  $$TracksTableProcessedTableManager? get trackId {
    final $_column = $_itemColumn<int>('track_id');
    if ($_column == null) return null;
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaylistImportItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PlaylistImportItemsTable> {
  $$PlaylistImportItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowIndex => $composableBuilder(
    column: $table.rowIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get artists => $composableBuilder(
    column: $table.artists,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get candidates => $composableBuilder(
    column: $table.candidates,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  $$PlaylistImportsTableFilterComposer get importId {
    final $$PlaylistImportsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.playlistImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistImportsTableFilterComposer(
            $db: $db,
            $table: $db.playlistImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistImportItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaylistImportItemsTable> {
  $$PlaylistImportItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowIndex => $composableBuilder(
    column: $table.rowIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get artists => $composableBuilder(
    column: $table.artists,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get album => $composableBuilder(
    column: $table.album,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get isrc => $composableBuilder(
    column: $table.isrc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get videoId => $composableBuilder(
    column: $table.videoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get candidates => $composableBuilder(
    column: $table.candidates,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  $$PlaylistImportsTableOrderingComposer get importId {
    final $$PlaylistImportsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.playlistImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistImportsTableOrderingComposer(
            $db: $db,
            $table: $db.playlistImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistImportItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaylistImportItemsTable> {
  $$PlaylistImportItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowIndex =>
      $composableBuilder(column: $table.rowIndex, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artists =>
      $composableBuilder(column: $table.artists, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get isrc =>
      $composableBuilder(column: $table.isrc, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get videoId =>
      $composableBuilder(column: $table.videoId, builder: (column) => column);

  GeneratedColumn<String> get candidates => $composableBuilder(
    column: $table.candidates,
    builder: (column) => column,
  );

  GeneratedColumn<double> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  $$PlaylistImportsTableAnnotationComposer get importId {
    final $$PlaylistImportsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.importId,
      referencedTable: $db.playlistImports,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaylistImportsTableAnnotationComposer(
            $db: $db,
            $table: $db.playlistImports,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaylistImportItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaylistImportItemsTable,
          PlaylistImportItem,
          $$PlaylistImportItemsTableFilterComposer,
          $$PlaylistImportItemsTableOrderingComposer,
          $$PlaylistImportItemsTableAnnotationComposer,
          $$PlaylistImportItemsTableCreateCompanionBuilder,
          $$PlaylistImportItemsTableUpdateCompanionBuilder,
          (PlaylistImportItem, $$PlaylistImportItemsTableReferences),
          PlaylistImportItem,
          PrefetchHooks Function({bool importId, bool trackId})
        > {
  $$PlaylistImportItemsTableTableManager(
    _$AppDatabase db,
    $PlaylistImportItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaylistImportItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaylistImportItemsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PlaylistImportItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> importId = const Value.absent(),
                Value<int> rowIndex = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> artists = const Value.absent(),
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> videoId = const Value.absent(),
                Value<String?> candidates = const Value.absent(),
                Value<int?> trackId = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistImportItemsCompanion(
                importId: importId,
                rowIndex: rowIndex,
                title: title,
                artists: artists,
                album: album,
                durationMs: durationMs,
                isrc: isrc,
                year: year,
                status: status,
                videoId: videoId,
                candidates: candidates,
                trackId: trackId,
                score: score,
                note: note,
                location: location,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int importId,
                required int rowIndex,
                required String title,
                required String artists,
                Value<String?> album = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String?> isrc = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> videoId = const Value.absent(),
                Value<String?> candidates = const Value.absent(),
                Value<int?> trackId = const Value.absent(),
                Value<double?> score = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaylistImportItemsCompanion.insert(
                importId: importId,
                rowIndex: rowIndex,
                title: title,
                artists: artists,
                album: album,
                durationMs: durationMs,
                isrc: isrc,
                year: year,
                status: status,
                videoId: videoId,
                candidates: candidates,
                trackId: trackId,
                score: score,
                note: note,
                location: location,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaylistImportItemsTable, PlaylistImportItem>(
                    table,
                  ),
                  $$PlaylistImportItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({importId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (importId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.importId,
                        referencedTable: $$PlaylistImportItemsTableReferences
                            ._importIdTable(db),
                        referencedColumn: $$PlaylistImportItemsTableReferences
                            ._importIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlaylistImportItemsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PlaylistImportItemsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaylistImportItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaylistImportItemsTable,
      PlaylistImportItem,
      $$PlaylistImportItemsTableFilterComposer,
      $$PlaylistImportItemsTableOrderingComposer,
      $$PlaylistImportItemsTableAnnotationComposer,
      $$PlaylistImportItemsTableCreateCompanionBuilder,
      $$PlaylistImportItemsTableUpdateCompanionBuilder,
      (PlaylistImportItem, $$PlaylistImportItemsTableReferences),
      PlaylistImportItem,
      PrefetchHooks Function({bool importId, bool trackId})
    >;
typedef $$PlaysTableCreateCompanionBuilder = PlaysCompanion Function({
  Value<int> id,
  required int trackId,
  required int playedAt,
  Value<int> msPlayed,
  Value<int?> context,
  Value<String?> contextName,
});
typedef $$PlaysTableUpdateCompanionBuilder = PlaysCompanion Function({
  Value<int> id,
  Value<int> trackId,
  Value<int> playedAt,
  Value<int> msPlayed,
  Value<int?> context,
  Value<String?> contextName,
});

final class $$PlaysTableReferences
    extends BaseReferences<_$AppDatabase, $PlaysTable, Play> {
  $$PlaysTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('plays__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaysTableFilterComposer extends Composer<_$AppDatabase, $PlaysTable> {
  $$PlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get msPlayed => $composableBuilder(
    column: $table.msPlayed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contextName => $composableBuilder(
    column: $table.contextName,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaysTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaysTable> {
  $$PlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get msPlayed => $composableBuilder(
    column: $table.msPlayed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get context => $composableBuilder(
    column: $table.context,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contextName => $composableBuilder(
    column: $table.contextName,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaysTable> {
  $$PlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  GeneratedColumn<int> get msPlayed =>
      $composableBuilder(column: $table.msPlayed, builder: (column) => column);

  GeneratedColumn<int> get context =>
      $composableBuilder(column: $table.context, builder: (column) => column);

  GeneratedColumn<String> get contextName => $composableBuilder(
    column: $table.contextName,
    builder: (column) => column,
  );

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaysTable,
          Play,
          $$PlaysTableFilterComposer,
          $$PlaysTableOrderingComposer,
          $$PlaysTableAnnotationComposer,
          $$PlaysTableCreateCompanionBuilder,
          $$PlaysTableUpdateCompanionBuilder,
          (Play, $$PlaysTableReferences),
          Play,
          PrefetchHooks Function({bool trackId})
        > {
  $$PlaysTableTableManager(_$AppDatabase db, $PlaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> trackId = const Value.absent(),
                Value<int> playedAt = const Value.absent(),
                Value<int> msPlayed = const Value.absent(),
                Value<int?> context = const Value.absent(),
                Value<String?> contextName = const Value.absent(),
              }) => PlaysCompanion(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                msPlayed: msPlayed,
                context: context,
                contextName: contextName,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int trackId,
                required int playedAt,
                Value<int> msPlayed = const Value.absent(),
                Value<int?> context = const Value.absent(),
                Value<String?> contextName = const Value.absent(),
              }) => PlaysCompanion.insert(
                id: id,
                trackId: trackId,
                playedAt: playedAt,
                msPlayed: msPlayed,
                context: context,
                contextName: contextName,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlaysTable, Play>(table),
                  $$PlaysTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PlaysTableReferences._trackIdTable(
                          db,
                        ),
                        referencedColumn: $$PlaysTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaysTable,
      Play,
      $$PlaysTableFilterComposer,
      $$PlaysTableOrderingComposer,
      $$PlaysTableAnnotationComposer,
      $$PlaysTableCreateCompanionBuilder,
      $$PlaysTableUpdateCompanionBuilder,
      (Play, $$PlaysTableReferences),
      Play,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$SmartPlaylistsTableCreateCompanionBuilder =
    SmartPlaylistsCompanion Function({
      Value<int> id,
      required String name,
      required String rules,
      Value<String?> sort,
      Value<int?> limitCount,
      required int createdAt,
    });
typedef $$SmartPlaylistsTableUpdateCompanionBuilder =
    SmartPlaylistsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> rules,
      Value<String?> sort,
      Value<int?> limitCount,
      Value<int> createdAt,
    });

class $$SmartPlaylistsTableFilterComposer
    extends Composer<_$AppDatabase, $SmartPlaylistsTable> {
  $$SmartPlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rules => $composableBuilder(
    column: $table.rules,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limitCount => $composableBuilder(
    column: $table.limitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SmartPlaylistsTableOrderingComposer
    extends Composer<_$AppDatabase, $SmartPlaylistsTable> {
  $$SmartPlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rules => $composableBuilder(
    column: $table.rules,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sort => $composableBuilder(
    column: $table.sort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limitCount => $composableBuilder(
    column: $table.limitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SmartPlaylistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SmartPlaylistsTable> {
  $$SmartPlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get rules =>
      $composableBuilder(column: $table.rules, builder: (column) => column);

  GeneratedColumn<String> get sort =>
      $composableBuilder(column: $table.sort, builder: (column) => column);

  GeneratedColumn<int> get limitCount => $composableBuilder(
    column: $table.limitCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SmartPlaylistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SmartPlaylistsTable,
          SmartPlaylist,
          $$SmartPlaylistsTableFilterComposer,
          $$SmartPlaylistsTableOrderingComposer,
          $$SmartPlaylistsTableAnnotationComposer,
          $$SmartPlaylistsTableCreateCompanionBuilder,
          $$SmartPlaylistsTableUpdateCompanionBuilder,
          (
            SmartPlaylist,
            BaseReferences<_$AppDatabase, $SmartPlaylistsTable, SmartPlaylist>,
          ),
          SmartPlaylist,
          PrefetchHooks Function()
        > {
  $$SmartPlaylistsTableTableManager(
    _$AppDatabase db,
    $SmartPlaylistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SmartPlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SmartPlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SmartPlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> rules = const Value.absent(),
                Value<String?> sort = const Value.absent(),
                Value<int?> limitCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => SmartPlaylistsCompanion(
                id: id,
                name: name,
                rules: rules,
                sort: sort,
                limitCount: limitCount,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String rules,
                Value<String?> sort = const Value.absent(),
                Value<int?> limitCount = const Value.absent(),
                required int createdAt,
              }) => SmartPlaylistsCompanion.insert(
                id: id,
                name: name,
                rules: rules,
                sort: sort,
                limitCount: limitCount,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SmartPlaylistsTable, SmartPlaylist>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SmartPlaylistsTable,
                    SmartPlaylist
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SmartPlaylistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SmartPlaylistsTable,
      SmartPlaylist,
      $$SmartPlaylistsTableFilterComposer,
      $$SmartPlaylistsTableOrderingComposer,
      $$SmartPlaylistsTableAnnotationComposer,
      $$SmartPlaylistsTableCreateCompanionBuilder,
      $$SmartPlaylistsTableUpdateCompanionBuilder,
      (
        SmartPlaylist,
        BaseReferences<_$AppDatabase, $SmartPlaylistsTable, SmartPlaylist>,
      ),
      SmartPlaylist,
      PrefetchHooks Function()
    >;
typedef $$UserTagsTableCreateCompanionBuilder = UserTagsCompanion Function({
  Value<int> id,
  required String name,
  Value<int?> color,
});
typedef $$UserTagsTableUpdateCompanionBuilder = UserTagsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<int?> color,
});

final class $$UserTagsTableReferences
    extends BaseReferences<_$AppDatabase, $UserTagsTable, UserTag> {
  $$UserTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TrackTagsTable, List<TrackTag>>
  _trackTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.trackTags,
    aliasName: 'user_tags__id__track_tags__tag_id',
  );

  $$TrackTagsTableProcessedTableManager get trackTagsRefs {
    final manager = $$TrackTagsTableTableManager(
      $_db,
      $_db.trackTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_trackTagsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UserTagsTableFilterComposer
    extends Composer<_$AppDatabase, $UserTagsTable> {
  $$UserTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> trackTagsRefs(
    Expression<bool> Function($$TrackTagsTableFilterComposer f) f,
  ) {
    final $$TrackTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackTagsTableFilterComposer(
            $db: $db,
            $table: $db.trackTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserTagsTable> {
  $$UserTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserTagsTable> {
  $$UserTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  Expression<T> trackTagsRefs<T extends Object>(
    Expression<T> Function($$TrackTagsTableAnnotationComposer a) f,
  ) {
    final $$TrackTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.trackTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TrackTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.trackTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserTagsTable,
          UserTag,
          $$UserTagsTableFilterComposer,
          $$UserTagsTableOrderingComposer,
          $$UserTagsTableAnnotationComposer,
          $$UserTagsTableCreateCompanionBuilder,
          $$UserTagsTableUpdateCompanionBuilder,
          (UserTag, $$UserTagsTableReferences),
          UserTag,
          PrefetchHooks Function({bool trackTagsRefs})
        > {
  $$UserTagsTableTableManager(_$AppDatabase db, $UserTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<int?> color = const Value.absent(),
          }) => UserTagsCompanion(id: id, name: name, color: color),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<int?> color = const Value.absent(),
          }) => UserTagsCompanion.insert(id: id, name: name, color: color),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserTagsTable, UserTag>(table),
                  $$UserTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (trackTagsRefs) db.trackTags],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (trackTagsRefs)
                    await $_getPrefetchedData<
                      UserTag,
                      $UserTagsTable,
                      TrackTag
                    >(
                      currentTable: table,
                      referencedTable: $$UserTagsTableReferences
                          ._trackTagsRefsTable(db),
                      managerFromTypedResult: (p0) => $$UserTagsTableReferences(
                        db,
                        table,
                        p0,
                      ).trackTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UserTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserTagsTable,
      UserTag,
      $$UserTagsTableFilterComposer,
      $$UserTagsTableOrderingComposer,
      $$UserTagsTableAnnotationComposer,
      $$UserTagsTableCreateCompanionBuilder,
      $$UserTagsTableUpdateCompanionBuilder,
      (UserTag, $$UserTagsTableReferences),
      UserTag,
      PrefetchHooks Function({bool trackTagsRefs})
    >;
typedef $$TrackTagsTableCreateCompanionBuilder = TrackTagsCompanion Function({
  required int trackId,
  required int tagId,
  Value<int> rowid,
});
typedef $$TrackTagsTableUpdateCompanionBuilder = TrackTagsCompanion Function({
  Value<int> trackId,
  Value<int> tagId,
  Value<int> rowid,
});

final class $$TrackTagsTableReferences
    extends BaseReferences<_$AppDatabase, $TrackTagsTable, TrackTag> {
  $$TrackTagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('track_tags__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $UserTagsTable _tagIdTable(_$AppDatabase db) =>
      db.userTags.createAlias('track_tags__tag_id__user_tags__id');

  $$UserTagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<int>('tag_id')!;

    final manager = $$UserTagsTableTableManager(
      $_db,
      $_db.userTags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackTagsTable> {
  $$TrackTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserTagsTableFilterComposer get tagId {
    final $$UserTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.userTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTagsTableFilterComposer(
            $db: $db,
            $table: $db.userTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackTagsTable> {
  $$TrackTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserTagsTableOrderingComposer get tagId {
    final $$UserTagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.userTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTagsTableOrderingComposer(
            $db: $db,
            $table: $db.userTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackTagsTable> {
  $$TrackTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$UserTagsTableAnnotationComposer get tagId {
    final $$UserTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.userTags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.userTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackTagsTable,
          TrackTag,
          $$TrackTagsTableFilterComposer,
          $$TrackTagsTableOrderingComposer,
          $$TrackTagsTableAnnotationComposer,
          $$TrackTagsTableCreateCompanionBuilder,
          $$TrackTagsTableUpdateCompanionBuilder,
          (TrackTag, $$TrackTagsTableReferences),
          TrackTag,
          PrefetchHooks Function({bool trackId, bool tagId})
        > {
  $$TrackTagsTableTableManager(_$AppDatabase db, $TrackTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<int> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackTagsCompanion(
                trackId: trackId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int trackId,
                required int tagId,
                Value<int> rowid = const Value.absent(),
              }) => TrackTagsCompanion.insert(
                trackId: trackId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackTagsTable, TrackTag>(table),
                  $$TrackTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$TrackTagsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackTagsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (tagId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.tagId,
                        referencedTable: $$TrackTagsTableReferences._tagIdTable(
                          db,
                        ),
                        referencedColumn: $$TrackTagsTableReferences
                            ._tagIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackTagsTable,
      TrackTag,
      $$TrackTagsTableFilterComposer,
      $$TrackTagsTableOrderingComposer,
      $$TrackTagsTableAnnotationComposer,
      $$TrackTagsTableCreateCompanionBuilder,
      $$TrackTagsTableUpdateCompanionBuilder,
      (TrackTag, $$TrackTagsTableReferences),
      TrackTag,
      PrefetchHooks Function({bool trackId, bool tagId})
    >;
typedef $$PodcastsTableCreateCompanionBuilder = PodcastsCompanion Function({
  Value<int> id,
  required String feedUrl,
  required String title,
  Value<String?> author,
  Value<String?> imageUrl,
  Value<String?> coverKey,
  Value<String?> language,
  Value<int?> lastCheckedAt,
  Value<int?> autoDeleteDays,
  required int addedAt,
});
typedef $$PodcastsTableUpdateCompanionBuilder = PodcastsCompanion Function({
  Value<int> id,
  Value<String> feedUrl,
  Value<String> title,
  Value<String?> author,
  Value<String?> imageUrl,
  Value<String?> coverKey,
  Value<String?> language,
  Value<int?> lastCheckedAt,
  Value<int?> autoDeleteDays,
  Value<int> addedAt,
});

final class $$PodcastsTableReferences
    extends BaseReferences<_$AppDatabase, $PodcastsTable, Podcast> {
  $$PodcastsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PodcastEpisodesTable, List<PodcastEpisode>>
  _podcastEpisodesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.podcastEpisodes,
    aliasName: 'podcasts__id__podcast_episodes__podcast_id',
  );

  $$PodcastEpisodesTableProcessedTableManager get podcastEpisodesRefs {
    final manager = $$PodcastEpisodesTableTableManager(
      $_db,
      $_db.podcastEpisodes,
    ).filter((f) => f.podcastId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _podcastEpisodesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PodcastsTableFilterComposer
    extends Composer<_$AppDatabase, $PodcastsTable> {
  $$PodcastsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoDeleteDays => $composableBuilder(
    column: $table.autoDeleteDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> podcastEpisodesRefs(
    Expression<bool> Function($$PodcastEpisodesTableFilterComposer f) f,
  ) {
    final $$PodcastEpisodesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.podcastId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableFilterComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastsTableOrderingComposer
    extends Composer<_$AppDatabase, $PodcastsTable> {
  $$PodcastsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get feedUrl => $composableBuilder(
    column: $table.feedUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get author => $composableBuilder(
    column: $table.author,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageUrl => $composableBuilder(
    column: $table.imageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverKey => $composableBuilder(
    column: $table.coverKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoDeleteDays => $composableBuilder(
    column: $table.autoDeleteDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PodcastsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PodcastsTable> {
  $$PodcastsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get feedUrl =>
      $composableBuilder(column: $table.feedUrl, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get imageUrl =>
      $composableBuilder(column: $table.imageUrl, builder: (column) => column);

  GeneratedColumn<String> get coverKey =>
      $composableBuilder(column: $table.coverKey, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoDeleteDays => $composableBuilder(
    column: $table.autoDeleteDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  Expression<T> podcastEpisodesRefs<T extends Object>(
    Expression<T> Function($$PodcastEpisodesTableAnnotationComposer a) f,
  ) {
    final $$PodcastEpisodesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.podcastEpisodes,
      getReferencedColumn: (t) => t.podcastId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastEpisodesTableAnnotationComposer(
            $db: $db,
            $table: $db.podcastEpisodes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PodcastsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PodcastsTable,
          Podcast,
          $$PodcastsTableFilterComposer,
          $$PodcastsTableOrderingComposer,
          $$PodcastsTableAnnotationComposer,
          $$PodcastsTableCreateCompanionBuilder,
          $$PodcastsTableUpdateCompanionBuilder,
          (Podcast, $$PodcastsTableReferences),
          Podcast,
          PrefetchHooks Function({bool podcastEpisodesRefs})
        > {
  $$PodcastsTableTableManager(_$AppDatabase db, $PodcastsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> feedUrl = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<int?> lastCheckedAt = const Value.absent(),
                Value<int?> autoDeleteDays = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
              }) => PodcastsCompanion(
                id: id,
                feedUrl: feedUrl,
                title: title,
                author: author,
                imageUrl: imageUrl,
                coverKey: coverKey,
                language: language,
                lastCheckedAt: lastCheckedAt,
                autoDeleteDays: autoDeleteDays,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String feedUrl,
                required String title,
                Value<String?> author = const Value.absent(),
                Value<String?> imageUrl = const Value.absent(),
                Value<String?> coverKey = const Value.absent(),
                Value<String?> language = const Value.absent(),
                Value<int?> lastCheckedAt = const Value.absent(),
                Value<int?> autoDeleteDays = const Value.absent(),
                required int addedAt,
              }) => PodcastsCompanion.insert(
                id: id,
                feedUrl: feedUrl,
                title: title,
                author: author,
                imageUrl: imageUrl,
                coverKey: coverKey,
                language: language,
                lastCheckedAt: lastCheckedAt,
                autoDeleteDays: autoDeleteDays,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PodcastsTable, Podcast>(table),
                  $$PodcastsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({podcastEpisodesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (podcastEpisodesRefs) db.podcastEpisodes,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (podcastEpisodesRefs)
                    await $_getPrefetchedData<
                      Podcast,
                      $PodcastsTable,
                      PodcastEpisode
                    >(
                      currentTable: table,
                      referencedTable: $$PodcastsTableReferences
                          ._podcastEpisodesRefsTable(db),
                      managerFromTypedResult: (p0) => $$PodcastsTableReferences(
                        db,
                        table,
                        p0,
                      ).podcastEpisodesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.podcastId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$PodcastsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PodcastsTable,
      Podcast,
      $$PodcastsTableFilterComposer,
      $$PodcastsTableOrderingComposer,
      $$PodcastsTableAnnotationComposer,
      $$PodcastsTableCreateCompanionBuilder,
      $$PodcastsTableUpdateCompanionBuilder,
      (Podcast, $$PodcastsTableReferences),
      Podcast,
      PrefetchHooks Function({bool podcastEpisodesRefs})
    >;
typedef $$PodcastEpisodesTableCreateCompanionBuilder =
    PodcastEpisodesCompanion Function({
      Value<int> id,
      required int podcastId,
      required String guid,
      required String title,
      Value<int?> publishedAt,
      Value<int?> durationMs,
      required String audioUrl,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      Value<String?> description,
      Value<int?> trackId,
      Value<bool> played,
      Value<int?> playedAt,
    });
typedef $$PodcastEpisodesTableUpdateCompanionBuilder =
    PodcastEpisodesCompanion Function({
      Value<int> id,
      Value<int> podcastId,
      Value<String> guid,
      Value<String> title,
      Value<int?> publishedAt,
      Value<int?> durationMs,
      Value<String> audioUrl,
      Value<String?> mimeType,
      Value<int?> sizeBytes,
      Value<String?> description,
      Value<int?> trackId,
      Value<bool> played,
      Value<int?> playedAt,
    });

final class $$PodcastEpisodesTableReferences
    extends
        BaseReferences<_$AppDatabase, $PodcastEpisodesTable, PodcastEpisode> {
  $$PodcastEpisodesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PodcastsTable _podcastIdTable(_$AppDatabase db) =>
      db.podcasts.createAlias('podcast_episodes__podcast_id__podcasts__id');

  $$PodcastsTableProcessedTableManager get podcastId {
    final $_column = $_itemColumn<int>('podcast_id')!;

    final manager = $$PodcastsTableTableManager(
      $_db,
      $_db.podcasts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_podcastIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('podcast_episodes__track_id__tracks__id');

  $$TracksTableProcessedTableManager? get trackId {
    final $_column = $_itemColumn<int>('track_id');
    if ($_column == null) return null;
    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PodcastEpisodesTableFilterComposer
    extends Composer<_$AppDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PodcastsTableFilterComposer get podcastId {
    final $$PodcastsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableFilterComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PodcastEpisodesTableOrderingComposer
    extends Composer<_$AppDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get guid => $composableBuilder(
    column: $table.guid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioUrl => $composableBuilder(
    column: $table.audioUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playedAt => $composableBuilder(
    column: $table.playedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PodcastsTableOrderingComposer get podcastId {
    final $$PodcastsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableOrderingComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PodcastEpisodesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PodcastEpisodesTable> {
  $$PodcastEpisodesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get guid =>
      $composableBuilder(column: $table.guid, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get publishedAt => $composableBuilder(
    column: $table.publishedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get audioUrl =>
      $composableBuilder(column: $table.audioUrl, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get played =>
      $composableBuilder(column: $table.played, builder: (column) => column);

  GeneratedColumn<int> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);

  $$PodcastsTableAnnotationComposer get podcastId {
    final $$PodcastsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.podcastId,
      referencedTable: $db.podcasts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PodcastsTableAnnotationComposer(
            $db: $db,
            $table: $db.podcasts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PodcastEpisodesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PodcastEpisodesTable,
          PodcastEpisode,
          $$PodcastEpisodesTableFilterComposer,
          $$PodcastEpisodesTableOrderingComposer,
          $$PodcastEpisodesTableAnnotationComposer,
          $$PodcastEpisodesTableCreateCompanionBuilder,
          $$PodcastEpisodesTableUpdateCompanionBuilder,
          (PodcastEpisode, $$PodcastEpisodesTableReferences),
          PodcastEpisode,
          PrefetchHooks Function({bool podcastId, bool trackId})
        > {
  $$PodcastEpisodesTableTableManager(
    _$AppDatabase db,
    $PodcastEpisodesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PodcastEpisodesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PodcastEpisodesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PodcastEpisodesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> podcastId = const Value.absent(),
                Value<String> guid = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> publishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<String> audioUrl = const Value.absent(),
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int?> trackId = const Value.absent(),
                Value<bool> played = const Value.absent(),
                Value<int?> playedAt = const Value.absent(),
              }) => PodcastEpisodesCompanion(
                id: id,
                podcastId: podcastId,
                guid: guid,
                title: title,
                publishedAt: publishedAt,
                durationMs: durationMs,
                audioUrl: audioUrl,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                description: description,
                trackId: trackId,
                played: played,
                playedAt: playedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int podcastId,
                required String guid,
                required String title,
                Value<int?> publishedAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                required String audioUrl,
                Value<String?> mimeType = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int?> trackId = const Value.absent(),
                Value<bool> played = const Value.absent(),
                Value<int?> playedAt = const Value.absent(),
              }) => PodcastEpisodesCompanion.insert(
                id: id,
                podcastId: podcastId,
                guid: guid,
                title: title,
                publishedAt: publishedAt,
                durationMs: durationMs,
                audioUrl: audioUrl,
                mimeType: mimeType,
                sizeBytes: sizeBytes,
                description: description,
                trackId: trackId,
                played: played,
                playedAt: playedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PodcastEpisodesTable, PodcastEpisode>(table),
                  $$PodcastEpisodesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({podcastId = false, trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (podcastId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.podcastId,
                        referencedTable: $$PodcastEpisodesTableReferences
                            ._podcastIdTable(db),
                        referencedColumn: $$PodcastEpisodesTableReferences
                            ._podcastIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$PodcastEpisodesTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$PodcastEpisodesTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PodcastEpisodesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PodcastEpisodesTable,
      PodcastEpisode,
      $$PodcastEpisodesTableFilterComposer,
      $$PodcastEpisodesTableOrderingComposer,
      $$PodcastEpisodesTableAnnotationComposer,
      $$PodcastEpisodesTableCreateCompanionBuilder,
      $$PodcastEpisodesTableUpdateCompanionBuilder,
      (PodcastEpisode, $$PodcastEpisodesTableReferences),
      PodcastEpisode,
      PrefetchHooks Function({bool podcastId, bool trackId})
    >;
typedef $$ArtistInfosTableCreateCompanionBuilder =
    ArtistInfosCompanion Function({
      required String artistKey,
      required String body,
      required String sourceUrl,
      required String lang,
      required int fetchedAt,
      Value<int> rowid,
    });
typedef $$ArtistInfosTableUpdateCompanionBuilder =
    ArtistInfosCompanion Function({
      Value<String> artistKey,
      Value<String> body,
      Value<String> sourceUrl,
      Value<String> lang,
      Value<int> fetchedAt,
      Value<int> rowid,
    });

class $$ArtistInfosTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistInfosTable> {
  $$ArtistInfosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtistInfosTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistInfosTable> {
  $$ArtistInfosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistInfosTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistInfosTable> {
  $$ArtistInfosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get artistKey =>
      $composableBuilder(column: $table.artistKey, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ArtistInfosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistInfosTable,
          ArtistInfo,
          $$ArtistInfosTableFilterComposer,
          $$ArtistInfosTableOrderingComposer,
          $$ArtistInfosTableAnnotationComposer,
          $$ArtistInfosTableCreateCompanionBuilder,
          $$ArtistInfosTableUpdateCompanionBuilder,
          (
            ArtistInfo,
            BaseReferences<_$AppDatabase, $ArtistInfosTable, ArtistInfo>,
          ),
          ArtistInfo,
          PrefetchHooks Function()
        > {
  $$ArtistInfosTableTableManager(_$AppDatabase db, $ArtistInfosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistInfosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistInfosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistInfosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> artistKey = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> lang = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistInfosCompanion(
                artistKey: artistKey,
                body: body,
                sourceUrl: sourceUrl,
                lang: lang,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String artistKey,
                required String body,
                required String sourceUrl,
                required String lang,
                required int fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => ArtistInfosCompanion.insert(
                artistKey: artistKey,
                body: body,
                sourceUrl: sourceUrl,
                lang: lang,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistInfosTable, ArtistInfo>(table),
                  BaseReferences<_$AppDatabase, $ArtistInfosTable, ArtistInfo>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtistInfosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistInfosTable,
      ArtistInfo,
      $$ArtistInfosTableFilterComposer,
      $$ArtistInfosTableOrderingComposer,
      $$ArtistInfosTableAnnotationComposer,
      $$ArtistInfosTableCreateCompanionBuilder,
      $$ArtistInfosTableUpdateCompanionBuilder,
      (
        ArtistInfo,
        BaseReferences<_$AppDatabase, $ArtistInfosTable, ArtistInfo>,
      ),
      ArtistInfo,
      PrefetchHooks Function()
    >;
typedef $$RadioStationsTableCreateCompanionBuilder =
    RadioStationsCompanion Function({
      required String stationId,
      required String name,
      required String streamUrl,
      Value<String> homepage,
      Value<String> faviconUrl,
      Value<String> countryCode,
      Value<String> state,
      Value<String> tags,
      Value<String> codec,
      Value<int> bitrate,
      Value<bool> hls,
      required int position,
      Value<int> addedAt,
      Value<int?> lastPlayedAt,
      Value<int?> lastOkAt,
      Value<bool> unreachable,
      Value<int> rowid,
    });
typedef $$RadioStationsTableUpdateCompanionBuilder =
    RadioStationsCompanion Function({
      Value<String> stationId,
      Value<String> name,
      Value<String> streamUrl,
      Value<String> homepage,
      Value<String> faviconUrl,
      Value<String> countryCode,
      Value<String> state,
      Value<String> tags,
      Value<String> codec,
      Value<int> bitrate,
      Value<bool> hls,
      Value<int> position,
      Value<int> addedAt,
      Value<int?> lastPlayedAt,
      Value<int?> lastOkAt,
      Value<bool> unreachable,
      Value<int> rowid,
    });

class $$RadioStationsTableFilterComposer
    extends Composer<_$AppDatabase, $RadioStationsTable> {
  $$RadioStationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stationId => $composableBuilder(
    column: $table.stationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get homepage => $composableBuilder(
    column: $table.homepage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get faviconUrl => $composableBuilder(
    column: $table.faviconUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hls => $composableBuilder(
    column: $table.hls,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOkAt => $composableBuilder(
    column: $table.lastOkAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unreachable => $composableBuilder(
    column: $table.unreachable,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RadioStationsTableOrderingComposer
    extends Composer<_$AppDatabase, $RadioStationsTable> {
  $$RadioStationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stationId => $composableBuilder(
    column: $table.stationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get streamUrl => $composableBuilder(
    column: $table.streamUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get homepage => $composableBuilder(
    column: $table.homepage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get faviconUrl => $composableBuilder(
    column: $table.faviconUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bitrate => $composableBuilder(
    column: $table.bitrate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hls => $composableBuilder(
    column: $table.hls,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOkAt => $composableBuilder(
    column: $table.lastOkAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unreachable => $composableBuilder(
    column: $table.unreachable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RadioStationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RadioStationsTable> {
  $$RadioStationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stationId =>
      $composableBuilder(column: $table.stationId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get streamUrl =>
      $composableBuilder(column: $table.streamUrl, builder: (column) => column);

  GeneratedColumn<String> get homepage =>
      $composableBuilder(column: $table.homepage, builder: (column) => column);

  GeneratedColumn<String> get faviconUrl => $composableBuilder(
    column: $table.faviconUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get countryCode => $composableBuilder(
    column: $table.countryCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<String> get codec =>
      $composableBuilder(column: $table.codec, builder: (column) => column);

  GeneratedColumn<int> get bitrate =>
      $composableBuilder(column: $table.bitrate, builder: (column) => column);

  GeneratedColumn<bool> get hls =>
      $composableBuilder(column: $table.hls, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get lastPlayedAt => $composableBuilder(
    column: $table.lastPlayedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOkAt =>
      $composableBuilder(column: $table.lastOkAt, builder: (column) => column);

  GeneratedColumn<bool> get unreachable => $composableBuilder(
    column: $table.unreachable,
    builder: (column) => column,
  );
}

class $$RadioStationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RadioStationsTable,
          SavedRadio,
          $$RadioStationsTableFilterComposer,
          $$RadioStationsTableOrderingComposer,
          $$RadioStationsTableAnnotationComposer,
          $$RadioStationsTableCreateCompanionBuilder,
          $$RadioStationsTableUpdateCompanionBuilder,
          (
            SavedRadio,
            BaseReferences<_$AppDatabase, $RadioStationsTable, SavedRadio>,
          ),
          SavedRadio,
          PrefetchHooks Function()
        > {
  $$RadioStationsTableTableManager(_$AppDatabase db, $RadioStationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RadioStationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RadioStationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RadioStationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> stationId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> streamUrl = const Value.absent(),
                Value<String> homepage = const Value.absent(),
                Value<String> faviconUrl = const Value.absent(),
                Value<String> countryCode = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> codec = const Value.absent(),
                Value<int> bitrate = const Value.absent(),
                Value<bool> hls = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<int?> lastOkAt = const Value.absent(),
                Value<bool> unreachable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RadioStationsCompanion(
                stationId: stationId,
                name: name,
                streamUrl: streamUrl,
                homepage: homepage,
                faviconUrl: faviconUrl,
                countryCode: countryCode,
                state: state,
                tags: tags,
                codec: codec,
                bitrate: bitrate,
                hls: hls,
                position: position,
                addedAt: addedAt,
                lastPlayedAt: lastPlayedAt,
                lastOkAt: lastOkAt,
                unreachable: unreachable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String stationId,
                required String name,
                required String streamUrl,
                Value<String> homepage = const Value.absent(),
                Value<String> faviconUrl = const Value.absent(),
                Value<String> countryCode = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<String> codec = const Value.absent(),
                Value<int> bitrate = const Value.absent(),
                Value<bool> hls = const Value.absent(),
                required int position,
                Value<int> addedAt = const Value.absent(),
                Value<int?> lastPlayedAt = const Value.absent(),
                Value<int?> lastOkAt = const Value.absent(),
                Value<bool> unreachable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RadioStationsCompanion.insert(
                stationId: stationId,
                name: name,
                streamUrl: streamUrl,
                homepage: homepage,
                faviconUrl: faviconUrl,
                countryCode: countryCode,
                state: state,
                tags: tags,
                codec: codec,
                bitrate: bitrate,
                hls: hls,
                position: position,
                addedAt: addedAt,
                lastPlayedAt: lastPlayedAt,
                lastOkAt: lastOkAt,
                unreachable: unreachable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RadioStationsTable, SavedRadio>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $RadioStationsTable,
                    SavedRadio
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RadioStationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RadioStationsTable,
      SavedRadio,
      $$RadioStationsTableFilterComposer,
      $$RadioStationsTableOrderingComposer,
      $$RadioStationsTableAnnotationComposer,
      $$RadioStationsTableCreateCompanionBuilder,
      $$RadioStationsTableUpdateCompanionBuilder,
      (
        SavedRadio,
        BaseReferences<_$AppDatabase, $RadioStationsTable, SavedRadio>,
      ),
      SavedRadio,
      PrefetchHooks Function()
    >;
typedef $$FollowedArtistsTableCreateCompanionBuilder =
    FollowedArtistsCompanion Function({
      required String ytmId,
      required String name,
      Value<String?> thumbUrl,
      Value<int> origin,
      Value<bool> excluded,
      Value<bool> muted,
      Value<int> followedAt,
      Value<int?> lastCheckedAt,
      Value<String?> lastError,
      Value<int> checksFailed,
      Value<int> rowid,
    });
typedef $$FollowedArtistsTableUpdateCompanionBuilder =
    FollowedArtistsCompanion Function({
      Value<String> ytmId,
      Value<String> name,
      Value<String?> thumbUrl,
      Value<int> origin,
      Value<bool> excluded,
      Value<bool> muted,
      Value<int> followedAt,
      Value<int?> lastCheckedAt,
      Value<String?> lastError,
      Value<int> checksFailed,
      Value<int> rowid,
    });

final class $$FollowedArtistsTableReferences
    extends
        BaseReferences<_$AppDatabase, $FollowedArtistsTable, FollowedArtist> {
  $$FollowedArtistsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ArtistReleasesTable, List<ArtistRelease>>
  _artistReleasesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.artistReleases,
    aliasName: 'followed_artists__ytm_id__artist_releases__artist_id',
  );

  $$ArtistReleasesTableProcessedTableManager get artistReleasesRefs {
    final manager = $$ArtistReleasesTableTableManager($_db, $_db.artistReleases)
        .filter(
          (f) => f.artistId.ytmId.sqlEquals($_itemColumn<String>('ytm_id')!),
        );

    final cache = $_typedResult.readTableOrNull(_artistReleasesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FollowedArtistsTableFilterComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ytmId => $composableBuilder(
    column: $table.ytmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get excluded => $composableBuilder(
    column: $table.excluded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get followedAt => $composableBuilder(
    column: $table.followedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checksFailed => $composableBuilder(
    column: $table.checksFailed,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> artistReleasesRefs(
    Expression<bool> Function($$ArtistReleasesTableFilterComposer f) f,
  ) {
    final $$ArtistReleasesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ytmId,
      referencedTable: $db.artistReleases,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistReleasesTableFilterComposer(
            $db: $db,
            $table: $db.artistReleases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FollowedArtistsTableOrderingComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ytmId => $composableBuilder(
    column: $table.ytmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get origin => $composableBuilder(
    column: $table.origin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get excluded => $composableBuilder(
    column: $table.excluded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get muted => $composableBuilder(
    column: $table.muted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get followedAt => $composableBuilder(
    column: $table.followedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checksFailed => $composableBuilder(
    column: $table.checksFailed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FollowedArtistsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FollowedArtistsTable> {
  $$FollowedArtistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ytmId =>
      $composableBuilder(column: $table.ytmId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<int> get origin =>
      $composableBuilder(column: $table.origin, builder: (column) => column);

  GeneratedColumn<bool> get excluded =>
      $composableBuilder(column: $table.excluded, builder: (column) => column);

  GeneratedColumn<bool> get muted =>
      $composableBuilder(column: $table.muted, builder: (column) => column);

  GeneratedColumn<int> get followedAt => $composableBuilder(
    column: $table.followedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastCheckedAt => $composableBuilder(
    column: $table.lastCheckedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get checksFailed => $composableBuilder(
    column: $table.checksFailed,
    builder: (column) => column,
  );

  Expression<T> artistReleasesRefs<T extends Object>(
    Expression<T> Function($$ArtistReleasesTableAnnotationComposer a) f,
  ) {
    final $$ArtistReleasesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ytmId,
      referencedTable: $db.artistReleases,
      getReferencedColumn: (t) => t.artistId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ArtistReleasesTableAnnotationComposer(
            $db: $db,
            $table: $db.artistReleases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FollowedArtistsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FollowedArtistsTable,
          FollowedArtist,
          $$FollowedArtistsTableFilterComposer,
          $$FollowedArtistsTableOrderingComposer,
          $$FollowedArtistsTableAnnotationComposer,
          $$FollowedArtistsTableCreateCompanionBuilder,
          $$FollowedArtistsTableUpdateCompanionBuilder,
          (FollowedArtist, $$FollowedArtistsTableReferences),
          FollowedArtist,
          PrefetchHooks Function({bool artistReleasesRefs})
        > {
  $$FollowedArtistsTableTableManager(
    _$AppDatabase db,
    $FollowedArtistsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FollowedArtistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FollowedArtistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FollowedArtistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ytmId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> origin = const Value.absent(),
                Value<bool> excluded = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<int> followedAt = const Value.absent(),
                Value<int?> lastCheckedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> checksFailed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FollowedArtistsCompanion(
                ytmId: ytmId,
                name: name,
                thumbUrl: thumbUrl,
                origin: origin,
                excluded: excluded,
                muted: muted,
                followedAt: followedAt,
                lastCheckedAt: lastCheckedAt,
                lastError: lastError,
                checksFailed: checksFailed,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String ytmId,
                required String name,
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> origin = const Value.absent(),
                Value<bool> excluded = const Value.absent(),
                Value<bool> muted = const Value.absent(),
                Value<int> followedAt = const Value.absent(),
                Value<int?> lastCheckedAt = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int> checksFailed = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FollowedArtistsCompanion.insert(
                ytmId: ytmId,
                name: name,
                thumbUrl: thumbUrl,
                origin: origin,
                excluded: excluded,
                muted: muted,
                followedAt: followedAt,
                lastCheckedAt: lastCheckedAt,
                lastError: lastError,
                checksFailed: checksFailed,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FollowedArtistsTable, FollowedArtist>(table),
                  $$FollowedArtistsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({artistReleasesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (artistReleasesRefs) db.artistReleases,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (artistReleasesRefs)
                    await $_getPrefetchedData<
                      FollowedArtist,
                      $FollowedArtistsTable,
                      ArtistRelease
                    >(
                      currentTable: table,
                      referencedTable: $$FollowedArtistsTableReferences
                          ._artistReleasesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FollowedArtistsTableReferences(
                            db,
                            table,
                            p0,
                          ).artistReleasesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.artistId == item.ytmId,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FollowedArtistsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FollowedArtistsTable,
      FollowedArtist,
      $$FollowedArtistsTableFilterComposer,
      $$FollowedArtistsTableOrderingComposer,
      $$FollowedArtistsTableAnnotationComposer,
      $$FollowedArtistsTableCreateCompanionBuilder,
      $$FollowedArtistsTableUpdateCompanionBuilder,
      (FollowedArtist, $$FollowedArtistsTableReferences),
      FollowedArtist,
      PrefetchHooks Function({bool artistReleasesRefs})
    >;
typedef $$ArtistReleasesTableCreateCompanionBuilder =
    ArtistReleasesCompanion Function({
      required String browseId,
      required String artistId,
      required String title,
      required int kind,
      Value<int?> year,
      Value<String?> thumbUrl,
      required int firstSeenAt,
      Value<bool> isNew,
      Value<int?> openedAt,
      required String groupKey,
      Value<int> rowid,
    });
typedef $$ArtistReleasesTableUpdateCompanionBuilder =
    ArtistReleasesCompanion Function({
      Value<String> browseId,
      Value<String> artistId,
      Value<String> title,
      Value<int> kind,
      Value<int?> year,
      Value<String?> thumbUrl,
      Value<int> firstSeenAt,
      Value<bool> isNew,
      Value<int?> openedAt,
      Value<String> groupKey,
      Value<int> rowid,
    });

final class $$ArtistReleasesTableReferences
    extends BaseReferences<_$AppDatabase, $ArtistReleasesTable, ArtistRelease> {
  $$ArtistReleasesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FollowedArtistsTable _artistIdTable(_$AppDatabase db) => db
      .followedArtists
      .createAlias('artist_releases__artist_id__followed_artists__ytm_id');

  $$FollowedArtistsTableProcessedTableManager get artistId {
    final $_column = $_itemColumn<String>('artist_id')!;

    final manager = $$FollowedArtistsTableTableManager(
      $_db,
      $_db.followedArtists,
    ).filter((f) => f.ytmId.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_artistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ArtistReleasesTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistReleasesTable> {
  $$ArtistReleasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupKey => $composableBuilder(
    column: $table.groupKey,
    builder: (column) => ColumnFilters(column),
  );

  $$FollowedArtistsTableFilterComposer get artistId {
    final $$FollowedArtistsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.followedArtists,
      getReferencedColumn: (t) => t.ytmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FollowedArtistsTableFilterComposer(
            $db: $db,
            $table: $db.followedArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArtistReleasesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistReleasesTable> {
  $$ArtistReleasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get browseId => $composableBuilder(
    column: $table.browseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get year => $composableBuilder(
    column: $table.year,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNew => $composableBuilder(
    column: $table.isNew,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupKey => $composableBuilder(
    column: $table.groupKey,
    builder: (column) => ColumnOrderings(column),
  );

  $$FollowedArtistsTableOrderingComposer get artistId {
    final $$FollowedArtistsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.followedArtists,
      getReferencedColumn: (t) => t.ytmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FollowedArtistsTableOrderingComposer(
            $db: $db,
            $table: $db.followedArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArtistReleasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistReleasesTable> {
  $$ArtistReleasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get browseId =>
      $composableBuilder(column: $table.browseId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<int> get firstSeenAt => $composableBuilder(
    column: $table.firstSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isNew =>
      $composableBuilder(column: $table.isNew, builder: (column) => column);

  GeneratedColumn<int> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<String> get groupKey =>
      $composableBuilder(column: $table.groupKey, builder: (column) => column);

  $$FollowedArtistsTableAnnotationComposer get artistId {
    final $$FollowedArtistsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.artistId,
      referencedTable: $db.followedArtists,
      getReferencedColumn: (t) => t.ytmId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FollowedArtistsTableAnnotationComposer(
            $db: $db,
            $table: $db.followedArtists,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ArtistReleasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistReleasesTable,
          ArtistRelease,
          $$ArtistReleasesTableFilterComposer,
          $$ArtistReleasesTableOrderingComposer,
          $$ArtistReleasesTableAnnotationComposer,
          $$ArtistReleasesTableCreateCompanionBuilder,
          $$ArtistReleasesTableUpdateCompanionBuilder,
          (ArtistRelease, $$ArtistReleasesTableReferences),
          ArtistRelease,
          PrefetchHooks Function({bool artistId})
        > {
  $$ArtistReleasesTableTableManager(
    _$AppDatabase db,
    $ArtistReleasesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistReleasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistReleasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistReleasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> browseId = const Value.absent(),
                Value<String> artistId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> kind = const Value.absent(),
                Value<int?> year = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> firstSeenAt = const Value.absent(),
                Value<bool> isNew = const Value.absent(),
                Value<int?> openedAt = const Value.absent(),
                Value<String> groupKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistReleasesCompanion(
                browseId: browseId,
                artistId: artistId,
                title: title,
                kind: kind,
                year: year,
                thumbUrl: thumbUrl,
                firstSeenAt: firstSeenAt,
                isNew: isNew,
                openedAt: openedAt,
                groupKey: groupKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String browseId,
                required String artistId,
                required String title,
                required int kind,
                Value<int?> year = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                required int firstSeenAt,
                Value<bool> isNew = const Value.absent(),
                Value<int?> openedAt = const Value.absent(),
                required String groupKey,
                Value<int> rowid = const Value.absent(),
              }) => ArtistReleasesCompanion.insert(
                browseId: browseId,
                artistId: artistId,
                title: title,
                kind: kind,
                year: year,
                thumbUrl: thumbUrl,
                firstSeenAt: firstSeenAt,
                isNew: isNew,
                openedAt: openedAt,
                groupKey: groupKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistReleasesTable, ArtistRelease>(table),
                  $$ArtistReleasesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({artistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (artistId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.artistId,
                        referencedTable: $$ArtistReleasesTableReferences
                            ._artistIdTable(db),
                        referencedColumn: $$ArtistReleasesTableReferences
                            ._artistIdTable(db)
                            .ytmId,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ArtistReleasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistReleasesTable,
      ArtistRelease,
      $$ArtistReleasesTableFilterComposer,
      $$ArtistReleasesTableOrderingComposer,
      $$ArtistReleasesTableAnnotationComposer,
      $$ArtistReleasesTableCreateCompanionBuilder,
      $$ArtistReleasesTableUpdateCompanionBuilder,
      (ArtistRelease, $$ArtistReleasesTableReferences),
      ArtistRelease,
      PrefetchHooks Function({bool artistId})
    >;
typedef $$ArtistLookupsTableCreateCompanionBuilder =
    ArtistLookupsCompanion Function({
      required String artistKey,
      required String name,
      required int status,
      Value<String?> ytmId,
      Value<String?> ytmName,
      Value<String?> thumbUrl,
      required int checkedAt,
      Value<int> rowid,
    });
typedef $$ArtistLookupsTableUpdateCompanionBuilder =
    ArtistLookupsCompanion Function({
      Value<String> artistKey,
      Value<String> name,
      Value<int> status,
      Value<String?> ytmId,
      Value<String?> ytmName,
      Value<String?> thumbUrl,
      Value<int> checkedAt,
      Value<int> rowid,
    });

class $$ArtistLookupsTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistLookupsTable> {
  $$ArtistLookupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ytmId => $composableBuilder(
    column: $table.ytmId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ytmName => $composableBuilder(
    column: $table.ytmName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtistLookupsTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistLookupsTable> {
  $$ArtistLookupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ytmId => $composableBuilder(
    column: $table.ytmId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ytmName => $composableBuilder(
    column: $table.ytmName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbUrl => $composableBuilder(
    column: $table.thumbUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistLookupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistLookupsTable> {
  $$ArtistLookupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get artistKey =>
      $composableBuilder(column: $table.artistKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get ytmId =>
      $composableBuilder(column: $table.ytmId, builder: (column) => column);

  GeneratedColumn<String> get ytmName =>
      $composableBuilder(column: $table.ytmName, builder: (column) => column);

  GeneratedColumn<String> get thumbUrl =>
      $composableBuilder(column: $table.thumbUrl, builder: (column) => column);

  GeneratedColumn<int> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$ArtistLookupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistLookupsTable,
          ArtistLookup,
          $$ArtistLookupsTableFilterComposer,
          $$ArtistLookupsTableOrderingComposer,
          $$ArtistLookupsTableAnnotationComposer,
          $$ArtistLookupsTableCreateCompanionBuilder,
          $$ArtistLookupsTableUpdateCompanionBuilder,
          (
            ArtistLookup,
            BaseReferences<_$AppDatabase, $ArtistLookupsTable, ArtistLookup>,
          ),
          ArtistLookup,
          PrefetchHooks Function()
        > {
  $$ArtistLookupsTableTableManager(_$AppDatabase db, $ArtistLookupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistLookupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistLookupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistLookupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> artistKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<String?> ytmId = const Value.absent(),
                Value<String?> ytmName = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                Value<int> checkedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistLookupsCompanion(
                artistKey: artistKey,
                name: name,
                status: status,
                ytmId: ytmId,
                ytmName: ytmName,
                thumbUrl: thumbUrl,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String artistKey,
                required String name,
                required int status,
                Value<String?> ytmId = const Value.absent(),
                Value<String?> ytmName = const Value.absent(),
                Value<String?> thumbUrl = const Value.absent(),
                required int checkedAt,
                Value<int> rowid = const Value.absent(),
              }) => ArtistLookupsCompanion.insert(
                artistKey: artistKey,
                name: name,
                status: status,
                ytmId: ytmId,
                ytmName: ytmName,
                thumbUrl: thumbUrl,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistLookupsTable, ArtistLookup>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ArtistLookupsTable,
                    ArtistLookup
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtistLookupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistLookupsTable,
      ArtistLookup,
      $$ArtistLookupsTableFilterComposer,
      $$ArtistLookupsTableOrderingComposer,
      $$ArtistLookupsTableAnnotationComposer,
      $$ArtistLookupsTableCreateCompanionBuilder,
      $$ArtistLookupsTableUpdateCompanionBuilder,
      (
        ArtistLookup,
        BaseReferences<_$AppDatabase, $ArtistLookupsTable, ArtistLookup>,
      ),
      ArtistLookup,
      PrefetchHooks Function()
    >;
typedef $$TrackCreditsTableCreateCompanionBuilder =
    TrackCreditsCompanion Function({
      required int trackId,
      required String name,
      required String nameKey,
      required String role,
      required String source,
      Value<int> rowid,
    });
typedef $$TrackCreditsTableUpdateCompanionBuilder =
    TrackCreditsCompanion Function({
      Value<int> trackId,
      Value<String> name,
      Value<String> nameKey,
      Value<String> role,
      Value<String> source,
      Value<int> rowid,
    });

final class $$TrackCreditsTableReferences
    extends BaseReferences<_$AppDatabase, $TrackCreditsTable, TrackCreditRow> {
  $$TrackCreditsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('track_credits__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackCreditsTableFilterComposer
    extends Composer<_$AppDatabase, $TrackCreditsTable> {
  $$TrackCreditsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackCreditsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackCreditsTable> {
  $$TrackCreditsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nameKey => $composableBuilder(
    column: $table.nameKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackCreditsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackCreditsTable> {
  $$TrackCreditsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get nameKey =>
      $composableBuilder(column: $table.nameKey, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackCreditsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackCreditsTable,
          TrackCreditRow,
          $$TrackCreditsTableFilterComposer,
          $$TrackCreditsTableOrderingComposer,
          $$TrackCreditsTableAnnotationComposer,
          $$TrackCreditsTableCreateCompanionBuilder,
          $$TrackCreditsTableUpdateCompanionBuilder,
          (TrackCreditRow, $$TrackCreditsTableReferences),
          TrackCreditRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$TrackCreditsTableTableManager(_$AppDatabase db, $TrackCreditsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackCreditsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackCreditsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackCreditsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> nameKey = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackCreditsCompanion(
                trackId: trackId,
                name: name,
                nameKey: nameKey,
                role: role,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int trackId,
                required String name,
                required String nameKey,
                required String role,
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => TrackCreditsCompanion.insert(
                trackId: trackId,
                name: name,
                nameKey: nameKey,
                role: role,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackCreditsTable, TrackCreditRow>(table),
                  $$TrackCreditsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$TrackCreditsTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackCreditsTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackCreditsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackCreditsTable,
      TrackCreditRow,
      $$TrackCreditsTableFilterComposer,
      $$TrackCreditsTableOrderingComposer,
      $$TrackCreditsTableAnnotationComposer,
      $$TrackCreditsTableCreateCompanionBuilder,
      $$TrackCreditsTableUpdateCompanionBuilder,
      (TrackCreditRow, $$TrackCreditsTableReferences),
      TrackCreditRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$TrackEnrichTableCreateCompanionBuilder =
    TrackEnrichCompanion Function({
      Value<int> trackId,
      Value<String?> details,
      Value<int?> deezerId,
      Value<String?> mbid,
      Value<int?> metaNoneAt,
      Value<int?> lyricsNoneAt,
      Value<int?> syncedNoneAt,
      Value<int?> curioNoneAt,
      Value<int?> creditsNoneAt,
      Value<bool> lyricsByUser,
    });
typedef $$TrackEnrichTableUpdateCompanionBuilder =
    TrackEnrichCompanion Function({
      Value<int> trackId,
      Value<String?> details,
      Value<int?> deezerId,
      Value<String?> mbid,
      Value<int?> metaNoneAt,
      Value<int?> lyricsNoneAt,
      Value<int?> syncedNoneAt,
      Value<int?> curioNoneAt,
      Value<int?> creditsNoneAt,
      Value<bool> lyricsByUser,
    });

final class $$TrackEnrichTableReferences
    extends BaseReferences<_$AppDatabase, $TrackEnrichTable, TrackEnrichData> {
  $$TrackEnrichTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('track_enrich__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackEnrichTableFilterComposer
    extends Composer<_$AppDatabase, $TrackEnrichTable> {
  $$TrackEnrichTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deezerId => $composableBuilder(
    column: $table.deezerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mbid => $composableBuilder(
    column: $table.mbid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get metaNoneAt => $composableBuilder(
    column: $table.metaNoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lyricsNoneAt => $composableBuilder(
    column: $table.lyricsNoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get syncedNoneAt => $composableBuilder(
    column: $table.syncedNoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get curioNoneAt => $composableBuilder(
    column: $table.curioNoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditsNoneAt => $composableBuilder(
    column: $table.creditsNoneAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lyricsByUser => $composableBuilder(
    column: $table.lyricsByUser,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackEnrichTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackEnrichTable> {
  $$TrackEnrichTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deezerId => $composableBuilder(
    column: $table.deezerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mbid => $composableBuilder(
    column: $table.mbid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get metaNoneAt => $composableBuilder(
    column: $table.metaNoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lyricsNoneAt => $composableBuilder(
    column: $table.lyricsNoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get syncedNoneAt => $composableBuilder(
    column: $table.syncedNoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get curioNoneAt => $composableBuilder(
    column: $table.curioNoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditsNoneAt => $composableBuilder(
    column: $table.creditsNoneAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lyricsByUser => $composableBuilder(
    column: $table.lyricsByUser,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackEnrichTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackEnrichTable> {
  $$TrackEnrichTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<int> get deezerId =>
      $composableBuilder(column: $table.deezerId, builder: (column) => column);

  GeneratedColumn<String> get mbid =>
      $composableBuilder(column: $table.mbid, builder: (column) => column);

  GeneratedColumn<int> get metaNoneAt => $composableBuilder(
    column: $table.metaNoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lyricsNoneAt => $composableBuilder(
    column: $table.lyricsNoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get syncedNoneAt => $composableBuilder(
    column: $table.syncedNoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get curioNoneAt => $composableBuilder(
    column: $table.curioNoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditsNoneAt => $composableBuilder(
    column: $table.creditsNoneAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get lyricsByUser => $composableBuilder(
    column: $table.lyricsByUser,
    builder: (column) => column,
  );

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackEnrichTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackEnrichTable,
          TrackEnrichData,
          $$TrackEnrichTableFilterComposer,
          $$TrackEnrichTableOrderingComposer,
          $$TrackEnrichTableAnnotationComposer,
          $$TrackEnrichTableCreateCompanionBuilder,
          $$TrackEnrichTableUpdateCompanionBuilder,
          (TrackEnrichData, $$TrackEnrichTableReferences),
          TrackEnrichData,
          PrefetchHooks Function({bool trackId})
        > {
  $$TrackEnrichTableTableManager(_$AppDatabase db, $TrackEnrichTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackEnrichTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackEnrichTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackEnrichTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<int?> deezerId = const Value.absent(),
                Value<String?> mbid = const Value.absent(),
                Value<int?> metaNoneAt = const Value.absent(),
                Value<int?> lyricsNoneAt = const Value.absent(),
                Value<int?> syncedNoneAt = const Value.absent(),
                Value<int?> curioNoneAt = const Value.absent(),
                Value<int?> creditsNoneAt = const Value.absent(),
                Value<bool> lyricsByUser = const Value.absent(),
              }) => TrackEnrichCompanion(
                trackId: trackId,
                details: details,
                deezerId: deezerId,
                mbid: mbid,
                metaNoneAt: metaNoneAt,
                lyricsNoneAt: lyricsNoneAt,
                syncedNoneAt: syncedNoneAt,
                curioNoneAt: curioNoneAt,
                creditsNoneAt: creditsNoneAt,
                lyricsByUser: lyricsByUser,
              ),
          createCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<int?> deezerId = const Value.absent(),
                Value<String?> mbid = const Value.absent(),
                Value<int?> metaNoneAt = const Value.absent(),
                Value<int?> lyricsNoneAt = const Value.absent(),
                Value<int?> syncedNoneAt = const Value.absent(),
                Value<int?> curioNoneAt = const Value.absent(),
                Value<int?> creditsNoneAt = const Value.absent(),
                Value<bool> lyricsByUser = const Value.absent(),
              }) => TrackEnrichCompanion.insert(
                trackId: trackId,
                details: details,
                deezerId: deezerId,
                mbid: mbid,
                metaNoneAt: metaNoneAt,
                lyricsNoneAt: lyricsNoneAt,
                syncedNoneAt: syncedNoneAt,
                curioNoneAt: curioNoneAt,
                creditsNoneAt: creditsNoneAt,
                lyricsByUser: lyricsByUser,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackEnrichTable, TrackEnrichData>(table),
                  $$TrackEnrichTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$TrackEnrichTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackEnrichTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackEnrichTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackEnrichTable,
      TrackEnrichData,
      $$TrackEnrichTableFilterComposer,
      $$TrackEnrichTableOrderingComposer,
      $$TrackEnrichTableAnnotationComposer,
      $$TrackEnrichTableCreateCompanionBuilder,
      $$TrackEnrichTableUpdateCompanionBuilder,
      (TrackEnrichData, $$TrackEnrichTableReferences),
      TrackEnrichData,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ActivityLogRowsTableCreateCompanionBuilder =
    ActivityLogRowsCompanion Function({
      Value<int> id,
      required int at,
      required String kind,
      required String name,
      Value<int> done,
      Value<int> total,
      Value<int> failed,
      Value<String?> detail,
    });
typedef $$ActivityLogRowsTableUpdateCompanionBuilder =
    ActivityLogRowsCompanion Function({
      Value<int> id,
      Value<int> at,
      Value<String> kind,
      Value<String> name,
      Value<int> done,
      Value<int> total,
      Value<int> failed,
      Value<String?> detail,
    });

class $$ActivityLogRowsTableFilterComposer
    extends Composer<_$AppDatabase, $ActivityLogRowsTable> {
  $$ActivityLogRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ActivityLogRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $ActivityLogRowsTable> {
  $$ActivityLogRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get done => $composableBuilder(
    column: $table.done,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failed => $composableBuilder(
    column: $table.failed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detail => $composableBuilder(
    column: $table.detail,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ActivityLogRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ActivityLogRowsTable> {
  $$ActivityLogRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get done =>
      $composableBuilder(column: $table.done, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<int> get failed =>
      $composableBuilder(column: $table.failed, builder: (column) => column);

  GeneratedColumn<String> get detail =>
      $composableBuilder(column: $table.detail, builder: (column) => column);
}

class $$ActivityLogRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ActivityLogRowsTable,
          ActivityLogRow,
          $$ActivityLogRowsTableFilterComposer,
          $$ActivityLogRowsTableOrderingComposer,
          $$ActivityLogRowsTableAnnotationComposer,
          $$ActivityLogRowsTableCreateCompanionBuilder,
          $$ActivityLogRowsTableUpdateCompanionBuilder,
          (
            ActivityLogRow,
            BaseReferences<
              _$AppDatabase,
              $ActivityLogRowsTable,
              ActivityLogRow
            >,
          ),
          ActivityLogRow,
          PrefetchHooks Function()
        > {
  $$ActivityLogRowsTableTableManager(
    _$AppDatabase db,
    $ActivityLogRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ActivityLogRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ActivityLogRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ActivityLogRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> at = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> done = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> failed = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => ActivityLogRowsCompanion(
                id: id,
                at: at,
                kind: kind,
                name: name,
                done: done,
                total: total,
                failed: failed,
                detail: detail,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int at,
                required String kind,
                required String name,
                Value<int> done = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> failed = const Value.absent(),
                Value<String?> detail = const Value.absent(),
              }) => ActivityLogRowsCompanion.insert(
                id: id,
                at: at,
                kind: kind,
                name: name,
                done: done,
                total: total,
                failed: failed,
                detail: detail,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ActivityLogRowsTable, ActivityLogRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ActivityLogRowsTable,
                    ActivityLogRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ActivityLogRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ActivityLogRowsTable,
      ActivityLogRow,
      $$ActivityLogRowsTableFilterComposer,
      $$ActivityLogRowsTableOrderingComposer,
      $$ActivityLogRowsTableAnnotationComposer,
      $$ActivityLogRowsTableCreateCompanionBuilder,
      $$ActivityLogRowsTableUpdateCompanionBuilder,
      (
        ActivityLogRow,
        BaseReferences<_$AppDatabase, $ActivityLogRowsTable, ActivityLogRow>,
      ),
      ActivityLogRow,
      PrefetchHooks Function()
    >;
typedef $$TrackGenresTableCreateCompanionBuilder =
    TrackGenresCompanion Function({
      required int trackId,
      required String genre,
      required int position,
      Value<int> rowid,
    });
typedef $$TrackGenresTableUpdateCompanionBuilder =
    TrackGenresCompanion Function({
      Value<int> trackId,
      Value<String> genre,
      Value<int> position,
      Value<int> rowid,
    });

final class $$TrackGenresTableReferences
    extends BaseReferences<_$AppDatabase, $TrackGenresTable, TrackGenreRow> {
  $$TrackGenresTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TracksTable _trackIdTable(_$AppDatabase db) =>
      db.tracks.createAlias('track_genres__track_id__tracks__id');

  $$TracksTableProcessedTableManager get trackId {
    final $_column = $_itemColumn<int>('track_id')!;

    final manager = $$TracksTableTableManager(
      $_db,
      $_db.tracks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_trackIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TrackGenresTableFilterComposer
    extends Composer<_$AppDatabase, $TrackGenresTable> {
  $$TrackGenresTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  $$TracksTableFilterComposer get trackId {
    final $$TracksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableFilterComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackGenresTableOrderingComposer
    extends Composer<_$AppDatabase, $TrackGenresTable> {
  $$TrackGenresTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get genre => $composableBuilder(
    column: $table.genre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  $$TracksTableOrderingComposer get trackId {
    final $$TracksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableOrderingComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackGenresTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrackGenresTable> {
  $$TrackGenresTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$TracksTableAnnotationComposer get trackId {
    final $$TracksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.trackId,
      referencedTable: $db.tracks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TracksTableAnnotationComposer(
            $db: $db,
            $table: $db.tracks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TrackGenresTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TrackGenresTable,
          TrackGenreRow,
          $$TrackGenresTableFilterComposer,
          $$TrackGenresTableOrderingComposer,
          $$TrackGenresTableAnnotationComposer,
          $$TrackGenresTableCreateCompanionBuilder,
          $$TrackGenresTableUpdateCompanionBuilder,
          (TrackGenreRow, $$TrackGenresTableReferences),
          TrackGenreRow,
          PrefetchHooks Function({bool trackId})
        > {
  $$TrackGenresTableTableManager(_$AppDatabase db, $TrackGenresTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackGenresTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackGenresTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackGenresTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> trackId = const Value.absent(),
                Value<String> genre = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrackGenresCompanion(
                trackId: trackId,
                genre: genre,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int trackId,
                required String genre,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => TrackGenresCompanion.insert(
                trackId: trackId,
                genre: genre,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrackGenresTable, TrackGenreRow>(table),
                  $$TrackGenresTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({trackId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (trackId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.trackId,
                        referencedTable: $$TrackGenresTableReferences
                            ._trackIdTable(db),
                        referencedColumn: $$TrackGenresTableReferences
                            ._trackIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TrackGenresTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TrackGenresTable,
      TrackGenreRow,
      $$TrackGenresTableFilterComposer,
      $$TrackGenresTableOrderingComposer,
      $$TrackGenresTableAnnotationComposer,
      $$TrackGenresTableCreateCompanionBuilder,
      $$TrackGenresTableUpdateCompanionBuilder,
      (TrackGenreRow, $$TrackGenresTableReferences),
      TrackGenreRow,
      PrefetchHooks Function({bool trackId})
    >;
typedef $$ArtistCountriesTableCreateCompanionBuilder =
    ArtistCountriesCompanion Function({
      required String artistKey,
      Value<String?> country,
      Value<String?> source,
      required int checkedAt,
      Value<int> rowid,
    });
typedef $$ArtistCountriesTableUpdateCompanionBuilder =
    ArtistCountriesCompanion Function({
      Value<String> artistKey,
      Value<String?> country,
      Value<String?> source,
      Value<int> checkedAt,
      Value<int> rowid,
    });

class $$ArtistCountriesTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistCountriesTable> {
  $$ArtistCountriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtistCountriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistCountriesTable> {
  $$ArtistCountriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get artistKey => $composableBuilder(
    column: $table.artistKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get country => $composableBuilder(
    column: $table.country,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistCountriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistCountriesTable> {
  $$ArtistCountriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get artistKey =>
      $composableBuilder(column: $table.artistKey, builder: (column) => column);

  GeneratedColumn<String> get country =>
      $composableBuilder(column: $table.country, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$ArtistCountriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistCountriesTable,
          ArtistCountry,
          $$ArtistCountriesTableFilterComposer,
          $$ArtistCountriesTableOrderingComposer,
          $$ArtistCountriesTableAnnotationComposer,
          $$ArtistCountriesTableCreateCompanionBuilder,
          $$ArtistCountriesTableUpdateCompanionBuilder,
          (
            ArtistCountry,
            BaseReferences<_$AppDatabase, $ArtistCountriesTable, ArtistCountry>,
          ),
          ArtistCountry,
          PrefetchHooks Function()
        > {
  $$ArtistCountriesTableTableManager(
    _$AppDatabase db,
    $ArtistCountriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistCountriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistCountriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistCountriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> artistKey = const Value.absent(),
                Value<String?> country = const Value.absent(),
                Value<String?> source = const Value.absent(),
                Value<int> checkedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistCountriesCompanion(
                artistKey: artistKey,
                country: country,
                source: source,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String artistKey,
                Value<String?> country = const Value.absent(),
                Value<String?> source = const Value.absent(),
                required int checkedAt,
                Value<int> rowid = const Value.absent(),
              }) => ArtistCountriesCompanion.insert(
                artistKey: artistKey,
                country: country,
                source: source,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistCountriesTable, ArtistCountry>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ArtistCountriesTable,
                    ArtistCountry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtistCountriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistCountriesTable,
      ArtistCountry,
      $$ArtistCountriesTableFilterComposer,
      $$ArtistCountriesTableOrderingComposer,
      $$ArtistCountriesTableAnnotationComposer,
      $$ArtistCountriesTableCreateCompanionBuilder,
      $$ArtistCountriesTableUpdateCompanionBuilder,
      (
        ArtistCountry,
        BaseReferences<_$AppDatabase, $ArtistCountriesTable, ArtistCountry>,
      ),
      ArtistCountry,
      PrefetchHooks Function()
    >;
typedef $$ArtistAliasesTableCreateCompanionBuilder =
    ArtistAliasesCompanion Function({
      required String aliasId,
      required String mainId,
      Value<int> createdAt,
      Value<int> rowid,
    });
typedef $$ArtistAliasesTableUpdateCompanionBuilder =
    ArtistAliasesCompanion Function({
      Value<String> aliasId,
      Value<String> mainId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$ArtistAliasesTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistAliasesTable> {
  $$ArtistAliasesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get aliasId => $composableBuilder(
    column: $table.aliasId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mainId => $composableBuilder(
    column: $table.mainId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtistAliasesTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistAliasesTable> {
  $$ArtistAliasesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get aliasId => $composableBuilder(
    column: $table.aliasId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mainId => $composableBuilder(
    column: $table.mainId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistAliasesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistAliasesTable> {
  $$ArtistAliasesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get aliasId =>
      $composableBuilder(column: $table.aliasId, builder: (column) => column);

  GeneratedColumn<String> get mainId =>
      $composableBuilder(column: $table.mainId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ArtistAliasesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistAliasesTable,
          ArtistAliase,
          $$ArtistAliasesTableFilterComposer,
          $$ArtistAliasesTableOrderingComposer,
          $$ArtistAliasesTableAnnotationComposer,
          $$ArtistAliasesTableCreateCompanionBuilder,
          $$ArtistAliasesTableUpdateCompanionBuilder,
          (
            ArtistAliase,
            BaseReferences<_$AppDatabase, $ArtistAliasesTable, ArtistAliase>,
          ),
          ArtistAliase,
          PrefetchHooks Function()
        > {
  $$ArtistAliasesTableTableManager(_$AppDatabase db, $ArtistAliasesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistAliasesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistAliasesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistAliasesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> aliasId = const Value.absent(),
                Value<String> mainId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistAliasesCompanion(
                aliasId: aliasId,
                mainId: mainId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String aliasId,
                required String mainId,
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistAliasesCompanion.insert(
                aliasId: aliasId,
                mainId: mainId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistAliasesTable, ArtistAliase>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ArtistAliasesTable,
                    ArtistAliase
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtistAliasesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistAliasesTable,
      ArtistAliase,
      $$ArtistAliasesTableFilterComposer,
      $$ArtistAliasesTableOrderingComposer,
      $$ArtistAliasesTableAnnotationComposer,
      $$ArtistAliasesTableCreateCompanionBuilder,
      $$ArtistAliasesTableUpdateCompanionBuilder,
      (
        ArtistAliase,
        BaseReferences<_$AppDatabase, $ArtistAliasesTable, ArtistAliase>,
      ),
      ArtistAliase,
      PrefetchHooks Function()
    >;
typedef $$ArtistNotSameTableCreateCompanionBuilder =
    ArtistNotSameCompanion Function({
      required String a,
      required String b,
      Value<int> createdAt,
      Value<int> rowid,
    });
typedef $$ArtistNotSameTableUpdateCompanionBuilder =
    ArtistNotSameCompanion Function({
      Value<String> a,
      Value<String> b,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$ArtistNotSameTableFilterComposer
    extends Composer<_$AppDatabase, $ArtistNotSameTable> {
  $$ArtistNotSameTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get a => $composableBuilder(
    column: $table.a,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get b => $composableBuilder(
    column: $table.b,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtistNotSameTableOrderingComposer
    extends Composer<_$AppDatabase, $ArtistNotSameTable> {
  $$ArtistNotSameTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get a => $composableBuilder(
    column: $table.a,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get b => $composableBuilder(
    column: $table.b,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtistNotSameTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArtistNotSameTable> {
  $$ArtistNotSameTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get a =>
      $composableBuilder(column: $table.a, builder: (column) => column);

  GeneratedColumn<String> get b =>
      $composableBuilder(column: $table.b, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ArtistNotSameTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArtistNotSameTable,
          ArtistNotSameData,
          $$ArtistNotSameTableFilterComposer,
          $$ArtistNotSameTableOrderingComposer,
          $$ArtistNotSameTableAnnotationComposer,
          $$ArtistNotSameTableCreateCompanionBuilder,
          $$ArtistNotSameTableUpdateCompanionBuilder,
          (
            ArtistNotSameData,
            BaseReferences<
              _$AppDatabase,
              $ArtistNotSameTable,
              ArtistNotSameData
            >,
          ),
          ArtistNotSameData,
          PrefetchHooks Function()
        > {
  $$ArtistNotSameTableTableManager(_$AppDatabase db, $ArtistNotSameTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtistNotSameTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtistNotSameTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtistNotSameTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> a = const Value.absent(),
                Value<String> b = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistNotSameCompanion(
                a: a,
                b: b,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String a,
                required String b,
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtistNotSameCompanion.insert(
                a: a,
                b: b,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArtistNotSameTable, ArtistNotSameData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ArtistNotSameTable,
                    ArtistNotSameData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtistNotSameTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArtistNotSameTable,
      ArtistNotSameData,
      $$ArtistNotSameTableFilterComposer,
      $$ArtistNotSameTableOrderingComposer,
      $$ArtistNotSameTableAnnotationComposer,
      $$ArtistNotSameTableCreateCompanionBuilder,
      $$ArtistNotSameTableUpdateCompanionBuilder,
      (
        ArtistNotSameData,
        BaseReferences<_$AppDatabase, $ArtistNotSameTable, ArtistNotSameData>,
      ),
      ArtistNotSameData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TracksTableTableManager get tracks =>
      $$TracksTableTableManager(_db, _db.tracks);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$PlaylistsTableTableManager get playlists =>
      $$PlaylistsTableTableManager(_db, _db.playlists);
  $$PlaylistTracksTableTableManager get playlistTracks =>
      $$PlaylistTracksTableTableManager(_db, _db.playlistTracks);
  $$PlaylistImportsTableTableManager get playlistImports =>
      $$PlaylistImportsTableTableManager(_db, _db.playlistImports);
  $$PlaylistImportItemsTableTableManager get playlistImportItems =>
      $$PlaylistImportItemsTableTableManager(_db, _db.playlistImportItems);
  $$PlaysTableTableManager get plays =>
      $$PlaysTableTableManager(_db, _db.plays);
  $$SmartPlaylistsTableTableManager get smartPlaylists =>
      $$SmartPlaylistsTableTableManager(_db, _db.smartPlaylists);
  $$UserTagsTableTableManager get userTags =>
      $$UserTagsTableTableManager(_db, _db.userTags);
  $$TrackTagsTableTableManager get trackTags =>
      $$TrackTagsTableTableManager(_db, _db.trackTags);
  $$PodcastsTableTableManager get podcasts =>
      $$PodcastsTableTableManager(_db, _db.podcasts);
  $$PodcastEpisodesTableTableManager get podcastEpisodes =>
      $$PodcastEpisodesTableTableManager(_db, _db.podcastEpisodes);
  $$ArtistInfosTableTableManager get artistInfos =>
      $$ArtistInfosTableTableManager(_db, _db.artistInfos);
  $$RadioStationsTableTableManager get radioStations =>
      $$RadioStationsTableTableManager(_db, _db.radioStations);
  $$FollowedArtistsTableTableManager get followedArtists =>
      $$FollowedArtistsTableTableManager(_db, _db.followedArtists);
  $$ArtistReleasesTableTableManager get artistReleases =>
      $$ArtistReleasesTableTableManager(_db, _db.artistReleases);
  $$ArtistLookupsTableTableManager get artistLookups =>
      $$ArtistLookupsTableTableManager(_db, _db.artistLookups);
  $$TrackCreditsTableTableManager get trackCredits =>
      $$TrackCreditsTableTableManager(_db, _db.trackCredits);
  $$TrackEnrichTableTableManager get trackEnrich =>
      $$TrackEnrichTableTableManager(_db, _db.trackEnrich);
  $$ActivityLogRowsTableTableManager get activityLogRows =>
      $$ActivityLogRowsTableTableManager(_db, _db.activityLogRows);
  $$TrackGenresTableTableManager get trackGenres =>
      $$TrackGenresTableTableManager(_db, _db.trackGenres);
  $$ArtistCountriesTableTableManager get artistCountries =>
      $$ArtistCountriesTableTableManager(_db, _db.artistCountries);
  $$ArtistAliasesTableTableManager get artistAliases =>
      $$ArtistAliasesTableTableManager(_db, _db.artistAliases);
  $$ArtistNotSameTableTableManager get artistNotSame =>
      $$ArtistNotSameTableTableManager(_db, _db.artistNotSame);
}

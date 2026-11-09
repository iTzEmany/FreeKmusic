import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../core/uuid.dart';

@TableIndex(name: 'tracks_album_key', columns: {#albumKey})
@TableIndex(name: 'tracks_artist', columns: {#artist})
@TableIndex(name: 'tracks_favorite', columns: {#isFavorite})
@TableIndex(name: 'tracks_isrc', columns: {#isrc})
@TableIndex(name: 'tracks_kind', columns: {#kind})
@TableIndex(name: 'tracks_missing', columns: {#missing})
@TableIndex(name: 'tracks_title', columns: {#title})
class Tracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  IntColumn get folderId => integer().nullable()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get albumArtist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumKey => text()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  TextColumn get format => text()();
  IntColumn get sampleRateHz => integer().nullable()();
  IntColumn get bitDepth => integer().nullable()();
  IntColumn get bitrateKbps => integer().nullable()();
  IntColumn get channels => integer().nullable()();
  IntColumn get sizeBytes => integer()();
  IntColumn get mtimeMs => integer()();
  BoolColumn get hasCover => boolean().withDefault(const Constant(false))();
  TextColumn get coverKey => text().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get lyricsPlain => text().nullable()();
  TextColumn get lyricsSynced => text().nullable()();
  TextColumn get curiosities => text().nullable()();
  IntColumn get enrichStatus => integer().withDefault(const Constant(0))();
  BoolColumn get userEdited => boolean().withDefault(const Constant(false))();
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  /// Hidden by the user (a duplicate that was merged away). Unlike `missing`
  /// the scanner never clears it; «Brani nascosti» does.
  BoolColumn get ignored => boolean().withDefault(const Constant(false))();

  /// 0 music · 1 a downloaded podcast episode. Every music view filters
  /// `kind = 0`: episodes never show up in the library.
  IntColumn get kind => integer().withDefault(const Constant(0))();
  TextColumn get sha256 => text().nullable()();
  IntColumn get addedAt => integer()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  RealColumn get replayGainDb => real().nullable()();

  /// «Riprendi da qui»: where a long track (≥ 20 min) was left; null = none.
  IntColumn get resumePositionMs => integer().nullable()();
  IntColumn get lastPlayedAt => integer().nullable()();

  /// International Standard Recording Code; never overwritten once set.
  TextColumn get isrc => text().nullable()();

  /// 0 automatic · 1 chosen by hand for the album · 2 chosen by hand for the track.
  IntColumn get coverSource => integer().withDefault(const Constant(0))();
}

class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get path => text().unique()();
  IntColumn get addedAt => integer()();
  TextColumn get label => text().nullable()();
}

@TableIndex(name: 'playlists_uuid', columns: {#uuid}, unique: true)
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get createdAt => integer()();

  /// Identity of the playlist across devices (schema v10): the same on every
  /// device it is synced to. Nullable only because the migration adds the
  /// column before filling it; every new row gets one.
  TextColumn get uuid => text().nullable().clientDefault(newUuid)();

  /// Epoch ms of the last change to its name, cover, tracks or order: «last
  /// change wins» when playlists are synced.
  IntColumn get updatedAt =>
      integer().withDefault(const Constant(0)).clientDefault(nowMs)();

  /// File name inside the covers folder; null = use the first track's cover.
  TextColumn get coverKey => text().nullable()();
}

@TableIndex(name: 'playlist_tracks_track', columns: {#trackId})
class PlaylistTracks extends Table {
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {playlistId, trackId};
}

/// One CSV import (Exportify) into a playlist. See `docs/fase-12-import-csv.md`.
class PlaylistImports extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  TextColumn get sourceName => text()();
  IntColumn get createdAt => integer()();

  /// 0 running · 1 paused · 2 finished · 3 cancelled.
  IntColumn get status => integer().withDefault(const Constant(0))();

  /// Where the rows came from: `exportify` · `tunemymusic` · `soundiiz` ·
  /// `lastfm` · `csv` · `m3u` · `xspf`.
  TextColumn get sourceKind =>
      text().withDefault(const Constant('exportify'))();

  /// Sub-folder of the download folder for this import (null = none).
  TextColumn get folderPath => text().nullable()();

  /// Prefix downloaded files with their position (`007 - Artist - Title`).
  BoolColumn get numberFiles => boolean().withDefault(const Constant(false))();

  /// Link what the library has and download nothing.
  BoolColumn get linkOnly => boolean().withDefault(const Constant(false))();

  /// Search everything first and wait for the user before downloading.
  BoolColumn get planFirst => boolean().withDefault(const Constant(false))();

  /// Look the album cover up after each download.
  BoolColumn get fetchCovers => boolean().withDefault(const Constant(false))();
}

/// One row of the CSV, in playlist order.
class PlaylistImportItems extends Table {
  IntColumn get importId =>
      integer().references(PlaylistImports, #id, onDelete: KeyAction.cascade)();
  IntColumn get rowIndex => integer()();
  TextColumn get title => text()();

  /// Artists joined with `;` (the CSV separator, so never inside a name).
  TextColumn get artists => text()();
  TextColumn get album => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get isrc => text().nullable()();
  IntColumn get year => integer().nullable()();

  /// 0 to search · 1 queued · 2 downloaded · 3 linked (already in library)
  /// · 4 to review · 5 not found · 6 failed · 7 skipped by the user
  /// · 8 planned (chosen, waiting for «Download») · 9 removed from the source.
  IntColumn get status => integer().withDefault(const Constant(0))();
  TextColumn get videoId => text().nullable()();

  /// JSON list of the best candidates, kept while status is 4 (to review).
  TextColumn get candidates => text().nullable()();
  IntColumn get trackId => integer().nullable().references(
    Tracks,
    #id,
    onDelete: KeyAction.setNull,
  )();
  RealColumn get score => real().nullable()();

  /// Why a row is «not found» or «to review» (shown and exported).
  TextColumn get note => text().nullable()();

  /// Path or URL of a local M3U/XSPF entry.
  TextColumn get location => text().nullable()();

  @override
  Set<Column> get primaryKey => {importId, rowIndex};
}

/// One listen: a track that played past the «counts as played» threshold.
/// The history starts empty (nothing is invented from `play_count`).
// Covering: a recap can group a year of listens by track from the index alone.
@TableIndex(name: 'plays_track', columns: {#trackId, #playedAt, #msPlayed})
@TableIndex(name: 'plays_at', columns: {#playedAt})
class Plays extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();

  /// Epoch ms of the moment it counted as played.
  IntColumn get playedAt => integer()();

  /// Time really spent playing it (seeks do not count); grows until the
  /// track changes.
  IntColumn get msPlayed => integer().withDefault(const Constant(0))();

  /// `PlayContextKind.index` of where it was started from, if known.
  IntColumn get context => integer().nullable()();
  TextColumn get contextName => text().nullable()();
}

/// A playlist defined by rules (text in the rule language), computed live.
class SmartPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get rules => text()();

  /// `SortOption` name, or `random`; null = the default order.
  TextColumn get sort => text().nullable()();
  IntColumn get limitCount => integer().nullable()();
  IntColumn get createdAt => integer()();
}

/// The user's own labels for tracks (distinct from the file tags).
class UserTags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name =>
      text().customConstraint('NOT NULL UNIQUE COLLATE NOCASE')();

  /// Index of one of the eight accent tokens; null = none.
  IntColumn get color => integer().nullable()();
}

class TrackTags extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(UserTags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {trackId, tagId};
}

/// A podcast the user subscribed to by its RSS address.
class Podcasts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get feedUrl => text().unique()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();

  /// Where the cover comes from (the feed's image).
  TextColumn get imageUrl => text().nullable()();

  /// File name inside the covers folder, once downloaded.
  TextColumn get coverKey => text().nullable()();
  TextColumn get language => text().nullable()();

  /// Epoch ms of the last successful refresh; null = never.
  IntColumn get lastCheckedAt => integer().nullable()();

  /// Delete played episodes after this many days; null = never.
  IntColumn get autoDeleteDays => integer().nullable()();
  IntColumn get addedAt => integer()();

  /// Where the episodes come from: 0 = RSS feed, 1 = YouTube Music show (D-404).
  IntColumn get source => integer().withDefault(const Constant(0))();

  /// The show's own id on its source (`MPSPP…` for YouTube Music); null for RSS.
  TextColumn get sourceId => text().nullable()();

  /// false = only listened to (not in the list, no refresh); true = subscribed (D-435).
  BoolColumn get followed => boolean().withDefault(const Constant(true))();
}

/// One episode of a feed. Downloaded ones also have a `tracks` row (kind 1),
/// linked by [trackId]; the others are only listed.
@TableIndex(
  name: 'podcast_episodes_podcast',
  columns: {#podcastId, #publishedAt},
)
class PodcastEpisodes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get podcastId =>
      integer().references(Podcasts, #id, onDelete: KeyAction.cascade)();
  TextColumn get guid => text()();
  TextColumn get title => text()();
  IntColumn get publishedAt => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get audioUrl => text()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get trackId => integer().nullable().references(
    Tracks,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get played => boolean().withDefault(const Constant(false))();
  IntColumn get playedAt => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {podcastId, guid},
  ];
}

/// What Wikipedia says about an artist, kept once per artist (not per track)
/// so every track of theirs shows it without asking again.
class ArtistInfos extends Table {
  /// `matchKey` of the main artist's name.
  TextColumn get artistKey => text()();
  TextColumn get body => text()();
  TextColumn get sourceUrl => text()();
  TextColumn get lang => text()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {artistKey};
}

/// «Le mie radio»: the stations the user saved, with the address they had when
/// saved, so they play even when Radio Browser is down. [stationId] is the
/// `stationuuid`, or `manual:<uuid>` for an address typed in by hand.
@DataClassName('SavedRadio')
class RadioStations extends Table {
  TextColumn get stationId => text()();
  TextColumn get name => text()();
  TextColumn get streamUrl => text()();
  TextColumn get homepage => text().withDefault(const Constant(''))();
  TextColumn get faviconUrl => text().withDefault(const Constant(''))();
  TextColumn get countryCode => text().withDefault(const Constant(''))();
  TextColumn get state => text().withDefault(const Constant(''))();

  /// Comma-separated.
  TextColumn get tags => text().withDefault(const Constant(''))();
  TextColumn get codec => text().withDefault(const Constant(''))();
  IntColumn get bitrate => integer().withDefault(const Constant(0))();
  BoolColumn get hls => boolean().withDefault(const Constant(false))();

  /// The order the user chose (0 = first).
  IntColumn get position => integer()();
  IntColumn get addedAt => integer().clientDefault(nowMs)();
  IntColumn get lastPlayedAt => integer().nullable()();

  /// The last refresh that found the station working.
  IntColumn get lastOkAt => integer().nullable()();

  /// The last refresh did not find the station, or found it broken. Shown as
  /// «non risponde»; the row is never deleted for it.
  BoolColumn get unreachable => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {stationId};
}

/// Artists whose new releases are checked (phase 34). [origin] 0 = followed by
/// hand, 1 = followed automatically (most listened).
@DataClassName('FollowedArtist')
class FollowedArtists extends Table {
  /// `UC…` channel id of the YouTube Music artist page.
  TextColumn get ytmId => text()();
  TextColumn get name => text()();
  TextColumn get thumbUrl => text().nullable()();
  IntColumn get origin => integer().withDefault(const Constant(0))();

  /// An automatic artist the user stopped following: never added again.
  BoolColumn get excluded => boolean().withDefault(const Constant(false))();

  /// No notification for this artist; the release still shows in Home.
  BoolColumn get muted => boolean().withDefault(const Constant(false))();
  IntColumn get followedAt => integer().clientDefault(nowMs)();

  /// Null until the first check (which marks everything as seen).
  IntColumn get lastCheckedAt => integer().nullable()();
  TextColumn get lastError => text().nullable()();

  /// Checks in a row that did not find the artist page.
  IntColumn get checksFailed => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {ytmId};
}

/// Albums, singles and EPs seen on a followed artist's page. A row is shown in
/// «Nuove uscite» when it was flagged new ([isNew], or [openedAt] once
/// opened); the others are the past, stored only to tell new ones apart.
@DataClassName('ArtistRelease')
class ArtistReleases extends Table {
  /// `MPREb_…`.
  TextColumn get browseId => text()();
  TextColumn get artistId =>
      text().references(FollowedArtists, #ytmId, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();

  /// `ReleaseKind.index`: 0 album, 1 single or EP.
  IntColumn get kind => integer()();
  IntColumn get year => integer().nullable()();
  TextColumn get thumbUrl => text().nullable()();
  IntColumn get firstSeenAt => integer()();
  BoolColumn get isNew => boolean().withDefault(const Constant(false))();
  IntColumn get openedAt => integer().nullable()();

  /// Same for the variants and reissues of one title (`releaseGroupKey`).
  TextColumn get groupKey => text()();

  @override
  Set<Column> get primaryKey => {browseId};
}

/// What «most listened» artist names were found to be on YouTube Music, kept
/// 30 days (also «nobody» and «several»), so the search is not repeated.
@DataClassName('ArtistLookup')
class ArtistLookups extends Table {
  /// `matchKey` of the main artist's name.
  TextColumn get artistKey => text()();
  TextColumn get name => text()();

  /// 0 = one exact artist ([ytmId]), 1 = nobody, 2 = several (to confirm).
  IntColumn get status => integer()();
  TextColumn get ytmId => text().nullable()();
  TextColumn get ytmName => text().nullable()();
  TextColumn get thumbUrl => text().nullable()();
  IntColumn get checkedAt => integer()();

  @override
  Set<Column> get primaryKey => {artistKey};
}

/// A credit (writer, producer, ...) of a track, from an online source.
@TableIndex(name: 'track_credits_name_key', columns: {#nameKey})
@DataClassName('TrackCreditRow')
class TrackCredits extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get nameKey => text()();
  TextColumn get role => text()();
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {trackId, nameKey, role};
}

/// Every genre of a track (D-390), in tag order; `tracks.genre` stays the first.
@TableIndex(name: 'track_genres_genre', columns: {#genre})
@DataClassName('TrackGenreRow')
class TrackGenres extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();

  /// Trimmed, as in the tag; compared ignoring case (the index too).
  TextColumn get genre => text().customConstraint('NOT NULL COLLATE NOCASE')();
  IntColumn get position => integer()();

  @override
  Set<Column> get primaryKey => {trackId, position};
}

/// Where an artist comes from (D-390): `matchKey` of the main artist's name.
/// A null [country] with a [checkedAt] is "not found", not asked again for 30 days.
class ArtistCountries extends Table {
  TextColumn get artistKey => text()();

  /// ISO 3166-1 alpha-2.
  TextColumn get country => text().nullable()();

  /// `musicbrainz` / `wikidata`; null when nothing answered.
  TextColumn get source => text().nullable()();
  IntColumn get checkedAt => integer()();

  @override
  Set<Column> get primaryKey => {artistKey};
}

/// A second YouTube Music profile of the same artist (D-402): [aliasId] shows
/// the page of [mainId]. Never a chain: [mainId] is never itself an alias.
class ArtistAliases extends Table {
  TextColumn get aliasId => text()();
  TextColumn get mainId => text()();
  IntColumn get createdAt => integer().clientDefault(nowMs)();

  @override
  Set<Column> get primaryKey => {aliasId};
}

/// Two profiles the user said are different artists (D-414), never proposed
/// to merge again. [a] < [b] (string order), so a pair has one row.
class ArtistNotSame extends Table {
  TextColumn get a => text()();
  TextColumn get b => text()();
  IntColumn get createdAt => integer().clientDefault(nowMs)();

  @override
  Set<Column> get primaryKey => {a, b};

  @override
  List<String> get customConstraints => ['CHECK (a < b)'];
}

/// Enrichment state of a track; the *_none_at columns hold when a part was
/// searched and not found (retried after 30 days).
class TrackEnrich extends Table {
  IntColumn get trackId =>
      integer().references(Tracks, #id, onDelete: KeyAction.cascade)();
  TextColumn get details => text().nullable()();
  IntColumn get deezerId => integer().nullable()();
  TextColumn get mbid => text().nullable()();
  IntColumn get metaNoneAt => integer().nullable()();
  IntColumn get lyricsNoneAt => integer().nullable()();
  IntColumn get syncedNoneAt => integer().nullable()();
  IntColumn get curioNoneAt => integer().nullable()();
  IntColumn get creditsNoneAt => integer().nullable()();
  BoolColumn get lyricsByUser => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {trackId};
}

/// Log of background jobs (the «Registro»).
@TableIndex(name: 'activity_log_at', columns: {#at})
@DataClassName('ActivityLogRow')
class ActivityLogRows extends Table {
  @override
  String get tableName => 'activity_log';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get at => integer()();
  TextColumn get kind => text()();
  TextColumn get name => text()();
  IntColumn get done => integer().withDefault(const Constant(0))();
  IntColumn get total => integer().withDefault(const Constant(0))();
  IntColumn get failed => integer().withDefault(const Constant(0))();
  TextColumn get detail => text().nullable()();
}

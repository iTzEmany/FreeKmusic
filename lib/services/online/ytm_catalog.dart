import 'package:dio/dio.dart' show CancelToken;

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import 'catalog_cache.dart';
import 'innertube_client.dart';
import 'search_cache.dart' show ytResultFromJson, ytResultToJson;
import 'ytm_album_parser.dart';
import 'ytm_album_search.dart';
import 'ytm_artist.dart';
import 'ytm_artist_parser.dart';
import 'youtube_service.dart';

/// Field masks of the YouTube Music pages (Google's `X-Goog-FieldMask`): only
/// what the parsers read, a page shrinks from ~600 KB to ~15 KB.
const _search = 'contents.tabbedSearchResultsRenderer.tabs.tabRenderer.content'
    '.sectionListRenderer.contents';
const _singleColumn = 'contents.singleColumnBrowseResultsRenderer.tabs.tabRenderer'
    '.content.sectionListRenderer.contents';
const topCardMask = '$_search.musicCardShelfRenderer(title,subtitle,thumbnail,onTap)';
const artistsMask = '$_search.musicShelfRenderer.contents.musicResponsiveListItemRenderer'
    '(flexColumns,thumbnail,navigationEndpoint)';
const artistPageMask = 'header.musicImmersiveHeaderRenderer(title,thumbnail,description,'
    'startRadioButton,monthlyListenerCount),$_singleColumn('
    'musicShelfRenderer(title,contents.musicResponsiveListItemRenderer('
    'flexColumns,fixedColumns,playlistItemData,thumbnail),bottomEndpoint),'
    'musicCarouselShelfRenderer(header.musicCarouselShelfBasicHeaderRenderer('
    'title,moreContentButton),contents.musicTwoRowItemRenderer('
    'title,subtitle,navigationEndpoint,thumbnailRenderer)),'
    'musicDescriptionShelfRenderer(header,description))';
/// Only the name and the carousels (with covers): what the new-releases check
/// reads, ~10 KB instead of ~35 KB.
const artistReleasesMask = 'header.musicImmersiveHeaderRenderer(title),$_singleColumn('
    'musicCarouselShelfRenderer(header.musicCarouselShelfBasicHeaderRenderer('
    'title,moreContentButton),contents.musicTwoRowItemRenderer('
    'title,subtitle,navigationEndpoint,thumbnailRenderer)))';
const albumPageMask = 'contents.twoColumnBrowseResultsRenderer('
    'tabs.tabRenderer.content.sectionListRenderer.contents.musicResponsiveHeaderRenderer('
    'title,subtitle,straplineTextOne,secondSubtitle,thumbnail),'
    'secondaryContents.sectionListRenderer.contents.musicShelfRenderer.contents.'
    'musicResponsiveListItemRenderer(flexColumns,fixedColumns,playlistItemData,index))';
const songListMask = '$_singleColumn.musicPlaylistShelfRenderer.contents.'
    'musicResponsiveListItemRenderer(flexColumns,fixedColumns,playlistItemData,thumbnail)';
const discographyMask = '$_singleColumn.gridRenderer.items.musicTwoRowItemRenderer('
    'title,subtitle,navigationEndpoint,thumbnailRenderer)';

/// YouTube Music search filter: «Artists».
const artistsFilter = 'EgWKAQIgAWoKEAMQBBAJEAoQBQ%3D%3D';

/// YouTube Music search filter: «Albums» (albums, singles and EPs). Built like
/// the two above, filter code 0x18 in place of songs' 0x08 and artists' 0x20;
/// checked against the live search (only `MUSIC_PAGE_TYPE_ALBUM` rows came back).
const albumsFilter = 'EgWKAQIYAWoKEAkQBRAKEAMQBA%3D%3D';

/// Same shelf of list items as the artists filter.
const albumsMask = artistsMask;

const _languages = {'it', 'en', 'de', 'es', 'fr', 'pt'};

/// The `hl` to ask YouTube Music for: the app language when it is one of the
/// supported ones, English otherwise.
String ytmLanguage(String appLanguage) =>
    _languages.contains(appLanguage) ? appLanguage : 'en';

/// A catalog answer with when it was fetched; [stale] when it is an old copy
/// shown because the network (or YouTube) failed.
class CatalogResult<T> {
  const CatalogResult(this.value, this.fetchedAt, {this.stale = false});

  final T value;
  final DateTime fetchedAt;
  final bool stale;
}

/// Artist, album and list pages of YouTube Music: one direct request each,
/// cached on disk. Albums fall back to yt-dlp when the direct page cannot be
/// read; the artist page has no fallback ([InnerTubeChanged] reaches the UI).
class YtmCatalog {
  YtmCatalog(this.client, this.ytDlp, this.cache, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final InnerTubeClient client;
  final YoutubeService ytDlp;
  final CatalogCache cache;
  final DateTime Function() _now;

  /// The top result card of [query] (artist, album, song or video), null when
  /// there is none. Same request as [topArtist]. Not cached.
  Future<TopCard?> topCard(String query, String hl, {CancelToken? cancel}) =>
      client.searchMusic(query, parseTopCard,
          hl: hl, mask: topCardMask, isEmpty: (r) => r == null, cancel: cancel);

  /// The artist behind the top result of [query], null when that result is not
  /// an artist (a song, an album) or there is none. Not cached.
  Future<YtmArtistRef?> topArtist(String query, String hl) => client.searchMusic(
      query, parseTopArtistCard,
      hl: hl, mask: topCardMask, isEmpty: (r) => r == null);

  /// Artists matching [query], best first. Not cached.
  /// When the search cannot reach YouTube (offline), an artist whose page was
  /// opened before is found by name in the cache, so its saved page opens.
  Future<List<YtmArtistRef>> searchArtists(String query, String hl, {CancelToken? cancel}) async {
    try {
      return await client.searchMusic(query, parseArtistSearch,
          params: artistsFilter,
          hl: hl, mask: artistsMask, isEmpty: (r) => r.isEmpty, cancel: cancel);
    } on YtException {
      final saved = await _cachedArtist(query);
      if (saved == null) rethrow;
      AppLog.i('artist lookup offline: "${saved.name}" from the saved pages');
      return [saved];
    }
  }

  /// Albums, singles and EPs matching [query], best first. Not cached.
  Future<List<YtmAlbumHit>> searchAlbums(String query, String hl, {CancelToken? cancel}) =>
      client.searchMusic(query, parseAlbumSearch,
          params: albumsFilter, hl: hl, mask: albumsMask, isEmpty: (r) => r.isEmpty, cancel: cancel);

  Future<YtmArtistRef?> _cachedArtist(String name) async {
    final want = normalize(name);
    if (want.isEmpty) return null;
    for (final json in await cache.allJson(CatalogKind.artist)) {
      final ref = YtmArtistPage.fromJson(json)?.ref;
      if (ref != null && normalize(ref.name) == want) return ref;
    }
    return null;
  }

  /// [refresh] skips a fresh cached copy (pull to refresh).
  Future<CatalogResult<YtmArtistPage>> artist(String id, String hl,
          {bool refresh = false}) =>
      _cached(
        CatalogKind.artist,
        '$id:$hl',
        refresh,
        () => client.browseMusic(id, (d) => parseArtistPage(d, id),
            hl: hl, mask: artistPageMask),
        (v) => v.toJson(),
        YtmArtistPage.fromJson,
      );

  /// The artist page as the new-releases check reads it: the releases
  /// carousels only, always fresh (neither read from nor written to the cache).
  Future<YtmArtistPage> releases(String id, String hl, {CancelToken? cancel}) =>
      client.browseMusic(id, (d) => parseArtistPage(d, id),
          hl: hl, mask: artistReleasesMask, cancel: cancel);

  /// The album page; when it cannot be read, yt-dlp lists the same tracks
  /// (slower, and without track numbers or the artist's page id).
  Future<CatalogResult<YtmAlbum>> album(String browseId, String hl,
          {bool refresh = false}) =>
      _cached(
        CatalogKind.album,
        '$browseId:$hl',
        refresh,
        () async {
          try {
            return await client.browseMusic(
                browseId, (d) => parseAlbumPage(d, browseId),
                hl: hl, mask: albumPageMask);
          } on InnerTubeChanged catch (e) {
            AppLog.w('direct album page unreadable ($e): yt-dlp');
            return _viaYtDlp(browseId);
          }
        },
        (v) => v.toJson(),
        YtmAlbum.fromJson,
      );

  /// The full «Top songs» style list behind [link] (first page, 100 songs).
  Future<CatalogResult<List<YtResult>>> songs(YtmBrowseLink link, String hl,
          {bool refresh = false}) =>
      _cached(
        CatalogKind.songs,
        '${link.browseId}:${link.params}:$hl',
        refresh,
        () => client.browseMusic(link.browseId, parseSongList,
            params: link.params, hl: hl, mask: songListMask, isEmpty: (r) => r.isEmpty),
        (v) => [for (final s in v) ytResultToJson(s)],
        (j) => j is List ? [for (final x in j) ?ytResultFromJson(x)] : null,
      );

  /// Every release behind a carousel's «more» [link].
  Future<CatalogResult<List<YtmRelease>>> discography(YtmBrowseLink link, String hl,
          {bool refresh = false}) =>
      _cached(
        CatalogKind.discography,
        '${link.browseId}:${link.params}:$hl',
        refresh,
        () => client.browseMusic(link.browseId, parseDiscography,
            params: link.params, hl: hl, mask: discographyMask, isEmpty: (r) => r.isEmpty),
        (v) => [for (final r in v) r.toJson()],
        (j) => j is List ? [for (final x in j) ?YtmRelease.fromJson(x)] : null,
      );

  Future<YtmAlbum> _viaYtDlp(String browseId) async {
    final tracks = await ytDlp.albumTracks('https://music.youtube.com/browse/$browseId');
    if (tracks.isEmpty) throw const InnerTubeChanged('album without tracks');
    final first = tracks.first;
    return YtmAlbum(
      browseId: browseId,
      title: first.album ?? '',
      artist: first.artists.isEmpty
          ? null
          : YtmArtistRef(id: first.artistIdAt(0), name: first.artists.first),
      tracks: [for (final t in tracks) YtmAlbumTrack(null, t)],
    );
  }

  /// A fresh copy, else the network; when that fails, any copy (marked
  /// [CatalogResult.stale]) or the error. «Not found» is final: it is neither
  /// answered from nor kept in the cache.
  Future<CatalogResult<T>> _cached<T>(
    CatalogKind kind,
    String key,
    bool refresh,
    Future<T> Function() fetch,
    Object? Function(T value) encode,
    T? Function(Object? json) decode,
  ) async {
    final copy = await cache.get(kind, key);
    final old = copy == null ? null : decode(copy.json);
    if (old != null && !copy!.expired && !refresh) {
      return CatalogResult(old, copy.storedAt);
    }
    try {
      final value = await fetch();
      await cache.put(kind, key, encode(value));
      return CatalogResult(value, _now());
    } on ArtistNotFound {
      rethrow;
    } on Object catch (e) {
      if (old == null || e is! YtException && e is! InnerTubeChanged) rethrow;
      AppLog.w('catalog page not fetched ($e): showing the saved copy');
      return CatalogResult(old, copy!.storedAt, stale: true);
    }
  }
}

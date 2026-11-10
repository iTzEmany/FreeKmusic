import 'package:audio_service/audio_service.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/library_queries.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/radio_repository.dart';
import '../../data/repositories/track_kinds.dart';
import '../../data/repositories/track_repository.dart';
import '../radio/radio_station.dart';

/// Android Auto (and any other media browser) asks for lists of this many
/// entries at most.
const kBrowseLimit = 200;

/// Texts of the folders a browser shows. No `BuildContext` here: the player
/// can run without any UI.
class BrowseLabels {
  const BrowseLabels({
    this.favorites = 'Preferiti',
    this.playlists = 'Playlist',
    this.albums = 'Album',
    this.top = 'Più ascoltati',
    this.recent = 'Ultimi aggiunti',
    this.radio = 'Radio',
  });

  final String favorites, playlists, albums, top, recent, radio;

  static BrowseLabels forLanguage(String code) => switch (code) {
        'en' => const BrowseLabels(
            favorites: 'Favourites', playlists: 'Playlists', albums: 'Albums',
            top: 'Most played', recent: 'Recently added'),
        'de' => const BrowseLabels(
            favorites: 'Favoriten', playlists: 'Playlists', albums: 'Alben',
            top: 'Am häufigsten gespielt', recent: 'Zuletzt hinzugefügt'),
        'es' => const BrowseLabels(
            favorites: 'Favoritos', playlists: 'Listas', albums: 'Álbumes',
            top: 'Más escuchados', recent: 'Añadidos recientemente'),
        'fr' => const BrowseLabels(
            favorites: 'Favoris', playlists: 'Playlists', albums: 'Albums',
            top: 'Les plus écoutés', recent: 'Ajoutés récemment'),
        'pt' => const BrowseLabels(
            favorites: 'Favoritos', playlists: 'Playlists', albums: 'Álbuns',
            top: 'Mais ouvidas', recent: 'Adicionadas recentemente', radio: 'Rádio'),
        _ => const BrowseLabels(),
      };
}

/// What the tree reads, as plain futures (the repositories give streams).
abstract class BrowseSource {
  Future<List<Track>> favorites();
  Future<List<PlaylistSummary>> playlists();
  Future<List<Track>> playlistTracks(int id);
  Future<List<AlbumSummary>> albums();
  Future<List<Track>> albumTracks(String albumKey);
  Future<List<Track>> top();
  Future<List<Track>> recent();
  Future<List<Track>> search(String query);

  /// «Le mie radio», in the user's order.
  Future<List<RadioStation>> radios();
}

class DbBrowseSource implements BrowseSource {
  DbBrowseSource(this._tracks, this._queries, this._playlists, [this._radios]);

  final TrackRepository _tracks;
  final LibraryQueries _queries;
  final PlaylistRepository _playlists;
  final RadioRepository? _radios;

  @override
  Future<List<RadioStation>> radios() async =>
      [for (final r in await _radios?.getAll() ?? const <SavedRadio>[]) r.toStation()];

  @override
  Future<List<Track>> favorites() => _tracks
      .watchTracks(favoritesOnly: true, sort: SortOption.title)
      .first
      .then((l) => l.take(kBrowseLimit).toList());

  @override
  Future<List<PlaylistSummary>> playlists() => _playlists.watchAll().first;

  @override
  Future<List<Track>> playlistTracks(int id) => _playlists.watchTracks(id).first;

  @override
  Future<List<AlbumSummary>> albums() => _queries.watchAlbums().first;

  @override
  Future<List<Track>> albumTracks(String albumKey) => _queries.watchAlbumTracks(albumKey).first;

  @override
  Future<List<Track>> top() => _queries.watchTopTracks(limit: kBrowseLimit).first;

  @override
  Future<List<Track>> recent() => _tracks
      .watchTracks(sort: SortOption.addedAt)
      .first
      .then((l) => l.take(kBrowseLimit).toList());

  @override
  Future<List<Track>> search(String query) => _tracks
      .watchTracks(query: query, sort: SortOption.title)
      .first
      .then((l) => l.take(50).toList());
}

/// The library as folders and tracks for a media browser. Ids are stable
/// strings: `root`, `fav`, `playlists`, `playlist:<id>`, `albums`,
/// `album:<albumKey>`, `top`, `recent`, and for a track
/// `track:<id>@<id of the folder it was listed in>`: the folder is the queue
/// that plays when the track is chosen. `radio` (only with saved stations)
/// lists `radio:<station id>` items.
class MediaBrowseTree {
  MediaBrowseTree(
    this._src, {
    this.labels = const BrowseLabels(),
    this.coverUri,
  });

  final BrowseSource _src;
  final BrowseLabels labels;

  /// Where the cover file of a cover key is (null = none).
  final Uri? Function(String coverKey)? coverUri;

  static const root = 'root';

  /// The folder of the saved radios; a station is `radio:<station id>`.
  static const radioFolder = 'radio';
  static const _radioPrefix = 'radio:';

  Future<List<RadioStation>> _stations() async {
    final all = await _src.radios();
    return all.length > kBrowseLimit ? all.sublist(0, kBrowseLimit) : all;
  }

  MediaItem _station(RadioStation s) {
    final art = Uri.tryParse(s.faviconUrl);
    return MediaItem(
      id: '$_radioPrefix${s.id}',
      title: s.name,
      artist: s.tags.isEmpty ? null : s.tags.first,
      artUri: art != null && art.hasScheme && art.host.isNotEmpty ? art : null,
    );
  }

  MediaItem _folder(String id, String title, {String? subtitle, Uri? art}) =>
      MediaItem(id: id, title: title, artist: subtitle, artUri: art, playable: false);

  MediaItem _track(Track t, String context) => MediaItem(
        id: 'track:${t.id}@$context',
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.durationMs > 0 ? Duration(milliseconds: t.durationMs) : null,
        artUri: t.coverKey == null ? null : coverUri?.call(t.coverKey!),
      );

  Future<List<MediaItem>> children(String parentId) async {
    switch (parentId) {
      case root:
        return [
          _folder('fav', labels.favorites),
          _folder('playlists', labels.playlists),
          _folder('albums', labels.albums),
          _folder('top', labels.top),
          _folder('recent', labels.recent),
          if ((await _src.radios()).isNotEmpty) _folder(radioFolder, labels.radio),
        ];
      case radioFolder:
        return [for (final s in (await _stations())) _station(s)];
      case 'playlists':
        return [
          for (final p in (await _src.playlists()).take(kBrowseLimit))
            _folder('playlist:${p.playlist.id}', p.playlist.name,
                subtitle: '${p.trackCount}',
                art: p.coverKey == null ? null : coverUri?.call(p.coverKey!)),
        ];
      case 'albums':
        return [
          for (final a in (await _src.albums()).take(kBrowseLimit))
            _folder('album:${a.albumKey}', a.title ?? '?',
                subtitle: a.artist,
                art: a.coverKey == null ? null : coverUri?.call(a.coverKey!)),
        ];
    }
    final tracks = await _tracksOf(parentId);
    if (tracks == null) return const [];
    return [for (final t in tracks) _track(t, parentId)];
  }

  /// The tracks of a folder, at most [kBrowseLimit]; null for an id that is
  /// not a folder of tracks.
  Future<List<Track>?> _tracksOf(String folderId) async {
    final List<Track> all;
    if (folderId == 'fav') {
      all = await _src.favorites();
    } else if (folderId == 'top') {
      all = await _src.top();
    } else if (folderId == 'recent') {
      all = await _src.recent();
    } else if (folderId.startsWith('playlist:')) {
      final id = int.tryParse(folderId.substring(9));
      if (id == null) return null;
      // A streamed track kept in a playlist (D-524) has no file the car can play.
      final inList = await _src.playlistTracks(id);
      all = [for (final t in inList) if (t.kind != kStreamKind) t];
      if (all.length != inList.length) {
        AppLog.i('browse: ${inList.length - all.length} streamed tracks of playlist $id not listed');
      }
    } else if (folderId.startsWith('album:')) {
      all = await _src.albumTracks(folderId.substring(6));
    } else if (folderId.startsWith('search:')) {
      all = await _src.search(folderId.substring(7));
    } else {
      return null;
    }
    return all.length > kBrowseLimit ? all.sublist(0, kBrowseLimit) : all;
  }

  Future<List<MediaItem>> search(String query) =>
      query.trim().isEmpty ? Future.value(const []) : children('search:${query.trim()}');

  /// The item of [mediaId] (a folder or a track), or null.
  Future<MediaItem?> item(String mediaId) async {
    final ref = parseTrackId(mediaId);
    if (ref == null) {
      return switch (mediaId) {
        root => _folder(root, 'Codecore'),
        'fav' => _folder('fav', labels.favorites),
        'playlists' => _folder('playlists', labels.playlists),
        'albums' => _folder('albums', labels.albums),
        'top' => _folder('top', labels.top),
        'recent' => _folder('recent', labels.recent),
        radioFolder => _folder(radioFolder, labels.radio),
        final id when id.startsWith(_radioPrefix) => (await _stations())
            .where((s) => '$_radioPrefix${s.id}' == id)
            .map(_station)
            .firstOrNull,
        _ => null,
      };
    }
    final list = await _tracksOf(ref.context);
    final t = list?.where((t) => t.id == ref.id).firstOrNull;
    return t == null ? null : _track(t, ref.context);
  }

  /// The queue to play when [mediaId] (a `track:` id) is chosen: what the
  /// folder showed, starting at that track. Null if it is not a track id;
  /// a track no longer in its folder plays alone.
  Future<({List<int> ids, int index})?> resolve(String mediaId) async {
    final ref = parseTrackId(mediaId);
    if (ref == null) return null;
    final list = await _tracksOf(ref.context);
    final ids = [for (final t in list ?? const <Track>[]) t.id];
    final at = ids.indexOf(ref.id);
    return at < 0 ? (ids: [ref.id], index: 0) : (ids: ids, index: at);
  }

  /// The stations to play when [mediaId] (a `radio:<id>` item) is chosen: the
  /// saved list, starting at that station. Null if it is not a radio id; a
  /// station no longer saved is not played at all (null).
  Future<({List<RadioStation> stations, int index})?> resolveRadio(String mediaId) async {
    if (!mediaId.startsWith(_radioPrefix)) return null;
    final id = mediaId.substring(_radioPrefix.length);
    final list = await _stations();
    final at = list.indexWhere((s) => s.id == id);
    return at < 0 ? null : (stations: list, index: at);
  }

  /// `track:12@album:Key` → (12, `album:Key`).
  static ({int id, String context})? parseTrackId(String mediaId) {
    if (!mediaId.startsWith('track:')) return null;
    final at = mediaId.indexOf('@');
    if (at < 0) return null;
    final id = int.tryParse(mediaId.substring(6, at));
    if (id == null) return null;
    return (id: id, context: mediaId.substring(at + 1));
  }
}

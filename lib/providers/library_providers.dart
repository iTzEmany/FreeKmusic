import 'dart:io';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../data/db/app_database.dart';
import '../data/repositories/home_sections.dart';
import '../data/repositories/library_entries.dart';
import '../data/repositories/library_queries.dart';
import '../data/repositories/library_search.dart';
import '../data/repositories/smart_search.dart';
import '../data/repositories/track_repository.dart';
import '../services/covers/cover_store.dart';
import '../services/covers/cover_thumbnails.dart';
import '../services/scanner/library_scanner.dart';
import '../services/tags/audio_metadata_tag_reader.dart';
import '../services/tags/metadata_god_tag_writer.dart';
import '../services/tags/safe_tag_writer.dart';
import '../services/tags/tag_backups.dart';
import '../services/tags/tag_reader.dart';
import '../services/tags/tag_writer.dart';
import '../services/library/rules/rule_parser.dart';
import '../services/library/track_editor.dart';
import '../services/library/track_file_sync.dart';
import '../core/paths.dart';
import 'credits_providers.dart' show searchCreditedProvider;
import 'database_providers.dart';
import 'smart_playlist_providers.dart';
import 'settings_providers.dart';

final tagReaderProvider = Provider<TagReader>(
  (ref) => const AudioMetadataTagReader(),
);

/// Resolved once in `main` (and overridden in tests): synchronous everywhere.
final coversDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('coversDirProvider not overridden'),
);

final coverStoreProvider = Provider<CoverStore>((ref) {
  final dir = ref.watch(coversDirProvider);
  return CoverStore(dir, thumbnails: encodeCoverThumbnail);
});

final libraryScannerProvider = Provider<LibraryScanner>(
  (ref) => LibraryScanner(
    ref.watch(tagReaderProvider),
    ref.watch(trackRepositoryProvider),
    ref.watch(coverStoreProvider),
  ),
);

class TrackQuery {
  const TrackQuery({
    this.text = '',
    this.sort = SortOption.defaultOrder,
    this.favoritesOnly = false,
  });

  final String text;
  final SortOption sort;
  final bool favoritesOnly;

  TrackQuery copyWith({String? text, SortOption? sort, bool? favoritesOnly}) =>
      TrackQuery(
        text: text ?? this.text,
        sort: sort ?? this.sort,
        favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is TrackQuery &&
      other.text == text &&
      other.sort == sort &&
      other.favoritesOnly == favoritesOnly;

  @override
  int get hashCode => Object.hash(text, sort, favoritesOnly);
}

class TrackQueryNotifier extends Notifier<TrackQuery> {
  TrackQueryNotifier(this.favoritesOnly);

  final bool favoritesOnly;

  @override
  TrackQuery build() => TrackQuery(favoritesOnly: favoritesOnly);

  void update(TrackQuery Function(TrackQuery) change) => state = change(state);
}

/// Argument: favoritesOnly. Each list (all tracks / favourites) keeps its own
/// sort order; the search text lives in the screen that types it.
final trackQueryProvider =
    NotifierProvider.family<TrackQueryNotifier, TrackQuery, bool>(
      TrackQueryNotifier.new,
    );

final tracksProvider = StreamProvider.autoDispose.family<List<Track>, TrackQuery>((ref, q) {
  return ref
      .watch(trackRepositoryProvider)
      .watchTracks(query: q.text, sort: q.sort, favoritesOnly: q.favoritesOnly);
});

/// All music tracks, whatever the Library search says.
final trackCountProvider = StreamProvider<int>(
  (ref) => ref.watch(trackRepositoryProvider).watchCount(),
);

/// Favourites, whatever the Favourites search says.
final favoriteCountProvider = StreamProvider<int>(
  (ref) => ref.watch(trackRepositoryProvider).watchCount(favoritesOnly: true),
);

/// Library rows for a (tab, order): sorted once and kept, so switching tabs
/// back and forth does not sort again.
final libraryEntriesProvider = Provider.family<
  AsyncValue<List<LibraryEntry>>,
  (LibraryKind?, LibrarySort)
>((ref, key) {
  final playlists = ref.watch(playlistsProvider);
  final albums = ref.watch(albumsProvider);
  final artists = ref.watch(artistsProvider);
  final smart = ref.watch(smartPlaylistsProvider).value ?? const [];
  if (!playlists.hasValue || !albums.hasValue || !artists.hasValue) {
    return const AsyncLoading();
  }
  return AsyncData(
    buildLibraryEntries(
      playlists: playlists.value!,
      albums: albums.value!,
      artists: artists.value!,
      smart: smart,
      kind: key.$1,
      sort: key.$2,
    ),
  );
});

/// Home: playlists and albums by last play, for «Riprendi».
final recentEntriesProvider = Provider<List<LibraryEntry>>((ref) {
  return buildLibraryEntries(
    playlists: ref.watch(playlistsProvider).value ?? const [],
    albums: ref.watch(albumsProvider).value ?? const [],
    artists: const [],
    sort: LibrarySort.recent,
  );
});

/// Home: «Riscopri» albums, derived once per change of the albums.
final rediscoverAlbumsProvider = Provider<List<AlbumSummary>>(
  (ref) => rediscoverAlbums(
    ref.watch(albumsProvider).value ?? const [],
    DateTime.now(),
  ).take(3).toList(),
);

/// Home: «Aggiunti da poco» albums, derived once per change of the albums.
final recentlyAddedAlbumsProvider = Provider<List<AlbumSummary>>(
  (ref) => recentlyAddedAlbums(
    ref.watch(albumsProvider).value ?? const [],
    limit: 20,
  ),
);

final foldersProvider = StreamProvider<List<Folder>>(
  (ref) => ref.watch(folderRepositoryProvider).watchAll(),
);

class ScanState {
  const ScanState({this.running = false, this.progress, this.error});

  final bool running;
  final ScanProgress? progress;
  final String? error;
}

class ScanNotifier extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanState();

  Future<void> scanAll() async {
    if (state.running) return;
    state = const ScanState(running: true);
    try {
      final folders = await ref.read(folderRepositoryProvider).getAll();
      final scanner = ref.read(libraryScannerProvider);
      String? error;
      for (final folder in folders) {
        await for (final p in scanner.scan(folder)) {
          if (p.failed) error = p.error;
          state = ScanState(running: true, progress: p, error: error);
        }
      }
      state = ScanState(progress: state.progress, error: error);
    } on Object catch (e, st) {
      AppLog.e('scan failed', e, st);
      state = ScanState(error: '$e');
    }
  }
}

final scanStateProvider = NotifierProvider<ScanNotifier, ScanState>(
  ScanNotifier.new,
);

final libraryQueriesProvider = Provider<LibraryQueries>(
  (ref) => LibraryQueries(ref.watch(databaseProvider)),
);

class AlbumSortNotifier extends Notifier<AlbumSort> {
  @override
  AlbumSort build() => AlbumSort.title;

  void set(AlbumSort s) => state = s;
}

final albumSortProvider = NotifierProvider<AlbumSortNotifier, AlbumSort>(
  AlbumSortNotifier.new,
);

final albumsProvider = StreamProvider<List<AlbumSummary>>(
  (ref) => ref
      .watch(libraryQueriesProvider)
      .watchAlbums(sort: ref.watch(albumSortProvider)),
);

final artistsProvider = StreamProvider<List<ArtistSummary>>(
  (ref) => ref.watch(libraryQueriesProvider).watchArtists(),
);

final albumTracksProvider = StreamProvider.family<List<Track>, String>(
  (ref, albumKey) =>
      ref.watch(libraryQueriesProvider).watchAlbumTracks(albumKey),
);

/// One-shot read (album preview): unlike [albumTracksProvider], no stream
/// stays open afterwards.
final albumTracksOnceProvider = Provider<Future<List<Track>> Function(String)>(
  (ref) =>
      (albumKey) =>
          ref.read(libraryQueriesProvider).watchAlbumTracks(albumKey).first,
);

final genresProvider = StreamProvider<List<GenreSummary>>(
  (ref) => ref.watch(libraryQueriesProvider).watchGenres(),
);

final genreTracksProvider = StreamProvider.family<List<Track>, String>(
  (ref, genre) => ref.watch(libraryQueriesProvider).watchGenreTracks(genre),
);

/// Every visible track with its tags, normalised once per change of the
/// library (not at every key typed).
final _indexTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(trackRepositoryProvider).watchTracks(),
);

final _indexTagsProvider = StreamProvider<Map<int, List<String>>>(
  (ref) => ref.watch(tagRepositoryProvider).watchNamesByTrack(),
);

/// Built on another isolate: normalising the whole library takes tens of ms
/// on a phone. Its own function so the closure sends only these two values.
Future<SearchIndex> _buildIndex(
  List<Track> tracks,
  Map<int, List<String>> tags,
) => Isolate.run(() => SearchIndex(tracks, tags));

// Does not wait for the tags (a late answer builds the index again).
final searchIndexProvider = FutureProvider<SearchIndex>((ref) async {
  // Both watched before the await, so neither stream is dropped meanwhile.
  final tagsAsync = ref.watch(_indexTagsProvider);
  final tracks = await ref.watch(_indexTracksProvider.future);
  return _buildIndex(tracks, tagsAsync.value ?? const {});
});

// autoDispose (here and below): one entry per text typed, and an entry left
// paused would keep its last result, rows of an older read of the library,
// for the whole session.
final _ruleTracksProvider = StreamProvider.autoDispose
    .family<List<Track>, String>(
      (ref, text) => ref
          .watch(trackRepositoryProvider)
          .watchByRules(parseRules(text).expr),
    );

/// Tracks matching a search: free words look in title, artist, album, genre,
/// year and tags together, best match first. Typed operators
/// (`artista:x anno:1990..1999 -live`) still run as rules in SQL, silently.
final searchTracksProvider = Provider.autoDispose
    .family<AsyncValue<List<Track>>, String>((ref, text) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (hasOperators(text)) return ref.watch(_ruleTracksProvider(text));
      // `.value`, not `whenData`: while the index is rebuilt after a change of
      // the library the rows of the old one stay, instead of going empty.
      final index = ref.watch(searchIndexProvider);
      if (index.hasError) {
        AppLog.w('search index failed', index.error, index.stackTrace);
        return AsyncError(index.error!, index.stackTrace!);
      }
      final i = index.value;
      if (i == null) return const AsyncLoading();
      return AsyncData(smartSearch(i, text, nowMs: now));
    });

/// What the Library search shows for [text]: a few tracks and a few of each
/// other kind, computed once per change of the data and not at every build.
final libraryResultsProvider = Provider.autoDispose
    .family<LibrarySearchResults, String>(
      (ref, text) => searchLibrary(
        text: text,
        credited: ref.watch(searchCreditedProvider(text)).value ?? const [],
        tracks: ref.watch(searchTracksProvider(text)).value ?? const [],
        artists: ref.watch(artistsProvider).value ?? const [],
        albums: ref.watch(albumsProvider).value ?? const [],
        playlists: ref.watch(playlistsProvider).value ?? const [],
        trackLimit: 5,
        sectionLimit: 3,
      ),
    );

final topTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(libraryQueriesProvider).watchTopTracks(),
);

/// The music added last, for the empty player (D-379).
final recentlyAddedTracksProvider = StreamProvider.autoDispose<List<Track>>(
  (ref) => ref.watch(trackRepositoryProvider).watchRecentlyAdded(),
);

final resumableTracksProvider = StreamProvider.autoDispose<List<Track>>(
  (ref) => ref.watch(trackRepositoryProvider).watchResumable(),
);

final artistTracksProvider = StreamProvider.family<List<Track>, String>(
  (ref, key) => ref.watch(libraryQueriesProvider).watchArtistTracks(key),
);

final artistAlbumsProvider = StreamProvider.family<List<AlbumSummary>, String>(
  (ref, key) => ref.watch(libraryQueriesProvider).watchArtistAlbums(key),
);

/// The only door to writing tags into files; tests override it.
final tagWriterProvider = Provider<TagWriter>((ref) => MetadataGodTagWriter());

final tagBackupStoreProvider = FutureProvider<TagBackupStore>(
  (ref) async =>
      TagBackupStore(Directory(p.join(await appSupportDir(), 'tag_backups'))),
);

final safeTagWriterProvider = FutureProvider<SafeTagWriter>((ref) async {
  return SafeTagWriter(
    writer: ref.watch(tagWriterProvider),
    reader: ref.watch(tagReaderProvider),
    workDir: Directory(p.join(await appSupportDir(), 'tagwork')),
    backups: await ref.watch(tagBackupStoreProvider.future),
  );
});

final trackEditorProvider = Provider<TrackEditor>((ref) {
  final db = ref.watch(databaseProvider);
  return TrackEditor(
    db,
    ref.watch(tagReaderProvider),
    files: TrackFileSync(db, () => ref.read(safeTagWriterProvider.future)),
    fileWritesEnabled: () {
      final s = ref.read(settingsProvider);
      return s.writeTagsToFiles && s.tagsAlsoInFile;
    },
  );
});

final missingTracksProvider = StreamProvider<List<Track>>(
  (ref) => ref.watch(trackRepositoryProvider).watchMissing(),
);

class PermissionDeniedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final permissionDeniedProvider =
    NotifierProvider<PermissionDeniedNotifier, bool>(
      PermissionDeniedNotifier.new,
    );

/// While a new query loads (and has no value yet) keep showing [prev]; an
/// error or data shows at once.
AsyncValue<T> keepWhileLoading<T>(AsyncValue<T> fresh, AsyncValue<T>? prev) =>
    fresh.isLoading && !fresh.hasValue && prev != null && prev.hasValue ? prev : fresh;

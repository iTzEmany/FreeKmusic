import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart';
import '../data/repositories/artist_alias_repository.dart';
import '../data/repositories/folder_repository.dart';
import '../data/repositories/import_repository.dart';
import '../data/repositories/play_history_repository.dart';
import '../data/repositories/smart_playlist_repository.dart';
import '../data/repositories/artist_info_repository.dart';
import '../data/repositories/tag_repository.dart';
import '../data/repositories/playlist_repository.dart';
import '../data/repositories/track_repository.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.production();
  ref.onDispose(db.close);
  return db;
});

final artistInfoRepositoryProvider = Provider<ArtistInfoRepository>(
  (ref) => ArtistInfoRepository(ref.watch(databaseProvider)),
);

/// What is stored about an artist (by name), or null.
final artistInfoProvider = StreamProvider.autoDispose.family<ArtistInfo?, String>(
  (ref, artist) => ref.watch(artistInfoRepositoryProvider).watch(artist),
);

final artistAliasRepositoryProvider = Provider<ArtistAliasRepository>(
  (ref) => ArtistAliasRepository(ref.watch(databaseProvider)),
);

final tagRepositoryProvider = Provider<TagRepository>(
  (ref) => TagRepository(ref.watch(databaseProvider)),
);

final smartPlaylistRepositoryProvider = Provider<SmartPlaylistRepository>(
  (ref) => SmartPlaylistRepository(
    ref.watch(databaseProvider),
    ref.watch(trackRepositoryProvider),
  ),
);

final playHistoryRepositoryProvider = Provider<PlayHistoryRepository>(
  (ref) => PlayHistoryRepository(ref.watch(databaseProvider)),
);

final trackRepositoryProvider = Provider<TrackRepository>(
  (ref) => TrackRepository(ref.watch(databaseProvider)),
);

final folderRepositoryProvider = Provider<FolderRepository>(
  (ref) => FolderRepository(ref.watch(databaseProvider)),
);

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(ref.watch(databaseProvider)),
);

final importRepositoryProvider = Provider<ImportRepository>(
  (ref) => ImportRepository(ref.watch(databaseProvider)),
);

final playlistsProvider = StreamProvider<List<PlaylistSummary>>(
  (ref) => ref.watch(playlistRepositoryProvider).watchAll(),
);

final playlistTracksProvider = StreamProvider.family<List<Track>, int>(
  (ref, id) => ref.watch(playlistRepositoryProvider).watchTracks(id),
);

/// Schema version of the open database (backups are checked against it).
final schemaVersionProvider = Provider<int>((ref) => ref.watch(databaseProvider).schemaVersion);

import 'package:drift/drift.dart';

import '../db/app_database.dart';

/// `playlist_imports.source_kind` of «Scarica album»: the import needs a
/// playlist, which is kept out of every list the user sees (the album is in
/// the library's Albums). The row stays in the database, so the full database
/// backup keeps it.
const ytmAlbumSourceKind = 'ytm-album';

/// SQL condition true for playlists the user may see; [alias] is the name of
/// the playlists table in the query. The single source of truth for the
/// hiding rule, shared by the raw SQL queries and [AppDatabasePlaylists].
String visiblePlaylistSql(String alias) =>
    'NOT EXISTS (SELECT 1 FROM playlist_imports i '
    "WHERE i.playlist_id = $alias.id AND i.source_kind = '$ytmAlbumSourceKind')";

extension AppDatabasePlaylists on AppDatabase {
  /// Drift filter with [visiblePlaylistSql].
  Expression<bool> isPlaylistVisible($PlaylistsTable table) =>
      CustomExpression<bool>(visiblePlaylistSql(table.aliasedName),
          watchedTables: [playlistImports]);

  /// Every playlist the user can see (not the technical ones).
  Future<List<Playlist>> visiblePlaylists() => (select(playlists)
        ..where((p) => isPlaylistVisible(p)))
      .get();
}

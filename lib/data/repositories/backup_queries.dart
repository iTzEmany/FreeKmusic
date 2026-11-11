import 'package:drift/drift.dart' show BooleanExpressionOperators, OrderingTerm;
import 'package:path/path.dart' as p;

import '../../services/backup/user_data.dart';
import '../../services/stream/stream_key.dart';
import '../db/app_database.dart';
import 'credits_repository.dart';
import 'hidden_playlists.dart';
import 'track_kinds.dart';

/// Reads everything the user created into the portable format, in one
/// read transaction and without a query per row.
Future<UserData> collectUserData(
  AppDatabase db, {
  Map<int, String> romanizations = const {},
  Set<int> handWritten = const {},
}) {
  return db.transaction(() async {
    final folders = {
      for (final f in await db.select(db.folders).get()) f.id: f.path,
    };
    final tracks = await (db.select(
      db.tracks,
    )..where((t) => t.kind.isNotValue(kStreamKind))).get();
    final portable = await CreditsRepository(db)
        .portableOfMany([for (final t in tracks) t.id]);
    final genresOf = <int, List<String>>{};
    for (final g in await (db.select(db.trackGenres)..orderBy([(g) => OrderingTerm.asc(g.position)])).get()) {
      (genresOf[g.trackId] ??= []).add(g.genre);
    }
    final refs = <int, TrackRef>{};
    final userData = <TrackUserData>[];
    for (final t in tracks) {
      final ref = trackRefFor(t, folders);
      refs[t.id] = ref;
      final hasLyrics =
          t.lyricsPlain != null ||
          t.lyricsSynced != null ||
          t.curiosities != null ||
          romanizations.containsKey(t.id);
      if (!(t.isFavorite ||
          t.userEdited ||
          hasLyrics ||
          t.playCount > 0 ||
          portable[t.id]!.credits.isNotEmpty ||
          portable[t.id]!.details != null ||
          (t.coverSource > 0 && t.coverKey != null))) {
        continue;
      }
      userData.add(
        TrackUserData(
          ref: ref,
          favorite: t.isFavorite,
          edit: t.userEdited
              ? TrackEditData(
                  title: t.title,
                  artist: t.artist,
                  album: t.album,
                  albumArtist: t.albumArtist,
                  year: t.year,
                  trackNumber: t.trackNumber,
                  genre: t.genre,
                )
              : null,
          lyricsPlain: t.lyricsPlain,
          lyricsSynced: t.lyricsSynced,
          curiosities: t.curiosities,
          romanization: romanizations[t.id],
          handWritten: handWritten.contains(t.id),
          playCount: t.playCount,
          lastPlayedAt: t.lastPlayedAt,
          credits: portable[t.id]!.credits,
          details: portable[t.id]!.details,
          genres: genresOf[t.id] ?? const [],
          coverSource: t.coverKey == null ? 0 : t.coverSource,
          coverKey: t.coverKey,
        ),
      );
    }

    // Shadow rows are no user data of their own, but a playlist that holds one keeps it (D-524).
    final inPlaylists = await (db.select(db.tracks)..where(
          (t) =>
              t.kind.equals(kStreamKind) &
              t.id.isInQuery(
                db.selectOnly(db.playlistTracks)..addColumns([db.playlistTracks.trackId]),
              ),
        ))
        .get();
    for (final t in inPlaylists) {
      refs[t.id] = trackRefFor(t, folders);
    }

    final playlists = await db.visiblePlaylists();
    final links = await (db.select(
      db.playlistTracks,
    )..orderBy([(l) => OrderingTerm.asc(l.position)])).get();
    final itemsByPlaylist = <int, List<TrackRef>>{};
    for (final l in links) {
      final ref = refs[l.trackId];
      if (ref != null) (itemsByPlaylist[l.playlistId] ??= []).add(ref);
    }
    final playlistData = [
      for (final pl in playlists)
        PlaylistData(
          name: pl.name,
          createdAt: pl.createdAt,
          coverKey: pl.coverKey,
          uuid: pl.uuid,
          items: itemsByPlaylist[pl.id] ?? const [],
        ),
    ];

    final names = {for (final pl in playlists) pl.id: pl.name};
    final importRows = await (db.select(
      db.playlistImportItems,
    )..orderBy([(i) => OrderingTerm.asc(i.rowIndex)])).get();
    final rowsByImport = <int, List<ImportRowData>>{};
    for (final r in importRows) {
      (rowsByImport[r.importId] ??= []).add(
        ImportRowData(
          rowIndex: r.rowIndex,
          title: r.title,
          artists: r.artists,
          status: r.status,
          album: r.album,
          durationMs: r.durationMs,
          isrc: r.isrc,
          videoId: r.videoId,
        ),
      );
    }
    final imports = [
      for (final i in await db.select(db.playlistImports).get())
        if (i.sourceKind != ytmAlbumSourceKind)
          ImportData(
            playlistName: names[i.playlistId] ?? '',
            sourceName: i.sourceName,
            createdAt: i.createdAt,
            status: i.status,
            rows: rowsByImport[i.id] ?? const [],
          ),
    ];

    final radios = [
      for (final r
          in await (db.select(db.radioStations)..orderBy([
                (r) => OrderingTerm.asc(r.position),
                (r) => OrderingTerm.asc(r.addedAt),
              ]))
              .get())
        RadioData(
          stationId: r.stationId,
          name: r.name,
          streamUrl: r.streamUrl,
          homepage: r.homepage,
          faviconUrl: r.faviconUrl,
          countryCode: r.countryCode,
          state: r.state,
          tags: r.tags,
          codec: r.codec,
          bitrate: r.bitrate,
          hls: r.hls,
          addedAt: r.addedAt,
          lastPlayedAt: r.lastPlayedAt,
        ),
    ];

    final followed = [
      for (final a
          in await (db.select(db.followedArtists)..orderBy([
                (a) => OrderingTerm.asc(a.name),
                (a) => OrderingTerm.asc(a.ytmId),
              ]))
              .get())
        FollowedArtistData(
          ytmId: a.ytmId,
          name: a.name,
          thumbUrl: a.thumbUrl,
          origin: a.origin,
          excluded: a.excluded,
          muted: a.muted,
        ),
    ];

    final countries = [
      for (final c in await (db.select(db.artistCountries)..orderBy([(c) => OrderingTerm.asc(c.artistKey)])).get())
        ArtistCountryData(artistKey: c.artistKey, country: c.country, source: c.source, checkedAt: c.checkedAt),
    ];

    return UserData(
      createdAt: DateTime.now().millisecondsSinceEpoch,
      tracks: userData,
      playlists: playlistData,
      imports: imports,
      radios: radios,
      followedArtists: followed,
      artistCountries: countries,
      artistAliases: [
        for (final r in await (db.select(db.artistAliases)..orderBy([(r) => OrderingTerm.asc(r.aliasId)])).get())
          ArtistAliasData(aliasId: r.aliasId, mainId: r.mainId, createdAt: r.createdAt),
      ],
      artistNotSame: [
        for (final r in await (db.select(db.artistNotSame)..orderBy([(r) => OrderingTerm.asc(r.a), (r) => OrderingTerm.asc(r.b)])).get())
          [r.a, r.b],
      ],
    );
  });
}

/// Portable reference to [t]; [folders] maps folder id to root path.
TrackRef trackRefFor(Track t, Map<int, String> folders) => trackRefOf(
  path: t.path,
  kind: t.kind,
  folderRoot: t.folderId == null ? null : folders[t.folderId],
  title: t.title,
  artist: t.artist,
  durationMs: t.durationMs,
  sha256: t.sha256,
);

/// [trackRefFor] from raw fields ([folderRoot]: path of the track's music folder).
TrackRef trackRefOf({
  required String path,
  required int? kind,
  required String? folderRoot,
  required String title,
  required String? artist,
  required int durationMs,
  required String? sha256,
}) {
  final streamKey = kind == kStreamKind ? keyOfStreamPath(path) : null;
  if (streamKey != null) {
    return TrackRef(streamKey: streamKey, title: title, artist: artist, durationMs: durationMs);
  }
  final inside = folderRoot != null && p.isWithin(folderRoot, path);
  return TrackRef(
    folder: inside ? folderRoot : path,
    relPath: inside ? p.relative(path, from: folderRoot).replaceAll(r'\', '/') : null,
    title: title,
    artist: artist,
    durationMs: durationMs,
    sha256: sha256,
  );
}

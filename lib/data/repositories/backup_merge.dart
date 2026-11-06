import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/text_utils.dart';
import '../../services/tags/tag_reader.dart' show splitGenres;
import '../../services/backup/track_resolver.dart';
import '../../services/backup/user_data.dart';
import '../db/app_database.dart';
import 'credits_repository.dart';
import 'track_genre_repository.dart';
import 'track_repository.dart';

class MergeReport {
  MergeReport();

  int recognized = 0;
  int favoritesAdded = 0;
  int playlistsCreated = 0;
  int playlistItemsSkipped = 0;
  int radiosAdded = 0;
  int followedArtistsAdded = 0;

  /// Titles of the tracks the backup mentions that this library does not have.
  final List<String> notFound = [];

  @override
  String toString() => 'MergeReport($recognized recognized, ${notFound.length} not found, '
      '$favoritesAdded favourites, $playlistsCreated playlists)';
}

bool _blank(String? s) => s == null || s.trim().isEmpty;

/// Merges [data] into this library in one transaction and deletes nothing:
/// a favourite is added (never removed), a hand edit applies only to a track
/// the user has not edited here, lyrics fill only empty fields, plays keep the
/// highest count and the latest date. A playlist already here (same uuid, or same
/// name and tracks) gets the missing tracks appended; a saved radio station
/// already here (same id, or for a hand-typed address the same stream URL) is kept
/// as it is, the others are added at the end in the backup's order; another one with a taken
/// name is created as «(ripristinata)». A followed artist is matched by its YouTube Music id: new ones are
/// added (never checked, so the first round stores their releases as seen), the ones here stay as they are, except
/// that an artist followed by hand in the backup becomes followed by hand here too. Imports are not merged (they depend
/// on the other device's downloads).
/// A hand-set cover (`coverSource`/`coverKey`) is taken only if its file is in
/// [coversDir] and the track has no hand-set cover of its own (source 1 or 2).
Future<MergeReport> mergeUserData(AppDatabase db, UserData data, TrackResolver resolver,
    {Directory? coversDir}) {
  final report = MergeReport();
  return db.transaction(() async {
    for (final u in data.tracks) {
      final id = resolver.resolve(u.ref);
      if (id == null) {
        report.notFound.add(u.ref.title);
        continue;
      }
      final t = await (db.select(db.tracks)..where((r) => r.id.equals(id))).getSingleOrNull();
      if (t == null) continue;
      report.recognized++;
      var upd = const TracksCompanion();
      if (u.favorite && !t.isFavorite) {
        upd = upd.copyWith(isFavorite: const Value(true));
        report.favoritesAdded++;
      }
      final e = u.edit;
      if (e != null && !t.userEdited) {
        final artist = _blankToNullTrim(e.artist), album = _blankToNullTrim(e.album);
        final albumArtist = _blankToNullTrim(e.albumArtist);
        final newKey = computeAlbumKey(
            albumArtist: albumArtist, artist: artist, album: album, directory: p.dirname(t.path));
        // A row with an album pick leaves it behind when the edit moves it to another album.
        await TrackRepository(db).settleMovedCover(t, newKey);
        upd = upd.copyWith(
          title: Value(e.title.trim()),
          artist: Value(artist),
          album: Value(album),
          albumArtist: Value(albumArtist),
          year: Value(e.year),
          trackNumber: Value(e.trackNumber),
          genre: Value(_blankToNullTrim(e.genre)),
          albumKey: Value(newKey),
          userEdited: const Value(true),
        );
      }
      if (_blank(t.lyricsPlain) && !_blank(u.lyricsPlain)) upd = upd.copyWith(lyricsPlain: Value(u.lyricsPlain));
      if (_blank(t.lyricsSynced) && !_blank(u.lyricsSynced)) upd = upd.copyWith(lyricsSynced: Value(u.lyricsSynced));
      if (_blank(t.curiosities) && !_blank(u.curiosities)) upd = upd.copyWith(curiosities: Value(u.curiosities));
      if (u.playCount > t.playCount) upd = upd.copyWith(playCount: Value(u.playCount));
      final last = u.lastPlayedAt;
      if (last != null && (t.lastPlayedAt == null || last > t.lastPlayedAt!)) {
        upd = upd.copyWith(lastPlayedAt: Value(last));
      }
      final ck = u.coverKey;
      if (u.coverSource > 0 && ck != null && t.coverSource == 0 && _coverFileExists(coversDir, ck)) {
        upd = upd.copyWith(coverSource: Value(u.coverSource), coverKey: Value(ck), hasCover: const Value(true));
      }
      await (db.update(db.tracks)..where((r) => r.id.equals(id))).write(upd);
      // A hand edit here sets the genres from its text; otherwise the backup's only fill a track that has none.
      final genreRepo = TrackGenreRepository(db);
      if (upd.userEdited.present) {
        await genreRepo.replace(id, splitGenres([e!.genre]));
      } else if (u.genres.isNotEmpty && (await genreRepo.of(id)).isEmpty) {
        await genreRepo.replace(id, u.genres);
      }
      if (u.credits.isNotEmpty || u.details != null) {
        await CreditsRepository(db).saveIfNone(id, u.credits, u.details);
      }
    }

    final local = await db.select(db.playlists).get();
    final names = {for (final p in local) p.name};
    final uuids = {for (final p in local) if (p.uuid != null) p.uuid!};
    final byUuid = {for (final p in local) if (p.uuid != null) p.uuid!: p};
    final links = await db.select(db.playlistTracks).get();
    final tracksOf = <int, List<PlaylistTrack>>{};
    for (final l in links) {
      (tracksOf[l.playlistId] ??= []).add(l);
    }
    for (final pl in data.playlists) {
      final ids = <int>[];
      final seen = <int>{};
      for (final ref in pl.items) {
        final id = resolver.resolve(ref);
        if (id == null) {
          report.playlistItemsSkipped++;
        } else if (seen.add(id)) {
          ids.add(id);
        }
      }

      // Same playlist = same uuid; without a uuid, same name and same tracks.
      Playlist? same = pl.uuid == null ? null : byUuid[pl.uuid];
      if (same == null && pl.uuid == null) {
        for (final c in local) {
          final have = {for (final l in tracksOf[c.id] ?? const <PlaylistTrack>[]) l.trackId};
          if (c.name == pl.name && have.length == seen.length && have.containsAll(seen)) {
            same = c;
            break;
          }
        }
      }
      if (same != null) {
        final existing = tracksOf[same.id] ?? const <PlaylistTrack>[];
        final have = {for (final l in existing) l.trackId};
        var position = existing.fold<int>(-1, (m, l) => l.position > m ? l.position : m) + 1;
        for (final id in ids) {
          if (have.add(id)) {
            await db.into(db.playlistTracks).insert(
                PlaylistTracksCompanion.insert(playlistId: same.id, trackId: id, position: position++));
          }
        }
        continue;
      }

      var name = pl.name;
      var renamed = false;
      if (names.contains(name)) {
        renamed = true;
        name = '${pl.name} (ripristinata)';
        for (var n = 2; names.contains(name); n++) {
          name = '${pl.name} (ripristinata $n)';
        }
      }
      names.add(name);
      // A copy keeps the backup's uuid only when it is free, so the next merge
      // of the same backup recognises it instead of copying again.
      final keepUuid = !renamed && pl.uuid != null && !uuids.contains(pl.uuid);
      final playlistId = await db.into(db.playlists).insert(PlaylistsCompanion.insert(
          name: name,
          createdAt: pl.createdAt,
          coverKey: Value(pl.coverKey),
          uuid: keepUuid ? Value(pl.uuid) : const Value.absent()));
      if (keepUuid) uuids.add(pl.uuid!);
      var position = 0;
      for (final id in ids) {
        await db.into(db.playlistTracks).insert(
            PlaylistTracksCompanion.insert(playlistId: playlistId, trackId: id, position: position++));
      }
      report.playlistsCreated++;
    }
    await _mergeRadios(db, data.radios, report);
    await _mergeFollowedArtists(db, data.followedArtists, report);
    await _mergeArtistCountries(db, data.artistCountries);
    return report;
  });
}

bool _coverFileExists(Directory? dir, String key) =>
    dir != null &&
    key == p.basename(key) &&
    ['jpg', 'png'].any((e) => File(p.join(dir.path, '$key.$e')).existsSync());

String? _blankToNullTrim(String? s) => _blank(s) ? null : s!.trim();

Future<void> _mergeRadios(AppDatabase db, List<RadioData> radios, MergeReport report) async {
  if (radios.isEmpty) return;
  final have = await db.select(db.radioStations).get();
  final ids = {for (final r in have) r.stationId};
  final urls = {for (final r in have) r.streamUrl};
  var position = have.fold<int>(-1, (m, r) => r.position > m ? r.position : m) + 1;
  for (final r in radios) {
    if (r.stationId.isEmpty || r.streamUrl.isEmpty) continue;
    if (ids.contains(r.stationId) || (r.isManual && urls.contains(r.streamUrl))) continue;
    ids.add(r.stationId);
    urls.add(r.streamUrl);
    await db.into(db.radioStations).insert(RadioStationsCompanion.insert(
          stationId: r.stationId,
          name: r.name,
          streamUrl: r.streamUrl,
          homepage: Value(r.homepage),
          faviconUrl: Value(r.faviconUrl),
          countryCode: Value(r.countryCode),
          state: Value(r.state),
          tags: Value(r.tags),
          codec: Value(r.codec),
          bitrate: Value(r.bitrate),
          hls: Value(r.hls),
          position: position++,
          addedAt: r.addedAt == null ? const Value.absent() : Value(r.addedAt!),
          lastPlayedAt: Value(r.lastPlayedAt),
        ));
    report.radiosAdded++;
  }
}

Future<void> _mergeFollowedArtists(
    AppDatabase db, List<FollowedArtistData> artists, MergeReport report) async {
  if (artists.isEmpty) return;
  final have = {for (final a in await db.select(db.followedArtists).get()) a.ytmId: a};
  final added = <String>{};
  for (final a in artists) {
    if (a.ytmId.isEmpty || a.name.isEmpty) continue;
    final local = have[a.ytmId];
    if (local == null) {
      if (added.contains(a.ytmId)) continue;
      await db.into(db.followedArtists).insert(FollowedArtistsCompanion.insert(
            ytmId: a.ytmId,
            name: a.name,
            thumbUrl: Value(a.thumbUrl),
            origin: Value(a.origin),
            excluded: Value(a.excluded),
            muted: Value(a.muted),
          ));
      added.add(a.ytmId);
      report.followedArtistsAdded++;
    } else if (a.origin == 0 && !a.excluded && (local.origin != 0 || local.excluded)) {
      await (db.update(db.followedArtists)..where((r) => r.ytmId.equals(a.ytmId)))
          .write(const FollowedArtistsCompanion(origin: Value(0), excluded: Value(false)));
    }
  }
}

/// New artists are added; for one already here the more recent check wins.
Future<void> _mergeArtistCountries(AppDatabase db, List<ArtistCountryData> items) async {
  if (items.isEmpty) return;
  final have = {for (final c in await db.select(db.artistCountries).get()) c.artistKey: c.checkedAt};
  for (final c in items) {
    if (c.artistKey.isEmpty) continue;
    final local = have[c.artistKey];
    if (local != null && local >= c.checkedAt) continue;
    have[c.artistKey] = c.checkedAt;
    await db.into(db.artistCountries).insertOnConflictUpdate(ArtistCountriesCompanion.insert(
          artistKey: c.artistKey,
          country: Value(c.country?.toUpperCase()),
          source: Value(c.source),
          checkedAt: c.checkedAt,
        ));
  }
}

import '../../data/repositories/track_kinds.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/favorite_collections_repository.dart';
import '../../data/repositories/track_genre_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../tags/tag_reader.dart';
import '../tags/tag_writer.dart';
import 'track_file_sync.dart';

class TrackEdit {
  const TrackEdit({
    required this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.trackNumber,
    this.genre,
    this.isrc,
    this.mbid,
  });

  final String title;
  final String? artist, album, albumArtist, genre;

  /// Written into the file only (the row keeps its own); empty removes the file's.
  final String? isrc, mbid;
  final int? year, trackNumber;

  /// What goes into the file: blank fields are left alone there (the tag
  /// library cannot erase one).
  TagChanges toChanges() => TagChanges(
    title: _blankToNull(title),
    artist: _blankToNull(artist),
    album: _blankToNull(album),
    albumArtist: _blankToNull(albumArtist),
    year: year,
    genre: _blankToNull(genre),
    trackNumber: trackNumber,
    isrc: isrc?.trim(),
    mbid: mbid?.trim(),
  );
}

String? _blankToNull(String? s) {
  final t = s?.trim();
  return (t == null || t.isEmpty) ? null : t;
}

/// Edits live in the DB, which stays the source of truth. The files are
/// rewritten only by [writeToFiles], and only when [fileWritesEnabled] says
/// the user wants it (setting on and «also in the file» ticked).
class TrackEditor {
  TrackEditor(
    this._db,
    this._tags, {
    this.files,
    bool Function()? fileWritesEnabled,
  }) : _enabled = fileWritesEnabled ?? (() => false);

  final AppDatabase _db;
  final TagReader _tags;
  final TrackFileSync? files;
  final bool Function() _enabled;

  /// The album key of [t] after an edit; a saved stream row keeps the `stream|` prefix and
  /// no folder (same format as `TrackRepository.saveStream`), so it never joins a local album.
  static String _albumKeyOf(Track t, {String? albumArtist, String? artist, String? album}) =>
      t.kind == kStreamKind
          ? streamAlbumKey(albumArtist: albumArtist, artist: artist, album: album)
          : computeAlbumKey(albumArtist: albumArtist, artist: artist, album: album, directory: p.dirname(t.path));

  /// Whether [writeToFiles] would write at all.
  bool get writesFiles => files != null && _enabled();

  /// Writes [changes] of each track into its file; never throws, and does
  /// nothing at all (no writer call) when file writes are off.
  Future<TagFileOutcome> writeToFiles(
    List<Track> tracks,
    TagChanges Function(Track) changes, {
    bool backup = true,
  }) async {
    final files = this.files;
    if (files == null || !_enabled() || tracks.isEmpty) {
      return TagFileOutcome.none;
    }
    return files.write(tracks, changes, backup: backup);
  }

  /// The ISRC and MBID the file has now (null: unknown, the file could not be read).
  Future<({String? isrc, String? mbid})?> fileIds(Track t) async {
    try {
      final i = await _tags.read(t.path, withCover: false);
      return (isrc: i.isrc ?? '', mbid: i.mbid ?? '');
    } on Object catch (e, st) {
      AppLog.w('ids of ${t.path} not read', e, st);
      return null;
    }
  }

  Future<bool> _isAlbumPick(String coverKey) async =>
      await (_db.select(_db.tracks)
            ..where((t) => t.coverKey.equals(coverKey) & t.coverSource.equals(1))
            ..limit(1))
          .getSingleOrNull() !=
      null;

  /// [markEdited] false: an automatic correction, the track stays open to others (D-318).
  Future<void> save(Track track, TrackEdit e, {bool markEdited = true}) async {
    final artist = _blankToNull(e.artist);
    final album = _blankToNull(e.album);
    final albumArtist = _blankToNull(e.albumArtist);
    final key = _albumKeyOf(track, albumArtist: albumArtist, artist: artist, album: album);
    final genre = _blankToNull(e.genre);
    await _db.transaction(() async {
      await (_db.update(_db.tracks)..where((t) => t.id.equals(track.id))).write(
        TracksCompanion(
          title: Value(e.title.trim()),
          artist: Value(artist),
          album: Value(album),
          albumArtist: Value(albumArtist),
          year: Value(e.year),
          trackNumber: Value(e.trackNumber),
          genre: Value(genre),
          albumKey: Value(key),
          userEdited: markEdited ? const Value(true) : const Value.absent(),
        ),
      );
      // Untouched genre text keeps the tag's own list (tracks.genre is only its first).
      if (genre != track.genre) {
        await TrackGenreRepository(_db).replace(track.id, splitGenres([genre]));
      }
      await FavoriteCollectionsRepository(_db)
          .followAlbumKey(track.albumKey, key);
    });
    await TrackRepository(_db).settleMovedCover(track, key);
  }

  /// Puts [tracks] in the album [album] by [albumArtist] (merging with it if
  /// it exists, creating it if not) in one transaction. Like [save] it marks
  /// them as edited and never touches a file. With [cover] the tracks take
  /// that cover, so a merged album shows the one of the album chosen as main.
  /// Returns what each track was before, for [restoreMany].
  Future<List<Track>> saveMany(
    List<Track> tracks, {
    required String album,
    required String albumArtist,
    ({bool hasCover, String? coverKey})? cover,
  }) async {
    final al = _blankToNull(album);
    final aa = _blankToNull(albumArtist);
    final repo = TrackRepository(_db);
    await _db.transaction(() async {
      // A hand-picked album cover travels with [cover]; a hand-picked track one never changes.
      final pick = cover?.coverKey;
      final source = pick != null && await _isAlbumPick(pick) ? 1 : 0;
      for (final t in tracks) {
        final key = _albumKeyOf(t, albumArtist: aa, artist: t.artist, album: al);
        final withCover = cover != null && t.coverSource != 2;
        await (_db.update(_db.tracks)..where((r) => r.id.equals(t.id))).write(
          TracksCompanion(
            album: Value(al),
            albumArtist: Value(aa),
            albumKey: Value(key),
            userEdited: const Value(true),
            hasCover: withCover ? Value(cover.hasCover) : const Value.absent(),
            coverKey: withCover ? Value(cover.coverKey) : const Value.absent(),
            coverSource: withCover ? Value(source) : const Value.absent(),
          ),
        );
        await FavoriteCollectionsRepository(_db)
            .followAlbumKey(t.albumKey, key);
        if (cover == null) await repo.settleMovedCover(t, key);
      }
    });
    return tracks;
  }

  /// Undoes [saveMany]: [before] are the tracks as it returned them.
  Future<void> restoreMany(List<Track> before) => _db.transaction(() async {
    final favs = FavoriteCollectionsRepository(_db);
    for (final t in before) {
      final now = await (_db.select(_db.tracks)..where((r) => r.id.equals(t.id))).getSingleOrNull();
      await (_db.update(_db.tracks)..where((r) => r.id.equals(t.id))).write(
        TracksCompanion(
          album: Value(t.album),
          albumArtist: Value(t.albumArtist),
          albumKey: Value(t.albumKey),
          userEdited: Value(t.userEdited),
          hasCover: Value(t.hasCover),
          coverKey: Value(t.coverKey),
          coverSource: Value(t.coverSource),
        ),
      );
      // shortcut: the favourite moves back only once no visible track keeps the merged key (no snapshot of it).
      if (now != null) await favs.followAlbumKey(now.albumKey, t.albumKey);
    }
  });

  Future<void> restoreFromFile(Track track) async {
    if (track.kind == kStreamKind) return; // no file to read
    final t = await _tags.read(track.path, withCover: false);
    final dir = p.dirname(track.path);
    final key = computeAlbumKey(
      albumArtist: t.albumArtist,
      artist: t.artist,
      album: t.album,
      directory: dir,
    );
    await _db.transaction(() async {
      await (_db.update(_db.tracks)..where((r) => r.id.equals(track.id))).write(
        TracksCompanion(
          title: Value(t.title ?? p.basenameWithoutExtension(track.path)),
          artist: Value(t.artist),
          album: Value(t.album),
          albumArtist: Value(t.albumArtist),
          year: Value(t.year),
          trackNumber: Value(t.trackNumber),
          genre: Value(t.genre),
          albumKey: Value(key),
          userEdited: const Value(false),
        ),
      );
      await TrackGenreRepository(_db).replace(track.id, t.genres);
      await FavoriteCollectionsRepository(_db).followAlbumKey(track.albumKey, key);
    });
    await TrackRepository(_db).settleMovedCover(track, key);
  }
}

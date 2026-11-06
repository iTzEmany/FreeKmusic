import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;

import '../../core/text_utils.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/track_genre_repository.dart';
import '../../data/repositories/track_kinds.dart';
import '../../data/repositories/track_repository.dart';
import '../tags/tag_reader.dart' show splitGenres;
import 'enrich_parts.dart';
import 'enrichment_proposal.dart';

/// Writes what the sources found to `tracks`. The only place that writes
/// `tracks.enrich_status`.
class EnrichWriter {
  EnrichWriter(this._db, this._tracks);

  final AppDatabase _db;
  final TrackRepository _tracks;

  Future<void> writeStatus(int trackId, EnrichStatus status) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(
        TracksCompanion(enrichStatus: Value(status.code)),
      );

  /// The `tracks` row of an apply (and of a commit) for [f], without the
  /// cover or the status. `found`: something was proposed; `wrote`: a field
  /// was written. Also the album key.
  Future<({bool found, bool wrote, String key})> writeFields(
      Track t, EnrichmentProposal p, Set<EnrichField> f) async {
    final m = p.meta;
    final title = f.contains(EnrichField.title) ? m?.title : null;
    final artist = f.contains(EnrichField.artist) ? m?.artist : null;
    final album = f.contains(EnrichField.album) ? m?.album : null;
    final key = albumKeyOf(t, artist, album);
    final found = m != null || (p.lyrics != null && !p.lyrics!.isEmpty) ||
        p.curiosity != null;
    final year = f.contains(EnrichField.year) ? m?.year : null;
    final genre = f.contains(EnrichField.genre) ? m?.genre : null;
    final disc = f.contains(EnrichField.trackNumber) && t.discNumber == null
        ? p.disc
        : null;
    final isrc = t.isrc == null ? p.isrc : null;
    final number = f.contains(EnrichField.trackNumber) ? m?.trackNumber : null;
    final plain = f.contains(EnrichField.lyrics) ? p.lyrics?.plain : null;
    final synced = f.contains(EnrichField.lyrics) ? p.lyrics?.synced : null;
    final curiosity = f.contains(EnrichField.curiosity) && p.curiosity != null
        ? '${p.curiosity!.text}\n${p.curiosity!.source}'
        : null;
    Value<T> opt<T>(T? v) => v == null ? const Value.absent() : Value(v);
    await _db.transaction(() async {
      await (_db.update(_db.tracks)..where((r) => r.id.equals(t.id))).write(
        TracksCompanion(
          title: opt(title),
          artist: opt(artist),
          album: opt(album),
          albumKey: Value(key),
          year: opt(year),
          genre: opt(genre),
          discNumber: opt(disc),
          isrc: opt(isrc),
          trackNumber: opt(number),
          lyricsPlain: opt(plain),
          lyricsSynced: opt(synced),
          curiosities: opt(curiosity),
        ),
      );
      if (genre != null) await TrackGenreRepository(_db).write(t.id, splitGenres([genre]));
    });
    await _tracks.settleMovedCover(t, key);
    final wrote = [title, artist, album, year, genre, disc, isrc, number, plain, synced, curiosity]
        .any((v) => v != null);
    return (found: found, wrote: wrote, key: key);
  }

  /// The album key of [t] once [artist] and [album] (when not null) are written.
  String albumKeyOf(Track t, String? artist, String? album) {
    // A streamed shadow row keeps its own `stream|<key>` album key.
    if ((artist == null && album == null) || t.kind == kStreamKind) {
      return t.albumKey;
    }
    return computeAlbumKey(
        albumArtist: t.albumArtist,
        artist: artist ?? t.artist,
        album: album ?? t.album,
        directory: p.dirname(t.path));
  }
}

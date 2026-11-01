import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import 'deezer_client.dart';
import 'deezer_match.dart';
import 'deezer_models.dart';
import 'http_client.dart';
import 'itunes_client.dart';
import 'query_cleaner.dart';

bool _never() => false;

/// [match] holds the merged fields; [disc], [isrc] and [hit] only exist on Deezer.
class ResolvedMeta {
  const ResolvedMeta(this.match, this.source, {this.disc, this.isrc, this.hit});

  final ItunesMatch match;
  final String source;
  final int? disc;
  final String? isrc;
  final DeezerTrack? hit;
}

/// The Deezer / iTunes cascade for the metadata of one track, and the Deezer
/// album cache it shares with the credits part.
class MetadataResolver {
  MetadataResolver({required this.itunes, this.deezer, this.useDeezer = _never});

  final ItunesClient itunes;
  final DeezerClient? deezer;

  /// The user's «Metadata from Deezer» option, read at each lookup.
  final bool Function() useDeezer;

  final _albums = <int, DeezerAlbum>{};

  /// The Deezer album already fetched for [id], if any.
  DeezerAlbum? albumOf(int? id) => _albums[id];

  /// Deezer first (when on); iTunes only if Deezer did not confirm, gave no
  /// cover, or a genre is wanted. Deezer fields win, iTunes fills the gaps
  /// (genre goes the other way: Deezer's is a last resort).
  Future<ResolvedMeta?> resolve(
      Track t, CleanQuery c, CancelToken? cancel, bool needGenre,
      {bool strict = false}) async {
    final dz = useDeezer() && deezer != null ? await _deezerLookup(t, c, cancel, strict: strict) : null;
    final needItunes = dz == null || dz.match.artworkUrl == null || needGenre;
    final ms = t.durationMs > 0 ? t.durationMs : null;
    var it = needItunes
        ? await itunes.search(c.title, c.artist,
            cancel: cancel, strict: strict, durationMs: ms)
        : null;
    final tagged = c.tagged;
    if (it == null && needItunes && tagged != null) {
      it = await itunes.search(tagged.title, tagged.artist,
          cancel: cancel, strict: strict, durationMs: ms);
    }
    if (dz == null && it == null) return null;
    if (dz == null) return ResolvedMeta(it!, 'itunes');
    final d = dz.match;
    final match = ItunesMatch(
      title: d.title,
      artist: d.artist,
      album: d.album ?? it?.album,
      year: d.year ?? it?.year,
      genre: it?.genre ?? d.genre,
      trackNumber: d.trackNumber ?? it?.trackNumber,
      artworkUrl: d.artworkUrl ?? it?.artworkUrl,
    );
    return ResolvedMeta(match, it == null ? 'deezer' : 'deezer+itunes',
        disc: dz.disc, isrc: dz.isrc, hit: dz.hit);
  }

  /// Null when Deezer does not confirm the track (or cannot answer). With
  /// [strict] «cannot answer» (resting, refused, unreachable) throws instead.
  Future<ResolvedMeta?> _deezerLookup(Track t, CleanQuery c, CancelToken? cancel,
      {bool strict = false}) async {
    final dz = deezer!;
    if (dz.isResting) {
      if (strict) throw const WebUnavailableException('deezer');
      return null;
    }
    try {
      final hit = await deezerHit(t, cancel, c);
      if (hit == null) return null;
      final ref = hit.album;
      var album = ref == null ? null : _albums[ref.id];
      if (ref != null && album == null) {
        album = await dz.album(ref.id, cancel: cancel);
        if (album != null) {
          if (_albums.length >= 200) _albums.clear(); // bounded for single lookups
          _albums[ref.id] = album;
        }
      }
      final usable = album != null && checkEdition(t.album, album).albumUsable;
      final year = usable ? int.tryParse((album.releaseDate ?? '').split('-').first) : null;
      return ResolvedMeta(
        ItunesMatch(
          title: hit.title,
          artist: hit.artist,
          album: usable ? album.title : null,
          year: year,
          genre: usable && album.genres.isNotEmpty ? album.genres.first : null,
          trackNumber: usable ? hit.trackPosition : null,
          artworkUrl: usable ? (album.coverXl ?? ref?.coverXl) : null,
        ),
        'deezer',
        disc: usable ? hit.diskNumber : null,
        isrc: hit.isrc,
        hit: hit,
      );
    } on RateLimitedException catch (e) {
      if (strict) rethrow;
      AppLog.w('Deezer resting, using iTunes: $e');
    } on DeezerNetworkException catch (e) {
      if (strict) rethrow;
      AppLog.w('Deezer unreachable, using iTunes: $e');
    }
    return null;
  }

  /// The Deezer track [t] is, by ISRC or else by text; null when Deezer does
  /// not confirm it. Throws what the client throws.
  Future<DeezerTrack?> deezerHit(Track t, CancelToken? cancel, [CleanQuery? clean]) async {
    final dz = deezer!;
    final c = clean ?? cleanSearchQuery(t.title, t.artist ?? '');
    DeezerWant wantOf(CleanQuery q) => DeezerWant(
          title: q.title,
          artist: q.artist,
          album: t.album,
          durationMs: t.durationMs > 0 ? t.durationMs : null,
          isrc: t.isrc,
        );
    final want = wantOf(c);
    if (t.isrc != null) {
      final x = await dz.trackByIsrc(t.isrc!, cancel: cancel);
      return x != null && acceptIsrcHit(want, x) ? x : null;
    }
    // Like iTunes: if the uploader split finds nothing, ask again as tagged.
    for (final q in [c, if (c.tagged != null) c.tagged!]) {
      final w = wantOf(q);
      final hit = pickDeezerTrack(w, await dz.searchTracks(deezerQuery(w), cancel: cancel));
      if (hit != null) return hit;
    }
    return null;
  }
}

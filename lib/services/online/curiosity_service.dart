import 'package:dio/dio.dart' show CancelToken;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import '../../data/repositories/artist_info_repository.dart';
import '../../data/repositories/track_repository.dart';
import 'curiosity_finder.dart';
import 'http_client.dart';
import 'query_cleaner.dart';

/// What the last search could not do, per part: `songLimited` / `artistLimited`
/// = Wikipedia refused (too many requests), so «nothing found» would be a lie.
class CuriosityOutcome {
  const CuriosityOutcome({
    this.songLimited = false,
    this.artistLimited = false,
    this.failed = false,
    this.nothing = false,
  });

  final bool songLimited, artistLimited, failed, nothing;

  bool get limited => songLimited || artistLimited;

  /// Asked and answered with no page at all (not an error, not a refusal):
  /// the only case worth a `curio_none_at` mark.
  bool get foundEmpty => nothing && !failed && !limited;
}

/// What [CuriosityService.find] found, not yet written. [artist] is the
/// cleaned artist name the bio is saved under.
class CuriosityLookup {
  const CuriosityLookup({
    required this.pair,
    required this.artist,
    required this.outcome,
  });

  final CuriosityPair pair;
  final String artist;
  final CuriosityOutcome outcome;
}

/// The curiosity search of one track: finder, then song text on the track and
/// artist bio in `artist_infos`. No Riverpod, so the enrichment chain can use it.
class CuriosityService {
  CuriosityService({
    required this.finder,
    required this.tracks,
    required this.artistInfos,
  });

  final CuriosityFinder finder;
  final TrackRepository tracks;
  final ArtistInfoRepository artistInfos;

  /// Asks the sources and writes nothing: [save] does, so a caller can put
  /// the write in its own transaction.
  Future<CuriosityLookup> find(
    Track t,
    String lang, {
    CancelToken? cancel,
    Map<String, String>? original,
  }) async {
    final c = cleanSearchQuery(t.title, t.artist ?? '');
    var songLimited = false, artistLimited = false, failed = false;

    // Identity first (MusicBrainz → Wikidata → the exact pages), the names
    // after; each part reports on its own, so one failing does not lose the other.
    var found = await finder.find(
      c.title,
      c.artist,
      lang,
      isrc: t.isrc,
      durationMs: t.durationMs,
      cancel: cancel,
    );
    // A cover with no page of its own speaks of the original; the bio stays the cover artist's.
    final o = original?['title'];
    if (o != null && found.song == null && found.songError == null) {
      final orig = await finder.find(o, original?['artist'] ?? '', lang, cancel: cancel);
      found = CuriosityPair(
        song: orig.song,
        artist: found.artist,
        songError: orig.songError,
        artistError: found.artistError,
        recordingId: found.recordingId,
      );
    }
    for (final (err, isSong) in [
      (found.songError, true),
      (found.artistError, false),
    ]) {
      if (err == null) continue;
      if (err is RateLimitedException) {
        AppLog.w('curiosity refused', err);
        isSong ? songLimited = true : artistLimited = true;
      } else {
        AppLog.w('curiosity lookup failed', err);
        failed = true;
      }
    }
    return CuriosityLookup(
      pair: found,
      artist: c.artist,
      outcome: CuriosityOutcome(
        songLimited: songLimited,
        artistLimited: artistLimited,
        failed: failed,
        nothing: found.song == null && found.artist == null,
      ),
    );
  }

  /// Writes what [find] found: the song text on the track, the bio in
  /// `artist_infos`. The returned outcome has `failed` set when the write failed.
  Future<CuriosityOutcome> save(int trackId, CuriosityLookup l) async {
    final song = l.pair.song, artist = l.pair.artist;
    try {
      // A new search replaces what was saved before, also with nothing: an
      // older version could have saved the artist's page as the song's. A part
      // that could not be asked is left as it was.
      if (l.pair.songError == null) {
        await tracks.setCuriosities(
          trackId,
          song == null ? null : '${song.text}\n${song.source}',
        );
      }
      if (artist != null) {
        await artistInfos.save(
          l.artist,
          body: artist.text,
          source: artist.source,
          lang: artist.lang,
        );
      }
    } on Object catch (e, st) {
      AppLog.w('could not save the curiosities', e, st);
      final o = l.outcome;
      return CuriosityOutcome(
        songLimited: o.songLimited,
        artistLimited: o.artistLimited,
        failed: true,
        nothing: o.nothing,
      );
    }
    return l.outcome;
  }

  Future<CuriosityOutcome> fetch(
    Track t,
    String lang, {
    CancelToken? cancel,
  }) async => save(t.id, await find(t, lang, cancel: cancel));
}

import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import 'discogs_client.dart';
import 'http_client.dart';
import 'musicbrainz_client.dart';
import 'query_cleaner.dart';
import 'wikipedia_client.dart';
import '../../core/artist_key.dart';

/// What was found about a song and about its artist. A part that could not be
/// asked says why in [songError] / [artistError] (usually a
/// [RateLimitedException]); a part simply not found has neither.
class CuriosityPair {
  const CuriosityPair({
    this.song,
    this.artist,
    this.songError,
    this.artistError,
    this.recordingId,
  });

  final Curiosity? song, artist;
  final Object? songError, artistError;

  /// MusicBrainz recording the lookup identified, null when none (for the credits).
  final String? recordingId;
}

/// The description of [artist]'s YouTube Music page with the page's address,
/// null when there is none. May throw (e.g. [RateLimitedException]).
typedef YtmArtistDescription =
    Future<({String text, Uri source, String lang})?> Function(
      String artist,
      CancelToken? cancel,
    );

/// Shortest text worth showing as a curiosity.
const _minFallbackText = 80;

/// Finds the Wikipedia pages of a song and of its artist. First by identity:
/// MusicBrainz says which song and artist the title is, Wikidata gives the
/// titles of their pages, and those exact pages are read. When that leads
/// nowhere (service down, song unknown to MusicBrainz, no page linked) it falls
/// back to guessing the page from the names (`WikipediaClient`). Where
/// Wikipedia has nothing, the artist falls back to the description of its
/// YouTube Music page, the song to the notes of its album's Discogs master.
class CuriosityFinder {
  CuriosityFinder({
    required this.wikipedia,
    required this.musicBrainz,
    required this.wikidata,
    this.discogs,
    this.ytmArtist,
  });

  final WikipediaClient wikipedia;
  final MusicBrainzClient musicBrainz;
  final WikidataClient wikidata;
  final DiscogsClient? discogs;
  final YtmArtistDescription? ytmArtist;

  Future<CuriosityPair> find(
    String title,
    String artist,
    String lang, {
    String? isrc,
    int durationMs = 0,
    CancelToken? cancel,
  }) async {
    final langs = lang == 'en' ? ['en'] : [lang, 'en'];
    final ids = await _identify(title, artist, langs, cancel, isrc, durationMs);

    Object? songError, artistError;
    Curiosity? song, art;
    try {
      // A page named by MusicBrainz is trusted only if it speaks of the song.
      final key = matchKey(
        coreTitle(title.split(RegExp(r'\s+[-–—]\s+')).first),
      );
      song =
          await _byLinks(ids.song, langs, cancel, mustMention: key) ??
          await wikipedia.findSong(title, artist, lang, cancel: cancel) ??
          await _discogsNotes(ids.recordingId, cancel);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      songError = e;
    } on Object catch (e) {
      songError = e;
    }
    if (artist.isNotEmpty) {
      try {
        art =
            await _byLinks(ids.artist, langs, cancel) ??
            await wikipedia.findArtist(artist, lang, cancel: cancel) ??
            await _ytmDescription(artist, cancel);
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        artistError = e;
      } on Object catch (e) {
        artistError = e;
      }
    }
    return CuriosityPair(
      song: song,
      artist: art,
      songError: songError,
      artistError: artistError,
      recordingId: ids.recordingId,
    );
  }

  /// The notes of the album's Discogs master, as a curiosity about the album.
  Future<Curiosity?> _discogsNotes(
    String? recordingId,
    CancelToken? cancel,
  ) async {
    final d = discogs;
    if (d == null || recordingId == null) return null;
    final id = await musicBrainz.discogsMasterOf(recordingId, cancel: cancel);
    if (id == null) return null;
    final notes = await d.master(id, cancel: cancel);
    if (notes == null || notes.length < _minFallbackText) return null;
    return Curiosity(
      notes,
      Uri.parse('https://www.discogs.com/master/$id'),
      'en',
    );
  }

  Future<Curiosity?> _ytmDescription(String artist, CancelToken? cancel) async {
    final f = ytmArtist;
    if (f == null) return null;
    final found = await f(artist, cancel);
    if (found == null || found.text.trim().length < _minFallbackText) {
      return null;
    }
    return Curiosity(found.text.trim(), found.source, found.lang);
  }

  /// The page titles MusicBrainz and Wikidata name for the song and the
  /// artist; empty maps when they cannot say. Never throws: it is a shortcut.
  Future<
    ({
      Map<String, String>? song,
      Map<String, String>? artist,
      String? recordingId,
    })
  >
  _identify(
    String title,
    String artist,
    List<String> langs,
    CancelToken? cancel,
    String? isrc,
    int durationMs,
  ) async {
    try {
      String? songQ, artistQ, recordingId;
      final main = extractPrimaryArtist(artist);
      final byIsrc = isrc == null
          ? const <MbRecording>[]
          : await musicBrainz.recordingsByIsrc(
              isrc,
              durationMs,
              title: title,
              artist: artist,
              cancel: cancel,
            );
      if (main.isNotEmpty || byIsrc.isNotEmpty) {
        final recs = byIsrc.isNotEmpty
            ? byIsrc
            : await musicBrainz.recordings(title, main, cancel: cancel);
        if (recs.isNotEmpty) {
          recordingId = recs.first.id;
          artistQ = await musicBrainz.artistWikidata(
            recs.first.artistId,
            cancel: cancel,
          );
          for (final r in recs.take(2)) {
            songQ = await musicBrainz.songWikidata(r.id, cancel: cancel);
            if (songQ != null) break;
          }
        } else {
          final a = await musicBrainz.artist(main, cancel: cancel);
          if (a != null) {
            artistQ = await musicBrainz.artistWikidata(a.id, cancel: cancel);
          }
        }
      }
      final wanted = [?songQ, ?artistQ];
      if (wanted.isEmpty) {
        return (song: null, artist: null, recordingId: recordingId);
      }
      final links = await wikidata.sitelinks(wanted, langs, cancel: cancel);
      return (
        song: songQ == null ? null : links[songQ],
        artist: artistQ == null ? null : links[artistQ],
        recordingId: recordingId,
      );
    } on Object catch (e, st) {
      if (e is DioException && CancelToken.isCancel(e)) rethrow;
      AppLog.w('musicbrainz lookup failed, falling back to names', e, st);
      return (song: null, artist: null, recordingId: null);
    }
  }

  /// The first of [titles] (per language, in order of preference) that reads.
  Future<Curiosity?> _byLinks(
    Map<String, String>? titles,
    List<String> langs,
    CancelToken? cancel, {
    String? mustMention,
  }) async {
    if (titles == null) return null;
    for (final l in langs) {
      final t = titles[l];
      if (t == null) continue;
      final c = await wikipedia.exact(l, t, cancel: cancel);
      if (c == null) continue;
      // The title or the lead has to name it: a wrong link is worse than none.
      if (mustMention != null && mustMention.isNotEmpty) {
        final text = matchKey(
          '$t ${c.text.substring(0, c.text.length.clamp(0, 600))}',
        );
        if (!text.contains(mustMention)) {
          AppLog.i('page "$t" does not mention the song: left out');
          continue;
        }
      }
      return c;
    }
    return null;
  }
}

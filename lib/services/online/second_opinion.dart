import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../core/import_row.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/track_repository.dart';
import '../import/track_matcher.dart';
import 'enrichment_service.dart';
import 'http_client.dart';
import 'innertube_client.dart';
import 'itunes_client.dart';
import 'lrclib_client.dart';
import 'musicbrainz_client.dart';
import 'youtube_service.dart';
import 'ytm_song_parser.dart' show ytmMatches;
import 'ytm_catalog.dart';
import '../../core/artist_key.dart';

enum SecondOpinionKind {
  /// YouTube Music answered and nothing in it is sure to be this song.
  notConfirmed,

  /// A result is certainly this song; whatever was missing got filled.
  confirmed,

  /// The search could not be made (offline, unreadable answer): ask again later.
  networkError,

  /// YouTube said «too many requests»: stop and leave the source alone.
  throttled,
}

class SecondOpinionOutcome {
  const SecondOpinionOutcome(
    this.kind, {
    this.written = const {},
    this.videoId,
  });

  final SecondOpinionKind kind;

  /// The fields filled in, empty when none.
  final Set<EnrichField> written;
  final String? videoId;
}

/// A second opinion from YouTube Music on a track the first sources left with
/// holes: the song is looked up by title and artist, and only a result that
/// is certainly the same recording (same length within 3 s, sure score) is
/// believed. Then, and only for empty fields, artist, album, cover, year,
/// track number, genre (MusicBrainz) and lyrics are filled in.
class SecondOpinion {
  SecondOpinion({
    required this.client,
    required this.catalog,
    required this.enrichment,
    required this.musicBrainz,
    required this.tracks,
    required this.hl,
  });

  final InnerTubeClient client;
  final YtmCatalog catalog;
  final EnrichmentService enrichment;
  final MusicBrainzClient musicBrainz;
  final TrackRepository tracks;
  final String Function() hl;

  /// MusicBrainz answered «too many requests»: no genre lookups until then.
  DateTime? _mbRestUntil;

  static const _maxDuration = Duration(minutes: 20);
  static const _durationSlack = Duration(seconds: 3);

  Future<SecondOpinionOutcome> check(Track track, {CancelToken? cancel}) async {
    final t = await tracks.getById(track.id) ?? track;
    if (t.durationMs <= 0) {
      return const SecondOpinionOutcome(SecondOpinionKind.notConfirmed);
    }
    final List<YtResult> results;
    try {
      await enrichment.limiter.wait();
      final artist = (t.artist ?? '').trim();
      results = await client.searchSongs(
        '${t.title} $artist'.trim(),
        cancel: cancel,
      );
    } on YtException catch (e) {
      return _failed(e, e.kind == YtErrorKind.rateLimited);
    } on InnerTubeChanged catch (e) {
      return _failed(e, false);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      return _failed(e, false);
    }
    final hit = _confirmed(t, results);
    if (hit == null) {
      return const SecondOpinionOutcome(SecondOpinionKind.notConfirmed);
    }
    return _fill(t, hit, cancel);
  }

  SecondOpinionOutcome _failed(Object e, bool rateLimited) {
    AppLog.w('second opinion search failed: $e');
    return SecondOpinionOutcome(
      rateLimited
          ? SecondOpinionKind.throttled
          : SecondOpinionKind.networkError,
    );
  }

  YtResult? _confirmed(Track t, List<YtResult> results) {
    final artist = (t.artist ?? '').trim();
    final row = ImportRow(
      index: 0,
      title: t.title,
      artists: [if (artist.isNotEmpty) artist],
      album: t.album,
      durationMs: t.durationMs,
    );
    final scored = [for (final r in results) (r, scoreCandidate(row, r))];
    YtResult? best;
    var bestScore = 0.0;
    for (final (r, score) in scored) {
      final d = r.duration;
      if (r.albumId == null || (d != null && d > _maxDuration)) continue;
      if (!ytmMatches(
        d,
        t.durationMs,
        slackMs: _durationSlack.inMilliseconds,
        titleOk: score >= sureThreshold,
      )) {
        continue;
      }
      if (artist.isEmpty) {
        // Homonyms: with no artist to compare, the title must be the same and
        // no other artist may sing a song just as good a match.
        if (matchTitleKey(r.title) != matchTitleKey(t.title)) continue;
        final who = matchKey(r.artists.firstOrNull ?? '');
        final rival = scored.any(
          (o) =>
              o.$2 >= sureThreshold &&
              matchKey(o.$1.artists.firstOrNull ?? '') != who,
        );
        if (rival) continue;
      }
      if (score > bestScore) {
        best = r;
        bestScore = score;
      }
    }
    return best;
  }

  Future<SecondOpinionOutcome> _fill(
    Track t,
    YtResult r,
    CancelToken? cancel,
  ) async {
    final fields = <EnrichField>{};
    var limited = false;
    final resultArtist = r.artists.firstOrNull;
    final artist = (t.artist ?? '').trim().isEmpty && !t.userEdited
        ? resultArtist
        : null;
    if (artist != null) fields.add(EnrichField.artist);
    // A local album that is another one: the song is the same but the file
    // belongs to a different release, so only the artist is believed.
    final differentAlbum =
        t.album != null &&
        (r.album == null || matchTitleKey(t.album!) != matchTitleKey(r.album!));
    String? album, cover, genre, lyrics;
    int? year, number;
    if (!differentAlbum) {
      if (t.album == null && r.album != null && !t.userEdited) {
        album = r.album;
        fields.add(EnrichField.album);
      }
      // A cover with no album would spread to the whole «unknown|dir» key.
      final wantCover = !t.hasCover && (album != null || t.album != null);
      if (t.year == null || t.trackNumber == null || wantCover) {
        try {
          final page = (await catalog.album(r.albumId!, hl())).value;
          if (t.year == null) year = int.tryParse(page.year ?? '');
          if (wantCover) cover = page.coverUrl;
          if (t.trackNumber == null) {
            number = page.tracks
                .where(
                  (x) =>
                      x.result.id == r.id ||
                      matchTitleKey(x.result.title) == matchTitleKey(r.title),
                )
                .firstOrNull
                ?.number;
          }
        } on YtException catch (e) {
          limited = e.kind == YtErrorKind.rateLimited;
          AppLog.w('second opinion album page failed: $e');
        } on InnerTubeChanged catch (e) {
          AppLog.w('second opinion album page failed: $e');
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) rethrow;
          AppLog.w('second opinion album page failed: $e');
        }
      }
      if (year != null) fields.add(EnrichField.year);
      if (cover != null) fields.add(EnrichField.cover);
      if (number != null) fields.add(EnrichField.trackNumber);
      final mbRest = _mbRestUntil;
      if (t.genre == null &&
          (mbRest == null || DateTime.now().isAfter(mbRest))) {
        try {
          genre = await musicBrainz.genreFor(
            t.title,
            (t.artist ?? '').trim().isEmpty ? resultArtist ?? '' : t.artist!,
            t.durationMs,
            isrc: t.isrc,
            cancel: cancel,
          );
        } on RateLimitedException catch (e) {
          _mbRestUntil = DateTime.now().add(const Duration(minutes: 10));
          AppLog.w('second opinion genre skipped: $e');
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) rethrow;
          AppLog.w('second opinion genre failed: $e');
        }
        if (genre != null) fields.add(EnrichField.genre);
      }
      if (t.lyricsPlain == null && t.lyricsSynced == null && !limited) {
        try {
          await enrichment.limiter.wait();
          lyrics = await client.lyrics(r.id, cancel: cancel);
        } on YtException catch (e) {
          limited = e.kind == YtErrorKind.rateLimited;
          AppLog.w('second opinion lyrics failed: $e');
        } on InnerTubeChanged catch (e) {
          AppLog.w('second opinion lyrics failed: $e');
        } on DioException catch (e) {
          if (CancelToken.isCancel(e)) rethrow;
          AppLog.w('second opinion lyrics failed: $e');
        }
        if (lyrics != null) fields.add(EnrichField.lyrics);
      }
    }
    // The user may have edited the track meanwhile: drop what is filled now.
    final cur = await tracks.getById(t.id);
    if (cur != null) {
      if (cur.year != null) fields.remove(EnrichField.year);
      if (cur.genre != null) fields.remove(EnrichField.genre);
      if (cur.lyricsPlain != null || cur.lyricsSynced != null) {
        fields.remove(EnrichField.lyrics);
      }
    }
    final proposal = EnrichmentProposal(
      track: t,
      meta: ItunesMatch(
        title: t.title,
        artist: artist ?? t.artist ?? '',
        album: album,
        year: year,
        genre: genre,
        trackNumber: number,
        artworkUrl: cover,
      ),
      lyrics: lyrics == null ? null : LyricsResult(plain: lyrics),
    );
    try {
      await enrichment.apply(proposal, fields, cancel: cancel);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) rethrow;
      AppLog.w('second opinion write failed: $e');
      return SecondOpinionOutcome(
        SecondOpinionKind.networkError,
        videoId: r.id,
      );
    }
    AppLog.i(
      'second opinion: ${r.id} confirmed, wrote ${fields.map((f) => f.name).join(', ')}',
    );
    return SecondOpinionOutcome(
      limited ? SecondOpinionKind.throttled : SecondOpinionKind.confirmed,
      written: fields,
      videoId: r.id,
    );
  }
}

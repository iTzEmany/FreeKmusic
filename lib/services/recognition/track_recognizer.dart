import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import '../import/track_matcher.dart' show hasPhrase, otherVersions;
import '../online/acoustid_client.dart';
import '../online/innertube_client.dart';
import '../online/ytm_song_parser.dart' show YtmSong, ytmMatches;
import '../online/metadata_resolver.dart' show ResolvedMeta;
import '../online/http_client.dart' show RateLimitedException;
import '../online/musicbrainz_client.dart';
import '../online/query_cleaner.dart';
import '../stream/stream_key.dart' show keyOfStreamPath;
import '../tags/fingerprinter.dart';
import '../tags/audio_metadata_tag_reader.dart' show readTrackIds;
import '../tags/tag_reader.dart' show normalizeIsrc;
import 'channel_detector.dart';
import 'cover_detector.dart';
import 'track_identity.dart';
import 'video_id.dart';
import '../../core/artist_key.dart';

/// AcoustID matches below this score are not the song (D-300).
const kAcoustIdMinScore = 0.9;

/// How far a source's duration may be from the track's (D-300).
const kDurationSlackMs = 10000;

/// A title shares at least this part of its words with the file to be a candidate
/// (more than this, to be «coherent» and sure).
const kTitleOverlap = 0.5;

/// Length tolerance when looking up the song of an official or uploaded video (as SecondOpinion).
const kVideoSongSlackMs = 3000;

/// The text search of the engine (`MetadataResolver.resolve`): with reliable
/// tags it is step 2 (skipped when the engine passes none).
typedef TextProbe = Future<ResolvedMeta?> Function(
  Track t,
  CleanQuery c,
  CancelToken? cancel,
);

/// The ISRC and MusicBrainz id written in a file's tags.
typedef FileIds = Future<({String? isrc, String? mbid})> Function(String path);

/// [rec] null with [lost] = a source failed and none found anything: ask again
/// later. [rec] with no `src` = every source answered «nothing».
/// [asked]: a source really got an answer from the network (a «nothing» with
/// none asked says nothing of being online); [limited]: a source refused.
class RecogOutcome {
  const RecogOutcome({
    this.rec,
    this.lost = false,
    this.asked = false,
    this.limited = false,
  });

  final Recognition? rec;
  final bool lost;
  final bool asked;
  final bool limited;
}

final _isrcShape = RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$');

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// The cascade of R-161: ISRC/MBID, video id, text, AcoustID, YouTube Music;
/// it stops at the first that finds the song.
class TrackRecognizer {
  TrackRecognizer({
    required this.musicBrainz,
    required this.innerTube,
    required this.acoustId,
    required this.fingerprinter,
    required this.useAcoustId,
    this.videoIdFor,
    this.fileIds = readTrackIds,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final MusicBrainzClient musicBrainz;
  final InnerTubeClient innerTube;
  final AcoustIdClient acoustId;
  final Fingerprinter fingerprinter;

  /// The user's AcoustID option, read for every track.
  final bool Function() useAcoustId;

  /// A video id known from outside the file name (download index, playlist import).
  final Future<String?> Function(Track t)? videoIdFor;
  final FileIds fileIds;
  final DateTime Function() _now;

  Future<RecogOutcome> recognize(
    Track t, {
    required TextProbe? textProbe,
    CancelToken? cancel,
  }) async {
    var lost = false, limited = false, asked = false;
    void got() => asked = true;
    // A source that throws is skipped (R-168); only a cancel goes up.
    Future<R?> attempt<R>(String name, Future<R?> Function() run) async {
      try {
        return await run();
      } catch (e, st) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
        lost = true;
        if (e is RateLimitedException) limited = true;
        AppLog.w('recognition: $name failed for ${t.path}', e, st);
        return null;
      }
    }

    final c = cleanSearchQuery(t.title, t.artist ?? '');
    // A channel is not an artist: it is neither searched nor compared with.
    final artist = artistIsChannel(c.artist) || isGenericArtist(c.artist)
        ? ''
        : c.artist;
    final dubious = tagsDubious(t);
    final hay = _Hay(t, c.title, artist, trustArtist: !dubious);
    Recognition? rec;
    ResolvedMeta? meta;
    final works = <MbWorkLink>[];
    rec = await attempt(
      'tags',
      () => _fromIds(t, dubious ? null : c, cancel, got, works),
    );
    rec ??= await attempt('video id', () => _fromVideoId(t, cancel, got));
    if (rec == null && !dubious && textProbe != null) {
      meta = await attempt('text', () async {
        final m = await textProbe(t, c, cancel);
        got();
        return m;
      });
      if (meta != null) rec = _text(meta);
    }
    // Reliable tags and no text search due: the text search already worked once, nothing to correct.
    final nothingToCorrect = !dubious && textProbe == null;
    if (rec == null && !nothingToCorrect) {
      if (keyOfStreamPath(t.path) != null || !Fingerprinter.supports(t.path)) {
        // No file, or Opus/WebM (R-184): a definite «no».
      } else if (!useAcoustId()) {
        lost = true; // not answered: ask again if the user turns it on
      } else if (acoustId.isResting) {
        lost = limited =
            true; // refused a moment ago: no point in decoding the file
      } else {
        rec = await attempt(
          'acoustid',
          () => _fromAcoustId(t, hay, cancel, got),
        );
      }
    }
    if (!nothingToCorrect) {
      rec ??= await attempt(
        'ytm',
        () => _fromYtm(t, c.title, artist, hay, cancel, got),
      );
    }
    if (rec != null) {
      final found = rec;
      // A failed cover lookup is a lost source: nothing is saved, the next run asks again.
      rec = await attempt(
        'cover',
        () => _coverOf(
          t.title,
          t.artist,
          found,
          works,
          artist,
          cancel,
          got,
          byCounts: !dubious,
        ),
      );
      if (rec == null) {
        return RecogOutcome(lost: true, asked: asked, limited: limited);
      }
      return RecogOutcome(rec: rec, asked: asked);
    }
    if (lost) return RecogOutcome(lost: true, asked: asked, limited: limited);
    return RecogOutcome(
      rec: Recognition(at: _now().millisecondsSinceEpoch),
      asked: asked,
    );
  }

  Recognition _found(
    RecogSource src,
    TrackIdentity id, {
    double? score,
    bool sure = false,
  }) => Recognition(
    at: _now().millisecondsSinceEpoch,
    src: src,
    score: score,
    sure: sure,
    identity: id,
  );

  /// Step 1: the MusicBrainz id or the ISRC of the tags, checked against the length.
  /// With reliable tags ([query] set) the ISRC answer is filtered by title and
  /// artist and is sure; with dubious ones any recording of that ISRC is only a proposal.
  Future<Recognition?> _fromIds(
    Track t,
    CleanQuery? query,
    CancelToken? cancel,
    void Function() got,
    List<MbWorkLink> works,
  ) async {
    // Untrusted tag text goes into a URL: only a real ISRC.
    String? validIsrc(String? raw) {
      final n = normalizeIsrc(raw);
      return n != null && _isrcShape.hasMatch(n) ? n : null;
    }

    var isrc = validIsrc(t.isrc);
    String? mbid;
    if (keyOfStreamPath(t.path) == null &&
        !t.path.toLowerCase().endsWith('.webm')) {
      try {
        final ids = await fileIds(t.path);
        isrc ??= validIsrc(ids.isrc);
        // Untrusted tag text goes into a URL: only a real UUID.
        mbid = ids.mbid != null && _uuid.hasMatch(ids.mbid!) ? ids.mbid : null;
      } catch (e, st) {
        AppLog.w('recognition: ids not read from ${t.path}', e, st);
      }
    }
    bool close(int? ms) =>
        ms == null ||
        t.durationMs <= 0 ||
        (ms - t.durationMs).abs() <= kDurationSlackMs;
    if (mbid != null) {
      final d = await musicBrainz.recordingById(mbid, cancel: cancel);
      got();
      if (d != null && close(d.length)) {
        works.addAll(d.works);
        return _found(
          RecogSource.tags,
          TrackIdentity(
            title: d.title,
            artist: d.artist,
            ms: d.length,
            isrc: isrc ?? d.isrcs.firstOrNull,
            mbid: d.id,
          ),
          sure: true,
        );
      }
    }
    if (isrc != null) {
      final recs = await musicBrainz.recordingsByIsrc(
        isrc,
        t.durationMs,
        title: query?.title,
        artist: query?.artist,
        cancel: cancel,
        strict: true,
      );
      got();
      final r = recs.where((r) => close(r.length)).firstOrNull;
      if (r != null) {
        return _found(
          RecogSource.tags,
          TrackIdentity(
            title: r.title,
            artist: r.artistName,
            ms: r.length,
            isrc: isrc,
            mbid: r.id,
          ),
          sure: query != null,
        );
      }
    }
    return null;
  }

  /// R-172/R-173: marks [rec] as a cover (MusicBrainz says so, or the file title
  /// does) and looks for the original. The identity stays the cover's own recording,
  /// and a hinted cover that resolves to the original's artist is never sure.
  Future<Recognition> _coverOf(
    String title,
    String? tagArtistRaw,
    Recognition rec,
    List<MbWorkLink> works,
    String artist,
    CancelToken? cancel,
    void Function() got, {
    bool byCounts = true,
  }) async {
    final link = works.where((w) => w.cover).firstOrNull;
    final hint = coverHint(
      title,
      tagArtistRaw,
      identityArtist: rec.identity?.artist,
      byCounts: byCounts,
    );
    if (link == null && !hint.cover) return rec;
    final id = rec.identity!;
    final tagArtist = matchKey(artist);
    final sameArtist = tagArtist.isNotEmpty && matchKey(id.artist) == tagArtist;
    // An artist's remix of their own song is not a cover (a «cover» by the same artist is).
    if (link == null && hint.remixOnly && sameArtist) return rec;
    MbRecording? orig;
    if (link != null) {
      orig = await musicBrainz.workOriginal(link.id, cancel: cancel);
      got();
    }
    if (orig == null && hint.original.isNotEmpty) {
      // The tag artist is the cover's: the original is searched by the identity's artist when that
      // is another one, else by title only (also skipping the tag artist's own recordings) (MusicBrainz's best match stands in for the oldest).
      final by = tagArtist.isNotEmpty && !sameArtist ? id.artist : '';
      final found = await musicBrainz.recordings(
        hint.original,
        by,
        studioOnly: true,
        cancel: cancel,
      );
      got();
      orig = found
          .where(
            (r) =>
                r.id != id.mbid &&
                (tagArtist.isEmpty || matchKey(r.artistName) != tagArtist),
          )
          .firstOrNull;
    }
    // Only a hinted cover whose identity is the original's own artist is no correction to apply.
    final isOriginal =
        link == null &&
        orig != null &&
        matchKey(id.artist) == matchKey(orig.artistName);
    return rec.copyWith(
      cover: true,
      sure: rec.sure && !isOriginal,
      original: orig == null
          ? null
          : {'title': orig.title, 'artist': orig.artistName, 'mbid': orig.id},
    );
  }

  /// An online item (`yt:`, stream) has no track row: only step 1b and the cover
  /// step, by video id alone. Null when YouTube Music has no song for it or a
  /// source failed (logged; the caller may ask again). Nothing is written.
  Future<Recognition?> recognizeOnline(
    String videoId, {
    CancelToken? cancel,
  }) async {
    try {
      String? videoTitle;
      final rec = await _ytmSong(
        videoId,
        0,
        cancel,
        () {},
        onVideoTitle: (v) => videoTitle = v,
      );
      if (rec == null) return null;
      final id = rec.identity!;
      final c = cleanSearchQuery(id.title, id.artist);
      // The video's own title tells a cover, not the official song title found for it.
      return await _coverOf(
        videoTitle ?? id.title,
        id.artist,
        rec,
        const [],
        artistIsChannel(c.artist) || isGenericArtist(c.artist) ? '' : c.artist,
        cancel,
        () {},
      );
    } catch (e, st) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLog.w('recognition: online item $videoId failed', e, st);
      return null;
    }
  }

  /// Step 1b: what YouTube Music says of the video this file came from. Sure
  /// only for a studio video, or an official one whose studio song was found (69e.5,
  /// narrows D-312), and not when the title names a version the file does not.
  Future<Recognition?> _fromVideoId(
    Track t,
    CancelToken? cancel,
    void Function() got,
  ) async {
    final id = await videoIdFor?.call(t) ?? videoIdOf(t.path);
    if (id == null) return null;
    final rec = await _ytmSong(id, t.durationMs, cancel, got);
    final hay = _Hay(t, t.title, t.artist ?? '');
    return rec != null &&
            rec.sure &&
            hay._extraVersions(matchKey(rec.identity!.title)) > 0
        ? rec.copyWith(sure: false)
        : rec;
  }

  /// The song of video [id], as an identity; [durationMs] > 0 must match its length.
  /// Studio audio (ATV) gives its own title; an official or uploaded video gives the
  /// video's title, so the song is looked up among YouTube Music songs (69e.5).
  Future<Recognition?> _ytmSong(
    String id,
    int durationMs,
    CancelToken? cancel,
    void Function() got, {
    void Function(String)? onVideoTitle,
  }) async {
    final YtmSong s;
    try {
      s = await innerTube.songOf(id, cancel: cancel);
      got();
    } on InnerTubeChanged catch (e) {
      // shortcut: a deleted or private video and a changed YouTube format look the same here; both are «nothing», the log tells.
      AppLog.w('recognition: no song for video $id', e);
      return null;
    }
    onVideoTitle?.call(s.title);
    final gap = s.durationMs == null ? 0 : (s.durationMs! - durationMs).abs();
    if (s.artists.isEmpty || (durationMs > 0 && gap > kDurationSlackMs)) {
      return null;
    }
    var title = s.title, artists = s.artists, sure = s.official;
    if (s.videoType != 'MUSIC_VIDEO_TYPE_ATV') {
      final c = cleanSearchQuery(s.title, s.artists.join(', '));
      if (c.title.isNotEmpty) title = c.title;
      sure = false;
      final wantMs = durationMs > 0 ? durationMs : s.durationMs ?? 0;
      if (c.title.isNotEmpty && wantMs > 0) {
        // A failing search goes up: the caller marks the source lost and asks again (R-168).
        final results = await innerTube.searchSongs(
          '${c.title} ${s.artists.first}'.trim(),
          cancel: cancel,
        );
        got();
        final mine = {for (final a in s.artists) matchKey(a)};
        final want = matchKey(c.title);
        final song = results.where((r) {
          final k = matchKey(r.title);
          return r.artists.any((a) => mine.contains(matchKey(a))) &&
              ytmMatches(
                r.duration,
                wantMs,
                slackMs: kVideoSongSlackMs,
                titleOk: true,
              ) &&
              (hasPhrase(want, k) || hasPhrase(k, want));
        }).firstOrNull;
        if (song != null) {
          title = song.title;
          artists = song.artists;
          sure = s.videoType == 'MUSIC_VIDEO_TYPE_OMV';
        }
      }
    }
    return _found(
      RecogSource.ytid,
      TrackIdentity(
        title: title,
        artist: artists.join(', '),
        ms: s.durationMs,
        vid: id,
      ),
      sure: sure,
    );
  }

  /// Step 2: the text search found it. Not sure: the tags may be as wrong as the match.
  Recognition _text(ResolvedMeta m) {
    final secs = m.hit?.duration ?? 0;
    return _found(
      RecogSource.text,
      TrackIdentity(
        title: m.match.title,
        artist: m.match.artist,
        ms: secs > 0 ? secs * 1000 : null,
        isrc: m.isrc,
      ),
    );
  }

  /// Step 3: AcoustID by fingerprint (only the fingerprint travels).
  Future<Recognition?> _fromAcoustId(
    Track t,
    _Hay hay,
    CancelToken? cancel,
    void Function() got,
  ) async {
    final fp = await fingerprinter.of(t.path);
    if (fp == null) return null; // too short or silent: a definite «no» (a read error throws instead)
    final wantMs = t.durationMs > 0 ? t.durationMs : fp.secs * 1000;
    final hits = await acoustId.lookup(fp.fp, fp.secs, cancel: cancel);
    got();
    final seen = <String>{};
    AcoustIdRecording? best;
    double? bestScore, bestHit;
    for (final h in hits.where((h) => h.score >= kAcoustIdMinScore)) {
      for (final r in h.recordings) {
        final d = r.durationS;
        if (r.title.isEmpty || d == null || !seen.add(r.id)) continue;
        final gap = (d * 1000 - wantMs).abs();
        if (gap > kDurationSlackMs) continue;
        // The duration gap only breaks ties between equally good titles.
        final s = hay.similarity(r.title, r.artists) - gap / 1e6;
        if (bestScore == null || s > bestScore) {
          best = r;
          bestScore = s;
          bestHit = h.score;
        }
      }
    }
    if (best == null) return null;
    return _found(
      RecogSource.acoustid,
      TrackIdentity(
        title: best.title,
        artist: best.artists.join(', '),
        ms: best.durationS! * 1000,
        mbid: best.id,
      ),
      score: bestHit,
      sure: hay.titleCoherent(best.title) && hay.artistCoherent(best.artists),
    );
  }

  /// Step 4: YouTube Music, a proposal at most (D-304).
  Future<Recognition?> _fromYtm(
    Track t,
    String title,
    String artist,
    _Hay hay,
    CancelToken? cancel,
    void Function() got,
  ) async {
    if (t.durationMs <= 0) return null;
    final results = await innerTube.searchSongs(
      '$title $artist'.trim(),
      cancel: cancel,
    );
    got();
    var bestScore = double.negativeInfinity;
    Recognition? best;
    for (final r in results) {
      final d = r.duration;
      if (r.artists.isEmpty) continue;
      // The length first: it is cheaper than the title.
      if (!ytmMatches(
        d,
        t.durationMs,
        slackMs: kDurationSlackMs,
        titleOk: true,
      )) {
        continue;
      }
      if (hay.titleOverlap(r.title) < kTitleOverlap) continue;
      final s = hay.similarity(r.title, r.artists);
      if (s > bestScore) {
        bestScore = s;
        best = _found(
          RecogSource.ytm,
          TrackIdentity(
            title: r.title,
            artist: r.artists.join(', '),
            ms: d!.inMilliseconds,
            vid: r.id,
          ),
        );
      }
    }
    return best;
  }
}

/// What the file name and the cleaned tags say, to compare a candidate with.
/// [artist] is the cleaned artist, '' when it is a channel.
class _Hay {
  _Hay(Track t, String title, String artist, {bool trustArtist = true})
    : key = matchKey(
        [
          if (keyOfStreamPath(t.path) == null)
            p.basenameWithoutExtension(t.path),
          title,
          artist,
        ].join(' '),
      ),
      artistKey = trustArtist ? matchKey(artist) : '' {
    tokens = _words(key);
    scripts = _scripts(key);
  }

  final String key;
  final String artistKey;
  late final Set<String> tokens;
  late final Set<int> scripts;

  static Set<String> _words(String k) =>
      k.split(' ').where((w) => w.isNotEmpty).toSet();

  /// 0..1: how much of [title] is in the file name or tags, by whole words.
  double titleOverlap(String title) {
    final k = matchKey(title);
    final words = _words(k);
    if (words.isEmpty) return 0;
    if (hasPhrase(key, k)) return 1;
    return words.where(tokens.contains).length / words.length;
  }

  /// Title and artists against the file; a version the file does not name costs a lot.
  double similarity(String title, List<String> artists) {
    final names = [for (final a in artists) matchKey(a)]
        .where((a) => a.isNotEmpty);
    final artistHit = names.isEmpty
        ? 0
        : names.where((a) => hasPhrase(key, a)).length / names.length;
    final k = matchKey(title);
    return 2 * titleOverlap(title) + artistHit - 1.5 * _extraVersions(k);
  }

  int _extraVersions(String titleKey) => otherVersions
      .where((v) => hasPhrase(titleKey, v) && !hasPhrase(key, v))
      .length;

  /// The title reads like the file: it shares more than half of its words, names
  /// no version the file does not, and uses the same non-Latin scripts, if any
  /// (K-RB-04: a Japanese title for a Latin file is a proposal).
  bool titleCoherent(String title) {
    final k = matchKey(title);
    final s = _scripts(k);
    return titleOverlap(title) > kTitleOverlap &&
        _extraVersions(k) == 0 &&
        s.length == scripts.length &&
        s.containsAll(scripts);
  }

  /// With a real tag artist, the recording shares one of its names with the file or
  /// tags, or one significant word of the tag artist («Marshmello ft. Bastille»
  /// vs «Marshmello, Bastille»). Without a tag artist there is nothing to contradict.
  bool artistCoherent(List<String> artists) {
    if (artistKey.isEmpty) return true;
    final names = [for (final a in artists) matchKey(a)]
        .where((a) => a.isNotEmpty)
        .toList();
    if (names.any((a) => hasPhrase(key, a))) return true;
    final theirs = {for (final n in names) ..._words(n)};
    return _words(artistKey).any((w) => w.length > 2 && theirs.contains(w));
  }

  /// Non-Latin writing systems in [s], as small ids.
  static Set<int> _scripts(String s) {
    int? id(int r) {
      if (r >= 0x0370 && r <= 0x03FF) return 1; // Greek
      if (r >= 0x0400 && r <= 0x052F) return 2; // Cyrillic
      if (r >= 0x0590 && r <= 0x05FF) return 3; // Hebrew
      if (r >= 0x0600 && r <= 0x06FF) return 4; // Arabic
      if (r >= 0x0900 && r <= 0x097F) return 5; // Devanagari
      if (r >= 0x0E00 && r <= 0x0E7F) return 6; // Thai
      final cjk =
          (r >= 0x3040 && r <= 0x30FF) ||
          (r >= 0x3400 && r <= 0x9FFF) ||
          (r >= 0xAC00 && r <= 0xD7AF) ||
          (r >= 0x1100 && r <= 0x11FF);
      return cjk ? 7 : null;
    }

    return {for (final r in s.runes) ?id(r)};
  }
}

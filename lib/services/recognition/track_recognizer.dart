import 'package:dio/dio.dart' show CancelToken, DioException, DioExceptionType;
import 'package:metadata_god/metadata_god.dart' as mg;
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show Track;
import '../import/track_matcher.dart' show hasPhrase, matchKey, otherVersions;
import '../online/acoustid_client.dart';
import '../online/innertube_client.dart';
import '../online/ytm_song_parser.dart' show YtmSong;
import '../online/metadata_resolver.dart' show ResolvedMeta;
import '../online/http_client.dart' show RateLimitedException;
import '../online/musicbrainz_client.dart';
import '../online/query_cleaner.dart';
import '../stream/stream_key.dart' show keyOfStreamPath;
import '../tags/fingerprinter.dart';
import '../tags/metadata_god_init.dart';
import '../tags/tag_reader.dart' show normalizeIsrc;
import 'channel_detector.dart';
import 'track_identity.dart';
import 'video_id.dart';

/// AcoustID matches below this score are not the song (D-300).
const kAcoustIdMinScore = 0.9;

/// How far a source's duration may be from the track's (D-300).
const kDurationSlackMs = 10000;

/// A title shares at least this part of its words with the file to be a candidate
/// (more than this, to be «coherent» and sure).
const kTitleOverlap = 0.5;

/// The text search of the engine (`MetadataResolver.resolve`): with reliable
/// tags it is step 2 (skipped when the engine passes none).
typedef TextProbe = Future<ResolvedMeta?> Function(Track t, CleanQuery c, CancelToken? cancel);

/// The ISRC and MusicBrainz id written in a file's tags.
typedef FileIds = Future<({String? isrc, String? mbid})> Function(String path);

Future<({String? isrc, String? mbid})> readFileIds(String path) async {
  await ensureMetadataGod();
  final ids = await mg.readIds(path: path);
  return (isrc: ids.isrc, mbid: ids.mbid);
}

/// [rec] null with [lost] = a source failed and none found anything: ask again
/// later. [rec] with no `src` = every source answered «nothing».
/// [asked]: a source really got an answer from the network (a «nothing» with
/// none asked says nothing of being online); [limited]: a source refused.
class RecogOutcome {
  const RecogOutcome({this.rec, this.lost = false, this.asked = false, this.limited = false});

  final Recognition? rec;
  final bool lost;
  final bool asked;
  final bool limited;
}

final _isrcShape = RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$');

final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');

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
    this.fileIds = readFileIds,
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

  Future<RecogOutcome> recognize(Track t,
      {required TextProbe? textProbe, CancelToken? cancel}) async {
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
    final artist = artistIsChannel(c.artist) ? '' : c.artist;
    final dubious = tagsDubious(t);
    final hay = _Hay(t, c.title, artist);
    Recognition? rec;
    ResolvedMeta? meta;
    rec = await attempt('tags', () => _fromIds(t, dubious ? null : c, cancel, got));
    rec ??= await attempt('video id', () => _fromVideoId(t, cancel, got));
    if (rec == null && !dubious && textProbe != null) {
      meta = await attempt('text', () async {
        final m = await textProbe(t, c, cancel);
        got();
        return m;
      });
      if (meta != null) rec = _text(meta);
    }
    if (rec == null) {
      if (keyOfStreamPath(t.path) != null || !Fingerprinter.supports(t.path)) {
        // No file, or Opus/WebM (R-184): a definite «no».
      } else if (!useAcoustId()) {
        lost = true; // not answered: ask again if the user turns it on
      } else if (acoustId.isResting) {
        lost = limited = true; // refused a moment ago: no point in decoding the file
      } else {
        rec = await attempt('acoustid', () => _fromAcoustId(t, hay, cancel, got));
      }
    }
    rec ??= await attempt('ytm', () => _fromYtm(t, c.title, artist, hay, cancel, got));
    if (rec != null) return RecogOutcome(rec: rec, asked: asked);
    if (lost) return RecogOutcome(lost: true, asked: asked, limited: limited);
    return RecogOutcome(rec: Recognition(at: _now().millisecondsSinceEpoch), asked: asked);
  }

  Recognition _found(RecogSource src, TrackIdentity id, {double? score, bool sure = false}) =>
      Recognition(at: _now().millisecondsSinceEpoch, src: src, score: score, sure: sure, identity: id);

  /// Step 1: the MusicBrainz id or the ISRC of the tags, checked against the length.
  /// With reliable tags ([query] set) the ISRC answer is filtered by title and
  /// artist and is sure; with dubious ones any recording of that ISRC is only a proposal.
  Future<Recognition?> _fromIds(Track t, CleanQuery? query, CancelToken? cancel, void Function() got) async {
    // Untrusted tag text goes into a URL: only a real ISRC.
    String? validIsrc(String? raw) {
      final n = normalizeIsrc(raw);
      return n != null && _isrcShape.hasMatch(n) ? n : null;
    }

    var isrc = validIsrc(t.isrc);
    String? mbid;
    if (keyOfStreamPath(t.path) == null && !t.path.toLowerCase().endsWith('.webm')) {
      try {
        final ids = await fileIds(t.path);
        isrc ??= validIsrc(ids.isrc);
        // Untrusted tag text goes into a URL: only a real UUID.
        mbid = ids.mbid != null && _uuid.hasMatch(ids.mbid!) ? ids.mbid : null;
      } catch (e, st) {
        AppLog.w('recognition: ids not read from ${t.path}', e, st);
      }
    }
    bool close(int? ms) => ms == null || t.durationMs <= 0 || (ms - t.durationMs).abs() <= kDurationSlackMs;
    if (mbid != null) {
      final d = await musicBrainz.recordingById(mbid, cancel: cancel);
      got();
      if (d != null && close(d.length)) {
        return _found(
            RecogSource.tags,
            TrackIdentity(
                title: d.title,
                artist: d.artist,
                ms: d.length,
                isrc: isrc ?? d.isrcs.firstOrNull,
                mbid: d.id),
            sure: true);
      }
    }
    if (isrc != null) {
      final recs = await musicBrainz.recordingsByIsrc(isrc, t.durationMs,
          title: query?.title, artist: query?.artist, cancel: cancel, strict: true);
      got();
      final r = recs.where((r) => close(r.length)).firstOrNull;
      if (r != null) {
        return _found(RecogSource.tags,
            TrackIdentity(title: r.title, artist: r.artistName, ms: r.length, isrc: isrc, mbid: r.id),
            sure: query != null);
      }
    }
    return null;
  }

  /// Step 1b: what YouTube Music says of the video this file came from. Sure
  /// only for a studio or official video (D-312).
  Future<Recognition?> _fromVideoId(Track t, CancelToken? cancel, void Function() got) async {
    final id = await videoIdFor?.call(t) ?? videoIdOf(t.path);
    if (id == null) return null;
    final YtmSong s;
    try {
      s = await innerTube.songOf(id, cancel: cancel);
      got();
    } on InnerTubeChanged catch (e) {
      // shortcut: a deleted or private video and a changed YouTube format look the same here; both are «nothing», the log tells.
      AppLog.w('recognition: no song for video $id', e);
      return null;
    }
    final gap = s.durationMs == null ? 0 : (s.durationMs! - t.durationMs).abs();
    if (s.artists.isEmpty || (t.durationMs > 0 && gap > kDurationSlackMs)) return null;
    return _found(
        RecogSource.ytid,
        TrackIdentity(title: s.title, artist: s.artists.join(', '), ms: s.durationMs, vid: id),
        sure: s.official);
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
            isrc: m.isrc));
  }

  /// Step 3: AcoustID by fingerprint (only the fingerprint travels).
  Future<Recognition?> _fromAcoustId(Track t, _Hay hay, CancelToken? cancel, void Function() got) async {
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
            mbid: best.id),
        score: bestHit,
        sure: hay.titleCoherent(best.title));
  }

  /// Step 4: YouTube Music, a proposal at most (D-304).
  Future<Recognition?> _fromYtm(
      Track t, String title, String artist, _Hay hay, CancelToken? cancel, void Function() got) async {
    if (t.durationMs <= 0) return null;
    final results = await innerTube.searchSongs('$title $artist'.trim(), cancel: cancel);
    got();
    var bestScore = double.negativeInfinity;
    Recognition? best;
    for (final r in results) {
      final d = r.duration;
      if (d == null || r.artists.isEmpty) continue;
      if ((d.inMilliseconds - t.durationMs).abs() > kDurationSlackMs) continue;
      if (hay.titleOverlap(r.title) < kTitleOverlap) continue;
      final s = hay.similarity(r.title, r.artists);
      if (s > bestScore) {
        bestScore = s;
        best = _found(
            RecogSource.ytm,
            TrackIdentity(
                title: r.title, artist: r.artists.join(', '), ms: d.inMilliseconds, vid: r.id));
      }
    }
    return best;
  }
}

/// What the file name and the cleaned tags say, to compare a candidate with.
/// [artist] is the cleaned artist, '' when it is a channel.
class _Hay {
  _Hay(Track t, String title, String artist)
      : key = matchKey([
          if (keyOfStreamPath(t.path) == null) p.basenameWithoutExtension(t.path),
          title,
          artist,
        ].join(' ')) {
    tokens = _words(key);
    scripts = _scripts(key);
  }

  final String key;
  late final Set<String> tokens;
  late final Set<int> scripts;

  static Set<String> _words(String k) => k.split(' ').where((w) => w.isNotEmpty).toSet();

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
    final names = [for (final a in artists) matchKey(a)].where((a) => a.isNotEmpty);
    final artistHit = names.isEmpty ? 0 : names.where((a) => hasPhrase(key, a)).length / names.length;
    final k = matchKey(title);
    return 2 * titleOverlap(title) + artistHit - 1.5 * _extraVersions(k);
  }

  int _extraVersions(String titleKey) =>
      otherVersions.where((v) => hasPhrase(titleKey, v) && !hasPhrase(key, v)).length;

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

  /// Non-Latin writing systems in [s], as small ids.
  static Set<int> _scripts(String s) {
    int? id(int r) {
      if (r >= 0x0370 && r <= 0x03FF) return 1; // Greek
      if (r >= 0x0400 && r <= 0x052F) return 2; // Cyrillic
      if (r >= 0x0590 && r <= 0x05FF) return 3; // Hebrew
      if (r >= 0x0600 && r <= 0x06FF) return 4; // Arabic
      if (r >= 0x0900 && r <= 0x097F) return 5; // Devanagari
      if (r >= 0x0E00 && r <= 0x0E7F) return 6; // Thai
      final cjk = (r >= 0x3040 && r <= 0x30FF) || (r >= 0x3400 && r <= 0x9FFF) ||
          (r >= 0xAC00 && r <= 0xD7AF) || (r >= 0x1100 && r <= 0x11FF);
      return cjk ? 7 : null;
    }

    return {for (final r in s.runes) ?id(r)};
  }
}

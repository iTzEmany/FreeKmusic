import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../core/app_log.dart';
import '../../core/clock.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/credits_repository.dart';
import '../../data/repositories/track_repository.dart';
import 'credits.dart';
import 'deezer_client.dart';
import 'deezer_gw_client.dart';
import 'deezer_models.dart';
import 'http_client.dart' show RateLimitedException;
import 'metadata_resolver.dart';
import 'musicbrainz_client.dart';

/// What the credits sources said about one track. Never touches `tracks`.
class CreditsPart {
  const CreditsPart({
    this.credits = const [],
    this.details,
    this.deezerId,
    this.mbid,
    this.failed = const {},
    this.limited = false,
  });

  /// Deezer's first, then what MusicBrainz adds ([mergeCredits]).
  final List<TrackCredit> credits;
  final TrackDetails? details;
  final int? deezerId;
  final String? mbid;

  /// The credit sources (`deezer`, `musicbrainz`) that did not answer. Only
  /// when none failed (a valid empty answer counts) may an empty result be
  /// remembered as «searched, nothing» (invariant 3).
  final Set<String> failed;

  /// A source refused (too many requests): [failed] holds it, but it is not a broken source.
  final bool limited;
  bool get complete => failed.isEmpty;
}

/// The credits part of the enrichment: asks Deezer and MusicBrainz ([fetch]),
/// stores the answer ([save]) and says when to ask ([isDue]).
class CreditsEnricher {
  CreditsEnricher({
    required this.tracks,
    required this.repo,
    required this.deezer,
    required this.gw,
    required this.musicBrainz,
    required this.resolver,
  });

  final TrackRepository tracks;
  final CreditsRepository repo;
  final DeezerClient? deezer;
  final DeezerGwClient? gw;
  final MusicBrainzClient? musicBrainz;

  /// The Deezer track and album of the metadata part, shared with this one.
  final MetadataResolver resolver;

  /// Some credit source can be asked now.
  bool get canAsk => musicBrainz != null || (gw != null && !gw!.isPaused);

  /// Deezer id (given [known] by the metadata part, else looked up even with
  /// «Metadata from Deezer» off, and then nothing but credits comes of it:
  /// R-36), details, Deezer and MusicBrainz credits. Each source is guarded on
  /// its own; only a cancellation escapes.
  Future<CreditsPart> fetch(
    Track t,
    DeezerTrack? known,
    CancelToken? cancel,
  ) async {
    final failed = <String>{};
    var limited = false;
    // [origin] is the credit source that gets no answer when [ask] fails
    // (no answer is not an empty answer: invariant 3).
    Future<T?> source<T>(
      String origin,
      String name,
      Future<T?> Function() ask,
    ) async {
      try {
        return await ask().timeout(const Duration(seconds: 25));
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) rethrow;
        AppLog.w('credits source $name failed', e);
      } on RateLimitedException catch (e) {
        AppLog.w('credits source $name refused', e);
        limited = true;
      } catch (e, st) {
        AppLog.w('credits source $name failed', e, st);
      }
      failed.add(origin);
      return null;
    }

    final dz = deezer;
    var hit = known;
    if (hit == null) {
      if (dz == null || dz.isResting) {
        failed.add('deezer');
      } else {
        hit = await source(
          'deezer',
          'deezer lookup',
          () => resolver.deezerHit(t, cancel),
        );
      }
    }
    final found = hit;
    final isrc = t.isrc ?? found?.isrc;
    final mb = musicBrainz;

    Future<(TrackDetails?, DeezerContributors?)> deezerBranch() async {
      if (found == null || dz == null) return (null, null);
      final d = await source(
        'deezer',
        'deezer details',
        () => dz.trackDetails(
          found.id,
          album: resolver.albumOf(found.album?.id),
          cancel: cancel,
        ),
      );
      final g = gw;
      final ready = g == null
          ? null
          : await source('deezer', 'deezer gw', () async {
              await g.load();
              return !g.isPaused;
            });
      if (ready != true) {
        failed.add('deezer'); // paused, missing or unreadable
        return (d, null);
      }
      return (
        d,
        await source('deezer', 'deezer page', () => g!.pageTrack(found.id)),
      );
    }

    Future<(String?, List<TrackCredit>)> mbBranch() async {
      if (mb == null) {
        failed.add('musicbrainz');
        return (null, const <TrackCredit>[]);
      }
      if (isrc == null) return (null, const <TrackCredit>[]);
      final recs = await source(
        'musicbrainz',
        'musicbrainz isrc',
        () => mb.recordingsByIsrc(
          isrc,
          t.durationMs,
          title: t.title,
          artist: t.artist ?? '',
          cancel: cancel,
          strict: true,
        ),
      );
      final mbid = recs?.firstOrNull?.id;
      if (mbid == null) return (null, const <TrackCredit>[]);
      final credits = await source(
        'musicbrainz',
        'musicbrainz credits',
        () => mb.recordingCredits(mbid, cancel: cancel),
      );
      return (mbid, credits ?? const <TrackCredit>[]);
    }

    // Different services: asked side by side. (Not a record `.wait`, which
    // would wrap a cancellation in a ParallelWaitError.)
    final both = await Future.wait<Object?>([deezerBranch(), mbBranch()]);
    final (details, page) = both[0] as (TrackDetails?, DeezerContributors?);
    final (mbid, mbCredits) = both[1] as (String?, List<TrackCredit>);
    return CreditsPart(
      credits: mergeCredits(page?.credits ?? const [], mbCredits),
      details: details == null && page == null
          ? null
          : (details ?? const TrackDetails()).copyWith(
              copyright: page?.copyright,
              physicalReleaseDate: page?.physicalReleaseDate,
            ),
      deezerId: found?.id,
      mbid: mbid,
      failed: failed,
      limited: limited,
    );
  }

  /// Writes `track_credits` and `track_enrich` only. Found → the none mark is
  /// cleared; valid and empty → marked now; any failure → left as it was.
  /// [trackKnown]: the caller has just read the track row. [stored]: the
  /// credits it has just read. [baseDetails]: the `details` column it has just
  /// read (none: read here). Returns the `details` written, if any.
  Future<String?> save(int trackId, CreditsPart? part,
      {bool trackKnown = false, List<TrackCreditRow>? stored, String? baseDetails}) async {
    if (part == null) return null;
    // The track may have been deleted while the sources were asked (FK).
    if (!trackKnown && await tracks.getById(trackId) == null) {
      AppLog.i('credits: track $trackId is gone, nothing saved');
      return null;
    }
    if (baseDetails == null && part.details != null) {
      // Read and write in one transaction: a recognition saved meanwhile is not lost.
      return repo.atomic(
          () async => _write(trackId, part, stored, (await repo.enrichOf(trackId))?.details));
    }
    return _write(trackId, part, stored, baseDetails);
  }

  Future<String?> _write(int trackId, CreditsPart part, List<TrackCreditRow>? stored, String? baseDetails) async {
    var list = part.credits;
    if (list.isNotEmpty && !part.complete) {
      // A source was down: keep only what it gave in an earlier run.
      list = mergeCredits(list, [
        for (final c in stored ?? await repo.creditsOf(trackId))
          if (part.failed.contains(c.source))
            TrackCredit(c.name, c.role, c.source),
      ]);
    }
    // The column is shared with the recognition: merge, never overwrite.
    final details = part.details == null
        ? null
        : mergeDetails(baseDetails, details: part.details);
    final row = TrackEnrichCompanion(
      trackId: Value(trackId),
      details: details == null ? const Value.absent() : Value(details),
      deezerId: part.deezerId == null
          ? const Value.absent()
          : Value(part.deezerId),
      mbid: part.mbid == null ? const Value.absent() : Value(part.mbid),
      creditsNoneAt: list.isNotEmpty
          ? const Value(null)
          : part.complete
          ? Value(nowMs())
          : const Value.absent(),
    );
    // Empty and complete replaces what was stored: credits and the none mark never coexist.
    if (list.isEmpty && !part.complete) {
      await repo.saveEnrich(row);
      return details;
    }
    await repo.save(trackId, [
      for (final c in list)
        TrackCreditsCompanion.insert(
          trackId: trackId,
          name: c.name,
          nameKey: c.nameKey,
          role: c.role,
          source: c.source,
        ),
    ], row);
    return details;
  }
}

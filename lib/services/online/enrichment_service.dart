import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../../core/clock.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/track_repository.dart';
import 'cover_fetcher.dart';
import 'credits_enricher.dart';
import 'enrich_gather.dart' show withTrackMemo;
import 'enrich_parts.dart';
import 'enrich_writer.dart';
import 'enrichment_proposal.dart';
import 'http_client.dart';
import 'lrclib_client.dart';
import 'lyrics_chain.dart';
import 'metadata_resolver.dart';
import 'query_cleaner.dart';
import 'wikipedia_client.dart';

export 'credits_enricher.dart' show CreditsPart;
export 'enrich_parts.dart' show AskMode, EnrichField, EnrichPart, PartOutcome;
export 'enrichment_proposal.dart' show EnrichmentProposal;

bool _never() => false;

class EnrichmentService {
  EnrichmentService({
    required this.db,
    required this.tracks,
    required this.resolver,
    required this.covers,
    this.creditsEnricher,
    this.useCredits = _never,
    required this.lrclib,
    this.lyricsChain,
    required this.wikipedia,
    required this.language,
    RateLimiter? limiter,
  }) : _limiter = limiter ?? RateLimiter(),
       _writer = EnrichWriter(db, tracks);

  final AppDatabase db;
  final TrackRepository tracks;
  final MetadataResolver resolver;
  final CoverFetcher covers;

  /// The credits part, used only while [useCredits] (the user's «Credits and
  /// details» option, off by default) says so.
  final CreditsEnricher? creditsEnricher;
  final bool Function() useCredits;
  bool get _creditsOn => useCredits() && creditsEnricher != null;

  /// Writes `track_credits` and `track_enrich` only (see [CreditsEnricher.save]).
  Future<void> saveCredits(int trackId, CreditsPart? part) async =>
      creditsEnricher?.save(trackId, part);
  final LrclibClient lrclib;

  /// LRCLIB, NetEase, lyrics.ovh; LRCLIB alone when not given.
  final LyricsChain? lyricsChain;
  late final LyricsChain _chain = lyricsChain ?? LyricsChain(lrclib: lrclib);
  final WikipediaClient wikipedia;
  final String Function() language;
  final RateLimiter _limiter;
  final EnrichWriter _writer;

  /// The pause between online lookups, shared with the second opinion.
  RateLimiter get limiter => _limiter;

  /// Reads only: nothing is written until [apply]. A source that answered
  /// «too many requests» is not an error: the proposal says [EnrichmentProposal.limited].
  Future<EnrichmentProposal> propose(Track t, {CancelToken? cancel}) =>
      withTrackMemo(() => _propose(t, cancel));

  Future<EnrichmentProposal> _propose(Track t, CancelToken? cancel) async {
    final c = cleanSearchQuery(t.title, t.artist ?? '');
    var limited = false;
    // Independent services run in parallel; a slow one cannot block the others.
    Future<T?> guarded<T>(Future<T?> f) => f
        .timeout(const Duration(seconds: 25))
        .catchError((Object e, StackTrace st) {
      if (e is DioException) throw e;
      if (e is RateLimitedException) {
        limited = true;
        AppLog.w('enrichment source refused', e);
      } else {
        AppLog.w('enrichment source failed', e, st);
      }
      return null as T?;
    });
    final results = await Future.wait<Object?>([
      guarded(resolver.resolve(t, c, cancel, true)),
      guarded(_chain.find(t, cancel: cancel).then((r) {
        // A refusal is not «no text».
        if (r.lyrics == null && r.limited) limited = true;
        return r.lyrics;
      })),
      guarded(wikipedia.find(c.title, c.artist, language(), cancel: cancel)),
    ]);
    final m = results[0] as ResolvedMeta?;
    final lr = results[1] as LyricsResult?;
    final cu = results[2] as Curiosity?;
    if (m != null) AppLog.i('enrichment: track ${t.id} metadata from ${m.source}');
    // After the other parts: it reuses their Deezer hit and can never abort them.
    final cp = _creditsOn && await _creditsDue(t)
        ? await creditsEnricher!.fetch(t, m?.hit, cancel)
        : null;
    // The only place credits are saved, even if the preview is cancelled.
    await saveCredits(t.id, cp);
    return EnrichmentProposal(
        track: t,
        meta: m?.match,
        lyrics: lr,
        curiosity: cu,
        credits: cp,
        disc: m?.disc,
        isrc: m?.isrc,
        source: m?.source,
        limited: limited);
  }

  Future<bool> _creditsDue(Track t) async {
    final repo = creditsEnricher!.repo;
    return isDue(
      EnrichPart.credits,
      t,
      await repo.enrichOf(t.id),
      DateTime.fromMillisecondsSinceEpoch(nowMs()),
      hasCredits: (await repo.creditsOf(t.id)).isNotEmpty,
    );
  }

  /// Writes only [fields]; `userEdited` tracks keep title/artist/album.
  /// True when the proposal had something (not that a field changed).
  Future<bool> apply(EnrichmentProposal p, Set<EnrichField> fields,
          {CancelToken? cancel, bool replaceCover = false}) async =>
      (await _apply(p, fields, cancel: cancel, replaceCover: replaceCover))
          .found;

  /// [apply] that also says what happened: `wrote`: a field or the cover was
  /// written (status `found` written with it); `coverFailed`: the cover
  /// download failed, so the answer is incomplete.
  Future<({bool found, bool wrote, bool coverFailed})> _apply(
      EnrichmentProposal p, Set<EnrichField> fields,
      {CancelToken? cancel, bool replaceCover = false}) async {
    final t = await tracks.getById(p.track.id) ?? p.track;
    final f = {...fields};
    if (t.userEdited) {
      f.removeAll({EnrichField.title, EnrichField.artist, EnrichField.album});
    }
    final w = await _writer.writeFields(t, p, f);
    var found = w.found, wrote = w.wrote, coverFailed = false;
    if (w.wrote) await _writer.writeStatus(t.id, EnrichStatus.found);
    if (f.contains(EnrichField.cover) && p.coverUrl != null) {
      final r = await covers.apply(w.key, p.coverUrl!,
          replace: replaceCover, cancel: cancel);
      coverFailed = r == CoverResult.failed;
      if (r == CoverResult.saved) {
        found = true;
        if (!w.wrote) {
          wrote = true;
          await _writer.writeStatus(t.id, EnrichStatus.found);
        }
      }
    }
    return (found: found, wrote: wrote, coverFailed: coverFailed);
  }
}

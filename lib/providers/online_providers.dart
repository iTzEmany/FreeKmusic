import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../data/repositories/credits_repository.dart';
import '../data/settings/settings_store.dart' show AppSettings;
import '../services/online/acoustid_client.dart';
import '../services/online/cover_fetcher.dart';
import '../services/online/credits_enricher.dart';
import '../services/online/enrich_engine.dart';
import '../services/online/enrich_runner.dart';
import '../services/online/enrichment_service.dart';
import '../services/online/metadata_resolver.dart';
import '../services/online/http_client.dart';
import '../services/online/itunes_client.dart';
import '../services/online/lrclib_client.dart';
import '../services/online/lyrics_chain.dart';
import '../services/online/lyrics_ovh_client.dart';
import '../services/online/netease_lyrics_client.dart';
import '../services/online/curiosity_finder.dart';
import '../services/online/curiosity_service.dart';
import '../services/online/deezer_client.dart';
import '../services/online/deezer_gw_client.dart';
import '../services/online/discogs_client.dart';
import '../core/app_log.dart';
import '../services/online/musicbrainz_client.dart';
import '../services/online/request_budget.dart' show apiIdentified;
import '../services/online/youtube_service.dart' show YtException, YtErrorKind;
import '../services/online/quiet_enricher.dart';
import '../services/library/download_tagger.dart';
import '../services/library/track_corrections.dart';
import '../services/library/track_file_sync.dart';
import '../services/recognition/track_identity.dart' show Recognition;
import '../services/recognition/track_recognizer.dart';
import '../services/tags/fingerprinter.dart';
import '../services/tags/tag_writer.dart';
import '../services/online/wikipedia_client.dart';
import '../services/online/ytm_artist_resolver.dart';
import 'ytm_catalog_providers.dart';
import 'database_providers.dart';
import 'library_providers.dart';
import 'settings_providers.dart';
import 'player_providers.dart';
import 'tag_backup_providers.dart' show tagWritableProvider;
import 'youtube_providers.dart' show downloadIndexProvider, innerTubeClientProvider, resolveDownloadFolder;

final webClientProvider = Provider<WebClient>((ref) => DioWebClient());

final itunesClientProvider = Provider(
  (ref) => ItunesClient(
    ref.watch(webClientProvider),
    // The store follows the app language: its catalogue has the local music.
    country: () => switch (ref.read(settingsProvider).language) {
      'it' => 'IT',
      'de' => 'DE',
      'es' => 'ES',
      _ => 'US',
    },
  ),
);
final deezerClientProvider = Provider(
  (ref) => DeezerClient(ref.watch(webClientProvider)),
);
final acoustIdClientProvider = Provider((ref) {
  final c = AcoustIdClient();
  ref.onDispose(c.close);
  return c;
});
final fingerprinterProvider = Provider<Fingerprinter>((ref) => RustFingerprinter());
final trackRecognizerProvider = Provider(
  (ref) => TrackRecognizer(
    musicBrainz: ref.watch(musicBrainzClientProvider),
    innerTube: ref.watch(innerTubeClientProvider),
    acoustId: ref.watch(acoustIdClientProvider),
    fingerprinter: ref.watch(fingerprinterProvider),
    useAcoustId: () => ref.read(settingsProvider).acoustId,
    // Where the file came from: the download index (memory), then the CSV import row.
    videoIdFor: (t) async =>
        (await ref.read(downloadIndexProvider.future)).idForPath(t.path) ??
        await ref.read(importRepositoryProvider).videoIdOfTrack(t.id),
  ),
);
/// The recognition of an online item (`yt:`, stream) by video id (R-186): step 1b
/// and the cover, nothing written. Kept in memory for the session.
final onlineRecognitionProvider = FutureProvider.autoDispose.family<Recognition?, String>((ref, videoId) async {
  final link = ref.keepAlive();
  final rec = await ref.watch(trackRecognizerProvider).recognizeOnline(videoId);
  if (rec == null) link.close(); // «nothing» and a failed source are not kept: the next look asks again
  return rec;
});
final deezerGwClientProvider = Provider(
  // shortcut: a one-off Registro line needs a LogEntry kind (phase 53); AppLog until then.
  (ref) => DeezerGwClient(onPaused: () => AppLog.w('deezer_gw: paused for 24 hours after 3 errors')),
);
final lrclibClientProvider = Provider(
  (ref) => LrclibClient(ref.watch(webClientProvider)),
);
final neteaseLyricsClientProvider = Provider(
  (ref) => NeteaseLyricsClient(ref.watch(webClientProvider)),
);
final lyricsOvhClientProvider = Provider(
  (ref) => LyricsOvhClient(ref.watch(webClientProvider)),
);
final lyricsChainProvider = Provider(
  (ref) => LyricsChain(
    lrclib: ref.watch(lrclibClientProvider),
    netease: ref.watch(neteaseLyricsClientProvider),
    ovh: ref.watch(lyricsOvhClientProvider),
  ),
);
final wikipediaClientProvider = Provider(
  (ref) => WikipediaClient(ref.watch(webClientProvider)),
);
final musicBrainzClientProvider = Provider(
  (ref) => MusicBrainzClient(ref.watch(webClientProvider)),
);
final curiosityFinderProvider = Provider(
  (ref) => CuriosityFinder(
    wikipedia: ref.watch(wikipediaClientProvider),
    musicBrainz: ref.watch(musicBrainzClientProvider),
    wikidata: WikidataClient(ref.watch(webClientProvider)),
    discogs: DiscogsClient(ref.watch(webClientProvider)),
    ytmArtist: (name, cancel) => ytmQuiet(() async {
      final catalog = ref.read(ytmCatalogProvider);
      final hl = ref.read(ytmLanguageProvider);
      // Only a certain match: a wrong artist's story is worse than none.
      final pick = pickYtmArtist(name, await catalog.searchArtists(name, hl));
      if (pick is! ExactArtist) return null;
      final page = (await catalog.artist(pick.artist.id, hl)).value;
      final text = page.description;
      if (text == null) return null;
      return (text: text, source: Uri.parse('https://music.youtube.com/channel/${pick.artist.id}'), lang: hl);
    }),
  ),
);

/// A YouTube Music fallback must stay quiet: a rate limit is the one thing the
/// finder understands, everything else is just "nothing found".
Future<T?> ytmQuiet<T>(Future<T?> Function() body) async {
  try {
    return await body();
  } on YtException catch (e, st) {
    if (e.kind == YtErrorKind.rateLimited) throw const RateLimitedException(429);
    AppLog.w('YouTube Music artist fallback failed', e, st);
    return null;
  }
}

final creditsRepositoryProvider = Provider(
  (ref) => CreditsRepository(ref.watch(databaseProvider)),
);

final curiosityServiceProvider = Provider(
  (ref) => CuriosityService(
    finder: ref.watch(curiosityFinderProvider),
    tracks: ref.watch(trackRepositoryProvider),
    artistInfos: ref.watch(artistInfoRepositoryProvider),
  ),
);

/// One pause between online lookups for the whole enrichment.
final enrichLimiterProvider = Provider((ref) => RateLimiter());

final metadataResolverProvider = Provider(
  (ref) => MetadataResolver(
    itunes: ref.watch(itunesClientProvider),
    deezer: ref.watch(deezerClientProvider),
    useDeezer: () => ref.read(settingsProvider).deezerMeta,
  ),
);

final coverFetcherProvider = Provider(
  (ref) => CoverFetcher(
    covers: ref.watch(coverStoreProvider),
    web: ref.watch(webClientProvider),
    tracks: ref.watch(trackRepositoryProvider),
    itunes: ref.watch(itunesClientProvider),
    deezer: ref.watch(deezerClientProvider),
    useDeezer: () => ref.read(settingsProvider).deezerMeta,
    limiter: ref.watch(enrichLimiterProvider),
  ),
);

final creditsEnricherProvider = Provider(
  (ref) => CreditsEnricher(
    tracks: ref.watch(trackRepositoryProvider),
    repo: ref.watch(creditsRepositoryProvider),
    deezer: ref.watch(deezerClientProvider),
    gw: ref.watch(deezerGwClientProvider),
    musicBrainz: ref.watch(musicBrainzClientProvider),
    resolver: ref.watch(metadataResolverProvider),
  ),
);

final enrichmentServiceProvider = Provider<EnrichmentService>((ref) {
  return EnrichmentService(
    db: ref.watch(databaseProvider),
    tracks: ref.watch(trackRepositoryProvider),
    resolver: ref.watch(metadataResolverProvider),
    covers: ref.watch(coverFetcherProvider),
    creditsEnricher: ref.watch(creditsEnricherProvider),
    useCredits: () => ref.read(settingsProvider).creditsDetails,
    lrclib: ref.watch(lrclibClientProvider),
    lyricsChain: ref.watch(lyricsChainProvider),
    wikipedia: ref.watch(wikipediaClientProvider),
    language: () => ref.read(settingsProvider).language,
    limiter: ref.watch(enrichLimiterProvider),
  );
});

/// Puts a recognised title and artist in a track (automatically or accepted by the user).
final trackCorrectionsProvider = Provider<TrackCorrections>((ref) {
  return TrackCorrections(
    ref.watch(databaseProvider),
    ref.watch(trackEditorProvider),
    ref.watch(creditsRepositoryProvider),
    fileBlock: (path) => ref.read(tagWritableProvider(path).future),
  );
});

final enrichEngineProvider = Provider<EnrichEngine>((ref) {
  return EnrichEngine(
    db: ref.watch(databaseProvider),
    tracks: ref.watch(trackRepositoryProvider),
    resolver: ref.watch(metadataResolverProvider),
    covers: ref.watch(coverFetcherProvider),
    chain: ref.watch(lyricsChainProvider),
    credits: ref.watch(creditsEnricherProvider),
    curiosities: ref.watch(curiosityServiceProvider),
    language: () => ref.read(settingsProvider).language,
    useCredits: () => ref.read(settingsProvider).creditsDetails,
    recognizer: ref.watch(trackRecognizerProvider),
    onSure: (t, rec) => ref.read(trackCorrectionsProvider).apply(t, rec, byUser: false).then((_) {}),
    limiter: ref.watch(enrichLimiterProvider),
  );
});

/// What a manual enrichment job came to (or, while it runs, how far it is).
/// The one place the Registro line and the final message are made from.
class EnrichJobResult {
  const EnrichJobResult({
    this.done = 0,
    this.total = 0,
    this.updated = 0,
    this.notFound = 0,
    this.failed = false,
    this.cancelled = false,
    this.rateLimited = false,
    this.sources = const {},
  });

  final int done, total, updated, notFound;

  /// Tracks recognised, by `RecogSource.name`.
  final Map<String, int> sources;

  /// The job stopped on an error, or because no source answered.
  final bool failed;
  final bool cancelled, rateLimited;

  /// The job left before its work was done.
  bool get stopped => cancelled || rateLimited;

  /// The `detail` of the Registro line; `updated` and `notFound` are always counts (int).
  Map<String, Object?>? get logDetail {
    final base = failed
        ? {'updated': updated, 'notFound': notFound}
        : stopped
        ? const {'stopped': true}
        : null;
    return sources.isEmpty ? base : {...?base, 'sources': sources};
  }
}

class EnrichJobState {
  const EnrichJobState({this.running = false, this.progress, this.result});

  final bool running;
  final EnrichJobResult? progress;

  /// Last finished job (shown once by the shell as a snackbar).
  final EnrichJobResult? result;
}

/// The parts a manual enrichment asks for (D-278): everything allowed, the
/// credits only with «Credits and details». The automatic switches do not apply.
Set<EnrichPart> manualParts(AppSettings s) => {
  EnrichPart.meta,
  EnrichPart.lyrics,
  EnrichPart.synced,
  EnrichPart.curio,
  if (s.creditsDetails) EnrichPart.credits,
};

/// Seconds per track for the whole enrichment, identified vs anonymous.
const kEnrichSecondsIdentified = 7;
// 40 s: measured on the phone (phase 69b.4), Wikimedia anonymous tier.
const kEnrichSecondsAnonymous = 40;

/// Rough minutes for [tracks].
int enrichMinutes(int tracks) =>
    (tracks * (apiIdentified ? kEnrichSecondsIdentified : kEnrichSecondsAnonymous) / 60)
        .ceil();

/// Tracks with something due for a manual job, and how many are all (live).
final manualDueCountProvider = StreamProvider.autoDispose<int>((ref) {
  ref.watch(settingsProvider.select((s) => s.creditsDetails));
  return ref
      .watch(creditsRepositoryProvider)
      .watchEnrichCounts(
        manualParts(ref.read(settingsProvider)),
        DateTime.now(),
        mode: AskMode.retryNone,
      )
      .map((c) => c.total - c.complete);
});

enum EnrichStart { started, busy, nothing }

class EnrichJobNotifier extends Notifier<EnrichJobState> {
  EnrichRunner? _runner;

  @override
  EnrichJobState build() => const EnrichJobState();

  /// Asks the manual parts of [ids] again, «nothing» marks included. Returns
  /// false when another job is already running.
  bool start(List<int> ids, {void Function()? onFinished}) {
    if (state.running || ids.isEmpty) return false;
    state = EnrichJobState(running: true, progress: EnrichJobResult(total: ids.length));
    unawaited(_run(ids, onFinished));
    return true;
  }

  /// [start] on the tracks with a manual part due: the whole library, or only
  /// those [among] the given ids («Arricchisci album»).
  Future<EnrichStart> startDue({Iterable<int>? among}) async {
    if (state.running) return EnrichStart.busy;
    final ids = await ref
        .read(creditsRepositoryProvider)
        .dueTrackIds(
          manualParts(ref.read(settingsProvider)),
          DateTime.now(),
          limit: 0x7fffffff,
          mode: AskMode.retryNone,
          among: among,
        );
    if (ids.isEmpty) return EnrichStart.nothing;
    return start(ids) ? EnrichStart.started : EnrichStart.busy;
  }

  Future<void> _run(List<int> ids, void Function()? onFinished) async {
    EnrichRunner? runner;
    EnrichRound? round;
    var failed = false;
    try {
      runner = _runner = EnrichRunner(
        engine: ref.read(enrichEngineProvider),
        ids: FixedIds(ids),
        parts: () => manualParts(ref.read(settingsProvider)),
        waitIdle: () async {}, // a manual job never waits for the user
        mode: AskMode.retryNone,
        onProgress: (done, total) {
          if (ref.mounted) state = EnrichJobState(running: true, progress: EnrichJobResult(done: done, total: total));
        },
      );
      round = await runner.run();
      // Offline: nothing answered, even if fewer than the 5 tracks of a stop.
      failed = round.failed || (round.worked == 0 && round.endedSilent);
    } on Object catch (e, st) {
      if (e is Error) {
        AppLog.e('enrichment job stopped by an error', e, st);
      } else {
        AppLog.w('enrichment job stopped by an error', e, st);
      }
      failed = true;
    } finally {
      _runner = null;
      if (ref.mounted) {
        final cancelled = runner?.cancelled ?? false;
        final refused = round?.allRefused ?? false;
        state = EnrichJobState(
          result: EnrichJobResult(
            done: round?.processed ?? 0,
            total: ids.length,
            updated: round?.updatedTracks ?? 0,
            notFound: round?.notFoundTracks ?? 0,
            failed: failed,
            cancelled: cancelled,
            rateLimited: refused || ((round?.limited ?? false) && round!.worked == 0),
            sources: round?.sources ?? const {},
          ),
        );
        if (!failed && !cancelled) {
          try {
            onFinished?.call();
          } on Object catch (e, st) {
            if (e is Error) {
              AppLog.e('enrichment job: onFinished failed', e, st);
            } else {
              AppLog.w('enrichment job: onFinished failed', e, st);
            }
          }
        }
      }
    }
  }

  void cancel() => _runner?.cancel();

  void clearResult() => state = const EnrichJobState();
}

final enrichJobProvider = NotifierProvider<EnrichJobNotifier, EnrichJobState>(
  EnrichJobNotifier.new,
);

/// The parts the switches turn on for a song that has just arrived.
Set<EnrichPart> autoParts(AppSettings s) => {
  if (s.autoEnrich) EnrichPart.meta,
  if (s.autoLyrics) ...[EnrichPart.lyrics, EnrichPart.synced],
  if (s.autoCuriosities) EnrichPart.curio,
  if (s.creditsDetails) EnrichPart.credits,
};

/// Downloaded songs get every part that is on (tags, lyrics, curiosities,
/// credits) here, one at a time and without a line in the Activity centre
/// (the batch job is for the user's own «Arricchisci»).
final downloadEnricherProvider = Provider<QuietEnricher>((ref) {
  final enricher = QuietEnricher(
    onDone: (id) => ref.read(downloadTaggerProvider).tag(id),
    enabled: () => autoParts(ref.read(settingsProvider)).isNotEmpty,
    enrich: (id) async {
      final engine = ref.read(enrichEngineProvider);
      await engine.limiter.wait();
      await engine.completeOne(id, autoParts(ref.read(settingsProvider)));
    },
  );
  ref.onDispose(enricher.dispose);
  return enricher;
});

/// The downloaded songs waiting for, or in, that enrichment.
final enrichingTracksProvider = StreamProvider<Set<int>>((ref) async* {
  final enricher = ref.watch(downloadEnricherProvider);
  yield enricher.pending;
  yield* enricher.changes;
});

/// Writes the tags of files Codecore downloaded or received into them.
/// Call `tag(trackId)` once the row has its final tags (also after a receive).
final downloadTaggerProvider = Provider<DownloadTagger>((ref) {
  final db = ref.watch(databaseProvider);
  final tracks = ref.watch(trackRepositoryProvider);
  final covers = ref.watch(coverStoreProvider);
  final handler = ref.watch(audioHandlerProvider);
  final tagger = DownloadTagger(
    trackById: tracks.getById,
    sync: TrackFileSync(db, () => ref.read(safeTagWriterProvider.future)),
    reader: ref.watch(tagReaderProvider),
    downloadRoot: () async =>
        (await resolveDownloadFolder(ref.read(folderRepositoryProvider)))?.$1.path,
    enabled: () => ref.read(settingsProvider).writeTagsAfterDownload,
    coverOf: (t) async {
      final f = t.coverKey == null ? null : covers.fileFor(t.coverKey!);
      if (f == null) return null;
      final png = f.path.toLowerCase().endsWith('.png');
      return TagCover(await f.readAsBytes(), png ? 'image/png' : 'image/jpeg');
    },
    playingPath: () => handler.currentTrack?.path,
    playingChanges: handler.currentTrackStream.map((t) => t?.path),
  );
  ref.onDispose(tagger.dispose);
  return tagger;
});

/// A downloaded song is ready: enrich it (tags are written when that ends), or
/// write its tags now when enrichment is off.
void afterDownload(Ref ref, int trackId) {
  try {
    if (autoParts(ref.read(settingsProvider)).isNotEmpty) {
      ref.read(downloadEnricherProvider).add(trackId);
    } else {
      unawaited(ref.read(downloadTaggerProvider).tag(trackId));
    }
  } on Object catch (e, st) {
    if (e is Error) {
      AppLog.e('afterDownload failed for track $trackId', e, st);
    } else {
      AppLog.w('afterDownload failed for track $trackId', e, st);
    }
  }
}

/// A received song is ready: like a download, it is enriched when a part is
/// on (its `onDone` writes the tags), otherwise tags go now.
/// [read] is `ref.read` of a Ref or a WidgetRef.
void afterReceive(T Function<T>(ProviderListenable<T>) read, int trackId) {
  try {
    if (autoParts(read(settingsProvider)).isNotEmpty) {
      read(downloadEnricherProvider).add(trackId);
    } else {
      unawaited(read(downloadTaggerProvider).tag(trackId));
    }
  } on Object catch (e, st) {
    if (e is Error) {
      AppLog.e('afterReceive failed for track $trackId', e, st);
    } else {
      AppLog.w('afterReceive failed for track $trackId', e, st);
    }
  }
}

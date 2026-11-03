import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/data/repositories/artist_info_repository.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/online/credits.dart';
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/curiosity_service.dart';
import 'package:codecore/services/online/deezer_client.dart';
import 'package:codecore/services/online/deezer_gw_client.dart';
import 'package:codecore/services/online/cover_fetcher.dart';
import 'package:codecore/services/online/credits_enricher.dart';
import 'package:codecore/services/online/enrich_engine.dart';
import 'package:codecore/services/online/enrich_runner.dart';
import 'package:codecore/services/online/enrichment_service.dart';
import 'package:codecore/services/online/metadata_resolver.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/lyrics_chain.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show ApplyInterceptor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;

enum ItunesMode { match, empty, down, limited }

/// iTunes, Deezer and MusicBrainz from memory; counts what was asked.
class EnrichWeb implements WebClient {
  ItunesMode itunes = ItunesMode.match;
  bool deezerDown = false;
  bool deezerLimited = false;
  bool musicBrainzLimited = false;
  bool itunesGenre = true; // false: the iTunes hit has no genre
  bool coverDown = false; // network error
  bool coverMissing = false; // 404

  /// Runs on every JSON request (e.g. to cancel a token «on the network»).
  void Function(String url)? onUrl;
  final urls = <String>[];

  /// `url query` of every JSON request.
  final queries = <String>[];
  int bytes = 0;

  int count(String part) => urls.where((u) => u.contains(part)).length;

  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
    bool strict = false,
  }) async {
    urls.add(url);
    queries.add('$url ${query ?? {}}');
    onUrl?.call(url);
    if (musicBrainzLimited && url.contains('musicbrainz')) {
      throw const RateLimitedException(429);
    }
    if (deezerLimited && url.contains('deezer')) {
      throw const RateLimitedException(429);
    }
    if (deezerDown && url.contains('deezer')) return null;
    if (url.contains('itunes')) {
      if (itunes == ItunesMode.limited) throw const RateLimitedException(429);
      if (itunes == ItunesMode.down) {
        if (strict) throw WebUnavailableException(url, 503);
        return null;
      }
      if (itunes == ItunesMode.empty) return {'results': <Object>[]};
      return {
        'results': [
          {
            'trackName': 'Song',
            'artistName': 'Band',
            'collectionName': 'New Album',
            'releaseDate': '2019-01-01',
            if (itunesGenre) 'primaryGenreName': 'Rock',
            'trackNumber': 2,
            'artworkUrl100': 'https://x/100x100bb.jpg',
          },
        ],
      };
    }
    if (url.contains('/track/isrc:')) {
      return {
        'id': 1,
        'title': 'Song',
        'duration': 200,
        'isrc': 'ITABC2400001',
        'artist': {'name': 'Band'},
        'album': {'id': 7, 'title': 'Deezer Album'},
      };
    }
    if (url.endsWith('/track/1')) {
      return {
        'bpm': 120.0,
        'rank': 5,
        'explicit_lyrics': false,
        'album': {'id': 7},
      };
    }
    if (url.contains('deezer') && url.contains('/album/')) {
      return {
        'id': 7,
        'title': 'Deezer Album',
        'label': 'Big Label',
        'fans': 9,
        'record_type': 'album',
        'release_date': '2020-05-01',
      };
    }
    if (url.contains('musicbrainz.org/ws/2/isrc/')) {
      return {
        'recordings': [
          {
            'id': 'mbid-1',
            'title': 'Song',
            'length': 200000,
            'artist-credit': [
              {
                'artist': {'id': 'a1', 'name': 'Band'},
              },
            ],
          },
        ],
      };
    }
    if (url.contains('musicbrainz.org/ws/2/recording/')) {
      return {
        'id': 'mbid-1',
        'relations': [
          {
            'target-type': 'artist',
            'type': 'producer',
            'attributes': <String>[],
            'artist': {'id': 'a2', 'name': 'Pro Ducer'},
          },
        ],
      };
    }
    return null;
  }

  @override
  Future<List<int>?> getBytes(
    String url, {
    int maxBytes = 0,
    CancelToken? cancel,
  }) async {
    bytes++;
    if (coverDown) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: url),
        reason: 'down',
      );
    }
    return coverMissing ? null : [1, 2, 3];
  }
}

class FakeGw extends DeezerGwClient {
  @override
  Future<void> load() async {}

  @override
  bool get isPaused => false;

  @override
  Future<DeezerContributors> pageTrack(int sngId) async =>
      DeezerContributors([TrackCredit('Wri Ter', 'composer', 'deezer')]);
}

/// The lyrics chain: counts the searches and gives [result] (or [failed]).
class FakeChain extends LyricsChain {
  FakeChain(WebClient web) : super(lrclib: LrclibClient(web));

  int calls = 0;

  /// The title and artist of every search.
  final askedWith = <String>[];
  LyricsResult? result = const LyricsResult(
    plain: 'la la',
    synced: '[00:01.00]la la',
  );
  bool failed = false;
  bool limited = false;
  bool resting = false; // «limited» because LRCLIB rests, not because of a quota
  bool syncedFailed = false;
  bool? wantSyncedSeen;

  /// The answer for one track, instead of [result].
  LyricsResult? Function(Track t)? resultFor;

  /// Runs while the search is «on the network», before it answers.
  Future<void> Function()? during;

  /// While set, the search never answers by itself; only a cancel ends it.
  Completer<void>? hold;

  @override
  bool get isResting => resting;

  @override
  Future<LyricsChainResult> find(
    Track t, {
    bool wantSynced = true,
    CancelToken? cancel,
  }) async {
    calls++;
    askedWith.add('${t.title}|${t.artist}');
    wantSyncedSeen = wantSynced;
    await during?.call();
    final h = hold;
    if (h != null) {
      await Future.any([
        h.future,
        if (cancel != null)
          cancel.whenCancel.then<void>((_) => throw DioException.requestCancelled(requestOptions: RequestOptions(), reason: 'cancel')),
      ]);
    }
    if (limited) {
      return const LyricsChainResult(
        failed: true,
        syncedFailed: true,
        limited: true,
      );
    }
    return failed
        ? const LyricsChainResult(failed: true, syncedFailed: true)
        : LyricsChainResult(
            lyrics: resultFor == null ? result : resultFor!(t),
            syncedFailed: syncedFailed,
            source: 'fake',
          );
  }
}

class FakeFinder implements CuriosityFinder {
  int calls = 0;

  /// `title|artist|isrc|durationMs` of every search.
  final askedFor = <String>[];

  /// Thrown by every search, when set (offline).
  Object? error;
  CuriosityPair pair = CuriosityPair(
    song: Curiosity(
      'A story',
      Uri.parse('https://it.wikipedia.org/wiki/X'),
      'it',
    ),
    artist: Curiosity(
      'A bio',
      Uri.parse('https://it.wikipedia.org/wiki/Y'),
      'it',
    ),
  );

  @override
  Future<CuriosityPair> find(
    String title,
    String artist,
    String lang, {
    String? isrc,
    int durationMs = 0,
    cancel,
  }) async {
    calls++;
    askedFor.add('$title|$artist|$isrc|$durationMs');
    if (error != null) throw error!;
    return pair;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// The service and the engine over the same resolver, covers and credits,
/// built from the raw sources like the providers do.
({EnrichmentService svc, EnrichEngine engine, CoverFetcher fetcher}) enrichStack({
  required AppDatabase db,
  required TrackRepository tracks,
  required CoverStore covers,
  required ItunesClient itunes,
  DeezerClient? deezer,
  bool Function()? useDeezer,
  DeezerGwClient? gw,
  MusicBrainzClient? musicBrainz,
  CreditsRepository? creditsRepo,
  bool Function()? useCredits,
  required LrclibClient lrclib,
  LyricsChain? lyricsChain,
  CuriosityService? curiosities,
  required WikipediaClient wikipedia,
  required WebClient web,
  required String Function() language,
  required RateLimiter limiter,
  TrackRecognizer? recognizer,
  Future<void> Function(Track, Recognition)? onSure,
}) {
  final resolver = MetadataResolver(
    itunes: itunes,
    deezer: deezer,
    useDeezer: useDeezer ?? () => false,
  );
  final fetcher = CoverFetcher(
    covers: covers,
    web: web,
    tracks: tracks,
    itunes: itunes,
    deezer: deezer,
    useDeezer: useDeezer ?? () => false,
    limiter: limiter,
  );
  final credits = creditsRepo == null
      ? null
      : CreditsEnricher(
          tracks: tracks,
          repo: creditsRepo,
          deezer: deezer,
          gw: gw,
          musicBrainz: musicBrainz,
          resolver: resolver,
        );
  final chain = lyricsChain ?? LyricsChain(lrclib: lrclib);
  return (
    svc: EnrichmentService(
      db: db,
      tracks: tracks,
      resolver: resolver,
      covers: fetcher,
      creditsEnricher: credits,
      useCredits: useCredits ?? () => false,
      lrclib: lrclib,
      lyricsChain: chain,
      wikipedia: wikipedia,
      language: language,
      limiter: limiter,
    ),
    engine: EnrichEngine(
      db: db,
      tracks: tracks,
      resolver: resolver,
      covers: fetcher,
      chain: chain,
      credits: credits,
      curiosities: curiosities,
      language: language,
      useCredits: useCredits ?? () => false,
      recognizer: recognizer,
      onSure: onSure,
      limiter: limiter,
    ),
    fetcher: fetcher,
  );
}

/// An [EnrichmentService] over an in-memory DB with every source faked.
class EnrichRig {
  EnrichRig._(this.tmp);

  /// [interceptor] sees every query of the database (e.g. to count reads).
  factory EnrichRig({
    QueryInterceptor? interceptor,
    TrackRecognizer? recognizer,
    Future<void> Function(Track, Recognition)? onSure,
  }) {
    final r = EnrichRig._(Directory.systemTemp.createTempSync('enrich_rig'));
    final executor = NativeDatabase.memory();
    r.db = AppDatabase(
      interceptor == null ? executor : executor.interceptWith(interceptor),
    );
    r.repo = TrackRepository(r.db);
    r.credits = CreditsRepository(r.db);
    r.web = EnrichWeb();
    r.chain = FakeChain(r.web);
    r.finder = FakeFinder();
    final stack = enrichStack(
      db: r.db,
      tracks: r.repo,
      covers: CoverStore(Directory(p.join(r.tmp.path, 'c'))),
      itunes: ItunesClient(r.web),
      gw: FakeGw(),
      musicBrainz: MusicBrainzClient(r.web, pause: (_) async {}),
      deezer: DeezerClient(r.web),
      creditsRepo: r.credits,
      useDeezer: () => r.deezerMeta,
      useCredits: () => true,
      lrclib: LrclibClient(r.web),
      lyricsChain: r.chain,
      curiosities: CuriosityService(
        finder: r.finder,
        tracks: r.repo,
        artistInfos: ArtistInfoRepository(r.db),
      ),
      wikipedia: WikipediaClient(r.web),
      web: r.web,
      language: () => 'it',
      limiter: RateLimiter(minGap: Duration.zero),
      recognizer: recognizer,
      onSure: onSure,
    );
    r.svc = stack.svc;
    r.engine = stack.engine;
    return r;
  }

  final Directory tmp;
  bool deezerMeta = false;
  late final AppDatabase db;
  late final TrackRepository repo;
  late final CreditsRepository credits;
  late final EnrichWeb web;
  late final FakeChain chain;
  late final FakeFinder finder;
  late final EnrichmentService svc;
  late final EnrichEngine engine;

  /// A manual job: the runner over a fixed list, every part «nothing» marks included.
  Future<EnrichRound> runManual(
    List<int> ids, {
    Set<EnrichPart> parts = const {EnrichPart.meta},
    void Function(int done, int total)? onProgress,
  }) => EnrichRunner(
    engine: engine,
    ids: FixedIds(ids),
    parts: () => parts,
    waitIdle: () async {},
    mode: AskMode.retryNone,
    onProgress: onProgress,
  ).run();

  Future<void> dispose() async {
    await db.close();
    // Windows locks open files: an in-flight cover write can outlive the container.
    for (var i = 0;; i++) {
      try {
        tmp.deleteSync(recursive: true);
        break;
      } on FileSystemException {
        if (i >= 9) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  Future<int> add({
    String title = 'Song',
    String artist = 'Band',
    String? isrc = 'ITABC2400001',
    String? album,
    String? genre,
    int? year,
    int? trackNumber,
    String? plain,
    String? synced,
    bool userEdited = false,
    int coverSource = 0,
    String? curiosities,
    String path = '/a.mp3',
    int kind = 0,
    bool missing = false,
    bool ignored = false,
    bool hasCover = false,
  }) async {
    final id = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: path,
            title: title,
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            durationMs: const Value(200000),
            artist: Value(artist),
            isrc: Value(isrc),
            album: Value(album),
            genre: Value(genre),
            year: Value(year),
            trackNumber: Value(trackNumber),
            lyricsPlain: Value(plain),
            lyricsSynced: Value(synced),
            curiosities: Value(curiosities),
            userEdited: Value(userEdited),
            coverSource: Value(coverSource),
            kind: Value(kind),
            missing: Value(missing),
            ignored: Value(ignored),
            hasCover: Value(hasCover),
          ),
        );
    return id;
  }

  Future<TrackEnrichData?> enrichOf(int id) => credits.enrichOf(id);
}

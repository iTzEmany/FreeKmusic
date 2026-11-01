import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_info_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/curiosity_service.dart';
import 'package:codecore/services/online/deezer_client.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/online/enrichment_service.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/enrich_fakes.dart';
import '../recognition/support.dart';

/// Records what the curiosity step asks the finder.
class _SpyFinder extends FakeFinder {
  final asked = <String>[];

  @override
  Future<CuriosityPair> find(
    String title,
    String artist,
    String lang, {
    String? isrc,
    int durationMs = 0,
    cancel,
  }) {
    asked.add('$title|$artist|$lang|$isrc|$durationMs');
    return super.find(title, artist, lang, isrc: isrc, durationMs: durationMs);
  }
}

/// Records the query of every JSON request.
class _SpyWeb extends EnrichWeb {
  final asked = <String>[];

  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
    bool strict = false,
  }) {
    asked.add('$url ${query ?? {}}');
    return super.getJson(url, query: query, cancel: cancel, strict: strict);
  }
}

/// Characterization (69d.1): what today's engine asks and writes for six
/// typical tracks without identity. Values are what the code produces today.
/// Request order is not fixed (metadata and lyrics run side by side).
void main() {
  late EnrichRig r;
  late _SpyFinder finder;
  late _SpyWeb web;
  late Directory tmp;

  setUp(() {
    r = EnrichRig();
    finder = _SpyFinder();
    web = _SpyWeb();
    tmp = Directory.systemTemp.createTempSync('recog_char');
  });
  tearDown(() async {
    await r.dispose();
    tmp.deleteSync(recursive: true);
  });

  // Real lyrics chain and curiosity service over the spy web/finder.
  Future<Track> run(
    String title,
    String? artist, {
    required bool deezer,
    TrackRecognizer? recognizer,
    Set<EnrichPart> parts = const {EnrichPart.meta, EnrichPart.lyrics, EnrichPart.curio},
  }) async {
    final stack = enrichStack(
      db: r.db,
      tracks: r.repo,
      covers: CoverStore(Directory(p.join(tmp.path, 'c'))),
      itunes: ItunesClient(web),
      deezer: DeezerClient(web),
      useDeezer: () => deezer,
      lrclib: LrclibClient(web),
      curiosities: CuriosityService(
        finder: finder,
        tracks: r.repo,
        artistInfos: ArtistInfoRepository(r.db),
      ),
      wikipedia: WikipediaClient(web),
      web: web,
      language: () => 'it',
      limiter: RateLimiter(minGap: Duration.zero),
      recognizer: recognizer,
    );
    final id = await r.db.into(r.db.tracks).insert(
      TracksCompanion.insert(
        path: '/a.mp3',
        title: title,
        albumKey: 'k',
        format: 'mp3',
        sizeBytes: 1,
        mtimeMs: 1,
        addedAt: 1,
        durationMs: const Value(200000),
        artist: Value(artist),
      ),
    );
    await stack.engine.completeOne(id, parts);
    return (await r.repo.getById(id))!;
  }

  const it = 'https://itunes.apple.com/search';
  const dz = 'https://api.deezer.com/search';
  const get = 'https://lrclib.net/api/get';
  const search = 'https://lrclib.net/api/search';
  String itq(String term) => '$it {term: $term, media: music, entity: song, limit: 8}';
  String dzq(String q) => '$dz {q: $q, limit: 10}';
  String lrGet(String a, String t) => '$get {artist_name: $a, track_name: $t, duration: 200}';
  String lrSearch(String a, String t) => '$search {track_name: $t, artist_name: $a}';

  // title, artist, iTunes asks, Deezer asks, LRCLIB asks, finder ask (title|artist)
  final cases = <(String, String, String?, List<String>, List<String>, List<String>, String)>[
    (
      'clean tags',
      'Believer',
      'Imagine Dragons',
      [itq('Imagine Dragons Believer'), itq('Believer')],
      [dzq('Imagine Dragons Believer')],
      [lrGet('Imagine Dragons', 'Believer'), lrSearch('Imagine Dragons', 'Believer')],
      'Believer|Imagine Dragons',
    ),
    (
      'channel as artist',
      'Believer',
      '7clouds Rock',
      [itq('7clouds Rock Believer'), itq('Believer')],
      [dzq('7clouds Rock Believer')],
      [lrGet('7clouds Rock', 'Believer'), lrSearch('7clouds Rock', 'Believer')],
      'Believer|7clouds Rock',
    ),
    (
      'Artist - Title under a channel',
      'Imagine Dragons - Believer',
      'Trap City',
      [
        itq('Imagine Dragons Believer'),
        itq('Believer'),
        itq('Trap City Imagine Dragons - Believer'), // raw fallback, iTunes only
        itq('Imagine Dragons - Believer'),
      ],
      [dzq('Imagine Dragons Believer')],
      [lrGet('Imagine Dragons', 'Believer'), lrSearch('Imagine Dragons', 'Believer')],
      'Believer|Imagine Dragons',
    ),
    (
      'OST',
      'He\'s a Pirate (From "Pirates of the Caribbean")',
      'Klaus Badelt',
      [
        itq('Klaus Badelt He\'s a Pirate (From Pirates of the Caribbean)'),
        itq('He\'s a Pirate (From Pirates of the Caribbean)'),
      ],
      [dzq('Klaus Badelt He\'s a Pirate (From Pirates of the Caribbean)')],
      [
        lrGet('Klaus Badelt', 'He\'s a Pirate (From Pirates of the Caribbean)'),
        lrSearch('Klaus Badelt', 'He\'s a Pirate (From Pirates of the Caribbean)'),
      ],
      'He\'s a Pirate (From Pirates of the Caribbean)|Klaus Badelt',
    ),
    (
      'cover',
      'Believer (Romy Wave Cover)',
      '7clouds Rock',
      [itq('7clouds Rock Believer (Romy Wave Cover)'), itq('Believer (Romy Wave Cover)')],
      [dzq('7clouds Rock Believer (Romy Wave Cover)')],
      [
        lrGet('7clouds Rock', 'Believer (Romy Wave Cover)'),
        lrSearch('7clouds Rock', 'Believer (Romy Wave Cover)'),
      ],
      'Believer (Romy Wave Cover)|7clouds Rock',
    ),
    (
      'no artist',
      'Believer',
      null,
      [itq('Believer')],
      [dzq('Believer')],
      [], // LRCLIB is not asked without an artist
      'Believer|',
    ),
  ];

  // A recognizer whose sources all answer «nothing» must change none of it (invariant 2).
  for (final (name, title, artist, itunes, deezer, lrclib, ask) in cases) {
    for (final useDeezer in [false, true]) {
      for (final recognized in [false, true]) {
      test('$name (${useDeezer ? 'Deezer' : 'iTunes'}${recognized ? ', recognizer: nothing' : ''})', () async {
        final t = await run(title, artist, deezer: useDeezer, recognizer: recognized ? Rig().recognizer : null);
        expect(web.asked, unorderedEquals([...(useDeezer ? deezer : itunes), ...lrclib]));
        expect(finder.asked, ['$ask|it|null|200000']);
        // The fake hits do not match: nothing but the curiosity is written.
        expect([t.title, t.artist], [title, artist]);
        expect([t.album, t.genre, t.year, t.trackNumber, t.lyricsPlain, t.lyricsSynced], everyElement(isNull));
        expect(t.curiosities, startsWith('A story'));
        final e = (await r.enrichOf(t.id))!;
        // «Nothing found» is marked for lyrics (and meta on iTunes; the fake answers
        // no Deezer search at all, which counts as a failure, not as «none»).
        expect([e.deezerId, e.mbid], [null, null]);
        expect([e.metaNoneAt != null, e.lyricsNoneAt != null, e.curioNoneAt != null], [!useDeezer, true, false]);
      });
      }
    }
    // Meta not due: reliable tags still cost no iTunes/Deezer search.
    test('$name: lyrics and curiosity only, with a recognizer', () async {
      await run(title, artist, deezer: false, recognizer: Rig().recognizer, parts: {EnrichPart.lyrics, EnrichPart.curio});
      expect(web.asked, unorderedEquals(lrclib));
    });
  }
}

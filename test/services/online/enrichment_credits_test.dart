import 'dart:convert';
import 'dart:io';

import 'package:codecore/core/clock.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/online/credits.dart';
import 'package:codecore/services/online/deezer_client.dart';
import 'package:codecore/services/online/deezer_gw_client.dart';
import 'package:codecore/services/online/enrich_engine.dart';
import 'package:codecore/services/online/enrich_gather.dart' show withTrackMemo;
import 'package:codecore/services/online/enrichment_service.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../support/enrich_fakes.dart';

/// Deezer (public API) and MusicBrainz from memory; iTunes and the rest know nothing.
class _Web implements WebClient {
  final urls = <String>[];
  bool mbDown = false, mbIsrcDown = false;
  List<Map<String, Object?>> mbRecordings = [
    {
      'id': 'mbid-1',
      'title': 'Song',
      'length': 200000,
      'artist-credit': [
        {
          'artist': {'id': 'a1', 'name': 'Band'}
        }
      ],
    }
  ];

  @override
  Future<Object?> getJson(String url,
      {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    urls.add(url);
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
      return {'bpm': 120.0, 'rank': 5, 'explicit_lyrics': false, 'album': {'id': 7}};
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
      if (mbIsrcDown && strict) throw WebUnavailableException(url, 503);
      return mbIsrcDown ? null : {'recordings': mbRecordings};
    }
    if (url.contains('musicbrainz.org/ws/2/recording/')) {
      if (mbDown) {
        if (strict) throw WebUnavailableException(url, 503);
        return null;
      }
      return {
        'id': 'mbid-1',
        'relations': [
          {
            'target-type': 'artist',
            'type': 'producer',
            'attributes': <String>[],
            'artist': {'id': 'a2', 'name': 'Pro Ducer'},
          }
        ],
      };
    }
    return null;
  }

  @override
  Future<List<int>?> getBytes(String url,
          {int maxBytes = 0, CancelToken? cancel}) async =>
      null;

  int count(String part) => urls.where((u) => u.contains(part)).length;
}

class _Gw extends DeezerGwClient {
  int calls = 0;
  bool paused = false;
  Object? error;
  Future<void> Function()? onCall;
  DeezerContributors result = DeezerContributors(
    [TrackCredit('Wri Ter', 'composer', 'deezer')],
    copyright: '(c) Big Label',
    physicalReleaseDate: '2020-04-01',
  );

  @override
  Future<void> load() async {}

  @override
  bool get isPaused => paused;

  @override
  Future<DeezerContributors> pageTrack(int sngId) async {
    calls++;
    await onCall?.call();
    if (error != null) throw error!;
    return result;
  }
}

Map<EnrichPart, PartOutcome> _only(PartOutcome o) => {EnrichPart.credits: o};

class _Rest extends DeezerClient {
  _Rest(super.web);
  @override
  bool get isResting => true;
}

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late CreditsRepository creditsRepo;
  late Directory tmp;
  late _Web web;
  late _Gw gw;
  late EnrichmentService svc;
  late EnrichEngine engine;
  var creditsOn = true, deezerMeta = false;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('enrcr');
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    creditsRepo = CreditsRepository(db);
    web = _Web();
    gw = _Gw();
    creditsOn = true;
    deezerMeta = false;
    final svcStack = enrichStack(
      db: db,
      tracks: repo,
      covers: CoverStore(Directory(p.join(tmp.path, 'c'))),
      itunes: ItunesClient(web),
      deezer: DeezerClient(web),
      useDeezer: () => deezerMeta,
      gw: gw,
      musicBrainz: MusicBrainzClient(web, pause: (_) async {}),
      creditsRepo: creditsRepo,
      useCredits: () => creditsOn,
      lrclib: LrclibClient(web),
      wikipedia: WikipediaClient(web),
      web: web,
      language: () => 'it',
      limiter: RateLimiter(minGap: Duration.zero),
    );
    svc = svcStack.svc;
    engine = svcStack.engine;
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<int> add({String? isrc = 'ITABC2400001'}) async {
    await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/a.mp3',
          title: 'Song',
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          durationMs: const Value(200000),
          artist: const Value('Band'),
          isrc: Value(isrc),
        ));
    return (await db.select(db.tracks).getSingle()).id;
  }

  Future<Map<EnrichPart, PartOutcome>> run(int id) =>
      engine.completeOne(id, {EnrichPart.meta, EnrichPart.credits});

  test('option off: neither credit client is called, Deezer is asked as before',
      () async {
    creditsOn = false;
    deezerMeta = true;
    final id = await add();
    await run(id);
    expect(gw.calls, 0);
    expect(web.count('musicbrainz'), 0);
    expect(web.count('/track/1'), 0);
    final e = await creditsRepo.enrichOf(id); // a row may exist for the marks
    expect([e?.details, e?.deezerId, e?.mbid, e?.creditsNoneAt], [null, null, null, null]);
    expect(await engine.completeOne(id, {EnrichPart.credits}), _only(PartOutcome.skipped));
    expect(gw.calls, 0);
  });

  test('Deezer metadata off, credits on: id and details saved, track untouched',
      () async {
    final id = await add();
    await run(id);
    final t = (await repo.getById(id))!;
    expect([t.title, t.year, t.genre, t.album], ['Song', null, null, null]);
    expect(t.enrichStatus, 2); // nothing proposed: as today
    final e = (await creditsRepo.enrichOf(id))!;
    expect(e.deezerId, 1);
    expect(e.mbid, 'mbid-1');
    expect(e.creditsNoneAt, isNull);
    final d = jsonDecode(e.details!) as Map;
    expect(d['bpm'], 120.0);
    expect(d['label'], 'Big Label');
    expect(d['copyright'], '(c) Big Label');
    expect(d['physicalReleaseDate'], '2020-04-01');
    final credits = await creditsRepo.creditsOf(id);
    expect({for (final c in credits) '${c.name}/${c.role}/${c.source}'},
        {'Wri Ter/composer/deezer', 'Pro Ducer/producer/musicbrainz'});
  });

  test('propose then apply, as the preview does, saves the credits', () async {
    final id = await add();
    final prop = await svc.propose((await repo.getById(id))!);
    expect(prop.credits!.credits, hasLength(2));
    await svc.apply(prop, {EnrichField.year});
    expect(await creditsRepo.creditsOf(id), hasLength(2));
    creditsOn = false;
    expect((await svc.propose((await repo.getById(id))!)).credits, isNull);
  });

  test('internal Deezer API paused: only MusicBrainz credits, no none mark',
      () async {
    gw.paused = true;
    final id = await add();
    await run(id);
    expect(gw.calls, 0);
    expect([for (final c in await creditsRepo.creditsOf(id)) c.source],
        ['musicbrainz']);
    expect((await creditsRepo.enrichOf(id))!.creditsNoneAt, isNull);
  });

  test('MusicBrainz down and nothing else: no «searched, nothing» mark',
      () async {
    web.mbDown = true;
    gw.result = const DeezerContributors([]);
    final id = await add();
    await run(id);
    final e = (await creditsRepo.enrichOf(id))!;
    expect(e.creditsNoneAt, isNull);
    expect(e.deezerId, 1);
    expect(await creditsRepo.creditsOf(id), isEmpty);
  });

  test('a rate limit on the internal API does not stop the batch or MusicBrainz',
      () async {
    gw.error = const RateLimitedException(429);
    final id = await add();
    final out = await run(id);
    expect(out[EnrichPart.credits], PartOutcome.found, reason: 'MusicBrainz still answered');
    expect([for (final c in await creditsRepo.creditsOf(id)) c.source],
        ['musicbrainz']);
    expect((await creditsRepo.enrichOf(id))!.creditsNoneAt, isNull);
  });

  test('every source answered and empty: marked as searched', () async {
    gw.result = const DeezerContributors([]);
    web.mbRecordings = [];
    final id = await add();
    await run(id);
    expect((await creditsRepo.enrichOf(id))!.creditsNoneAt, isNotNull);
    expect(await creditsRepo.creditsOf(id), isEmpty);
  });

  test('completeOne asks again when the none mark is older than 30 days', () async {
    final id = await add();
    await creditsRepo.saveEnrich(
        TrackEnrichCompanion(trackId: Value(id), creditsNoneAt: const Value(5)));
    final out = await engine.completeOne(id, {EnrichPart.credits});
    expect(out, isNot(_only(PartOutcome.skipped)));
    expect(gw.calls, 1);
  });

  test('completeOne skips a track that has credits or a none mark, force asks again',
      () async {
    final id = await add();
    expect(await engine.completeOne(id, {EnrichPart.credits}), _only(PartOutcome.found));
    final calls = gw.calls;
    expect(calls, 1);
    expect(await engine.completeOne(id, {EnrichPart.credits}), _only(PartOutcome.skipped));
    expect(gw.calls, calls);
    expect(await engine.completeOne(id, {EnrichPart.credits}, force: true), _only(PartOutcome.found));
    expect(gw.calls, calls + 1);

    await creditsRepo.save(
        id, const [], TrackEnrichCompanion(trackId: Value(id), creditsNoneAt: Value(nowMs())));
    expect(await engine.completeOne(id, {EnrichPart.credits}), _only(PartOutcome.skipped));
    expect(gw.calls, calls + 1);
  });

  test('a forced refresh with a source down keeps the credits already stored',
      () async {
    final id = await add();
    await engine.completeOne(id, {EnrichPart.credits});
    gw.paused = true;
    await engine.completeOne(id, {EnrichPart.credits}, force: true);
    expect(await creditsRepo.creditsOf(id), hasLength(2));
  });

  test('MusicBrainz ISRC lookup without an answer and Deezer empty: no none mark',
      () async {
    web.mbIsrcDown = true;
    gw.result = const DeezerContributors([]);
    final id = await add();
    await run(id);
    expect((await creditsRepo.enrichOf(id))!.creditsNoneAt, isNull);
  });

  test('MusicBrainz resting (503): the credits come out limited, not failed (D-683)',
      () async {
    web.mbIsrcDown = true;
    gw.result = const DeezerContributors([]);
    final id = await add();
    expect((await run(id))[EnrichPart.credits], PartOutcome.limited);
  });

  test('one track, one ISRC lookup for every part that wants it (136.4)', () async {
    final id = await add();
    final t = (await repo.getById(id))!;
    await withTrackMemo(() async {
      await svc.creditsEnricher!.fetch(t, null, null);
      await svc.creditsEnricher!.fetch(t, null, null);
    });
    expect(web.count('musicbrainz.org/ws/2/isrc/'), 1);
  });

  test('the track deleted during the lookup: nothing is saved, nothing throws',
      () async {
    final id = await add();
    gw.onCall = () async => (db.delete(db.tracks)..where((r) => r.id.equals(id))).go();
    await run(id);
    expect(await creditsRepo.enrichOf(id), isNull);
    expect(await creditsRepo.creditsOf(id), isEmpty);
  });

  test('a complete empty forced run clears the stored credits with the none mark',
      () async {
    final id = await add();
    await engine.completeOne(id, {EnrichPart.credits});
    expect(await creditsRepo.creditsOf(id), isNotEmpty);
    gw.result = const DeezerContributors([]);
    web.mbRecordings = [];
    await engine.completeOne(id, {EnrichPart.credits}, force: true);
    expect(await creditsRepo.creditsOf(id), isEmpty);
    expect((await creditsRepo.enrichOf(id))!.creditsNoneAt, isNotNull);
  });

  test('a failed source only carries over its own stored credits', () async {
    final id = await add();
    await engine.completeOne(id, {EnrichPart.credits});
    gw.paused = true; // Deezer down; MusicBrainz now answers with other credits
    web.mbDown = false;
    await engine.completeOne(id, {EnrichPart.credits}, force: true);
    final c = {for (final c in await creditsRepo.creditsOf(id)) '${c.source}/${c.name}'};
    expect(c, {'deezer/Wri Ter', 'musicbrainz/Pro Ducer'});
  });

  test('propose does not ask again when the track already has credits', () async {
    final id = await add();
    await engine.completeOne(id, {EnrichPart.credits});
    final calls = gw.calls;
    final prop = await svc.propose((await repo.getById(id))!);
    expect(prop.credits, isNull);
    expect(gw.calls, calls);
  });

  test('forced refresh with both sources down keeps stored credits and no mark', () async {
    final id = await add();
    await engine.completeOne(id, {EnrichPart.credits});
    gw.paused = true;
    web.mbDown = true;
    await engine.completeOne(id, {EnrichPart.credits}, force: true);
    expect(await creditsRepo.creditsOf(id), hasLength(2));
    expect((await creditsRepo.enrichOf(id))!.creditsNoneAt, isNull);
  });

  test('found credits clear an old none mark', () async {
    final id = await add();
    await creditsRepo.save(id, const [],
        TrackEnrichCompanion(trackId: Value(id), creditsNoneAt: Value(nowMs())));
    expect(await engine.completeOne(id, {EnrichPart.credits}, force: true), _only(PartOutcome.found));
    expect((await creditsRepo.enrichOf(id))!.creditsNoneAt, isNull);
  });

  test('Deezer public API resting, MB empty and valid: no none mark', () async {
    web.mbRecordings = [];
    final id = await add();
    final s2Stack = enrichStack(
      db: db, tracks: repo, covers: CoverStore(Directory(p.join(tmp.path, 'c'))),
      itunes: ItunesClient(web), deezer: _Rest(web), useDeezer: () => false,
      gw: gw, musicBrainz: MusicBrainzClient(web, pause: (_) async {}),
      creditsRepo: creditsRepo, useCredits: () => true,
      lrclib: LrclibClient(web), wikipedia: WikipediaClient(web), web: web,
      language: () => 'it', limiter: RateLimiter(minGap: Duration.zero));
    final s2 = s2Stack.engine;
    await s2.completeOne(id, {EnrichPart.credits});
    expect((await creditsRepo.enrichOf(id))?.creditsNoneAt, isNull);
  });

  test('outcome per part: none for a complete empty answer, failed for a silent source',
      () async {
    gw.result = const DeezerContributors([]);
    web.mbRecordings = [];
    final id = await add();
    expect(await engine.completeOne(id, {EnrichPart.credits}), _only(PartOutcome.none));
    gw.paused = true;
    expect(await engine.completeOne(id, {EnrichPart.credits}, force: true),
        _only(PartOutcome.failed));
  });

  test('propose with credits on saves the track credits without apply', () async {
    final id = await add();
    final prop = await svc.propose((await repo.getById(id))!);
    expect(prop.credits!.credits, isNotEmpty);
    final saved = await creditsRepo.creditsOf(id);
    expect(saved, hasLength(2));
    await svc.apply(prop, {EnrichField.album});
    expect(await creditsRepo.creditsOf(id), hasLength(2));
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_country_repository.dart';
import 'package:codecore/services/online/artist_country_finder.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Object _fixture(String name) =>
    jsonDecode(File('test/fixtures/musicbrainz/$name.json').readAsStringSync()) as Object;

/// MusicBrainz and Wikidata answering from the fixtures; [refuseAt] is the request that gets a 429.
class _Web implements WebClient {
  _Web({this.cityOnly = false, this.refuseAt});

  /// The search finds an artist whose area is a city (no country): Wikidata has to answer.
  final bool cityOnly;
  final int? refuseAt;
  final asked = <String>[];

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    asked.add(url);
    if (refuseAt != null && asked.length >= refuseAt!) throw const RateLimitedException(429);
    if (url.endsWith('/artist')) return _fixture(cityOnly ? 'artist_search_city_only' : 'artist_search_coldplay');
    if (url.contains('/artist/')) return _fixture('artist_urlrels_wikidata');
    return _fixture(query!['ids'] == 'Q303' ? 'wikidata_claims_p27' : 'wikidata_claims_p297');
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

void main() {
  late AppDatabase db;
  late ArtistCountryRepository repo;
  var clock = 1000000000000;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ArtistCountryRepository(db);
  });
  tearDown(() => db.close());

  Future<void> add(String artist, {int n = 0, int kind = 0}) => db.into(db.tracks).insert(
        TracksCompanion.insert(
          path: '$artist-$n-$kind',
          title: 't',
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          artist: Value(artist),
          kind: Value(kind),
        ),
      );

  ArtistCountryFinder finder(_Web web, {Future<bool> Function()? allowed}) => ArtistCountryFinder(
        repo: repo,
        mb: MusicBrainzClient(web, pause: (_) async {}),
        wikidata: WikidataClient(web),
        allowed: allowed ?? () async => true,
        waitIdle: () async {},
        now: () => clock,
      );

  test('the country of the search hit is stored as ISO with source musicbrainz', () async {
    await add('Coldplay');
    final web = _Web();
    final r = await finder(web).run();
    final row = (await repo.of('coldplay'))!;
    expect((row.country, row.source, row.checkedAt), ('GB', 'musicbrainz', clock));
    expect((r.checked, r.found, r.stopped), (1, 1, false));
    expect(web.asked, hasLength(1));
  });

  test('an area that is a city, with no country: Wikidata gives it through the MusicBrainz link', () async {
    await add('Elvis Presley');
    await finder(_Web(cityOnly: true)).run();
    final row = (await repo.of('elvis presley'))!;
    expect((row.country, row.source), ('US', 'wikidata'));
  });

  test('area ISO code stands in when the hit has no country field', () async {
    final hit = {
      'artists': [
        {'id': 'a', 'name': 'Rammstein', 'score': 100, 'area': {'type': 'Country', 'iso-3166-1-codes': ['DE']}}
      ]
    };
    final mb = MusicBrainzClient(_Inline(hit), pause: (_) async {});
    expect((await mb.artistOrigin('Rammstein'))?.country, 'DE');
  });

  test('worldwide and other X codes are not a country', () async {
    final hit = {
      'artists': [
        {'id': 'a', 'name': 'Nobody', 'score': 100, 'country': 'XW'}
      ]
    };
    final o = await MusicBrainzClient(_Inline(hit), pause: (_) async {}).artistOrigin('Nobody');
    expect(o?.country, isNull);
  });

  test('not found is written with its date and not asked again before 30 days', () async {
    await add('Obscure Band');
    await repo.upsert('obscure band', checkedAtMs: clock - const Duration(days: 29).inMilliseconds);
    final web = _Web();
    expect((await finder(web).run()).checked, 0);
    expect(web.asked, isEmpty);

    await repo.upsert('obscure band', checkedAtMs: clock - const Duration(days: 30).inMilliseconds);
    expect((await finder(web).run()).checked, 1);
    expect(web.asked, isNotEmpty);
  });

  test('a found country is not asked again', () async {
    await add('Coldplay');
    await repo.upsert('coldplay', country: 'GB', source: 'musicbrainz', checkedAtMs: 1);
    final web = _Web();
    await finder(web).run();
    expect(web.asked, isEmpty);
  });

  test('not allowed: no request at all', () async {
    await add('Coldplay');
    final web = _Web();
    final r = await finder(web, allowed: () async => false).run();
    expect(web.asked, isEmpty);
    expect((r.checked, r.stopped), (0, true));
  });

  test('allowed only with the enrichment on, no Jam and a network that is online and not metered', () async {
    Future<bool> ask({bool on = true, bool jam = false, bool metered = false}) =>
        artistCountryAllowed(enrichmentOn: on, jamActive: jam, meteredOrOffline: () async => metered);
    expect(await ask(), isTrue);
    expect(await ask(on: false), isFalse, reason: 'enrichment is off by default');
    expect(await ask(jam: true), isFalse);
    expect(await ask(metered: true), isFalse, reason: 'metered or offline');
  });

  test('spellings of one artist share a key and cost one request', () async {
    await add('The Beatles', n: 1);
    await add('the  BEATLES', n: 2);
    await add('Beatles feat. Someone', n: 3);
    expect(artistCountryKey('The Beatles'), artistCountryKey('THE  beatles'));
    expect(artistCountryKey('Björk'), artistCountryKey('BJORK'));
    expect(artistCountryKey('Coldplay feat. Rihanna'), artistCountryKey('coldplay'));
    final web = _Web();
    // «The Beatles» and «Beatles» stay two keys (the whole app keeps «The»); the two «The» spellings are one.
    expect((await finder(web).run()).checked, 2);
  });

  test('hidden tracks do not count as library artists', () async {
    await add('Podcast Host', kind: 1);
    final web = _Web();
    await finder(web).run();
    expect(web.asked, isEmpty);
  });

  test('the first rate limit stops the round and the artist is not recorded', () async {
    await add('Coldplay', n: 1);
    await add('Elvis Presley', n: 2);
    await add('Elvis Presley', n: 3);
    await add('Third Artist', n: 4);
    final web = _Web(refuseAt: 2);
    final r = await finder(web).run();
    expect(r.stopped, isTrue);
    expect(web.asked, hasLength(2), reason: 'nothing is asked after the 429');
    expect(await db.select(db.artistCountries).get(), hasLength(r.checked));
  });
}

class _Inline implements WebClient {
  _Inline(this.json);
  final Object json;

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async => json;

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

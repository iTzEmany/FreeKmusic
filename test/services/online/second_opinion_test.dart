import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/covers/cover_store.dart';
import 'package:codecore/services/online/enrich_engine.dart';
import 'package:codecore/services/online/enrichment_service.dart' show EnrichField;
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/second_opinion.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import '../../support/enrich_fakes.dart';

Object _fixture(String name) => jsonDecode(File('test/fixtures/musicbrainz/$name.json').readAsStringSync()) as Object;

/// MusicBrainz from the saved answers; every other address answers nothing.
class _Web implements WebClient {
  final recordingGenres = <Map<String, Object?>>[];
  final asked = <String>[];
  var mbLimited = false;

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    asked.add(Uri.parse(url).path);
    if (mbLimited && url.contains('musicbrainz')) throw WebUnavailableException(url, 503);
    if (!url.contains('musicbrainz')) return null;
    if (url.endsWith('/recording')) return _fixture('recording_search_official');
    if (url.contains('/recording/')) return {'genres': recordingGenres};
    if (url.contains('/artist/')) return _fixture('artist_genres');
    return null;
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => [1, 2, 3];
}

class _Client extends InnerTubeClient {
  _Client(this.results, {this.lyricsText, this.searchError}) : super(Dio());

  final List<YtResult> results;
  final String? lyricsText;
  final Object? searchError;
  var searches = 0;

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5, CancelToken? cancel}) async {
    searches++;
    if (searchError != null) throw searchError!;
    return results;
  }

  @override
  Future<String?> lyrics(String videoId, {CancelToken? cancel}) async => lyricsText;
}

class _Catalog implements YtmCatalog {
  _Catalog(this.page);

  final YtmAlbum page;

  @override
  Future<CatalogResult<YtmAlbum>> album(String browseId, String hl, {bool refresh = false}) async =>
      CatalogResult(page, DateTime(2026));

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

YtResult _hit({
  String id = 'vid',
  String title = 'Viva la Vida',
  List<String> artists = const ['Coldplay'],
  String? album = 'Viva la Vida or Death and All His Friends',
  String? albumId = 'MPREb_1',
  Duration duration = const Duration(milliseconds: 244000),
}) =>
    YtResult(id: id, title: title, channel: 'c', duration: duration, artists: artists, album: album, albumId: albumId);

void main() {
  late AppDatabase db;
  late Directory tmp;
  late _Web web;
  late EnrichEngine engine;
  late TrackRepository repo;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('so');
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    web = _Web();
    final enrichmentStack = enrichStack(
      db: db,
      tracks: repo,
      covers: CoverStore(Directory(p.join(tmp.path, 'c'))),
      itunes: ItunesClient(web),
      lrclib: LrclibClient(web),
      wikipedia: WikipediaClient(web),
      web: web,
      language: () => 'it',
      limiter: RateLimiter(minGap: Duration.zero),
    );
    engine = enrichmentStack.engine;
  });
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  final albumPage = YtmAlbum(
    browseId: 'MPREb_1',
    title: 'Viva la Vida or Death and All His Friends',
    year: '2008',
    coverUrl: 'https://x/c.jpg',
    tracks: [YtmAlbumTrack(4, _hit())],
  );

  Future<Track> add({
    String? artist = 'Coldplay',
    String? album,
    int durationMs = 244000,
    bool userEdited = false,
    int? year,
    String? genre,
    String? lyrics,
    int? trackNumber,
    bool hasCover = false,
  }) async {
    final id = await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/a.mp3',
          title: 'Viva la Vida',
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          artist: Value(artist),
          album: Value(album),
          durationMs: Value(durationMs),
          userEdited: Value(userEdited),
          year: Value(year),
          genre: Value(genre),
          lyricsPlain: Value(lyrics),
          trackNumber: Value(trackNumber),
          hasCover: Value(hasCover),
          enrichStatus: const Value(2),
        ));
    return (await repo.getById(id))!;
  }

  SecondOpinion opinion(_Client client) => SecondOpinion(
        client: client,
        catalog: _Catalog(albumPage),
        engine: engine,
        musicBrainz: MusicBrainzClient(web, pause: (_) async {}),
        tracks: repo,
        hl: () => 'it',
      );

  test('a result of the same length and credit fills every empty field', () async {
    final t = await add(artist: null);
    final out = await opinion(_Client([_hit()], lyricsText: 'a\nb\nc')).check(t);
    expect(out.kind, SecondOpinionKind.confirmed);
    expect(out.videoId, 'vid');
    final got = (await repo.getById(t.id))!;
    expect(got.artist, 'Coldplay');
    expect(got.album, 'Viva la Vida or Death and All His Friends');
    expect(got.year, 2008);
    expect(got.trackNumber, 4);
    expect(got.hasCover, isTrue);
    expect(got.genre, 'Alternative Rock', reason: 'one vote on the recording: the artist stands in');
    expect(got.lyricsPlain, 'a\nb\nc');
    expect(got.lyricsSynced, isNull);
    expect(got.enrichStatus, 1);
  });

  test('a confirmation that writes nothing leaves the status as it was', () async {
    final t = await add(
      album: 'Viva la Vida or Death and All His Friends',
      year: 2008,
      genre: 'Rock',
      lyrics: 'la',
      trackNumber: 4,
      hasCover: true,
    );
    final out = await opinion(_Client([_hit()])).check(t);
    expect(out.kind, SecondOpinionKind.confirmed);
    expect(out.written, isEmpty);
    expect((await repo.getById(t.id))!.enrichStatus, 2);
  });

  test('a cover alone written takes the status from 2 to 1', () async {
    final t = await add(
      album: 'Viva la Vida or Death and All His Friends',
      year: 2008,
      genre: 'Rock',
      lyrics: 'la',
      trackNumber: 4,
    );
    final out = await opinion(_Client([_hit()])).check(t);
    expect(out.written, {EnrichField.cover});
    expect((await repo.getById(t.id))!.enrichStatus, 1);
  });

  test('a length 4 s away is not the same recording', () async {
    final t = await add();
    final out = await opinion(_Client([_hit(duration: const Duration(milliseconds: 248000))])).check(t);
    expect(out.kind, SecondOpinionKind.notConfirmed);
    expect((await repo.getById(t.id))!.enrichStatus, 2);
  });

  test('without a local length nothing is asked and nothing is believed', () async {
    final t = await add(durationMs: 0);
    final client = _Client([_hit()]);
    expect((await opinion(client).check(t)).kind, SecondOpinionKind.notConfirmed);
    expect(client.searches, 0);
  });

  test('with no artist, a title shared by two artists confirms nothing', () async {
    final t = await add(artist: null);
    final out = await opinion(_Client([_hit(), _hit(id: 'other', artists: const ['Someone Else'])])).check(t);
    expect(out.kind, SecondOpinionKind.notConfirmed);
  });

  test('a different local album: only the artist is written', () async {
    final t = await add(artist: null, album: 'Greatest Hits');
    final out = await opinion(_Client([_hit()], lyricsText: 'a\nb\nc')).check(t);
    expect(out.written, {EnrichField.artist});
    final got = (await repo.getById(t.id))!;
    expect(got.album, 'Greatest Hits');
    expect(got.year, isNull);
    expect(got.genre, isNull);
    expect(got.lyricsPlain, isNull);
  });

  test('fields already filled are left alone', () async {
    final t = await add(album: 'Viva la Vida or Death and All His Friends', year: 2000, genre: 'Pop', lyrics: 'mine', trackNumber: 9, hasCover: true);
    final out = await opinion(_Client([_hit()], lyricsText: 'a\nb\nc')).check(t);
    expect(out.kind, SecondOpinionKind.confirmed);
    expect(out.written, isEmpty);
    final got = (await repo.getById(t.id))!;
    expect((got.year, got.genre, got.lyricsPlain, got.trackNumber), (2000, 'Pop', 'mine', 9));
  });

  test('a track the user edited keeps its album', () async {
    final t = await add(userEdited: true);
    final out = await opinion(_Client([_hit()])).check(t);
    expect((await repo.getById(t.id))!.album, isNull);
    expect(out.written, isNot(contains(EnrichField.album)));
  });

  test('«too many requests» from the search says throttled', () async {
    final t = await add();
    final out = await opinion(_Client(const [], searchError: const YtException(YtErrorKind.rateLimited))).check(t);
    expect(out.kind, SecondOpinionKind.throttled);
  });

  test('a search that could not be read says network error', () async {
    final t = await add();
    final out = await opinion(_Client(const [], searchError: const InnerTubeChanged('x'))).check(t);
    expect(out.kind, SecondOpinionKind.networkError);
  });

  test('a user-edited track with no album gets no cover (it would spread to the folder)', () async {
    final t = await add(userEdited: true);
    final out = await opinion(_Client([_hit()])).check(t);
    expect(out.written, isNot(contains(EnrichField.cover)));
    expect((await repo.getById(t.id))!.hasCover, isFalse);
  });

  test('after a MusicBrainz 503 the genre is not asked again for a while', () async {
    web.mbLimited = true;
    final t = await add();
    final op = opinion(_Client([_hit()]));
    await op.check(t);
    final first = web.asked.where((a) => a.contains('/ws/2')).length;
    expect(first, 1);
    await op.check(t);
    expect(web.asked.where((a) => a.contains('/ws/2')).length, first);
  });
}

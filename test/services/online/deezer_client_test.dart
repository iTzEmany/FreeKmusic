import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/deezer_client.dart';
import 'package:codecore/services/online/credits.dart';
import 'package:codecore/services/online/deezer_models.dart';
import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/external_links.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

Object _fixture(String name) =>
    jsonDecode(File('test/fixtures/deezer/$name.json').readAsStringSync())
        as Object;

class _Web implements WebClient {
  _Web(this.answer, {this.byUrl = const {}});

  /// null mimics DioWebClient on a timeout.
  final Object? answer;
  final Map<String, Object> byUrl;
  final urls = <String>[];
  int calls = 0;

  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel, bool strict = false,
  }) async {
    calls++;
    urls.add(url);
    return byUrl[url] ?? answer;
  }

  @override
  Future<List<int>?> getBytes(
    String url, {
    int maxBytes = 0,
    CancelToken? cancel,
  }) async => null;
}

void main() {
  final albumUrl = 'https://api.deezer.com/album/119606';
  _Web details(String track) => _Web(
    null,
    byUrl: {
      'https://api.deezer.com/track/1': _fixture(track),
      albumUrl: _fixture('album_details'),
    },
  );

  test('trackDetails: fields from the track and the album fixtures', () async {
    final web = details('track_details');
    final d = (await DeezerClient(web).trackDetails(1))!;
    expect(d.bpm, 171.6);
    expect(d.rank, 980436);
    expect(d.explicit, true);
    expect(d.label, 'Daft Life Ltd./ADA France');
    expect(d.albumFans, 344063);
    expect(d.recordType, 'album');
    expect(d.digitalReleaseDate, '2001-03-07');
    expect(web.urls, ['https://api.deezer.com/track/1', albumUrl]);
  });

  test('trackDetails: an album already read saves the request', () async {
    final web = details('track_details');
    final alb = DeezerAlbum.fromJson(_fixture('album_details') as Map);
    final d = await DeezerClient(web).trackDetails(1, album: alb);
    expect(d!.label, alb.label);
    expect(web.urls, ['https://api.deezer.com/track/1']);
  });

  test('trackDetails: bpm 0 is no bpm', () async {
    final alb = DeezerAlbum.fromJson(_fixture('album_details') as Map);
    final d = await DeezerClient(details('track_bpm_zero'))
        .trackDetails(1, album: alb);
    expect(d!.bpm, isNull);
  });

  test('trackDetails: rests on quota error like the other calls', () async {
    final c = DeezerClient(
      _Web({
        'error': {'code': 4},
      }),
    );
    await expectLater(c.trackDetails(1), throwsA(isA<RateLimitedException>()));
    expect(c.isResting, isTrue);
  });

  test('TrackDetails: JSON round trip', () {
    const d = TrackDetails(
      bpm: 171.6,
      label: 'L',
      digitalReleaseDate: '2001-03-07',
      recordType: 'album',
      rank: 5,
      albumFans: 7,
      explicit: false,
      copyright: 'c',
      physicalReleaseDate: '2000-01-01',
    );
    expect(TrackDetails.fromJson(d.toJson()).toJson(), d.toJson());
  });

  test('ISRC found: the fields are parsed', () async {
    final t = await DeezerClient(_Web(_fixture('track_isrc_corsi')))
        .trackByIsrc('ITZ042500021');
    expect(t!.title, 'Sigarette');
    expect(t.artist, 'Lucio Corsi');
    expect(t.duration, 179);
    expect(t.isrc, 'ITZ042500021');
    expect((t.trackPosition, t.diskNumber), (2, 1));
    expect(t.album!.id, 730631321);
    expect(t.album!.title, 'Volevo essere un duro');
    expect(t.album!.releaseDate, '2025-03-20');
    expect(t.album!.coverXl, contains('1000x1000'));
  });

  test('code 800: no data, null', () async {
    expect(
      await DeezerClient(_Web(_fixture('error_no_data'))).trackByIsrc('X'),
      isNull,
    );
  });

  test(
    'code 4: RateLimitedException, then 10 minutes without asking',
    () async {
      var now = DateTime(2026);
      final web = _Web(_fixture('error_quota'));
      final c = DeezerClient(web, now: () => now);
      await expectLater(
        c.trackByIsrc('X'),
        throwsA(isA<RateLimitedException>()),
      );
      await expectLater(c.album(1), throwsA(isA<RateLimitedException>()));
      expect(web.calls, 1);
      now = now.add(DeezerClient.cooldown);
      await expectLater(c.album(1), throwsA(isA<RateLimitedException>()));
      expect(web.calls, 2);
    },
  );

  test('timeout: a network error, not null', () async {
    await expectLater(
      DeezerClient(_Web(null)).trackByIsrc('X'),
      throwsA(isA<DeezerNetworkException>()),
    );
  });

  test('album: record type, track count and genres', () async {
    final a = await DeezerClient(_Web(_fixture('album_signature_box')))
        .album(1);
    expect(a!.recordType, 'album');
    expect(a.nbTracks, 119);
  });

  test('search: the data list is parsed', () async {
    final r = await DeezerClient(_Web(_fixture('search_viva_la_vida')))
        .searchTracks('x');
    expect(r.length, greaterThan(1));
    expect(r.first.artist, 'Party Machine');
  });

  group('link reading', () {
    const base = 'https://api.deezer.com';
    final instant = RateLimiter(minGap: Duration.zero);

    DeezerClient client(_Web web, {List<Duration>? pauses}) => DeezerClient(
      web,
      limiter: instant,
      pause: (d) async => pauses?.add(d),
    );

    test('playlist: `next` is followed and every track read', () async {
      final web = _Web(null, byUrl: {
        '$base/playlist/2138566342': _fixture('playlist'),
        '$base/playlist/2138566342/tracks?limit=100': _fixture('playlist_tracks_p1'),
        '$base/playlist/2138566342/tracks?limit=100&index=100':
            _fixture('playlist_tracks_p2'),
      });
      final l = await client(web).playlist(2138566342);
      expect(l.tracks.length, 136);
      expect(l.declaredTotal, 136);
      expect(l.title, 'Jazz Now');
      expect(web.calls, 3);
    });

    test('code 4: waits 5 s and retries, without the 10-minute rest', () async {
      final answers = [_fixture('error_quota'), _fixture('track')];
      final web = _Seq(answers);
      final pauses = <Duration>[];
      final c = client(web, pauses: pauses);
      final t = await c.track(3135556);
      expect(t.title, isNotEmpty);
      expect(pauses, [const Duration(seconds: 5)]);
      expect(c.isResting, isFalse);
    });

    test('code 4 four times in a row: gives up as a network error', () async {
      final web = _Seq([for (var i = 0; i < 4; i++) _fixture('error_quota')]);
      final pauses = <Duration>[];
      await expectLater(
        client(web, pauses: pauses).track(1),
        throwsA(isA<DeezerNetworkException>()),
      );
      expect(pauses.length, 3);
    });

    test('code 800: the collection is not found', () async {
      await expectLater(
        client(_Web(_fixture('error_no_data'))).playlist(1),
        throwsA(isA<CollectionNotFound>()),
      );
    });

    test('reader: an album becomes an ExternalCollection', () async {
      final web = _Web(null, byUrl: {
        '$base/album/119606': _fixture('album'),
        '$base/album/119606/tracks?limit=100': _fixture('album_tracks'),
      });
      final c = await DeezerCollectionReader(client(web))
          .read(const ExternalLink(ExternalService.deezer, ExternalLinkKind.album, '119606'));
      expect(c.kind, CollectionKind.album);
      expect(c.tracks.first.title, 'Intro');
      expect(c.tracks.first.artists, ['Eminem']);
      expect(c.tracks.first.durationMs, 34000);
      expect(c.tracks.first.isrc, 'USUM70506385');
      expect(c.coverUrl, isNotNull);
    });

    test('reader: an artist top and a track', () async {
      final web = _Web(null, byUrl: {
        '$base/artist/27': _fixture('artist'),
        '$base/artist/27/top?limit=50': _fixture('artist_top'),
        '$base/track/3135556': _fixture('track'),
      });
      final r = DeezerCollectionReader(client(web));
      final top = await r.read(const ExternalLink(ExternalService.deezer, ExternalLinkKind.artist, '27'));
      expect(top.title, 'Daft Punk');
      expect(top.tracks, isNotEmpty);
      final one = await r.read(const ExternalLink(ExternalService.deezer, ExternalLinkKind.track, '3135556'));
      expect(one.tracks.length, 1);
    });
  });

  group('link reading errors', () {
    const base = 'https://api.deezer.com';
    DeezerClient client(WebClient web) =>
        DeezerClient(web, limiter: RateLimiter(minGap: Duration.zero), pause: (_) async {});
    Object err(int code) => {'error': {'type': 'x', 'message': 'm', 'code': code}};

    test('codes 200 and 300 are a private or missing collection', () async {
      for (final code in [200, 300]) {
        await expectLater(client(_Web(err(code))).playlist(1), throwsA(isA<CollectionNotFound>()));
      }
    });

    test('codes 100 and 700 are a network error', () async {
      for (final code in [100, 700]) {
        await expectLater(client(_Web(err(code))).playlist(1), throwsA(isA<DeezerNetworkException>()));
      }
    });

    test('a 403 from the web client is a network error', () async {
      await expectLater(client(_Throwing()).playlist(1), throwsA(isA<DeezerNetworkException>()));
    });

    test('a `next` on another host is not followed', () async {
      final web = _Web(null, byUrl: {
        '$base/album/1': {'title': 'A'},
        '$base/album/1/tracks?limit=100': {'data': [], 'next': 'https://evil.test/x'},
      });
      await client(web).albumTracks(1);
      expect(web.urls, isNot(contains('https://evil.test/x')));
    });
  });
}

/// Serves [answers] one per request.
class _Seq extends _Web {
  _Seq(this.queue) : super(null);

  final List<Object> queue;

  @override
  Future<Object?> getJson(
    String url, {
    Map<String, String>? query,
    CancelToken? cancel,
    bool strict = false,
  }) async {
    calls++;
    return queue.removeAt(0);
  }
}

class _Throwing extends _Web {
  _Throwing() : super(null);
  @override
  Future<Object?> getJson(String url,
          {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async =>
      throw const RateLimitedException(403);
}

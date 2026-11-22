import 'package:codecore/providers/online_providers.dart' show ytmQuiet;
import 'package:codecore/services/online/youtube_service.dart' show YtException, YtErrorKind;
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/enrich_gather.dart' show withTrackMemo;
import 'package:codecore/services/online/discogs_client.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_test/flutter_test.dart';

/// All three services behind one fake: it answers by address and records the calls.
class _World implements WebClient {
  _World({this.mb = true, this.mbRecordings = const [], this.work, this.artistQ, this.songQ, this.sitelinks = const {}, this.pages = const {}, this.wikipediaLimited = false, this.discogsNotes, this.mbDown = false});

  final bool mb, mbDown;
  final List<Map<String, Object?>> mbRecordings;
  final String? work, artistQ, songQ;
  final Map<String, Map<String, String>> sitelinks; // Q -> lang -> title
  final Map<String, String> pages; // 'lang:Title' -> extract
  final bool wikipediaLimited;

  /// Notes of the Discogs master 26600 (the album the recording is on); null = no link.
  final String? discogsNotes;
  final calls = <String>[];

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    final q = query ?? {};
    calls.add('${Uri.parse(url).host}${Uri.parse(url).path} ${q['titles'] ?? q['ids'] ?? q['query'] ?? q['gsrsearch'] ?? ''}');
    final host = Uri.parse(url).host;
    final path = Uri.parse(url).path;
    if (host == 'musicbrainz.org') {
      if (mbDown) throw WebUnavailableException(url, 503);
      if (!mb) return null;
      if (path.contains('/isrc/')) return {'recordings': mbRecordings};
      if (path.endsWith('/recording')) return {'recordings': mbRecordings};
      if (path.contains('/release-group/')) {
        return {'relations': [{'type': 'discogs', 'url': {'resource': 'https://www.discogs.com/master/26600'}}]};
      }
      if (path.contains('/recording/') && q['inc'] == 'releases+release-groups') {
        return {'releases': discogsNotes == null ? [] : [{'release-group': {'id': 'rg1', 'primary-type': 'Album'}}]};
      }
      if (path.contains('/recording/')) {
        return {'relations': work == null ? [] : [{'work': {'id': work}}]};
      }
      if (path.contains('/work/')) {
        return {'relations': songQ == null ? [] : [{'type': 'wikidata', 'url': {'resource': 'https://www.wikidata.org/wiki/$songQ'}}]};
      }
      if (path.contains('/artist/')) {
        return {'relations': artistQ == null ? [] : [{'type': 'wikidata', 'url': {'resource': 'https://www.wikidata.org/wiki/$artistQ'}}]};
      }
      if (path.endsWith('/artist')) return {'artists': []};
    }
    if (host == 'api.discogs.com') return {'notes': discogsNotes};
    if (host == 'www.wikidata.org') {
      final ids = (q['ids'] ?? '').split('|');
      return {
        'entities': {
          for (final id in ids)
            if (sitelinks[id] != null) id: {'sitelinks': {for (final e in sitelinks[id]!.entries) '${e.key}wiki': {'title': e.value}}},
        }
      };
    }
    if (host.endsWith('wikipedia.org')) {
      if (wikipediaLimited) throw const RateLimitedException(429);
      final lang = host.split('.').first;
      final titles = (q['titles'] ?? '').split('|');
      return {
        'query': {
          'pages': {
            for (final t in titles)
              if (pages['$lang:$t'] != null) '${t.hashCode}': {'title': t, 'extract': pages['$lang:$t']},
          }
        }
      };
    }
    return null;
  }

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

Map<String, Object?> _rec(String id, String title, String artist, String artistId) => {
      'id': id,
      'title': title,
      'artist-credit': [
        {'artist': {'id': artistId, 'name': artist}}
      ],
    };

final _long = ' è una pagina abbastanza lunga da contare come introduzione di un articolo vero. ' * 2;

CuriosityFinder _finder(_World w, {List<Duration>? pauses, YtmArtistDescription? ytm}) => CuriosityFinder(
      wikipedia: WikipediaClient(w),
      musicBrainz: MusicBrainzClient(w, pause: (d) async => pauses?.add(d), now: () => DateTime(2026)),
      wikidata: WikidataClient(w),
      discogs: DiscogsClient(w),
      ytmArtist: ytm,
    );

void main() {
  _ytmQuietTests();
  test('by identity: the exact pages MusicBrainz and Wikidata name, in the app language', () async {
    final w = _World(
      mbRecordings: [_rec('r1', 'Dirty Work', 'Steely Dan', 'a1')],
      work: 'w1',
      songQ: 'Q1',
      artistQ: 'Q2',
      sitelinks: {
        'Q1': {'en': 'Dirty Work (Steely Dan song)'},
        'Q2': {'it': 'Steely Dan', 'en': 'Steely Dan'},
      },
      pages: {
        'en:Dirty Work (Steely Dan song)': 'Dirty Work is a song by Steely Dan,$_long',
        'it:Steely Dan': 'Gli Steely Dan sono un gruppo musicale,$_long',
      },
    );
    final r = await _finder(w).find('Dirty Work', 'Steely Dan', 'it');
    expect(r.song!.source.toString(), 'https://en.wikipedia.org/wiki/Dirty_Work_(Steely_Dan_song)');
    expect(r.artist!.source.toString(), 'https://it.wikipedia.org/wiki/Steely_Dan');
    expect(r.songError, isNull);
    expect(w.calls.where((c) => c.contains('generator') || c.contains('gsrsearch')), isEmpty, reason: 'no word search was needed');
  });

  test('a page MusicBrainz links that does not speak of the song is not used', () async {
    final w = _World(
      mbRecordings: [_rec('r1', 'Felicità', 'Lucio Dalla', 'a1')],
      work: 'w1',
      songQ: 'Q1',
      sitelinks: {'Q1': {'it': 'Chissà se stai dormendo'}},
      pages: {'it:Chissà se stai dormendo': 'Chissà se stai dormendo è un brano di un altro autore,$_long'},
    );
    final r = await _finder(w).find('Felicità', 'Lucio Dalla', 'it');
    expect(r.song, isNull);
  });

  test('MusicBrainz down: the names are used, as before', () async {
    final w = _World(mb: false, pages: {
      'it:Steely Dan': 'Gli Steely Dan sono un gruppo musicale,$_long',
      'it:Dirty Work (Steely Dan)': 'Dirty Work è un brano dei Steely Dan,$_long',
    });
    final r = await _finder(w).find('Dirty Work', 'Steely Dan', 'it');
    expect(r.artist!.source.toString(), 'https://it.wikipedia.org/wiki/Steely_Dan');
    expect(r.song!.source.toString(), 'https://it.wikipedia.org/wiki/Dirty_Work_(Steely_Dan)');
  });

  test('a song MusicBrainz knows but without a page falls back to the names, the artist stays exact', () async {
    final w = _World(
      mbRecordings: [_rec('r1', 'Mother', 'Pink Floyd', 'a1')],
      artistQ: 'Q2',
      sitelinks: {'Q2': {'it': 'Pink Floyd'}},
      pages: {
        'it:Pink Floyd': 'I Pink Floyd sono stati un gruppo musicale,$_long',
        'en:Mother (Pink Floyd song)': 'Mother is a song by Pink Floyd,$_long',
      },
    );
    final r = await _finder(w).find('Mother', 'Pink Floyd', 'it');
    expect(r.artist!.source.toString(), 'https://it.wikipedia.org/wiki/Pink_Floyd');
    expect(r.song!.source.toString(), 'https://en.wikipedia.org/wiki/Mother_(Pink_Floyd_song)');
  });

  test('an artist unknown as a recording is looked up by name', () async {
    final w = _World(pages: {'it:Nobody': 'Nobody è un gruppo musicale,$_long'});
    final r = await _finder(w).find('Whatever', 'Nobody', 'it');
    expect(r.artist!.source.toString(), 'https://it.wikipedia.org/wiki/Nobody');
    expect(w.calls.any((c) => c.startsWith('musicbrainz.org/ws/2/artist')), isTrue);
  });

  test('MusicBrainz resting is an error of the track, not «nothing found»', () async {
    final r = await _finder(_World(mbDown: true)).find('Dirty Work', 'Steely Dan', 'it', isrc: 'X1');
    expect(r.songError, isA<MusicBrainzUnavailable>());
    expect(r.artistError, isA<MusicBrainzUnavailable>());
  });

  test('inside one track memo an ISRC shared by two titles gives each its own recording', () async {
    final w = _World(mbRecordings: [_rec('r1', 'Song One', 'A1', 'a1'), _rec('r2', 'Song Two', 'A2', 'a2')]);
    final f = _finder(w);
    await withTrackMemo(() async {
      final one = await f.find('Song One', 'A1', 'it', isrc: 'X1');
      final two = await f.find('Song Two', 'A2', 'it', isrc: 'X1');
      expect([one.recordingId, two.recordingId], ['r1', 'r2']);
    });
  });

  test('Wikipedia refusing is reported per part and the finder does not throw', () async {
    final w = _World(wikipediaLimited: true);
    final r = await _finder(w).find('Dirty Work', 'Steely Dan', 'it');
    expect(r.songError, isA<RateLimitedException>());
    expect(r.artistError, isA<RateLimitedException>());
    expect(r.song, isNull);
  });

  test('without an artist there is no artist part and MusicBrainz is not asked', () async {
    final w = _World();
    final r = await _finder(w).find('Dirty Work', '', 'it');
    expect(r.artist, isNull);
    expect(r.artistError, isNull);
    expect(w.calls.where((c) => c.startsWith('musicbrainz.org')), isEmpty);
  });

  group('MusicBrainz client', () {
    test('requests are spaced by a little over a second', () async {
      final pauses = <Duration>[];
      var t = DateTime(2026);
      final w = _World(mbRecordings: [_rec('r1', 'Mother', 'Pink Floyd', 'a1')], artistQ: 'Q2');
      final mb = MusicBrainzClient(w, pause: (d) async {
        pauses.add(d);
        t = t.add(d);
      }, now: () => t);
      await mb.recordings('Mother', 'Pink Floyd');
      await mb.artistWikidata('a1');
      await mb.artistWikidata('a2'); // the same request would come from the cache (D-683)
      expect(pauses, [MusicBrainzClient.gap, MusicBrainzClient.gap]);
    });

    test('only recordings with the same title and the same credit are kept', () async {
      final w = _World(mbRecordings: [
        _rec('r1', 'Mother Love', 'Pink Floyd', 'a1'),
        _rec('r2', 'Mother', 'Somebody Else', 'a2'),
        _rec('r3', 'MOTHER', 'pink floyd', 'a1'),
      ]);
      final recs = await MusicBrainzClient(w, pause: (_) async {}).recordings('Mother', 'Pink Floyd');
      expect(recs.map((r) => r.id), ['r3']);
    });

    test('a null answer (404) is final: asked once, no retry (D-683)', () async {
      final w = _World(mb: false);
      final pauses = <Duration>[];
      final mb = MusicBrainzClient(w, pause: (d) async => pauses.add(d));
      expect(await mb.recordings('Mother', 'Pink Floyd'), isEmpty);
      expect(w.calls.where((c) => c.contains('/recording')), hasLength(1));
      expect(pauses, isEmpty);
    });

    test('an artist is taken only on an exact name with a high score', () async {
      final fake = _ArtistsWeb([
        {'id': 'x1', 'name': 'Pink Floyd Tribute', 'score': 100},
        {'id': 'x2', 'name': 'Pink Floyd', 'score': 60},
        {'id': 'x3', 'name': 'Pink Floyd', 'score': 100},
      ]);
      final a = await MusicBrainzClient(fake, pause: (_) async {}).artist('Pink Floyd');
      expect(a!.id, 'x3');
    });

    test('Wikidata: titles per language, and only for the ones that exist', () async {
      final w = _World(sitelinks: {'Q1': {'it': 'Uno', 'en': 'One'}, 'Q2': {'en': 'Two'}});
      final r = await WikidataClient(w).sitelinks(['Q1', 'Q2', 'Q9'], ['it', 'en']);
      expect(r, {'Q1': {'it': 'Uno', 'en': 'One'}, 'Q2': {'en': 'Two'}});
      expect(await WikidataClient(w).sitelinks([], ['it']), isEmpty);
    });
  });
  group('fallbacks', () {
    final notes = 'Initially released in early 2008 as a ten track album, later re-issued as a special edition. [b]Bold[/b] notes.';

    test('Wikipedia has no page for the song: the notes of the album master on Discogs, BBCode removed', () async {
      final w = _World(mbRecordings: [_rec('r1', 'Viva la Vida', 'Coldplay', 'a1')], discogsNotes: notes);
      final r = await _finder(w).find('Viva la Vida', 'Coldplay', 'it');
      expect(r.song!.text, startsWith('Initially released'));
      expect(r.song!.text, contains('Bold notes.'));
      expect(r.song!.source.toString(), 'https://www.discogs.com/master/26600');
    });

    test('Discogs notes under 80 characters are dropped', () async {
      final w = _World(mbRecordings: [_rec('r1', 'Viva la Vida', 'Coldplay', 'a1')], discogsNotes: 'Too short.');
      final r = await _finder(w).find('Viva la Vida', 'Coldplay', 'it');
      expect(r.song, isNull);
    });

    test('Wikipedia has no page for the artist: the YouTube Music description', () async {
      final text = 'Coldplay are a British rock band formed in London in 1997. ' * 2;
      final w = _World();
      final r = await _finder(w, ytm: (name, _) async => (
            text: text,
            source: Uri.parse('https://music.youtube.com/channel/UC1'),
            lang: 'it',
          )).find('Viva la Vida', 'Coldplay', 'it');
      expect(r.artist!.text, text.trim());
      expect(r.artist!.source.host, 'music.youtube.com');
    });

    test('a short YouTube Music description is dropped', () async {
      final r = await _finder(_World(), ytm: (_, _) async => (text: 'Band.', source: Uri.parse('https://music.youtube.com/channel/UC1'), lang: 'it'))
          .find('Viva la Vida', 'Coldplay', 'it');
      expect(r.artist, isNull);
    });
  });

  test('Discogs BBCode: links, artist names and formatting tags become plain text', () {
    expect(
      DiscogsClient.stripBbcode('[b]Hi[/b] [a=Coldplay] and [a123] [url=https://x.y/z]the EP[/url] [r456]\n\n\n\nEnd'),
      'Hi Coldplay and the EP\n\nEnd',
    );
  });
}

class _ArtistsWeb implements WebClient {
  _ArtistsWeb(this.artists);

  final List<Map<String, Object?>> artists;

  @override
  Future<Object?> getJson(String url, {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async => {'artists': artists};

  @override
  Future<List<int>?> getBytes(String url, {int maxBytes = 0, CancelToken? cancel}) async => null;
}

void _ytmQuietTests() {
  test('ytmQuiet: a YouTube failure is quiet, a rate limit is the finder\'s own', () async {
    expect(await ytmQuiet<int>(() async => throw const YtException(YtErrorKind.network)), isNull);
    expect(
      ytmQuiet<int>(() async => throw const YtException(YtErrorKind.rateLimited)),
      throwsA(isA<RateLimitedException>()),
    );
  });
}

import 'package:codecore/services/online/deezer_client.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:codecore/services/online/lrc_parser.dart';
import 'package:codecore/services/online/lrclib_client.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeWeb implements WebClient {
  FakeWeb(this.handler);

  final Object? Function(String url, Map<String, String> q) handler;
  final calls = <String>[];

  @override
  Future<Object?> getJson(String url,
      {Map<String, String>? query, CancelToken? cancel, bool strict = false}) async {
    calls.add('$url ${query ?? {}}');
    return handler(url, query ?? {});
  }

  @override
  Future<List<int>?> getBytes(String url,
          {int maxBytes = 0, CancelToken? cancel}) async =>
      null;
}

Map<String, Object?> song(String t, String a, {String? album}) => {
      'trackName': t,
      'artistName': a,
      'collectionName': album ?? 'Alb (Deluxe Edition)',
      'releaseDate': '2015-05-01T07:00:00Z',
      'primaryGenreName': 'Alternative',
      'trackNumber': 3,
      'artworkUrl100': 'https://x/100x100bb.jpg',
    };

void main() {
  group('iTunes', () {
    Map<String, Object?> album(String name, String artist) => {
          'collectionName': name,
          'artistName': artist,
          'artworkUrl100': 'https://x/100x100bb.jpg',
        };

    test('album search: right album and artist, noise ignored, big artwork',
        () async {
      final web = FakeWeb((_, q) {
        expect(q['entity'], 'album');
        expect(q['term'], 'Lucio Corsi Volevo essere un duro');
        return {
          'results': [
            album('Altro disco', 'Lucio Corsi'),
            album('Volevo essere un duro (Deluxe Edition)', 'Lucio Corsi'),
          ]
        };
      });
      final a = await ItunesClient(web)
          .searchAlbum('Volevo essere un duro', 'Lucio Corsi');
      expect(a!.name, 'Volevo essere un duro (Deluxe Edition)');
      expect(a.artworkUrl, 'https://x/600x600bb.jpg');
    });

    test('album search: another artist\'s album of the same name is refused',
        () async {
      final web = FakeWeb((_, _) => {
            'results': [album('Greatest Hits', 'Somebody Else')]
          });
      expect(await ItunesClient(web).searchAlbum('Greatest Hits', 'Queen'), isNull);
    });

    test('the store country is sent with song and album searches', () async {
      final seen = <String?>[];
      final web = FakeWeb((_, q) {
        seen.add(q['country']);
        return {'results': []};
      });
      final it = ItunesClient(web, country: () => 'IT');
      await it.search('Sigarette', 'Lucio Corsi');
      await it.searchAlbum('Volevo essere un duro', 'Lucio Corsi');
      expect(seen, isNotEmpty);
      expect(seen.every((c) => c == 'IT'), isTrue);
    });

    test('without a country the default store is used', () async {
      final seen = <Map<String, String>>[];
      final web = FakeWeb((_, q) {
        seen.add(q);
        return {'results': []};
      });
      await ItunesClient(web).search('x', 'y');
      expect(seen.every((q) => !q.containsKey('country')), isTrue);
    });

    test('album search: no album name means no call result', () async {
      final web = FakeWeb((_, _) => {'results': []});
      expect(await ItunesClient(web).searchAlbum('  ', 'Queen'), isNull);
      expect(web.calls, isEmpty);
    });

    test('exact match', () async {
      final web = FakeWeb((_, _) => {
            'results': [song('Car Radio', 'twenty one pilots')]
          });
      final m = await ItunesClient(web).search('Car Radio', 'twenty one pilots');
      expect(m!.album, 'Alb');
      expect(m.year, 2015);
      expect(m.artworkUrl, 'https://x/600x600bb.jpg');
    });

    test('same title different artist -> null', () async {
      final web = FakeWeb((_, _) => {
            'results': [song('Car Radio', 'Someone Else')]
          });
      expect(await ItunesClient(web).search('Car Radio', 'twenty one pilots'),
          isNull);
    });

    test('no results -> null', () async {
      final web = FakeWeb((_, _) => {'results': []});
      expect(await ItunesClient(web).search('X Y', 'Z'), isNull);
    });

    test('generic title with unknown artist never takes another artist',
        () async {
      final web = FakeWeb((_, _) => {
            'results': [song('Intro', 'Other Band')]
          });
      expect(await ItunesClient(web).search('Intro', ''), isNull);
    });

    group('duration', () {
      Map<String, Object?> timed(String t, String a, int ms, String album) =>
          {...song(t, a, album: album), 'trackTimeMillis': ms};

      test('a candidate more than 20 s off is rejected', () async {
        final web = FakeWeb((_, _) => {
              'results': [timed('Here', 'A', 225000, 'Remix')]
            });
        expect(await ItunesClient(web).search('Here', 'A', durationMs: 200000), isNull);
        expect(await ItunesClient(web).search('Here', 'A', durationMs: 210000), isNotNull);
      });

      test('between equal titles the closest length wins', () async {
        final web = FakeWeb((_, _) => {
              'results': [
                timed('Here', 'A', 190000, 'Far'),
                timed('Here', 'A', 201000, 'Close'),
              ]
            });
        expect((await ItunesClient(web).search('Here', 'A', durationMs: 200000))!.album, 'Close');
      });

      test('an unknown length on either side changes nothing', () async {
        final web = FakeWeb((_, _) => {
              'results': [timed('Here', 'A', 999000, 'Long'), song('Here', 'A', album: 'NoTime')]
            });
        expect((await ItunesClient(web).search('Here', 'A'))!.album, 'Long');
        expect(await ItunesClient(web).search('Here', 'A', durationMs: 200000), isNotNull);
      });
    });

    test('query order and dedupe', () {
      final q = ItunesClient(FakeWeb((_, _) => null))
          .buildQueries('Song (Live)', 'A & B');
      expect(q.first, 'A & B Song (Live)');
      expect(q, contains('A Song'));
      expect(q.toSet().length, q.length);
    });
  });

  test('albumCovers: iTunes and Deezer give one proposal per edition, at the big size', () async {
    final it = await ItunesClient(FakeWeb((_, _) => {
          'results': [
            {'collectionName': 'A', 'artworkUrl100': 'https://x/100x100bb.jpg'},
            {'collectionName': 'A (Deluxe)', 'artworkUrl100': 'https://y/100x100bb.jpg'},
            {'collectionName': 'No art'},
          ]
        })).albumCovers('A', 'B');
    expect([for (final c in it) c.url], ['https://x/600x600bb.jpg', 'https://y/600x600bb.jpg']);
    final dz = await DeezerClient(FakeWeb((_, _) => {
          'data': [
            {'title': 'A', 'cover_xl': 'https://d/1.jpg'},
            {'title': 'A 2', 'cover_xl': 'https://d/2.jpg'},
          ]
        })).albumCovers('A', 'B');
    expect([for (final c in dz) c.title], ['A', 'A 2']);
  });

  group('LRC', () {
    test('multiple stamps, ms digits, offset, tags', () {
      const raw = '[ar:Someone]\n[offset:500]\n[00:10.50]Hello\n'
          '[00:20.123][01:00.00]Again\n\n[00:05]First\n';
      final l = parseLrc(raw);
      expect(l.map((e) => e.text), ['First', 'Hello', 'Again', 'Again']);
      expect(l[0].time, const Duration(milliseconds: 4500));
      expect(l[1].time, const Duration(milliseconds: 10000));
      expect(l[2].time, const Duration(milliseconds: 19623));
    });

    test('currentLrcIndex', () {
      final l = parseLrc('[00:01.00]a\n[00:03.00]b');
      expect(currentLrcIndex(l, Duration.zero), -1);
      expect(currentLrcIndex(l, const Duration(seconds: 2)), 0);
      expect(currentLrcIndex(l, const Duration(seconds: 9)), 1);
    });
  });

  group('LRCLIB', () {
    test('accepts matching artist/duration', () async {
      final web = FakeWeb((u, _) => u.endsWith('/get')
          ? {
              'artistName': 'Queen',
              'duration': 355,
              'plainLyrics': 'x',
              'syncedLyrics': '[00:01.00]x'
            }
          : null);
      final r = await LrclibClient(web)
          .find(title: 'Bohemian', artist: 'Queen', durationSec: 354);
      expect(r!.synced, isNotNull);
    });

    test('rejects other artist or far duration', () async {
      final web = FakeWeb((u, _) => {
            'artistName': 'Other',
            'duration': 100,
            'plainLyrics': 'x'
          });
      expect(
          await LrclibClient(web)
              .find(title: 'T', artist: 'Queen', durationSec: 100),
          isNull);
      final web2 = FakeWeb((u, _) =>
          {'artistName': 'Queen', 'duration': 200, 'plainLyrics': 'x'});
      expect(
          await LrclibClient(web2)
              .find(title: 'T', artist: 'Queen', durationSec: 100),
          isNull);
    });
  });

  test('Wikipedia skips short and disambiguation pages, in one request', () async {
    final long = 'A song by the band. ' * 10;
    final web = FakeWeb((u, q) => {
          'query': {
            'pages': {
              '1': {'title': 'Short', 'index': 1, 'extract': 'tiny'},
              '2': {'title': 'Real Song', 'index': 2, 'extract': long},
            }
          }
        });
    final c = await WikipediaClient(web).find('Real Song', 'Band', 'en');
    expect(c!.source.toString(), 'https://en.wikipedia.org/wiki/Real_Song');
    expect(c.text.length, lessThanOrEqualTo(1500));
    expect(web.calls, hasLength(1), reason: 'search and intros come together');
  });

  group('Wikipedia: song and artist are told apart', () {
    final bio = 'Band are a rock group formed in London in 1970. ' * 4;
    final about = 'Real Song is a song by the band Band, released in 1975. ' * 4;
    final elsewhere = 'A completely different subject that is long enough to count. ' * 4;

    /// Pages come in a map, not in ranking order: `index` says the rank.
    FakeWeb web({required List<String> hits}) => FakeWeb((u, q) => {
          'query': {
            'pages': {
              for (var i = hits.length - 1; i >= 0; i--)
                '${i + 10}': {
                  'title': hits[i],
                  'index': i + 1,
                  'extract': hits[i] == 'Band'
                      ? bio
                      : hits[i] == 'Other Thing'
                          ? elsewhere
                          : about,
                },
            }
          }
        });

    test('the song page wins even when the artist page ranks first', () async {
      final c = await WikipediaClient(web(hits: ['Band', 'Real Song (Band song)']))
          .findSong('Real Song', 'Band', 'en');
      expect(c!.source.toString(), 'https://en.wikipedia.org/wiki/Real_Song_(Band_song)');
      expect(c.text, startsWith('Real Song is a song'));
    });

    test('a title with a tail is tried whole and without the tail, in one request', () async {
      final web = FakeWeb((u, q) => {
            'query': {
              'pages': {'1': {'title': 'Real Song', 'index': 1, 'extract': about}}
            }
          });
      final c = await WikipediaClient(web).findSong('Real Song - Remastered 2011', 'Band', 'en');
      expect(c!.source.toString(), 'https://en.wikipedia.org/wiki/Real_Song');
      expect(web.calls, hasLength(1));
      expect(web.calls.single, contains('Real Song - Remastered 2011'));
      expect(web.calls.single, contains('Real Song (Band song)'));
    });

    test('a version group like (Radio Edit) is dropped to find the song\'s page', () async {
      final web = FakeWeb((u, q) {
        final whole = (q['gsrsearch'] ?? '').contains('Radio Edit');
        return {
          'query': {
            'pages': whole ? {} : {'1': {'title': 'Real Song', 'index': 1, 'extract': about}}
          }
        };
      });
      final c = await WikipediaClient(web).findSong('Real Song (Radio Edit)', 'Band', 'en');
      expect(c!.source.toString(), 'https://en.wikipedia.org/wiki/Real_Song');
    });

    test('when no exact title exists the words are searched, with OR groups, never an AND of many words', () async {
      final w = FakeWeb((u, q) => {'query': <String, Object?>{}});
      await WikipediaClient(w).findArtist('Band', 'it');
      final searches = w.calls.where((c) => c.contains('generator')).toList();
      expect(searches, isNotEmpty, reason: 'the fallback ran');
      expect(searches.first, contains('OR'));
    });

    test('a page is found by its exact title even when a search would not rank it', () async {
      final web = FakeWeb((u, q) {
        if (q.containsKey('titles')) {
          return {
            'query': {
              'pages': {
                '5': {'title': 'Band', 'extract': bio},
                '-1': {'title': 'Band (cantante)', 'missing': ''},
              }
            }
          };
        }
        fail('no search was needed');
      });
      final c = await WikipediaClient(web).findArtist('Band', 'it');
      expect(c!.source.toString(), 'https://it.wikipedia.org/wiki/Band');
      expect(web.calls, hasLength(1));
    });

    test('a lower-case name is tried with capitals, and a redirect is followed', () async {
      final web = FakeWeb((u, q) {
        expect(q['titles'], contains('Bob Dylan'));
        return {
          'query': {
            'redirects': [{'from': 'Dylan', 'to': 'Bob Dylan'}],
            'pages': {
              '1': {'title': 'Bob Dylan', 'extract': 'Bob Dylan è un cantautore e musicista statunitense, autore di molte canzoni. ' * 2},
            }
          }
        };
      });
      final c = await WikipediaClient(web).findArtist('bob dylan', 'it');
      expect(c!.source.toString(), 'https://it.wikipedia.org/wiki/Bob_Dylan');
    });

    test('the most specific title wins: «Title (Band song)» before a plain «Title»', () async {
      final web = FakeWeb((u, q) => {
            'query': {
              'pages': {
                '1': {'title': 'Real Song', 'extract': 'Real Song is a song from long ago that many have recorded, and Band too. ' * 2},
                '2': {'title': 'Real Song (Band song)', 'extract': about},
              }
            }
          });
      final c = await WikipediaClient(web).findSong('Real Song', 'Band', 'en');
      expect(c!.source.toString(), 'https://en.wikipedia.org/wiki/Real_Song_(Band_song)');
    });

    test('an artist page that is not about music (a namesake) is refused', () async {
      final web = FakeWeb((u, q) => {
            'query': {
              'pages': {
                '1': {'title': 'Rio', 'extract': 'Rio is a Swiss village in the canton of Bern, with a church and a river. ' * 2},
              }
            }
          });
      expect(await WikipediaClient(web).findArtist('Rio', 'en'), isNull);
    });

    test('with only the artist page the song has nothing, never the artist text', () async {
      final c = await WikipediaClient(web(hits: ['Band'])).findSong('Real Song', 'Band', 'en');
      expect(c, isNull);
    });

    test('a page with the song\'s name that is not about music is not the song', () async {
      final film = 'Fade to Black is a technical term from cinema meaning a gradual darkening of the picture. ' * 2;
      final web = FakeWeb((u, q) => {
            'query': {
              'pages': {'1': {'title': 'Fade to Black', 'index': 1, 'extract': film}}
            }
          });
      expect(await WikipediaClient(web).findSong('Fade to Black', 'Dire Straits', 'en'), isNull);
    });

    test('a song of the same name by another artist is not taken', () async {
      final web = FakeWeb((u, q) => {
            'query': {
              'pages': {
                '1': {
                  'title': 'Fade to Black (Metallica song)',
                  'index': 1,
                  'extract': 'Fade to Black is a song by American heavy metal band Metallica, released in 1984. ' * 2,
                },
              }
            }
          });
      expect(await WikipediaClient(web).findSong('Fade To Black', 'Dire Straits', 'en'), isNull);
      expect(await WikipediaClient(web).findSong('Fade To Black', 'Metallica', 'en'), isNotNull);
    });

    test('a page with the song\'s name that is a song, or names the artist, is accepted', () async {
      FakeWeb page(String extract) => FakeWeb((u, q) => {
            'query': {
              'pages': {'1': {'title': 'Real Song', 'index': 1, 'extract': extract}}
            }
          });
      final song = 'Real Song is a song recorded in the studio and released as a single in 1975. ' * 2;
      expect(await WikipediaClient(page(song)).findSong('Real Song', '', 'en'), isNotNull, reason: 'no artist known: a song page is enough');
      final named = 'Real Song was written in 1975 and recorded by Band in London over two weeks. ' * 2;
      expect(await WikipediaClient(page(named)).findSong('Real Song', 'Band', 'en'), isNotNull);
    });

    test('a page about another song that only quotes this one is not taken', () async {
      final web = FakeWeb((u, q) => {
            'query': {
              'pages': {
                '1': {
                  'title': 'Chissà se stai dormendo',
                  'index': 1,
                  'extract': 'Chissà se stai dormendo è un singolo di Jovanotti del 1992. '
                      "L'intro del brano è un omaggio al brano Felicità di Lucio Dalla.",
                },
              }
            }
          });
      expect(await WikipediaClient(web).findSong('Felicità', 'Lucio Dalla', 'it'), isNull);
    });

    test('a page named otherwise is taken when the song opens it and the artist is named', () async {
      final web = FakeWeb((u, q) => {
            'query': {
              'pages': {
                '1': {
                  'title': 'Junk (canzone)',
                  'index': 1,
                  'extract': 'Singalong Junk è la versione strumentale di Junk, un brano di Paul McCartney del 1970, '
                      'pubblicato nel suo primo album.',
                },
              }
            }
          });
      final c = await WikipediaClient(web).findSong('Singalong Junk', 'Paul McCartney', 'it');
      expect(c!.source.toString(), 'https://it.wikipedia.org/wiki/Junk_(canzone)');
    });

    test('a page on another subject is not taken for the song', () async {
      final c = await WikipediaClient(web(hits: ['Other Thing']))
          .findSong('Real Song', 'Band', 'en');
      expect(c, isNull);
    });

    test('the artist page is the one named like the artist', () async {
      final c = await WikipediaClient(web(hits: ['Real Song (Band song)', 'Band']))
          .findArtist('Band feat. Someone', 'en');
      expect(c!.source.toString(), 'https://en.wikipedia.org/wiki/Band');
      expect(c.text, startsWith('Band are a rock group'));
    });

    test('an artist with no page of their own gets nothing', () async {
      final c = await WikipediaClient(web(hits: ['Band (disambiguation)', 'Real Song (Band song)']))
          .findArtist('Nobody', 'en');
      expect(c, isNull);
    });
  });

  test('decodeJsonBody handles text/javascript payloads', () {
    expect(decodeJsonBody('{"results":[1]}'), {'results': [1]});
    expect(decodeJsonBody('not json'), isNull);
    expect(decodeJsonBody({'a': 1}), {'a': 1});
  });
}

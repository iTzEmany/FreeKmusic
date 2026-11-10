import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/online/query_intent.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_artist_parser.dart';
import 'package:flutter_test/flutter_test.dart';

TopCard? card(String file) => parseTopCard(
    jsonDecode(File('test/fixtures/innertube/$file.json').readAsStringSync()) as Map);

void main() {
  final artist = card('ytm_top_artist_card');

  test('the name of the artist, in any case and with or without «the», is the artist page',
      () {
    for (final q in ['pink floyd', 'PINK FLOYD', 'the pink floyd', ' Pink  Floyd ']) {
      expect(intentOf(q, artist), SearchIntent.artistPage, reason: q);
    }
  });

  test('the start of a name, on whole words and from four letters, is the artist page', () {
    final vasco = parseTopCard(jsonDecode(
        File('test/fixtures/smart_search/cases.json').readAsStringSync())
        .firstWhere((c) => c['query'] == 'vasco')['card'] as Map);
    expect(intentOf('vasco', vasco), SearchIntent.artistPage);
    expect(intentOf('vas', vasco), SearchIntent.artistAndSongs);
    expect(intentOf('vasc', vasco), SearchIntent.artistAndSongs);
  });

  test('an artist and more words is the artist and songs', () {
    expect(intentOf('pink floyd mother', artist), SearchIntent.artistAndSongs);
  });

  test('an album, a song and a video card give album, song and songs', () {
    expect(intentOf('the wall', card('ytm_top_album_card')), SearchIntent.album);
    expect(intentOf('mother pink floyd', card('ytm_top_song_card')), SearchIntent.song);
    expect(intentOf('bohemian rhapsody', card('ytm_top_video_card')), SearchIntent.songs);
  });

  test('without a card the intent is songs', () {
    expect(intentOf('pink floyd', null), SearchIntent.songs);
  });

  test('playlist and channel addresses, video addresses and words are told apart', () {
    final playlist = classifyQuery('https://www.youtube.com/playlist?list=PLabc123');
    expect(playlist.kind, QueryKind.listing);
    expect(playlist.url, 'https://www.youtube.com/playlist?list=PLabc123');
    expect(classifyQuery('https://www.youtube.com/@fredagain').kind, QueryKind.listing);
    expect(classifyQuery('https://youtu.be/dQw4w9WgXcQ').kind, QueryKind.video);
    expect(classifyQuery('pink floyd mother').kind, QueryKind.text);
  });

  test('a YouTube Music album address carries its browse id', () {
    final album = classifyQuery('https://music.youtube.com/browse/MPREb_abc123?si=x');
    expect(album.kind, QueryKind.album);
    expect(album.browseId, 'MPREb_abc123');
    expect(classifyQuery('https://music.youtube.com/browse/UCabc').kind, QueryKind.text);
  });
  _externalRows();
}

void _externalRows() {
  test('Deezer and Spotify links are external, short links carry the url', () {
    final c = classifyQuery('https://open.spotify.com/playlist/abc');
    expect(c.kind, QueryKind.external);
    expect(c.link?.id, 'abc');
    final s = classifyQuery(' https://spotify.link/xyz ');
    expect(s.kind, QueryKind.external);
    expect(s.link, isNull);
    expect(s.url, 'https://spotify.link/xyz');
    expect(classifyQuery('spotify wrapped').kind, QueryKind.text);
    expect(classifyQuery('www.deezer.com/playlist/1').kind, QueryKind.text);
  });
}

// Opt-in: how many Wikipedia pages the curiosity search finds for real songs.
//   CODECORE_LIVE=1 flutter test test/live/curiosity_survey_live_test.dart
//
// The songs are the 34 of test/fixtures/Just_a_mood.csv (real titles and
// artists, no test files or voice notes). Each song is asked **once**: rows
// that are the same song after cleaning (a remaster, a copy) count once, and
// the answers are kept in build/curiosity_survey.json so a later run only asks
// what is still missing or failed (CODECORE_SURVEY_FRESH=1 asks everything
// again). The real web client is used, with its real request budget (8 a
// minute to Wikimedia without a contact in the User-Agent): a full fresh run
// takes several minutes on purpose.
import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/import/csv_profiles.dart';
import 'package:codecore/services/online/curiosity_finder.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/query_cleaner.dart';
import 'package:codecore/services/online/wikipedia_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/core/artist_key.dart';

/// The same song whatever the file calls it: core title + main artist.
String songKey(String title, String artist) {
  final head = title.split(RegExp(r'\s+[-–—]\s+')).first;
  return '${matchKey(coreTitle(head))}|${matchKey(extractPrimaryArtist(artist))}';
}

void main() {
  final live = Platform.environment['CODECORE_LIVE'] == '1';
  final fresh = Platform.environment['CODECORE_SURVEY_FRESH'] == '1';

  test('curiosity survey over Just a mood, each song once', () async {
    final csv = File('test/fixtures/Just_a_mood.csv');
    final rows = readCsvPlaylist('Just_a_mood.csv', csv.readAsStringSync()).rows;

    final songs = <String, CleanQuery>{};
    for (final r in rows) {
      final c = cleanSearchQuery(r.title, r.artists.join(', '));
      songs.putIfAbsent(songKey(c.title, c.artist), () => c);
    }

    final cacheFile = File('build/curiosity_survey.json');
    final cache = <String, Map<String, dynamic>>{};
    if (!fresh && cacheFile.existsSync()) {
      final saved = jsonDecode(cacheFile.readAsStringSync()) as Map<String, dynamic>;
      for (final e in saved.entries) {
        cache[e.key] = (e.value as Map).cast<String, dynamic>();
      }
    }

    final web = DioWebClient();
    final finder = CuriosityFinder(
      wikipedia: WikipediaClient(web),
      musicBrainz: MusicBrainzClient(web),
      wikidata: WikidataClient(web),
    );
    String? describe(Object? found, Object? error) => error != null
        ? 'ERR $error'
        : found is Curiosity
            ? '${found.lang}:${found.source.pathSegments.last}'
            : null;

    var asked = 0;
    for (final e in songs.entries) {
      final done = cache[e.key];
      // An answer (found or not) is final; an error is asked again.
      if (done != null && !'${done['song']}${done['artist']}'.contains('ERR')) continue;
      final p = await finder.find(e.value.title, e.value.artist, 'it');
      asked++;
      cache[e.key] = {
        'title': e.value.title,
        'artist': e.value.artist,
        'song': describe(p.song, p.songError),
        'artistPage': describe(p.artist, p.artistError),
      };
      cacheFile
        ..createSync(recursive: true)
        ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(cache));
    }

    final all = [for (final k in songs.keys) cache[k]!];
    bool ok(Object? v) => v != null && !'$v'.startsWith('ERR');
    final songPages = all.where((r) => ok(r['song'])).length;
    final artistPages = all.where((r) => ok(r['artistPage'])).length;
    final errors = all.where((r) => '${r['song']}${r['artistPage']}'.contains('ERR')).length;
    // ignore: avoid_print
    print('${rows.length} rows, ${songs.length} songs, $asked asked now: '
        'song pages $songPages, artist pages $artistPages, errors $errors');
    for (final r in all) {
      if (!ok(r['song']) || !ok(r['artistPage'])) {
        // ignore: avoid_print
        print('  ${r['title']} / ${r['artist']}: song ${r['song']}, artist ${r['artistPage']}');
      }
    }
    expect(songs.length, lessThanOrEqualTo(rows.length));
  }, skip: live ? false : 'set CODECORE_LIVE=1', timeout: const Timeout(Duration(minutes: 60)));
}

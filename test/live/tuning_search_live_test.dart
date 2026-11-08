// Opt-in helper for tuning `query_match.dart` with real searches (task 32.7).
//   CODECORE_LIVE=1 TUNING_QUERIES=q.json TUNING_DUMP=dump.json flutter test test/live/tuning_search_live_test.dart
//     asks YouTube Music / YouTube (the raw answers, ~1 phrase per second) and saves them;
//   TUNING_DUMP=dump.json flutter test test/live/tuning_search_live_test.dart
//     scores a saved dump with the current code and prints the table (no network).
import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/catalog_cache.dart';
import 'package:codecore/services/online/direct_search_service.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_intent.dart';
import 'package:codecore/services/online/query_match.dart';
import 'package:codecore/services/online/search_cache.dart';
import 'package:codecore/services/online/yt_dlp_process_service.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_artist_parser.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/core/artist_key.dart';

void main() {
  final env = Platform.environment;
  final dumpPath = env['TUNING_DUMP'];
  final live = env['CODECORE_LIVE'] == '1';

  test('dump the raw answers', () async {
    final queries = jsonDecode(File(env['TUNING_QUERIES']!).readAsStringSync()) as List;
    final dir = Directory.systemTemp.createTempSync('tuning');
    final client = InnerTubeClient();
    final yt = YtDlpProcessService(executable: env['YTDLP']);
    final catalog = YtmCatalog(
        client, yt, CatalogCache(file: () async => File('${dir.path}/c.json')));
    final service = DirectSearchService(yt, client, catalog: catalog);
    final out = <Map>[];
    for (final q in queries) {
      final text = q['text'] as String;
      Object? card;
      Future<Object?> askCard() async {
        try {
          await client.searchMusic<TopCard?>(text, (m) {
            card = m;
            return parseTopCard(m);
          }, mask: topCardMask, isEmpty: (r) => r == null);
        } on Object catch (e) {
          stderr.writeln('card failed for $text: $e');
        }
        return card;
      }

      List<Map> enc(List l) => [for (final r in l) ytResultToJson(r)];
      var songs = <Map>[], videos = <Map>[];
      try {
        songs = enc(await service.searchSongs(text, limit: 10));
      } on Object catch (e) {
        stderr.writeln('songs failed for $text: $e');
      }
      try {
        videos = enc((await service.search(text)).take(10).toList());
      } on Object catch (e) {
        stderr.writeln('videos failed for $text: $e');
      }
      await askCard();
      out.add({...q as Map, 'songs': songs, 'videos': videos, 'card': card});
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    File(dumpPath!).writeAsStringSync(jsonEncode(out));
    client.close();
    dir.deleteSync(recursive: true);
  }, skip: live && dumpPath != null && env['TUNING_QUERIES'] != null ? false : 'dump mode off',
      timeout: const Timeout(Duration(minutes: 30)));

  test('write fixture cases', () {
    final want = env['TUNING_CASES']!.split('|').toSet();
    final cases = jsonDecode(File(dumpPath!).readAsStringSync()) as List;
    final out = <Map>[];
    for (final c in cases.cast<Map>().where((c) => want.contains(c['text']))) {
      final songs = (c['songs'] as List).take(6).toList();
      final videos = (c['videos'] as List).take(6).toList();
      final artistCase = c['kind'] == 'artist';
      final wantTitle = matchTitleKey('${c['title']}');
      final wantArtists = [for (final a in '${c['artist']}'.split(', ')) matchKey(a)];
      final ok = [
        if (!artistCase)
          for (final j in [...songs, ...videos])
            if (matchTitleKey(ytResultFromJson(j)!.title) == wantTitle &&
                wantArtists.any((w) => _artistOk(ytResultFromJson(j)!, w)))
              (j as Map)['id'],
      ];
      out.add({
        'query': c['text'],
        'group': 'moto',
        'expectedFirst': artistCase ? null : ok,
        'intent': artistCase ? 'artistPage' : null,
        'card': c['card'],
        'songs': songs,
        'videos': videos,
      });
    }
    File(env['TUNING_CASES_OUT']!).writeAsStringSync(jsonEncode(out));
  }, skip: env['TUNING_CASES'] != null && dumpPath != null ? false : 'no cases');

  test('score a dump', () {
    final cases = jsonDecode(File(dumpPath!).readAsStringSync()) as List;
    // The library is simulated with the artists of the dump (TUNING_LIBRARY=none: empty).
    final library = env['TUNING_LIBRARY'] == 'none'
        ? <String>{}
        : {
            for (final c in cases.cast<Map>())
              for (final a in '${c['artist']}'.split(', ')) libraryArtistKey(a),
          };
    final stats = <String, Map<String, int>>{};
    final lines = <String>[];
    for (final c in cases.cast<Map>()) {
      final kind = c['kind'] as String;
      final text = c['text'] as String;
      final songs = [for (final s in c['songs'] as List) ytResultFromJson(s)!];
      final videos = [for (final s in c['videos'] as List) ytResultFromJson(s)!];
      final card = c['card'] == null ? null : parseTopCard(c['card'] as Map);
      final scored = scoreAll(
        text,
        songs: songs,
        videos: videos,
        card: card,
        libraryArtists: library,
      );
      final split = splitBest(mergeResults(scored), kBestThreshold);
      final s = stats.putIfAbsent(kind, () => {});
      void inc(String k) => s[k] = (s[k] ?? 0) + 1;
      inc('n');
      if (kind == 'artist') {
        final want = _name((c['artist'] as String).split(', ').first);
        final ok = card is TopArtist && _name(card.artist.name) == want;
        if (ok) inc('card');
        if (ok && intentOf(text, card) == SearchIntent.artistPage) inc('page');
        lines.add('${ok ? 'ok ' : 'BAD'} artist "$text" -> ${card is TopArtist ? card.artist.name : card.runtimeType}');
        continue;
      }
      final wantTitle = matchTitleKey(c['title'] as String);
      final wantArtists = [for (final a in (c['artist'] as String).split(', ')) matchKey(a)];
      bool isIt(SmartResult r, {bool anyArtist = false}) => [r.primary, ...r.alternatives].any((x) =>
          matchTitleKey(x.title) == wantTitle &&
          (anyArtist || wantArtists.any((w) => _artistOk(x, w))));
      if (env['TUNING_ROWS'] == text) {
        for (final r in scored) {
          lines.add('  ROW ${r.source.name} #${r.position} ${r.confidence.toStringAsFixed(2)} ${r.result.title} | ${r.result.artists} | ${r.result.channel} | ${r.result.duration}');
        }
      }
      var where = 'missing';
      int at(List<SmartResult> l, {bool anyArtist = false}) =>
          l.indexWhere((r) => isIt(r, anyArtist: anyArtist));
      final b = at(split.best), o = at(split.others);
      if (b == 0) {
        where = 'first';
      } else if (b > 0) {
        where = 'best';
      } else if (o >= 0) {
        where = 'others';
      }
      if (where == 'first') {
        inc('first');
        inc('best');
        inc('anyBest');
      } else if (where == 'best') {
        inc('best');
        inc('anyBest');
      } else if (where == 'others') {
        inc('others');
      } else {
        inc('missing');
      }
      if (where == 'others' || where == 'missing') {
        if (at(split.best, anyArtist: true) >= 0) inc('anyBest');
      }
      if (env['TUNING_ALL'] == '1' || where != 'first') {
        final top = split.best.isEmpty ? null : split.best.first;
        lines.add('${where.padRight(7)} [$kind] "$text"  want "${c['title']}" / ${c['artist']}'
            '  pos ${b >= 0 ? b : o >= 0 ? 'o$o' : '-'} first: '
            '${top?.primary.title} / ${top?.primary.artists.join(',')} / ${top?.primary.channel} ${top?.confidence.toStringAsFixed(2)}');
      }
    }
    final buf = StringBuffer(lines.join('\n'))..writeln('\n');
    for (final e in stats.entries) {
      buf.writeln('${e.key}: ${e.value}');
    }
    File('$dumpPath.report.txt').writeAsStringSync(buf.toString());
    stdout.writeln(buf);
  }, skip: dumpPath != null && File(dumpPath).existsSync() ? false : 'no dump');
}

String _name(String s) {
  final k = matchKey(s);
  return k.startsWith('the ') ? k.substring(4) : k;
}

bool _artistOk(YtResult x, String want) {
  final names = [...x.artists, x.channel];
  return names.any((n) {
    final k = matchKey(n);
    return k.isNotEmpty && (k.contains(want) || want.contains(k));
  });
}

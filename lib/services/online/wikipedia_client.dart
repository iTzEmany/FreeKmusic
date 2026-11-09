import 'package:dio/dio.dart';

import 'http_client.dart';
import 'query_cleaner.dart';
import '../../core/artist_key.dart';

class Curiosity {
  const Curiosity(this.text, this.source, this.lang);

  final String text;
  final Uri source;
  final String lang;
}

/// Words, in the languages of the app, that an article about a song, single or
/// album uses about itself (compared on `matchKey` text: lower case, no accents).
final _musicWords = RegExp(
  r'\b(song|songs|single|album|band|singer|musician|songwriter|rapper|vocalist|composer|guitarist|pianist|'
  r'canzone|brano|singolo|gruppo|cantante|cantautore|cantautrice|musicista|chitarrista|pianista|compositore|duo|'
  r'chanson|chanteur|chanteuse|musicien|cancion|cantante|musico|grupo|banda|lied|sanger|musiker|gruppe|'
  r'musica|music|musique)\b',
);

class WikipediaClient {
  WikipediaClient(this._web);

  final WebClient _web;

  /// The article about the song itself. A page about the artist (or about
  /// anything else a search happens to rank first) is never returned. The page
  /// is looked up by its likely titles first («Title», «Title (Artist song)»,
  /// «Title (singolo)»…), all in one request per language; only when none of
  /// them exists is the title searched for in words.
  Future<Curiosity?> findSong(String title, String artist, String lang,
      {CancelToken? cancel}) async {
    // The title as it is, without a «- Remastered 2011» tail, and without a
    // «(Radio Edit)» / «(Live)» group: the article has the plain name.
    final head = title.split(RegExp(r'\s+[-–—]\s+')).first.trim();
    final names = <String>{
      title.trim(),
      head,
      coreTitle(head),
    }.where((v) => v.isNotEmpty).toList();
    final by = artistKey(artist);
    final keys = {for (final n in names) matchKey(n)}..remove('');
    if (keys.isEmpty) return null;
    final main = extractPrimaryArtist(artist).trim();

    bool accept(String page, String extract) {
      final pageName = matchKey(_withoutQualifier(page));
      if (pageName == by && !keys.contains(pageName)) return false; // the artist's page
      final lead = matchKey(extract.substring(0, extract.length.clamp(0, 600)));
      // The same name as the song: it has to be about music too (a page
      // «Fade to Black» can be about a film term), i.e. name the artist or
      // call itself a song, single, album…
      if (keys.contains(pageName)) {
        // With an artist known, the page has to name them: «Fade to Black
        // (Metallica song)» is a song too, but not Dire Straits'. Without one,
        // being about music is all that can be asked.
        return by.isNotEmpty ? lead.contains(by) : _musicWords.hasMatch(lead);
      }
      // Named differently: the song must be what the page is about, so its name
      // opens the lead («Junk è un brano…»), and the artist must be named. A
      // page that only quotes it («…omaggio al brano Felicità di Lucio Dalla»
      // in another song's page) is not the song.
      final opening = lead.substring(0, lead.length.clamp(0, 80));
      return by.isNotEmpty && keys.any(opening.contains) && lead.contains(by);
    }

    List<String> titlesFor(String l) {
      // Most specific first: «Title (Artist song)» beats a plain «Title».
      final forms = l == 'en'
          ? [
              if (main.isNotEmpty) '($main song)',
              if (main.isNotEmpty) '($main single)',
              '(song)',
              '(single)',
              if (main.isNotEmpty) '($main)',
            ]
          : [
              if (main.isNotEmpty) '($main)',
              if (main.isNotEmpty) '(singolo $main)',
              if (main.isNotEmpty) '(canzone $main)',
              '(brano musicale)',
              '(singolo)',
              '(canzone)',
            ];
      return [
        for (final n in names.take(2)) for (final f in forms) '$n $f',
        ...names,
      ].take(_maxTitles).toList();
    }

    return _lookup(
      lang,
      cancel,
      titlesFor: titlesFor,
      searches: (l) {
        // OR groups: every word of an AND list would have to be on the page.
        final words = l == 'en' ? '(song OR single)' : '(canzone OR singolo OR brano OR song)';
        return ['"${names.first}" $artist $words'];
      },
      accept: accept,
    );
  }

  /// The article about the artist or band, found by its name («Bob Dylan»,
  /// «Bob Dylan (cantante)», «Sticky Fingers (gruppo musicale)»…).
  Future<Curiosity?> findArtist(String artist, String lang,
      {CancelToken? cancel}) async {
    final name = extractPrimaryArtist(artist).trim();
    final key = matchKey(name);
    if (key.isEmpty) return null;
    final spellings = {name, titleCase(name)};
    List<String> titlesFor(String l) {
      final forms = l == 'en'
          ? ['(musician)', '(band)', '(singer)', '(rapper)', '(group)']
          : ['(cantante)', '(gruppo musicale)', '(musicista)', '(cantautore)', '(rapper)', '(band)', '(duo musicale)'];
      return [
        ...spellings,
        for (final n in spellings) for (final f in forms) '$n $f',
      ].take(_maxTitles).toList();
    }

    return _lookup(
      lang,
      cancel,
      titlesFor: titlesFor,
      searches: (l) => ['"$name" (cantante OR gruppo OR band OR singer OR musician OR rapper)'],
      accept: (page, extract) => matchKey(_withoutQualifier(page)) == key && _musicWords.hasMatch(_music(extract)),
    );
  }

  /// The page with exactly this [title] in [lang] (redirects followed), whatever
  /// it is about: for a title that Wikidata has already vouched for.
  Future<Curiosity?> exact(String lang, String title, {CancelToken? cancel}) =>
      _byTitles(lang, [title], (_, _) => true, cancel);

  /// Kept for the callers that want the song's article.
  Future<Curiosity?> find(String title, String artist, String lang,
          {CancelToken? cancel}) =>
      findSong(title, artist, lang, cancel: cancel);

  /// The api takes at most 20 extracts per request.
  static const _maxTitles = 20;

  /// «bob dylan» → «Bob Dylan»: Wikipedia only capitalises the first letter.
  static String titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// The lead of an artist's page, as `matchKey` text, for the «is it about
  /// music» check (an artist page names its trade, in some language).
  static String _music(String extract) =>
      matchKey(extract.substring(0, extract.length.clamp(0, 600)));

  Future<Curiosity?> _lookup(
    String lang,
    CancelToken? cancel, {
    required List<String> Function(String lang) titlesFor,
    required List<String> Function(String lang) searches,
    required bool Function(String page, String extract) accept,
  }) async {
    final langs = lang == 'en' ? ['en'] : [lang, 'en'];
    for (final l in langs) {
      final c = await _byTitles(l, titlesFor(l), accept, cancel);
      if (c != null) return c;
    }
    for (final l in langs) {
      for (final q in searches(l)) {
        final c = await _findIn(l, q, accept, cancel);
        if (c != null) return c;
      }
    }
    return null;
  }

  /// «Title (song)», «Title (Band song)» → «Title».
  static String _withoutQualifier(String page) =>
      page.replaceFirst(RegExp(r'\s*\([^)]*\)\s*$'), '');

  /// The pages with exactly these [titles] (redirects followed), in the order
  /// of [titles]; a title that does not exist is simply absent. One request.
  Future<Curiosity?> _byTitles(String lang, List<String> titles,
      bool Function(String page, String extract) accept, CancelToken? cancel) async {
    if (titles.isEmpty) return null;
    final api = 'https://$lang.wikipedia.org/w/api.php';
    final found = await _web.getJson(api,
        query: {
          'action': 'query',
          'titles': titles.join('|'),
          'prop': 'extracts',
          'exintro': '1',
          'explaintext': '1',
          'exlimit': 'max',
          'redirects': '1',
          'format': 'json',
        },
        cancel: cancel);
    final q = found is Map ? found['query'] : null;
    final pages = q is Map ? q['pages'] : null;
    if (pages is! Map) return null;
    // Where each title ended up: «Foo» → normalised «Foo» → redirected «Bar».
    final moved = <String, String>{};
    for (final key in const ['normalized', 'redirects']) {
      final list = q is Map ? q[key] : null;
      if (list is List) {
        for (final m in list) {
          if (m is Map && m['from'] is String && m['to'] is String) {
            moved[m['from'] as String] = m['to'] as String;
          }
        }
      }
    }
    final rank = <String, int>{};
    for (var i = 0; i < titles.length; i++) {
      var t = titles[i];
      for (var hop = 0; hop < 3 && moved.containsKey(t); hop++) {
        t = moved[t]!;
      }
      rank.putIfAbsent(t, () => i);
    }
    final ranked = [
      for (final v in pages.values)
        if (v is Map && v['title'] is String) v,
    ]..sort((x, y) => (rank[x['title']] ?? 99).compareTo(rank[y['title']] ?? 99));
    return _firstAccepted(lang, ranked, accept);
  }

  Curiosity? _firstAccepted(String lang, List<Map> ranked,
      bool Function(String page, String extract) accept) {
    for (final h in ranked) {
      final page = h['title'] as String;
      final extract = h['extract'] as String?;
      if (extract == null) continue;
      final lower = extract.toLowerCase();
      if (extract.length < 80 ||
          lower.contains('disambigua') ||
          lower.contains('may refer to')) {
        continue;
      }
      if (!accept(page, extract)) continue;
      final url = Uri.https(
          '$lang.wikipedia.org', '/wiki/${page.replaceAll(' ', '_')}');
      return Curiosity(_truncate(extract.trim()), url, lang);
    }
    return null;
  }

  /// One request per language: the search and the intro of every hit come back
  /// together (`generator=search` + `prop=extracts`); Wikipedia answers bursts
  /// with HTTP 429.
  Future<Curiosity?> _findIn(String lang, String search,
      bool Function(String page, String extract) accept, CancelToken? cancel) async {
    final api = 'https://$lang.wikipedia.org/w/api.php';
    final found = await _web.getJson(api,
        query: {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': search,
          'gsrlimit': '5',
          'prop': 'extracts',
          'exintro': '1',
          'explaintext': '1',
          'exlimit': '5',
          'redirects': '1',
          'format': 'json',
        },
        cancel: cancel);
    final pages = (found is Map ? found['query'] : null) is Map
        ? ((found as Map)['query'] as Map)['pages']
        : null;
    if (pages is! Map) return null;
    // Back in the order of the search ranking.
    final ranked = [
      for (final v in pages.values)
        if (v is Map && v['title'] is String) v,
    ]..sort((x, y) => ((x['index'] as num?) ?? 0).compareTo((y['index'] as num?) ?? 0));
    return _firstAccepted(lang, ranked, accept);
  }

  /// Long enough to read as an article's opening, short enough to store.
  String _truncate(String s) {
    if (s.length <= 1500) return s;
    final cut = s.substring(0, 1500);
    final end = cut.lastIndexOf(RegExp(r'[.!?]\s'));
    return end > 200 ? cut.substring(0, end + 1) : cut;
  }
}

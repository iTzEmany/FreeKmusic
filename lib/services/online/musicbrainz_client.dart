import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../import/track_matcher.dart';
import 'credits.dart';
import 'http_client.dart';
import 'query_cleaner.dart';
import 'wikipedia_client.dart';

/// One recording of MusicBrainz (a performance of a song, with its credit).
class MbRecording {
  const MbRecording({
    required this.id,
    required this.title,
    required this.artistId,
    required this.artistName,
    this.length,
  });

  final String id, title, artistId, artistName;

  /// Milliseconds, when MusicBrainz knows them.
  final int? length;
}

/// A recording read by id: enough to say who sings it, when it first came
/// out, and which works (songs) it performs.
class MbRecordingDetail {
  const MbRecordingDetail({
    required this.id,
    required this.title,
    required this.artist,
    this.length,
    this.isrcs = const [],
    this.year,
    this.works = const [],
  });

  final String id, title, artist;
  final int? length;
  final List<String> isrcs;

  /// The earliest year among its releases.
  final int? year;
  final List<MbWorkLink> works;
}

/// A link recording <-> work; [cover] is set when MusicBrainz marks that
/// performance as a cover (not the original song).
class MbWorkLink {
  const MbWorkLink(this.id, {this.cover = false});

  final String id;
  final bool cover;
}

/// Where an artist comes from per MusicBrainz: an ISO [country], else the
/// [wikidata] item (`Q…`) to ask; both null when it has neither.
class MbArtistOrigin {
  const MbArtistOrigin({this.country, this.wikidata});

  final String? country, wikidata;
}

/// MusicBrainz did not answer (503 or network) even after the second try.
class MusicBrainzUnavailable implements Exception {
  const MusicBrainzUnavailable(this.what);

  final String what;

  @override
  String toString() => 'MusicBrainzUnavailable($what)';
}

/// MusicBrainz, the open music database: it says *which* song and *which*
/// artist a title is, with links to Wikidata, from where the exact Wikipedia
/// pages follow. No key; at most one request per second (the rules of the
/// service), so every call waits its turn.
class MusicBrainzClient {
  MusicBrainzClient(
    this._web, {
    Future<void> Function(Duration)? pause,
    DateTime Function()? now,
  })  : _pause = pause ?? Future<void>.delayed,
        _now = now ?? DateTime.now;

  final WebClient _web;
  final Future<void> Function(Duration) _pause;
  final DateTime Function() _now;

  static const _base = 'https://musicbrainz.org/ws/2';

  /// A little over one second between two requests.
  static const gap = Duration(milliseconds: 1100);
  DateTime? _last;

  Future<Map?> _get(String path, Map<String, String> query, CancelToken? cancel,
      {bool retry = true, bool strict = false}) async {
    // The service answers 503 now and then; a non-answer is tried once more.
    for (var attempt = 0; attempt < (retry ? 2 : 1); attempt++) {
      final last = _last;
      if (last != null) {
        final wait = gap - _now().difference(last);
        if (!wait.isNegative && wait > Duration.zero) await _pause(wait);
      }
      _last = _now();
      Object? res;
      try {
        res = await _web.getJson('$_base/$path', query: {...query, 'fmt': 'json'}, cancel: cancel, strict: strict);
        if (strict && res == null) return null; // strict: null is a 404, final
      } on WebUnavailableException catch (e) {
        if (attempt == (retry ? 1 : 0)) throw MusicBrainzUnavailable(path);
        AppLog.w('musicbrainz $path: $e');
      }
      if (res is Map) return res;
      if (attempt == 0) await _pause(const Duration(seconds: 2));
    }
    return null;
  }

  /// The credits of recording [mbid] in one request. Empty when unknown;
  /// throws [MusicBrainzUnavailable] when the service does not answer after
  /// the retry (network, timeout, 5xx); an unknown mbid (404) is just empty.
  Future<List<TrackCredit>> recordingCredits(String mbid, {CancelToken? cancel}) async {
    final data = await _get(
      'recording/$mbid',
      {'inc': 'artist-rels+work-rels+work-level-rels'},
      cancel,
      strict: true,
    );
    return data == null ? const [] : parseMbCredits(Map<String, dynamic>.from(data));
  }

  /// The recordings called [title] by [artist], best first: the ones whose
  /// title and credit are the same as asked (compared without accents and case).
  /// With [studioOnly] the search leaves out live recordings and bootlegs.
  Future<List<MbRecording>> recordings(String title, String artist,
      {bool studioOnly = false, CancelToken? cancel}) async {
    final t = title.replaceAll('"', ' ').trim();
    if (t.isEmpty) return const [];
    final by = artist.replaceAll('"', ' ').trim();
    final data = await _get(
      'recording',
      {
        'query': '${by.isEmpty ? 'recording:"$t"' : 'recording:"$t" AND artist:"$by"'}'
            '${studioOnly ? ' AND status:official AND primarytype:album AND NOT secondarytype:live' : ''}',
        'limit': '8',
      },
      cancel,
    );
    final list = data?['recordings'];
    if (list is! List) return const [];
    final wantTitle = matchKey(title);
    final wantArtist = matchKey(extractPrimaryArtist(artist));
    final out = <MbRecording>[];
    for (final r in list) {
      if (r is! Map || r['title'] is! String) continue;
      if (matchKey(r['title'] as String) != wantTitle) continue;
      final credit = r['artist-credit'];
      if (credit is! List) continue;
      for (final c in credit) {
        final a = c is Map ? c['artist'] : null;
        if (a is! Map || a['id'] is! String || a['name'] is! String) continue;
        // With an artist asked for, the credit has to be that artist.
        if (wantArtist.isNotEmpty && matchKey(a['name'] as String) != wantArtist) continue;
        out.add(MbRecording(
          id: r['id'] as String,
          title: r['title'] as String,
          artistId: a['id'] as String,
          artistName: a['name'] as String,
          length: r['length'] is num ? (r['length'] as num).toInt() : null,
        ));
        break;
      }
    }
    return out;
  }

  /// The recordings that carry [isrc], the one closest in length to
  /// [durationMs] first (those with no length last). Empty when unknown.
  /// A recording counts only if its title or its first artist is the local
  /// [title] / [artist] (an ISRC is sometimes reused for another song).
  Future<List<MbRecording>> recordingsByIsrc(String isrc, int durationMs,
      {String? title, String? artist, CancelToken? cancel, bool strict = false}) async {
    final code = isrc.trim().toUpperCase();
    if (code.isEmpty) return const [];
    // 404 means an unknown ISRC: no retry. With [strict] (credits) a network
    // error or 5xx throws MusicBrainzUnavailable while 404 is just «nothing
    // found», so «nothing found» is never remembered by mistake.
    final data = await _get('isrc/$code', {'inc': 'artist-credits'}, cancel, retry: false, strict: strict);
    final list = data?['recordings'];
    if (list is! List) return const [];
    // Without a [title] and an [artist] (dirty tags) nothing is filtered out.
    final filter = title != null && artist != null;
    final wantTitle = matchKey(title ?? '');
    final wantArtist = matchKey(extractPrimaryArtist(artist ?? ''));
    final out = <MbRecording>[];
    for (final r in list) {
      if (r is! Map || r['id'] is! String || r['title'] is! String) continue;
      final credit = r['artist-credit'];
      final a = credit is List && credit.isNotEmpty && credit.first is Map ? (credit.first as Map)['artist'] : null;
      if (a is! Map || a['id'] is! String || a['name'] is! String) {
        AppLog.i('musicbrainz isrc $code: recording ${r['id']} has no artist credit');
        continue;
      }
      if (filter && matchKey(r['title'] as String) != wantTitle && matchKey(a['name'] as String) != wantArtist) {
        AppLog.i('musicbrainz isrc $code: recording ${r['id']} is another song, skipped');
        continue;
      }
      out.add(MbRecording(
        id: r['id'] as String,
        title: r['title'] as String,
        artistId: a['id'] as String,
        artistName: a['name'] as String,
        length: r['length'] is num ? (r['length'] as num).toInt() : null,
      ));
    }
    int gap(MbRecording r) => r.length == null ? 1 << 40 : (r.length! - durationMs).abs();
    out.sort((a, b) => gap(a).compareTo(gap(b)));
    return out;
  }

  /// The recording [mbid] with its ISRCs, release years and works; null when
  /// MusicBrainz does not know it. A 503 or no network ends in
  /// [MusicBrainzUnavailable] after the second try.
  Future<MbRecordingDetail?> recordingById(String mbid, {CancelToken? cancel}) async {
    final r = await _get('recording/$mbid', {'inc': 'isrcs+artist-credits+releases+work-rels'}, cancel, strict: true);
    if (r == null || r['id'] is! String || r['title'] is! String) return null;
    final credit = r['artist-credit'];
    final artist = credit is List
        ? credit.whereType<Map>().map((c) => '${c['name'] ?? ''}${c['joinphrase'] ?? ''}').join().trim()
        : '';
    int? year;
    for (final rel in r['releases'] is List ? r['releases'] as List : const []) {
      final y = rel is Map && rel['date'] is String ? int.tryParse((rel['date'] as String).split('-').first) : null;
      if (y != null && (year == null || y < year)) year = y;
    }
    final works = <MbWorkLink>[];
    for (final rel in r['relations'] is List ? r['relations'] as List : const []) {
      final w = rel is Map ? rel['work'] : null;
      if (w is! Map || w['id'] is! String) continue;
      works.add(MbWorkLink(w['id'] as String, cover: _isCover(rel)));
    }
    return MbRecordingDetail(
      id: r['id'] as String,
      title: r['title'] as String,
      artist: artist,
      length: r['length'] is num ? (r['length'] as num).toInt() : null,
      isrcs: [for (final i in r['isrcs'] is List ? r['isrcs'] as List : const []) if (i is String) i],
      year: year,
      works: works,
    );
  }

  /// The original recording of the work [workId]: of those not marked as a
  /// cover, the one first released earliest (ties: the first listed). Null when
  /// MusicBrainz has none with a date. One browse request (69e.0 point 5);
  /// `work-rels` is there only to read the cover mark of each recording.
  // shortcut: one page of 100 recordings, no paging; a work with more may miss its original, upgrade if one is seen.
  Future<MbRecording?> workOriginal(String workId, {CancelToken? cancel}) async {
    final data = await _get(
        'recording', {'work': workId, 'inc': 'artist-credits+work-rels', 'limit': '100'}, cancel,
        strict: true);
    final list = data?['recordings'];
    if (list is! List) return null;
    MbRecording? best;
    String? bestDate;
    for (final r in list) {
      if (r is! Map || r['id'] is! String || r['title'] is! String || r['first-release-date'] is! String) continue;
      final date = r['first-release-date'] as String;
      if (date.isEmpty || (bestDate != null && date.compareTo(bestDate) >= 0)) continue;
      final rels = r['relations'] is List ? r['relations'] as List : const [];
      if (rels.any((rel) => rel is Map && rel['work'] is Map && (rel['work'] as Map)['id'] == workId && _isCover(rel))) continue;
      final credit = r['artist-credit'];
      final a = credit is List && credit.isNotEmpty && credit.first is Map ? (credit.first as Map)['artist'] : null;
      if (a is! Map || a['id'] is! String || a['name'] is! String) continue;
      bestDate = date;
      best = MbRecording(
        id: r['id'] as String,
        title: r['title'] as String,
        artistId: a['id'] as String,
        artistName: a['name'] as String,
        length: r['length'] is num ? (r['length'] as num).toInt() : null,
      );
    }
    return best;
  }

  static bool _isCover(Map rel) => rel['attributes'] is List && (rel['attributes'] as List).contains('cover');

  /// The genre of a recording of [title] by [artist] that lasts [durationMs]
  /// (within 3 s when MusicBrainz knows its length), null when none is sure.
  /// The recording's own genre counts with 2 votes or more; otherwise the
  /// artist's most voted one stands in. Capitalised like Wikipedia's titles.
  /// With an [isrc] the recording is looked up by it first, by text otherwise.
  Future<String?> genreFor(String title, String artist, int durationMs,
      {String? isrc, CancelToken? cancel}) async {
    bool near(MbRecording r) => r.length == null || (r.length! - durationMs).abs() <= 3000;
    final byIsrc = isrc == null
        ? const <MbRecording>[]
        : await recordingsByIsrc(isrc, durationMs, title: title, artist: artist, cancel: cancel);
    // No ISRC match of the right length: the text search decides.
    final rec = byIsrc.where(near).firstOrNull ??
        (await recordings(title, artist, studioOnly: true, cancel: cancel)).where(near).firstOrNull;
    if (rec == null) return null;
    final own = _topGenre(await _get('recording/${rec.id}', {'inc': 'genres'}, cancel), 2);
    final name = own ?? _topGenre(await _get('artist/${rec.artistId}', {'inc': 'genres'}, cancel), 1);
    return name == null ? null : WikipediaClient.titleCase(name);
  }

  static String? _topGenre(Map? data, int minVotes) {
    final genres = data?['genres'];
    if (genres is! List) return null;
    String? best;
    var votes = minVotes - 1;
    for (final g in genres) {
      if (g is! Map || g['name'] is! String || g['count'] is! num) continue;
      if ((g['count'] as num) > votes) {
        best = g['name'] as String;
        votes = (g['count'] as num).toInt();
      }
    }
    return best;
  }

  /// The artist called [name], when MusicBrainz is sure (an exact name and a
  /// high score); null otherwise.
  Future<({String id, String name})?> artist(String name, {CancelToken? cancel}) async {
    final n = name.replaceAll('"', ' ').trim();
    if (n.isEmpty) return null;
    final a = _artistHit(await _get('artist', {'query': 'artist:"$n"', 'limit': '5'}, cancel), n);
    return a == null ? null : (id: a['id'] as String, name: a['name'] as String);
  }

  static Map? _artistHit(Map? data, String name) {
    final list = data?['artists'];
    if (list is! List) return null;
    final want = matchKey(name);
    for (final a in list) {
      if (a is! Map || a['id'] is! String || a['name'] is! String) continue;
      final score = a['score'];
      if (matchKey(a['name'] as String) == want && (score is! num || score >= 90)) return a;
    }
    return null;
  }

  /// Where the artist [name] comes from (D-390): the ISO country of the search hit
  /// (MusicBrainz fills `country` even when the area is a city), else the ISO code of
  /// its area; with neither, the Wikidata item of its links. Null when no artist is sure.
  /// Strict: a 503 or no network throws [MusicBrainzUnavailable], so "not found" is never a guess.
  Future<MbArtistOrigin?> artistOrigin(String name, {CancelToken? cancel}) async {
    final n = name.replaceAll('"', ' ').trim();
    if (n.isEmpty) return null;
    final a = _artistHit(await _get('artist', {'query': 'artist:"$n"', 'limit': '5'}, cancel, strict: true), n);
    if (a == null) return null;
    final area = a['area'];
    final country = _iso(a['country']) ??
        _iso(area is Map && area['iso-3166-1-codes'] is List ? (area['iso-3166-1-codes'] as List).firstOrNull : null);
    if (country != null) return MbArtistOrigin(country: country);
    final links = await _get('artist/${a['id']}', {'inc': 'url-rels'}, cancel, strict: true);
    return MbArtistOrigin(wikidata: _wikidataOf(links));
  }

  // shortcut: every X?? code (XW worldwide, XE Europe...) is dropped, Kosovo (XK) with them; upgrade if one is missed.
  static String? _iso(Object? code) {
    if (code is! String || !RegExp(r'^[A-Za-z]{2}$').hasMatch(code) || code.toUpperCase().startsWith('X')) return null;
    return code.toUpperCase();
  }

  /// The Wikidata item of the artist (`Q…`), or null.
  Future<String?> artistWikidata(String artistId, {CancelToken? cancel}) async {
    final data = await _get('artist/$artistId', {'inc': 'url-rels'}, cancel);
    return _wikidataOf(data);
  }

  /// The Wikidata item of the *song* a recording is a performance of, or null
  /// (many recordings have no work, and many works no page).
  Future<String?> songWikidata(String recordingId, {CancelToken? cancel}) async {
    final rec = await _get('recording/$recordingId', {'inc': 'work-rels'}, cancel);
    final rels = rec?['relations'];
    if (rels is! List) return null;
    for (final r in rels) {
      final work = r is Map ? r['work'] : null;
      if (work is! Map || work['id'] is! String) continue;
      final data = await _get('work/${work['id']}', {'inc': 'url-rels'}, cancel);
      final q = _wikidataOf(data);
      if (q != null) return q;
    }
    return null;
  }

  static final _discogsMaster = RegExp(r'discogs\.com/master/(\d+)');

  /// The Discogs master id linked from the release-group (the album) a
  /// recording appears on, or null. Two requests; the link sits on the
  /// release-group, not on the release.
  Future<int?> discogsMasterOf(String recordingId, {CancelToken? cancel}) async {
    final rec = await _get('recording/$recordingId', {'inc': 'releases+release-groups'}, cancel);
    final releases = rec?['releases'];
    if (releases is! List) return null;
    var tried = 0;
    final seen = <String>{};
    for (final r in releases) {
      final rg = r is Map ? r['release-group'] : null;
      if (rg is! Map || rg['id'] is! String) continue;
      // Plain albums only: a single, compilation or live master speaks of another thing.
      if (rg['primary-type'] != 'Album') continue;
      final secondary = rg['secondary-types'];
      if (secondary is List && secondary.isNotEmpty) continue;
      if (!seen.add(rg['id'] as String)) continue;
      if (++tried > 3) break;
      final data = await _get('release-group/${rg['id']}', {'inc': 'url-rels'}, cancel);
      final rels = data?['relations'];
      if (rels is! List) continue;
      for (final rel in rels) {
        if (rel is! Map || rel['type'] != 'discogs') continue;
        final url = rel['url'];
        final res = url is Map ? url['resource'] : null;
        final m = res is String ? _discogsMaster.firstMatch(res) : null;
        if (m != null) return int.parse(m.group(1)!);
      }
    }
    return null;
  }

  static final _qid = RegExp(r'/(Q\d+)$');

  static String? _wikidataOf(Map? data) {
    final rels = data?['relations'];
    if (rels is! List) return null;
    for (final r in rels) {
      if (r is! Map || r['type'] != 'wikidata') continue;
      final url = r['url'];
      final res = url is Map ? url['resource'] : null;
      final m = res is String ? _qid.firstMatch(res) : null;
      if (m != null) return m.group(1);
    }
    return null;
  }
}

/// Wikidata: from an item to the title of its Wikipedia page, in each language.
class WikidataClient {
  WikidataClient(this._web);

  final WebClient _web;

  /// For each item in [ids], its page title per language of [langs] (`it` →
  /// «Pink Floyd»); items or languages without a page are absent.
  Future<Map<String, Map<String, String>>> sitelinks(List<String> ids, List<String> langs,
      {CancelToken? cancel}) async {
    if (ids.isEmpty || langs.isEmpty) return const {};
    final data = await _web.getJson(
      'https://www.wikidata.org/w/api.php',
      query: {
        'action': 'wbgetentities',
        'ids': ids.join('|'),
        'props': 'sitelinks',
        'sitefilter': langs.map((l) => '${l}wiki').join('|'),
        'format': 'json',
      },
      cancel: cancel,
    );
    final entities = data is Map ? data['entities'] : null;
    if (entities is! Map) return const {};
    final out = <String, Map<String, String>>{};
    for (final e in entities.entries) {
      final links = e.value is Map ? (e.value as Map)['sitelinks'] : null;
      if (links is! Map) continue;
      final byLang = <String, String>{};
      for (final l in langs) {
        final t = links['${l}wiki'];
        if (t is Map && t['title'] is String) byLang[l] = t['title'] as String;
      }
      if (byLang.isNotEmpty) out['${e.key}'] = byLang;
    }
    if (out.isEmpty) AppLog.i('wikidata: no pages for $ids');
    return out;
  }

  /// The ISO 3166-1 alpha-2 code of the country of item [id]: its citizenship (P27), else
  /// its country of origin (P495, bands), through the country's own code (P297). Null when
  /// the item has none. Strict: an unreachable service throws [WebUnavailableException].
  Future<String?> countryOf(String id, {CancelToken? cancel}) async {
    final own = (await _claims([id], cancel))[id];
    var countries = _items(own?['P27']);
    if (countries.isEmpty) countries = _items(own?['P495']);
    if (countries.isEmpty) return null;
    final claims = await _claims(countries, cancel);
    for (final c in countries) {
      final list = claims[c]?['P297'];
      final value = list is List && list.isNotEmpty ? _mainValue(list.first) : null;
      if (value is String && RegExp(r'^[A-Z]{2}$').hasMatch(value)) return value;
    }
    return null;
  }

  Future<Map<String, Map>> _claims(List<String> ids, CancelToken? cancel) async {
    final data = await _web.getJson(
      'https://www.wikidata.org/w/api.php',
      query: {'action': 'wbgetentities', 'ids': ids.join('|'), 'props': 'claims', 'format': 'json'},
      cancel: cancel,
      strict: true,
    );
    final entities = data is Map ? data['entities'] : null;
    if (entities is! Map) return const {};
    return {
      for (final e in entities.entries)
        if (e.value is Map && (e.value as Map)['claims'] is Map) '${e.key}': (e.value as Map)['claims'] as Map,
    };
  }

  // shortcut: at most 3 countries are read (the first listed); upgrade if dual citizens come out wrong.
  static List<String> _items(Object? statements) => [
        if (statements is List)
          for (final s in statements)
            if (_mainValue(s) case {'id': final String id}) id,
      ].take(3).toList();

  static Object? _mainValue(Object? statement) {
    final snak = statement is Map ? statement['mainsnak'] : null;
    final data = snak is Map ? snak['datavalue'] : null;
    return data is Map ? data['value'] : null;
  }
}

import 'dart:isolate';

const _diacritics = <String, String>{
  'àáâãäåāăą': 'a', 'ç': 'c', 'ćčĉċ': 'c', 'ďđ': 'd', 'èéêëēėęěĕ': 'e',
  'ĝğġ': 'g', 'ìíîïīĩįı': 'i', 'ñńňņ': 'n', 'òóôõöøōőŏ': 'o', 'ŕřŗ': 'r',
  'śšşŝș': 's', 'ťţț': 't', 'ùúûüūůűŭũų': 'u', 'ýÿŷ': 'y', 'źżž': 'z',
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe', 'ł': 'l',
};

// Only for search (searchFold): Vietnamese letters. Not in `normalize`, which
// builds persisted keys (album_key) and must not change.
const _searchOnly = <String, String>{
  'ạảấầẩẫậắằẳẵặ': 'a', 'ẹẻẽếềểễệ': 'e', 'ỉị': 'i', 'ọỏốồổỗộơớờởỡợ': 'o',
  'ụủứừửữựư': 'u', 'ỳỵỷỹ': 'y',
};

Map<int, String> _mapOf(Iterable<Map<String, String>> tables) => {
      for (final t in tables)
        for (final e in t.entries)
          for (final r in e.key.runes) r: e.value,
    };

final Map<int, String> _diacriticMap = _mapOf([_diacritics]);
final Map<int, String> _searchMap = _mapOf([_diacritics, _searchOnly]);

String stripDiacritics(String s) => _strip(s, _diacriticMap, false);

String _strip(String s, Map<int, String> map, bool skipCombining) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if (skipCombining && r >= 0x300 && r <= 0x36F) continue; // NFD marks
    final lower = String.fromCharCode(r).toLowerCase().runes.first;
    final rep = map[lower];
    if (rep == null) {
      out.writeCharCode(r);
    } else {
      final isUpper = String.fromCharCode(r) != String.fromCharCode(r).toLowerCase();
      out.write(isUpper ? rep.toUpperCase() : rep);
    }
  }
  return out.toString();
}

final _spaces = RegExp(r'\s+');

/// Stable key text (album keys, matching): do not change what it returns.
String normalize(String s) =>
    stripDiacritics(s).toLowerCase().trim().replaceAll(_spaces, ' ');

/// Folding for search only: like [normalize] plus NFD marks and Vietnamese.
String searchFold(String s) =>
    _strip(s, _searchMap, true).toLowerCase().trim().replaceAll(_spaces, ' ');

// The normalised fields of each list, made once per list, not at every key
// typed (D-500). shortcut: keyed on the list only, so every caller of one list
// must pass the same `fields`; make the key (list, fields) if that changes.
final _haystacks = Expando<List<String>>();

String _haystack<T>(T i, Iterable<String?> Function(T) fields) =>
    fields(i).map((f) => searchFold(f ?? '')).join('\n');

List<String> _normaliseAll(List<String> raw) =>
    [for (final r in raw) r.split('\n').map(searchFold).join('\n')];

final _priming = Expando<Future<void>>();

/// Makes the haystacks of a big [items] in another isolate, so the search does
/// not do it on the UI thread at the first key. Without it [filterByText]
/// makes them on the spot (fine for small lists). Calls on one list share
/// the same work.
Future<void> primeHaystacks<T>(
  List<T> items,
  Iterable<String?> Function(T) fields,
) {
  if (_haystacks[items] != null) return Future.value();
  return _priming[items] ??= () async {
    try {
      await null; // so a failure before any real await still clears after the caller stored the future
      final raw = [for (final i in items) fields(i).map((f) => f ?? '').join('\n')];
      _haystacks[items] ??= await Isolate.run(() => _normaliseAll(raw));
    } finally {
      _priming[items] = null; // a failure is not kept: the next key retries
    }
  }();
}

/// [items] whose [fields] contain [query] (case and accents ignored); all of
/// them for an empty query. One filter for every in-memory search (D-490).
List<T> filterByText<T>(
  List<T> items,
  String query,
  Iterable<String?> Function(T) fields,
) {
  final needle = searchFold(query);
  if (needle.isEmpty) return items;
  final hay = _haystacks[items] ??= [for (final i in items) _haystack(i, fields)];
  return [
    for (var k = 0; k < items.length; k++)
      if (hay[k].contains(needle)) items[k],
  ];
}

const _unknownAlbums = {'album sconosciuto', 'unknown', 'unknown album'};

String computeAlbumKey({
  String? albumArtist,
  String? artist,
  String? album,
  required String directory,
}) {
  final albumPart = normalize(album ?? '');
  if (albumPart.isEmpty || _unknownAlbums.contains(albumPart)) {
    return 'unknown|${normalize(directory)}';
  }
  final artistPart = normalize(albumArtist ?? artist ?? '');
  return '$artistPart|$albumPart';
}

final _illegalChars = RegExp(r'[\\/:*?"<>|%\u0000-\u001F]');
final _reserved = RegExp(r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$',
    caseSensitive: false);

String sanitizeFileName(String name) {
  var s = name.replaceAll(_illegalChars, '');
  s = s.replaceAll(RegExp(r' {2,}'), ' ').trim();
  s = s.replaceAll(RegExp(r'[. ]+$'), '');
  s = s.replaceAll(RegExp(r'^\.+'), '');
  final dot = s.lastIndexOf('.');
  final stem = dot > 0 ? s.substring(0, dot) : s;
  if (_reserved.hasMatch(stem)) s = '_$s';
  final runes = s.runes.toList();
  if (runes.length > 120) s = String.fromCharCodes(runes.take(120));
  s = s.replaceAll(RegExp(r'[. ]+$'), '');
  return s.isEmpty ? 'track' : s;
}

final _entity = RegExp(r'&(#x[0-9a-fA-F]+|#\d+|amp|lt|gt|quot|apos);');

/// Decodes the HTML entities some yt-dlp listings leave in titles
/// (`Tom &amp; Jerry`). Anything that is not one of them stays as it is.
String htmlUnescape(String s) {
  if (!s.contains('&')) return s;
  return s.replaceAllMapped(_entity, (m) {
    final e = m[1]!;
    switch (e) {
      case 'amp':
        return '&';
      case 'lt':
        return '<';
      case 'gt':
        return '>';
      case 'quot':
        return '"';
      case 'apos':
        return "'";
    }
    final code = e.startsWith('#x')
        ? int.tryParse(e.substring(2), radix: 16)
        : int.tryParse(e.substring(1));
    if (code == null || code <= 0 || code > 0x10FFFF) return m[0]!;
    return String.fromCharCode(code);
  });
}

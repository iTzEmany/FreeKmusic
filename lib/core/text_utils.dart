const _diacritics = <String, String>{
  'àáâãäåāăą': 'a', 'ç': 'c', 'ćčĉċ': 'c', 'ďđ': 'd', 'èéêëēėęěĕ': 'e',
  'ĝğġ': 'g', 'ìíîïīĩįı': 'i', 'ñńňņ': 'n', 'òóôõöøōőŏ': 'o', 'ŕřŗ': 'r',
  'śšşŝș': 's', 'ťţț': 't', 'ùúûüūůűŭũų': 'u', 'ýÿŷ': 'y', 'źżž': 'z',
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe', 'ł': 'l',
};

final Map<int, String> _diacriticMap = {
  for (final e in _diacritics.entries)
    for (final r in e.key.runes) r: e.value,
};

String stripDiacritics(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    final lower = String.fromCharCode(r).toLowerCase().runes.first;
    final rep = _diacriticMap[lower];
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

String normalize(String s) =>
    stripDiacritics(s).toLowerCase().trim().replaceAll(_spaces, ' ');

// The normalised fields of each list, made once per list (a new list comes
// only when the data changes), not again at every key typed (D-500).
// shortcut: keyed on the list only, so every caller of one list must pass the
// same `fields`; make the key (list, fields) if that ever changes.
final _haystacks = Expando<List<String>>();

/// [items] whose [fields] contain [query] (case and accents ignored); all of
/// them for an empty query. One filter for every in-memory search (D-490).
List<T> filterByText<T>(
  List<T> items,
  String query,
  Iterable<String?> Function(T) fields,
) {
  final needle = normalize(query);
  if (needle.isEmpty) return items;
  final hay = _haystacks[items] ??= [
    for (final i in items) fields(i).map((f) => normalize(f ?? '')).join('\n'),
  ];
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

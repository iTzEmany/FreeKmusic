import '../../core/text_utils.dart';

/// [original]: the file title without the cover words, to search the original with.
/// [remixOnly]: the only hint is «remix» (an artist may remix their own song).
typedef CoverHint = ({bool cover, String original, bool remixOnly});

// «cover» / «remix» / «arrangement» are no hint as the first word («Cover Me»).
final _word = RegExp(
    r'\b(cover(?!\s+(me|up)\b)|remix(?:ed)?|arrangement|(?:piano|orchestral)\s+version)\b',
    caseSensitive: false);
final _group = RegExp(r'[\(\[][^\)\]]*[\)\]]');
// «by» needs two words before it and a name after it: not «Stand By Me».
final _by = RegExp(r'^(\S+(?:\s+\S+)+?)\s+by\s+(.+)$', caseSensitive: false);
const _notNames = {'me', 'you', 'my', 'your', 'the', 'a', 'an', 'us', 'him', 'her', 'them', 'now', 'and'};

/// D-303: does the file [title] say it is a cover, an arrangement or a remix?
/// [artist] is the file's artist: «by X» counts when X is somebody else.
/// shortcut: «Walking by Someone» (a real title with a name after «by») is a false hit; it only adds a search.
CoverHint coverHint(String title, String? artist) {
  var t = title.trim();
  var cover = false, other = false;
  void hit(String w) {
    cover = true;
    if (!w.toLowerCase().startsWith('remix')) other = true;
  }

  // A bracket group with a cover word goes whole.
  t = t.replaceAllMapped(_group, (m) {
    final w = _word.firstMatch(m[0]!);
    if (w == null) return m[0]!;
    hit(w[1]!);
    return '';
  });
  // A bare cover word (not the first) cuts the rest: «Believer Romy Wave Cover Not So Good Remix».
  final bare = _word.firstMatch(t);
  if (bare != null && bare.start > 0) {
    hit(bare[1]!);
    t = t.substring(0, bare.start);
  }
  final by = _by.firstMatch(t);
  if (by != null) {
    final who = normalize(by[2]!);
    final a = normalize(artist ?? '');
    if (who.isNotEmpty && !_notNames.contains(who.split(' ').first) && !(a.isNotEmpty && (a.contains(who) || who.contains(a)))) {
      cover = other = true;
      t = by[1]!;
    }
  }
  return (cover: cover, remixOnly: cover && !other, original: t.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\s\-–—]+$'), '').trim());
}

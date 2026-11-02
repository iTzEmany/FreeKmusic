import '../../core/text_utils.dart';

/// [original]: the file title without the cover words, to search the original with.
/// [remixOnly]: the only hint is «remix» (an artist may remix their own song).
typedef CoverHint = ({bool cover, String original, bool remixOnly});

// In brackets any of these counts.
final _word = RegExp(
    r'\b(cover(?!\s+(me|up)\b)|remix(?:ed)?|arrangement|(?:piano|orchestral)\s+version)\b',
    caseSensitive: false);
// Outside brackets only shapes that read as a label count: «Piano Cover», «- Cover», «Name Cover … Remix».
// «Take Cover», «Under Cover of Darkness», «Sad Arrangement» are titles.
final _bare = RegExp(
    r'\b(?:remix(?:ed)?|(?:piano|orchestral)\s+version)\b'
    r'|\b(?:piano|acoustic|guitar|instrumental|orchestral|violin|lofi|metal|rock|jazz)\s+(?:cover|arrangement)\b'
    r'|[-–—|]\s*(?:cover|arrangement)\s*$'
    r'|\bcover\b(?=.*\bremix)',
    caseSensitive: false);
final _group = RegExp(r'[\(\[][^\)\]]*[\)\]]');
// «by» needs two words before it and a name after it: not «Stand By Me».
final _by = RegExp(r'^(\S+(?:\s+\S+)+?)\s+by\s+(.+)$', caseSensitive: false);
const _notNames = {'me', 'you', 'my', 'your', 'the', 'a', 'an', 'us', 'him', 'her', 'them', 'now', 'and'};

/// D-303: does the file [title] say it is a cover, an arrangement or a remix?
/// [artist] is the file's artist: «by X» counts when X is somebody else.
/// shortcut: «Walking by Someone» (a real title with a name after «by») is a false hit; it only adds a search.
///
/// «X by Y» names the performer: it counts only when [byCounts], and Y is neither [artist] nor [identityArtist].
CoverHint coverHint(String title, String? artist, {String? identityArtist, bool byCounts = true}) {
  // Capped: the regexes below are quadratic on huge input.
  var t = title.trim();
  if (t.length > 300) t = t.substring(0, 300);
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
  final bare = _bare.firstMatch(t);
  if (bare != null && bare.start > 0) {
    hit(bare[0]!.replaceFirst(RegExp(r'^[-–—|\s]+'), ''));
    t = t.substring(0, bare.start);
  }
  final by = byCounts ? _by.firstMatch(t) : null;
  if (by != null) {
    final who = normalize(by[2]!);
    bool same(String? name) {
      final a = normalize(name ?? '');
      return a.isNotEmpty && (a.contains(who) || who.contains(a));
    }

    if (who.isNotEmpty && !_notNames.contains(who.split(' ').first) && !same(artist) && !same(identityArtist)) {
      cover = other = true;
      t = by[1]!;
    }
  }
  return (cover: cover, remixOnly: cover && !other, original: t.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'[\s\-–—]+$'), '').trim());
}

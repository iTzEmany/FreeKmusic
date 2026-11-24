import '../../core/app_log.dart';
import '../share/share_fragment.dart';
import 'external_links.dart';
import 'youtube_urls.dart';

/// Text another app shared with Codecore, told apart by what it holds.
sealed class SharedText {
  const SharedText();
}

/// Holds a YouTube, Spotify or Deezer page (or a short link to one).
class SharedLink extends SharedText {
  const SharedLink(this.url);
  final String url;
}

/// A song Shazam shared: `<title> di <artist> https://www.shazam.com/track/<id>/<slug>`.
class ShazamShare extends SharedText {
  const ShazamShare(this.title, this.artist, [this.shazamUrl]);
  final String title, artist;
  final String? shazamUrl;
}

/// A link of the share page (D-702) whose fragment holds a list of tracks.
class SharedCollection extends SharedText {
  const SharedCollection(this.fragment);
  final SharedFragment fragment;
}

/// A link of the share page whose fragment cannot be read: «link non valido».
class InvalidShareLink extends SharedText {
  const InvalidShareLink();
}

/// Anything else: goes to Cerca as typed.
class PlainShare extends SharedText {
  const PlainShare(this.text);
  final String text;
}

// The page address, scheme and host in any case. A token that starts with it (then «/», «?»,
// «#» or the end) is ours: without a readable fragment it is an invalid link, not a search.
final _pageBase = RegExp.escape(kSharePageUrl.substring(0, kSharePageUrl.length - 1));
final _sharePrefix = RegExp('^$_pageBase(?=[/?#]|\$)', caseSensitive: false);
final _sharePage = RegExp('^$_pageBase/?(?:index\\.html)?(?:\\?[^#]*)?#(.*)\$', caseSensitive: false);
final _wrapChars = RegExp('^[.,)!(<>"\']+|[.,)!(<>"\']+\$');

SharedText? _parseSharePage(String raw) {
  final token = raw.replaceAll(_wrapChars, '');
  if (!_sharePrefix.hasMatch(token)) return null;
  final m = _sharePage.firstMatch(token);
  if (m == null) return const InvalidShareLink();
  try {
    return SharedCollection(decodeShareFragment(m[1]!));
  } on ShareFragmentError catch (e) {
    AppLog.d('share page link not readable: $e');
    return const InvalidShareLink();
  }
}

bool _isKnownLink(String s) =>
    parseExternalLink(s) != null ||
    isShortLink(s) ||
    classifyYoutubeUrl(s) != YoutubeLinkKind.other;

// One row per language, each proven by a real fixture in test/fixtures/shazam/
// (R-210): a new language = a new real fixture + one row here. Nothing is guessed.
// shortcut: the split is on the LAST « di » before the link, so a title with « di »
// works ("Il mare di notte di X") but an artist with « di » does not; upgrade when
// a real fixture shows one.
final _shazamTemplates = [
  RegExp(r'^(.+) di (.+) (https://www\.shazam\.com/track/\d+/\S*)$'), // it-IT, Shazam 9.50
];

ShazamShare? _parseShazam(String body) {
  for (final t in _shazamTemplates) {
    final m = t.firstMatch(body);
    if (m == null) continue;
    final (title, artist) = (m[1]!.trim(), m[2]!.trim());
    if (title.isNotEmpty && artist.isNotEmpty) return ShazamShare(title, artist, m[3]);
  }
  return null; // a shazam.com link alone says nothing: slug is not enough (R-209)
}

/// The first known link in [text]; [subject] only stands in for an empty text.
SharedText routeSharedText(String text, {String? subject}) {
  final body = text.trim().isEmpty ? (subject ?? '').trim() : text.trim();
  final tokens = body.split(RegExp(r'\s+'));
  // The share page wins over any other link in the text (a title may hold a YouTube one).
  for (final token in tokens) {
    final page = _parseSharePage(token);
    if (page != null) return page;
  }
  final shazam = _parseShazam(body);
  if (shazam != null) return shazam;
  for (final token in tokens) {
    if (_isKnownLink(token)) return SharedLink(token);
  }
  return PlainShare(body);
}

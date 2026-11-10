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

/// Anything else: goes to Cerca as typed.
class PlainShare extends SharedText {
  const PlainShare(this.text);
  final String text;
}

bool _isKnownLink(String s) =>
    parseExternalLink(s) != null ||
    isShortLink(s) ||
    classifyYoutubeUrl(s) != YoutubeLinkKind.other;

/// The first known link in [text]; [subject] only stands in for an empty text.
SharedText routeSharedText(String text, {String? subject}) {
  final body = text.trim().isEmpty ? (subject ?? '').trim() : text.trim();
  for (final token in body.split(RegExp(r'\s+'))) {
    if (_isKnownLink(token)) return SharedLink(token);
  }
  return PlainShare(body);
}

import 'package:path/path.dart' as p;

import '../online/youtube_service.dart' show YtErrorKind;

/// One episode as a feed lists it.
class PodcastEpisodeInfo {
  const PodcastEpisodeInfo({
    required this.guid,
    required this.title,
    required this.audioUrl,
    this.publishedAt,
    this.duration,
    this.mimeType,
    this.sizeBytes,
    this.description,
  });

  /// The feed's own id for the episode (the enclosure address when it has none).
  final String guid;
  final String title;
  final String audioUrl;
  final DateTime? publishedAt;
  final Duration? duration;
  final String? mimeType;
  final int? sizeBytes;

  /// Plain text: tags stripped, entities decoded.
  final String? description;
}

/// What a feed says about the show and its episodes.
class PodcastFeed {
  const PodcastFeed({
    required this.title,
    required this.episodes,
    this.author,
    this.description,
    this.imageUrl,
    this.language,
    this.skipped = 0,
  });

  final String title;
  final String? author, description, imageUrl, language;
  final List<PodcastEpisodeInfo> episodes;

  /// Items left out because they carry no audio.
  final int skipped;
}

/// A result of the public podcast search.
class PodcastSearchHit {
  const PodcastSearchHit({
    required this.name,
    required this.feedUrl,
    this.author,
    this.artworkUrl,
    this.episodeCount,
  });

  final String name, feedUrl;
  final String? author, artworkUrl;
  final int? episodeCount;
}

enum PodcastErrorKind {
  /// Not an http(s) address.
  invalidUrl,

  /// The feed is bigger than the limit.
  tooLarge,

  /// Could not be reached, or the server answered with an error.
  network,

  /// It arrived but is not an RSS feed.
  notFeed,

  /// The episode is in a format the player does not handle.
  unsupportedFormat,
}

class PodcastException implements Exception {
  const PodcastException(this.kind, [this.detail, this.yt]);

  final PodcastErrorKind kind;
  final String? detail;

  /// Why yt-dlp / YouTube Music failed, when it did (the text is the `yt*` one).
  final YtErrorKind? yt;

  @override
  String toString() => 'PodcastException($kind${detail == null ? '' : ', $detail'})';
}

/// Downloads a feed's text (http or https, size-limited).
typedef FeedFetcher = Future<String> Function(String url);

/// Reads RSS text. Throws [FormatException] when it is not an RSS feed.
typedef FeedParser = Future<PodcastFeed> Function(String xml);

/// Feeds bigger than this are refused.
const maxFeedBytes = 20 * 1024 * 1024;

/// `Podcasts.source` of a YouTube Music show (0 is an RSS feed).
const kPodcastSourceYtm = 1;

/// The audio containers an episode may come in, by the extension we save it as.
const episodeExtensions = {'mp3', 'm4a', 'ogg', 'opus'};

/// `mp3`, `m4a`, `ogg` or `opus` from what the server says, else from the
/// address, else from what the feed said; null when none of them is known.
String? episodeExtension({String? contentType, String? url, String? mime}) {
  String? fromMime(String? m) {
    final t = (m ?? '').toLowerCase().split(';').first.trim();
    return switch (t) {
      'audio/mpeg' || 'audio/mp3' || 'audio/mpeg3' || 'audio/x-mpeg' => 'mp3',
      'audio/mp4' || 'audio/x-m4a' || 'audio/m4a' || 'audio/aac' || 'audio/x-aac' => 'm4a',
      'audio/ogg' || 'application/ogg' || 'audio/vorbis' => 'ogg',
      'audio/opus' => 'opus',
      _ => null,
    };
  }

  String? fromUrl(String? u) {
    final path = Uri.tryParse(u ?? '')?.path ?? '';
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    if (ext == 'mp4') return 'm4a';
    return episodeExtensions.contains(ext) ? ext : null;
  }

  return fromMime(contentType) ?? fromUrl(url) ?? fromMime(mime);
}

/// The albumKey every episode of a podcast shares (its cover hangs on it).
String podcastAlbumKeyOf(int podcastId) => 'podcast|$podcastId';

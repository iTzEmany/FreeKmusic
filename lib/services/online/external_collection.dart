import 'youtube_service.dart' show YtResult;

enum CollectionKind { playlist, album }

/// A list of songs that lives outside the library (a YouTube playlist today;
/// Spotify and Deezer links join in phase 114).
class ExternalCollection {
  const ExternalCollection({
    required this.title,
    required this.kind,
    required this.tracks,
    required this.sourceUrl,
    this.coverUrl,
    this.owner,
    this.declaredTotal,
    this.truncated = false,
  });

  final String title;
  final CollectionKind kind;
  final List<ExternalTrack> tracks;
  final String sourceUrl;
  final String? coverUrl, owner;

  /// What the source says it holds, when it says.
  final int? declaredTotal;

  /// More songs exist than were read.
  final bool truncated;
}

class ExternalTrack {
  const ExternalTrack({
    required this.title,
    required this.artists,
    required this.key,
    this.durationMs,
    this.isrc,
  });

  final String title;
  final List<String> artists;
  final int? durationMs;
  final String? isrc;

  /// Stable id of the song inside its collection.
  final String key;
}

/// What a track of a collection resolved to. A page draws one row per case.
sealed class TrackMatch {
  const TrackMatch();
}

class TrackPending extends TrackMatch {
  const TrackPending();
}

class TrackReady extends TrackMatch {
  const TrackReady(this.result);
  final YtResult result;
}

class TrackNotFound extends TrackMatch {
  const TrackNotFound();
}

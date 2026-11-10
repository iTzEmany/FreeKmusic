import 'package:dio/dio.dart' show CancelToken;

import '../../core/import_row.dart';
import '../../data/db/app_database.dart' show Track;
import 'external_links.dart';
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

  ImportRow toImportRow(int index) => ImportRow(
        index: index,
        title: title,
        artists: artists,
        durationMs: durationMs,
        isrc: isrc,
      );
}

/// The link points at nothing (deleted, private, wrong id).
class CollectionNotFound implements Exception {
  const CollectionNotFound();
  @override
  String toString() => 'CollectionNotFound';
}

/// The page exists but could not be read (network, layout change).
class CollectionUnreadable implements Exception {
  const CollectionUnreadable([this.cause]);
  final Object? cause;
  @override
  String toString() => 'CollectionUnreadable($cause)';
}

abstract interface class ExternalReader {
  Future<ExternalCollection> read(ExternalLink link, {CancelToken? cancelToken});
}

/// What a track of a collection resolved to. A page draws one row per case.
sealed class TrackMatch {
  const TrackMatch();
}

class TrackPending extends TrackMatch {
  const TrackPending();
}

/// Found: a song to stream ([TrackReady.online]) or one already in the library.
sealed class TrackReady extends TrackMatch {
  const TrackReady();
  const factory TrackReady.online(YtResult result) = TrackReadyOnline;
  const factory TrackReady.library(Track track) = TrackReadyLibrary;
}

class TrackReadyOnline extends TrackReady {
  const TrackReadyOnline(this.result);
  final YtResult result;
}

class TrackReadyLibrary extends TrackReady {
  const TrackReadyLibrary(this.track);
  final Track track;
}

class TrackNotFound extends TrackMatch {
  const TrackNotFound();
}

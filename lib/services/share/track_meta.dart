import '../../data/db/app_database.dart';
import '../online/credits.dart';
import '../online/lrc_parser.dart';
import '../stream/stream_key.dart' show ytIdRe;

final _isrcRe = RegExp(r'^[A-Z]{2}[A-Z0-9]{3}\d{7}$');

const kMaxMetaCredits = 200;

/// The metadata that travels with a shared track. Untrusted input: every
/// field is validated alone and a bad one becomes null, never the whole pack.
class TrackMeta {
  const TrackMeta({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.year,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.isrc,
    this.lyricsPlain,
    this.lyricsSynced,
    this.enrichStatus,
    this.youtubeId,
    this.curiosities,
    this.credits = const [],
    this.details,
  });

  /// `youtubeId` has no column on [Track] yet: null here.
  factory TrackMeta.fromTrack(
    Track t, {
    List<TrackCredit> credits = const [],
    TrackDetails? details,
  }) => TrackMeta(
    title: t.title,
    artist: t.artist,
    albumArtist: t.albumArtist,
    album: t.album,
    year: t.year,
    genre: t.genre,
    trackNumber: t.trackNumber,
    discNumber: t.discNumber,
    isrc: t.isrc,
    lyricsPlain: t.lyricsPlain,
    lyricsSynced: t.lyricsSynced,
    enrichStatus: t.enrichStatus,
    // A list row carries '' for "has some" (light_tracks): not a text.
    curiosities: (t.curiosities ?? '').isEmpty ? null : t.curiosities,
    credits: credits.take(kMaxMetaCredits).toList(),
    details: details,
  );

  final String? title, artist, albumArtist, album, genre;
  final int? year, trackNumber, discNumber, enrichStatus;
  final String? isrc, lyricsPlain, lyricsSynced, youtubeId;

  /// Jam info screen only: never applied to a row by the share path.
  final String? curiosities;

  /// Credits (at most [kMaxMetaCredits]) and Deezer details of the owner.
  final List<TrackCredit> credits;
  final TrackDetails? details;

  Map<String, Object?> toJson() => {
    if (title != null) 'title': title,
    if (artist != null) 'artist': artist,
    if (albumArtist != null) 'albumArtist': albumArtist,
    if (album != null) 'album': album,
    if (year != null) 'year': year,
    if (genre != null) 'genre': genre,
    if (trackNumber != null) 'trackNumber': trackNumber,
    if (discNumber != null) 'discNumber': discNumber,
    if (isrc != null) 'isrc': isrc,
    if (lyricsPlain != null) 'lyricsPlain': lyricsPlain,
    if (lyricsSynced != null) 'lyricsSynced': lyricsSynced,
    if (enrichStatus != null) 'enrichStatus': enrichStatus,
    if (youtubeId != null) 'youtubeId': youtubeId,
    if (curiosities != null) 'curiosities': curiosities,
    if (credits.isNotEmpty) 'credits': [for (final c in credits) c.toJson()],
    if (details != null) 'details': details!.toJson(),
  };

  /// Never throws: a non-map gives null, a bad field gives a null field.
  static TrackMeta? tryParse(Object? raw) {
    if (raw is! Map) return null;
    String? text(String k, int max) {
      final v = raw[k];
      return v is String ? (v.length > max ? v.substring(0, max) : v) : null;
    }

    int? num(String k, int min, int max) {
      final v = raw[k];
      return v is int && v >= min && v <= max ? v : null;
    }

    String? lyrics(String k, int max) {
      final v = raw[k];
      return v is String && v.length <= max ? v : null;
    }

    final isrc = text('isrc', 64)?.toUpperCase();
    final synced = lyrics('lyricsSynced', 40000);
    final yt = raw['youtubeId'];
    return TrackMeta(
      title: text('title', 200),
      artist: text('artist', 200),
      albumArtist: text('albumArtist', 200),
      album: text('album', 200),
      year: num('year', 1000, DateTime.now().year + 1),
      genre: text('genre', 100),
      trackNumber: num('trackNumber', 1, 999),
      discNumber: num('discNumber', 1, 999),
      isrc: isrc != null && _isrcRe.hasMatch(isrc) ? isrc : null,
      lyricsPlain: lyrics('lyricsPlain', 20000),
      lyricsSynced: synced != null && parseLrc(synced).isNotEmpty
          ? synced
          : null,
      enrichStatus: num('enrichStatus', 0, 2),
      youtubeId: yt is String && ytIdRe.hasMatch(yt) ? yt : null,
      curiosities: lyrics('curiosities', 20000),
      credits: parseCreditList(raw['credits'], max: kMaxMetaCredits),
      details: raw['details'] is Map ? TrackDetails.fromJson(raw['details'] as Map) : null,
    );
  }
}

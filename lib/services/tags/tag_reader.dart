class TagInfo {
  const TagInfo({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
    this._genres = const [],
    this.trackNumber,
    this.discNumber,
    this.year,
    this.durationMs,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.channels,
    this.coverBytes,
    this.coverMime,
    this.replayGainDb,
    this.isrc,
    this.mbid,
  });

  final String? title, artist, albumArtist, album, genre, isrc, mbid;
  final int? trackNumber, discNumber, year, durationMs;
  final int? bitrateKbps, sampleRateHz, bitDepth, channels;
  final List<int>? coverBytes;
  final String? coverMime;
  final List<String> _genres;

  /// Every genre in tag order, separators already split; the first is [genre].
  /// Without an explicit list it is made from [genre].
  List<String> get genres => _genres.isNotEmpty ? _genres : splitGenres([genre]);

  /// REPLAYGAIN_TRACK_GAIN in dB (negative = quieter), when present.
  final double? replayGainDb;

  /// Same tags with the ISRC and MusicBrainz id set.
  TagInfo withIds({String? isrc, String? mbid}) => TagInfo(
    title: title,
    artist: artist,
    albumArtist: albumArtist,
    album: album,
    genre: genre,
    genres: _genres,
    trackNumber: trackNumber,
    discNumber: discNumber,
    year: year,
    durationMs: durationMs,
    bitrateKbps: bitrateKbps,
    sampleRateHz: sampleRateHz,
    bitDepth: bitDepth,
    channels: channels,
    coverBytes: coverBytes,
    coverMime: coverMime,
    replayGainDb: replayGainDb,
    isrc: isrc,
    mbid: mbid,
  );
}

/// Genres from raw tag values: split on `;`, `/` and NUL (ID3v2.4 lists), trimmed,
/// blanks dropped, repeats (ignoring case) kept once, in order. [slash] false keeps `/` inside a
/// name (web genres such as «Hip-Hop/Rap»).
List<String> splitGenres(Iterable<String?> raw, {bool slash = true}) {
  final sep = slash ? RegExp(r'[;/\u0000]') : RegExp(r'[;\u0000]');
  final seen = <String>{};
  return [
    for (final r in raw)
      if (r != null)
        for (final g in r.split(sep))
          if (g.trim().replaceAll(RegExp(r'\s+'), ' ') case final t when t.isNotEmpty && seen.add(t.toLowerCase())) t,
  ];
}

/// Uppercase, no dashes or spaces; null when nothing is left.
String? normalizeIsrc(String? raw) {
  final t = raw?.replaceAll(RegExp(r'[-\s]'), '').toUpperCase();
  return (t == null || t.isEmpty) ? null : t;
}

/// Parses "-6.50 dB" / "+1.2dB" / "-3"; null when not a number.
double? parseReplayGain(String? raw) {
  if (raw == null) return null;
  // ID3 TXXX values may carry NUL / BOM characters around the text.
  raw = raw.replaceAll(RegExp(r'[\u0000-\u001F\uFEFF]'), ' ');
  final m = RegExp(
    r'^\s*([+-]?\d+(?:[.,]\d+)?)\s*(?:dB)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw);
  if (m == null) return null;
  return double.tryParse(m.group(1)!.replaceAll(',', '.'));
}

abstract class TagReader {
  Future<TagInfo> read(String path, {bool withCover = true});
}

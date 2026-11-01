class TagInfo {
  const TagInfo({
    this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.genre,
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

  /// REPLAYGAIN_TRACK_GAIN in dB (negative = quieter), when present.
  final double? replayGainDb;

  /// Same tags with the ISRC and MusicBrainz id set.
  TagInfo withIds({String? isrc, String? mbid}) => TagInfo(
    title: title,
    artist: artist,
    albumArtist: albumArtist,
    album: album,
    genre: genre,
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

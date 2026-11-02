/// Fields to write into a file's tags; `null` = leave the field as it is.
/// (The tag library cannot erase a field, so a blank value is never written.)
class TagChanges {
  const TagChanges({
    this.title,
    this.artist,
    this.album,
    this.albumArtist,
    this.year,
    this.genre,
    this.trackNumber,
    this.discNumber,
    this.cover,
    this.isrc,
    this.mbid,
  });

  final String? title, artist, album, albumArtist, genre;

  /// Recording ids (ISRC, MusicBrainz): null leaves the file's, an empty string removes it.
  final String? isrc, mbid;
  final int? year, trackNumber, discNumber;

  /// Front cover to embed.
  final TagCover? cover;

  bool get isEmpty =>
      title == null &&
      artist == null &&
      album == null &&
      albumArtist == null &&
      year == null &&
      genre == null &&
      trackNumber == null &&
      discNumber == null &&
      isrc == null &&
      mbid == null &&
      cover == null;
}

class TagCover {
  const TagCover(this.bytes, this.mime);

  final List<int> bytes;
  final String mime;
}

enum TagWriteReason {
  /// The format cannot be written (or the platform has no writer).
  unsupported,
  notFound,

  /// The file or its folder cannot be modified (read-only media, scoped storage).
  readOnly,

  /// The tags read back from the copy differ from what was written.
  verifyFailed,

  /// The tag library failed.
  writeFailed,
  backupFailed,
  ioError,
}

/// Why a file was left untouched. The original is always intact.
class TagWriteException implements Exception {
  const TagWriteException(this.reason, [this.detail]);

  final TagWriteReason reason;
  final String? detail;

  @override
  String toString() =>
      'TagWriteException(${reason.name}${detail == null ? '' : ': $detail'})';
}

/// Writes tags straight into [path]. Use it only through `SafeTagWriter`.
abstract class TagWriter {
  /// [format] is the lower-case extension without the dot.
  bool supports(String format);

  Future<void> write(String path, TagChanges changes);
}

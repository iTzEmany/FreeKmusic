import '../../data/db/app_database.dart';

/// A row-less [Track] carrying only what a lookup reads (title, artist, album, length).
Track syntheticTrack({
  required String title,
  String? artist,
  String? album,
  int durationMs = 0,
  String format = '',
  int kind = 0,
}) =>
    Track(
      id: 0,
      path: '',
      title: title,
      artist: artist,
      album: album,
      albumKey: '',
      durationMs: durationMs,
      format: format,
      sizeBytes: 0,
      mtimeMs: 0,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false,
      kind: kind,
      addedAt: 0,
      playCount: 0,
      coverSource: 0,
    );

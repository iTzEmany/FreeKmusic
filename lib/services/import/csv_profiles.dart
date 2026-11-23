import 'csv_parser.dart';
import 'imported_playlist.dart';
import 'playlist_paths.dart';

/// A playlist CSV is a few hundred KB; anything near these limits is not one.
const kMaxCsvBytes = 5 * 1024 * 1024;
const kMaxCsvRows = 10000;

class CsvTooLargeException extends FormatException {
  const CsvTooLargeException(super.message);
}

/// Throws [CsvTooLargeException] before the file is read into memory.
void checkCsvSize(int bytes) {
  if (bytes > kMaxCsvBytes) {
    throw CsvTooLargeException('CSV of $bytes bytes exceeds $kMaxCsvBytes');
  }
}

/// Column names (lower case) the different services use for the same thing.
/// The first name found in the header wins, in the order written here.
const _titleHeaders = ['track name', 'track', 'title', 'name', 'song', 'song name'];
const _artistHeaders = [
  'artist name(s)',
  'artist name',
  'artists',
  'artist',
  'band',
];
const _albumHeaders = ['album name', 'album', 'album title', 'release'];
const _durationHeaders = [
  'duration (ms)',
  'track duration (ms)',
  'duration_ms',
  'duration',
  'length',
  'track length',
  'time',
];
const _uriHeaders = ['track uri', 'spotify uri', 'spotify id'];
const _playlistHeaders = ['playlist name', 'playlist'];

int? _col(List<String> header, List<String> names) {
  for (final n in names) {
    final i = header.indexOf(n);
    if (i >= 0) return i;
  }
  return null;
}

String? _cell(List<String> row, int? i) {
  if (i == null || i >= row.length) return null;
  final v = row[i].trim();
  return v.isEmpty ? null : v;
}

/// Which service wrote the file, from its header. Only a label (stored with
/// the import): every kind is read by the same column rules.
String detectCsvKind(List<String> header) {
  bool has(String h) => header.contains(h);
  if (has('track uri') || has('artist name(s)')) return 'exportify';
  if (has('uts') || has('utc_time')) return 'lastfm';
  if (has('playlist name') && has('artist name')) return 'tunemymusic';
  if (has('title') && has('artist') && has('album') && has('isrc')) {
    return 'soundiiz';
  }
  return 'csv';
}

/// `ms` when the header says so, else decided from the value: `m:ss` or
/// `h:mm:ss` are clock times, a number of 10 000 or more is milliseconds and a
/// smaller one is seconds (no song is under ten seconds in milliseconds).
int? parseDurationMs(String? raw, {required bool headerSaysMs}) {
  if (raw == null) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  if (s.contains(':')) {
    final parts = s.split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null) || parts.length > 3) return null;
    var secs = 0;
    for (final p in parts) {
      secs = secs * 60 + p!;
    }
    return secs * 1000;
  }
  final n = double.tryParse(s.replaceAll(',', '.'));
  if (n == null || n < 0) return null;
  return (headerSaysMs || n >= 10000) ? n.round() : (n * 1000).round();
}

/// The year of an Exportify `Release Date` («1971-10-11», «1971-10», «1971»);
/// anything else is no year.
int? parseReleaseYear(String? raw) {
  final m = RegExp(r'^(\d{4})(-\d{2}(-\d{2})?)?$').firstMatch(raw?.trim() ?? '');
  final y = m == null ? null : int.parse(m.group(1)!);
  return y != null && y >= 1900 && y <= DateTime.now().year + 1 ? y : null;
}

/// Exportify names the file after the playlist, with spaces turned into `_`.
String playlistNameFromFile(String fileName) {
  final base = fileName.split(RegExp(r'[\\/]')).last;
  final noExt = base.replaceFirst(RegExp(r'\.csv$', caseSensitive: false), '');
  final name = noExt.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return name.isEmpty ? 'Playlist' : name;
}

String _dedupeKey(String title, List<String> artists) =>
    '${title.toLowerCase()}|${artists.join(';').toLowerCase()}';

/// Reads a playlist (or a listening history) from a CSV of Exportify,
/// TuneMyMusic, Soundiiz, Last.fm or any file with a title and an artist
/// column. Throws [FormatException] when there are none.
ImportedPlaylist readCsvPlaylist(String fileName, String text) {
  final table = parseCsv(text);
  if (table.isEmpty) {
    throw const FormatException('not a playlist CSV: empty');
  }
  if (table.length - 1 > kMaxCsvRows) {
    throw CsvTooLargeException('CSV with ${table.length - 1} rows');
  }
  final header = [for (final h in table.first) h.trim().toLowerCase()];
  final titleCol = _col(header, _titleHeaders);
  final artistCol = _col(header, _artistHeaders);
  if (titleCol == null || artistCol == null) {
    throw const FormatException('not a playlist CSV: missing title or artist');
  }
  final albumCol = _col(header, _albumHeaders);
  final durationCol = _col(header, _durationHeaders);
  final isrcCol = _col(header, const ['isrc']);
  final yearCol = _col(header, const ['release date']);
  final uriCol = _col(header, _uriHeaders);
  final playlistCol = _col(header, _playlistHeaders);
  final kind = detectCsvKind(header);
  final msHeader = durationCol != null &&
      (header[durationCol].contains('ms') || header[durationCol].contains('milli'));

  final rows = <ImportRow>[];
  final seen = <String>{};
  final playlistNames = <String>{};
  var skipped = 0;
  for (final r in table.skip(1)) {
    final title = _cell(r, titleCol);
    final uri = _cell(r, uriCol);
    final isTrack = uri == null ||
        !(uri.startsWith('spotify:episode:') || uri.startsWith('spotify:local:'));
    if (title == null || !isTrack) {
      skipped++;
      continue;
    }
    final artists = [
      for (final a in (_cell(r, artistCol) ?? '').split(';'))
        if (a.trim().isNotEmpty) a.trim(),
    ];
    // A listening history repeats songs: keep the first time each appears.
    if (kind == 'lastfm' && !seen.add(_dedupeKey(title, artists))) continue;
    final pl = _cell(r, playlistCol);
    if (pl != null) playlistNames.add(pl);
    rows.add(ImportRow(
      index: rows.length,
      title: title,
      artists: artists,
      album: _cell(r, albumCol),
      durationMs: parseDurationMs(_cell(r, durationCol), headerSaysMs: msHeader),
      isrc: _cell(r, isrcCol),
      spotifyUri: uri,
      location: uri == null ? null : streamPathOfWatchUrl(uri),
      year: parseReleaseYear(_cell(r, yearCol)),
    ));
  }
  return ImportedPlaylist(
    // Services that name the playlist inside the file know better than the file name.
    name: playlistNames.length == 1
        ? playlistNames.single
        : playlistNameFromFile(fileName),
    rows: rows,
    skipped: skipped,
    kind: kind,
  );
}

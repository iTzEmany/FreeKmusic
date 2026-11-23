import 'imported_playlist.dart';
import 'playlist_paths.dart';

/// `.m3u` / `.m3u8`: `#EXTINF:<seconds>,<Artist - Title>` before each path.
/// Web streams keep only their label; unreadable lines are counted in `skipped`.
ImportedPlaylist readM3u(String fileName, String text) {
  final rows = <ImportRow>[];
  var skipped = 0;
  String? name;
  String? label;
  int? seconds;
  for (final raw in text.replaceFirst('\uFEFF', '').split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#')) {
      final upper = line.toUpperCase();
      if (upper.startsWith('#PLAYLIST:')) {
        name = line.substring(10).trim();
      } else if (upper.startsWith('#EXTINF:')) {
        final body = line.substring(8);
        final comma = body.indexOf(',');
        final lenText = comma < 0 ? body : body.substring(0, comma);
        seconds = int.tryParse(lenText.trim().split(RegExp(r'\s')).first);
        label = comma < 0 ? null : body.substring(comma + 1).trim();
      }
      continue;
    }
    final stream = streamPathOfWatchUrl(line);
    final local = stream ?? localPathFromLocation(line);
    final labelParts = label == null || label.isEmpty ? null : splitLabel(label);
    final title =
        labelParts?.title ?? (local == null || stream != null ? null : withoutExtension(basenameOf(local)));
    final artist = labelParts?.artist;
    if (title == null || title.isEmpty) {
      skipped++;
    } else {
      rows.add(ImportRow(
        index: rows.length,
        title: title,
        artists: [if (artist != null && artist.isNotEmpty) artist],
        durationMs: seconds != null && seconds > 0 ? seconds * 1000 : null,
        location: local,
      ));
    }
    label = null;
    seconds = null;
  }
  return ImportedPlaylist(
    name: (name != null && name.isNotEmpty) ? name : _nameFromFile(fileName),
    rows: rows,
    skipped: skipped,
    kind: 'm3u',
  );
}

String _nameFromFile(String fileName) {
  final base = basenameOf(fileName);
  final n = withoutExtension(base).replaceAll('_', ' ').trim();
  return n.isEmpty ? 'Playlist' : n;
}

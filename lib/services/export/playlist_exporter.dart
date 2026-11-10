import 'dart:convert';

import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/track_kinds.dart';
import '../../data/repositories/backup_queries.dart' show trackRefFor;
import '../../core/text_utils.dart';
import '../backup/user_data.dart';
import '../import/csv_parser.dart';

/// M3U8 (UTF-8). Paths are absolute, or relative to [relativeTo] with `/`. A streamed
/// track (`kind = 2`, D-524) has no file: it is left out.
String toM3u8(String name, List<Track> tracks, {String? relativeTo}) {
  final b = StringBuffer('#EXTM3U\n#PLAYLIST:$name\n');
  final files = tracks.where((t) => t.kind != kStreamKind).toList();
  if (files.length != tracks.length) {
    AppLog.i('m3u: ${tracks.length - files.length} streamed tracks not exported');
  }
  for (final t in files) {
    final secs = t.durationMs > 0 ? (t.durationMs / 1000).round() : -1;
    final label = t.artist == null || t.artist!.isEmpty
        ? t.title
        : '${t.artist} - ${t.title}';
    final path = relativeTo == null
        ? t.path
        : p.relative(t.path, from: relativeTo).replaceAll(r'\', '/');
    b.write('#EXTINF:$secs,$label\n$path\n');
  }
  return b.toString();
}

const exportifyHeader = [
  'Track URI',
  'Track Name',
  'Album Name',
  'Artist Name(s)',
  'Duration (ms)',
  'ISRC',
];

/// Same column names Exportify uses, so the CSV import (`readCsvPlaylist`) reads it back.
String toExportifyCsv(List<Track> tracks, Map<int, String> isrcByTrack) =>
    writeCsv([
      exportifyHeader,
      for (final t in tracks)
        [
          '',
          t.title,
          t.album ?? '',
          t.artist ?? '',
          t.durationMs > 0 ? '${t.durationMs}' : '',
          isrcByTrack[t.id] ?? '',
        ],
    ]);

String toPlaylistJson(PlaylistData playlist) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': kUserDataFormat,
      'playlists': [playlist.toJson()],
    });

enum ExportFormat { m3u8, csv, json }

extension ExportFormatX on ExportFormat {
  String get extension => switch (this) {
        ExportFormat.m3u8 => 'm3u8',
        ExportFormat.csv => 'csv',
        ExportFormat.json => 'json',
      };

  String get mimeType => switch (this) {
        ExportFormat.m3u8 => 'audio/x-mpegurl',
        ExportFormat.csv => 'text/csv',
        ExportFormat.json => 'application/json',
      };
}

String exportFileName(String playlistName, ExportFormat f) =>
    '${sanitizeFileName(playlistName)}.${f.extension}';

/// Deepest folder that holds every track (the base for relative M3U8 paths).
String commonDirectory(List<Track> tracks) {
  if (tracks.isEmpty) return '';
  var parts = p.split(p.dirname(tracks.first.path));
  for (final t in tracks.skip(1)) {
    final other = p.split(p.dirname(t.path));
    var n = 0;
    while (n < parts.length && n < other.length && parts[n] == other[n]) {
      n++;
    }
    parts = parts.sublist(0, n);
  }
  return parts.isEmpty ? '' : p.joinAll(parts);
}

/// The text of [playlist] in [format]. [folders] (id -> root path) and
/// [isrcByTrack] only matter for JSON and CSV.
String renderPlaylist(
  ExportFormat format, {
  required String name,
  required int createdAt,
  String? coverKey,
  required List<Track> tracks,
  Map<int, String> isrcByTrack = const {},
  Map<int, String> folders = const {},
  bool relativePaths = false,
}) =>
    switch (format) {
      ExportFormat.m3u8 => toM3u8(name, tracks,
          relativeTo: relativePaths ? commonDirectory([for (final t in tracks) if (t.kind != kStreamKind) t]) : null),
      ExportFormat.csv => toExportifyCsv(tracks, isrcByTrack),
      ExportFormat.json => toPlaylistJson(PlaylistData(
          name: name,
          createdAt: createdAt,
          coverKey: coverKey,
          items: [for (final t in tracks) trackRefFor(t, folders)],
        )),
    };

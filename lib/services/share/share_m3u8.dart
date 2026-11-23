import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/text_utils.dart' show sanitizeFileName;
import '../../data/db/app_database.dart' show Track;
import '../export/playlist_exporter.dart' show streamUrlOf, toM3u8;

/// Writes the m3u8 of the streamed rows of [tracks] (YouTube Music links; local paths mean nothing
/// to the receiver) in [dir], after deleting what an earlier share left there.
Future<File> writeShareM3u8(Directory dir, String name, List<Track> tracks) async {
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, '${sanitizeFileName(name).isEmpty ? 'playlist' : sanitizeFileName(name)}.m3u8'));
  return file.writeAsString(toM3u8(name, [for (final t in tracks) if (streamUrlOf(t) != null) t]));
}

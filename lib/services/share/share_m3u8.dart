import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/text_utils.dart' show sanitizeFileName;
import '../../data/db/app_database.dart' show Track;
import 'external_share_text.dart' show shareRowOf;

/// The m3u8 of every row of [tracks], as the link has them (D-713): a YouTube Music link for a row with
/// a video id, else a search of its artist + title (local paths mean nothing to the receiver).
String shareM3u8Body(String name, List<Track> tracks) {
  final b = StringBuffer('#EXTM3U\n#PLAYLIST:$name\n');
  for (final t in tracks) {
    final r = shareRowOf(t);
    final url = r.id != null
        ? 'https://music.youtube.com/watch?v=${r.id}'
        : 'https://music.youtube.com/search?q=${Uri.encodeQueryComponent('${r.artist} ${r.title}'.trim())}';
    final secs = t.durationMs > 0 ? (t.durationMs / 1000).round() : -1;
    b.write('#EXTINF:$secs,${(t.artist ?? '').isEmpty ? t.title : '${t.artist} - ${t.title}'}\n$url\n');
  }
  return b.toString();
}

/// Writes [shareM3u8Body] in [dir], which is ours alone: what an earlier share left there is deleted first.
Future<File> writeShareM3u8(Directory dir, String name, List<Track> tracks) async {
  if (await dir.exists()) await dir.delete(recursive: true);
  await dir.create(recursive: true);
  return File(p.join(dir.path, '${sanitizeFileName(name)}.m3u8')).writeAsString(shareM3u8Body(name, tracks));
}

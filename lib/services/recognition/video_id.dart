import '../stream/stream_key.dart' show keyOfStreamPath;

final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');
final _ytDlpSuffix = RegExp(r'\[([A-Za-z0-9_-]{11})\]\.[A-Za-z0-9]{1,5}$');
const _ytPrefix = 'youtube:';

/// The YouTube video id in a file name (yt-dlp's `… [xxxxxxxxxxx].ext`) or a
/// `stream:youtube:<id>` path; null when there is none (R-183).
String? videoIdOf(String path) {
  final key = keyOfStreamPath(path);
  if (key != null) {
    final id = key.startsWith(_ytPrefix) ? key.substring(_ytPrefix.length) : '';
    return _id.hasMatch(id) ? id : null;
  }
  return _ytDlpSuffix.firstMatch(path)?[1];
}

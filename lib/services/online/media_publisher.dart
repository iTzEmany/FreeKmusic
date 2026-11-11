import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/paths.dart';
import '../../core/platform.dart';

/// Android downloads are made in a private work folder (yt-dlp and the tag
/// writer need a real path) and published to `Music/FreeKmusic` afterwards.
Future<Directory> downloadWorkDir() async =>
    Directory(p.join(await appSupportDir(), 'download-work')).create(recursive: true);

class MediaPublisher {
  MediaPublisher({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('codecore/publish');
  final MethodChannel _channel;

  /// Copies [path] into the public folder through MediaStore, deletes the work
  /// copy and returns the final path. Off Android: [path] itself.
  Future<String> publish(String path) async {
    if (!isAndroid) return path;
    final out = await _channel.invokeMethod<String>('publish', {'path': path});
    if (out == null) throw const FileSystemException('publish returned no path');
    try {
      await File(path).delete();
    } on FileSystemException catch (e, st) {
      AppLog.w('work copy not removed: $path', e, st);
    }
    return out;
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/paths.dart';
import '../../core/platform.dart';
import '../tags/tag_backups.dart';

const _workDirName = 'download-work';

/// Android downloads are made in a private work folder (yt-dlp and the tag
/// writer need a real path) and published to `Music/FreeKmusic` afterwards.
Future<Directory> downloadWorkDir() async =>
    Directory(p.join(await appSupportDir(), _workDirName)).create(recursive: true);

/// Tests set the Android API level instead of asking the channel.
@visibleForTesting
int? debugAndroidSdk;
int? _sdk;

/// D-567: MediaStore publishing only from Android 11 (API 30); below, downloads
/// stay in the app folder as in 1.5.1.
Future<bool> publishesToMediaStore({MethodChannel channel = const MethodChannel('codecore/publish')}) async {
  if (!isAndroid) return false;
  final sdk = debugAndroidSdk ?? (_sdk ??= await channel.invokeMethod<int>('sdk') ?? 0);
  return sdk >= 30;
}

class MediaPublisher {
  MediaPublisher({MethodChannel? channel}) : _channel = channel ?? const MethodChannel('codecore/publish');
  final MethodChannel _channel;

  /// Copies [path] into the public folder through MediaStore (keeping its
  /// subfolder under the work folder), deletes the work copy and returns the
  /// final path. Where nothing is published: [path] itself.
  Future<String> publish(String path) async {
    if (!await publishesToMediaStore(channel: _channel)) return path;
    final parts = p.split(p.dirname(path));
    final i = parts.lastIndexOf(_workDirName);
    final subdir = i < 0 ? '' : parts.sublist(i + 1).join('/');
    final out = await _channel.invokeMethod<String>('publish', {'path': path, 'subdir': subdir});
    if (out == null) throw const FileSystemException('publish returned no path');
    try {
      await File(path).delete();
    } on FileSystemException catch (e, st) {
      AppLog.w('work copy not removed: $path', e, st);
    }
    return out;
  }

  /// Rewrites the public file [dest] with [src] through MediaStore (a rename
  /// is refused there). False: [dest] is not an entry of this app, so the
  /// caller must use a plain rename. A failure is a [FileSystemException].
  Future<bool> replace(String dest, String src) async {
    try {
      return await _channel.invokeMethod<bool>('replace', {'path': dest, 'src': src}) ?? false;
    } on PlatformException catch (e) {
      throw FileSystemException('MediaStore replace failed: ${e.message}', dest);
    }
  }
}

/// Installs a tagged copy [src] over [dest]: through MediaStore for the app's
/// own files in the public Music folder (Android 11+), else [installFile].
Future<void> installTagged(String src, String dest, {MediaPublisher? publisher}) async {
  if (await publishesToMediaStore() && p.isWithin('/storage/emulated/0/Music', dest) && await (publisher ?? MediaPublisher()).replace(dest, src)) {
    return;
  }
  await installFile(src, dest);
}

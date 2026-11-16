import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

/// Tests set the app folders of the SD volumes instead of asking path_provider.
@visibleForTesting
List<String>? debugSdDirs;

/// App folders (`…/Android/data/<pkg>/files`) on removable volumes: the second
/// and later `getExternalStorageDirectories`. Empty off Android or without a card.
Future<List<String>> sdVolumeDirs() async {
  if (debugSdDirs case final d?) return d;
  if (!isAndroid) return const [];
  final dirs = await getExternalStorageDirectories() ?? const [];
  return [for (final d in dirs.skip(1)) d.path];
}

/// `/storage/1234-5678/…` -> `/storage/1234-5678`; null for any other path (the internal `emulated` too).
String? sdRootOf(String location) {
  final parts = p.split(location);
  return parts.length > 2 && parts[1] == 'storage' && parts[2] != 'emulated' && parts[2] != 'self'
      ? p.joinAll(parts.take(3))
      : null;
}

/// The download location to really use: '' (internal) when it names an SD
/// volume that is not in the device any more (card removed), else [location].
Future<String> effectiveLocation(String location) async {
  final root = sdRootOf(location);
  if (!isAndroid || root == null) return location;
  return [for (final d in await sdVolumeDirs()) sdRootOf(d)].contains(root) ? location : '';
}

/// MediaStore's name of the volume [path] is on: the SD card's, else null (primary).
String? mediaVolumeOf(String path) {
  final root = sdRootOf(path);
  return root == null ? null : p.basename(root).toLowerCase();
}

class MediaPublisher {
  /// [volume]: the download location setting; an SD one publishes on that volume.
  MediaPublisher({MethodChannel? channel, this.volume}) : _channel = channel ?? const MethodChannel('codecore/publish');
  final MethodChannel _channel;
  final Future<String> Function()? volume;

  /// Copies [path] into the public folder through MediaStore (keeping its
  /// subfolder under the work folder), deletes the work copy and returns the
  /// final path. Where nothing is published: [path] itself.
  Future<String> publish(String path) async {
    if (!await publishesToMediaStore(channel: _channel)) return path;
    final parts = p.split(p.dirname(path));
    final i = parts.lastIndexOf(_workDirName);
    final subdir = i < 0 ? '' : parts.sublist(i + 1).join('/');
    final vol = mediaVolumeOf(await volume?.call() ?? '');
    final out = await _channel.invokeMethod<String>('publish', {
      'path': path,
      'subdir': subdir,
      'volume': ?vol,
    });
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
      final vol = mediaVolumeOf(dest);
      return await _channel.invokeMethod<bool>('replace', {'path': dest, 'src': src, 'volume': ?vol}) ?? false;
    } on PlatformException catch (e) {
      throw FileSystemException('MediaStore replace failed: ${e.message}', dest);
    }
  }
}

/// Installs a tagged copy [src] over [dest]: through MediaStore for the app's
/// own files in the public Music folder, internal or SD (Android 11+), else [installFile].
Future<void> installTagged(String src, String dest, {MediaPublisher? publisher}) async {
  if (await publishesToMediaStore() && _inMusic(dest) && await (publisher ?? MediaPublisher()).replace(dest, src)) {
    return;
  }
  await installFile(src, dest);
}

/// A path in the primary Music folder or in `Music` of an SD volume.
bool _inMusic(String path) {
  final sd = sdRootOf(path);
  return p.isWithin('/storage/emulated/0/Music', path) || (sd != null && p.isWithin(p.join(sd, 'Music'), path));
}

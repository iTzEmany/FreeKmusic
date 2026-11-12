import 'package:permission_handler/permission_handler.dart';

import 'platform.dart';

/// True when audio files can be read. Desktop needs no permission.
Future<bool> ensureAudioPermission() async {
  if (!isAndroid) return true;
  final results = await [Permission.audio, Permission.storage].request();
  return results.values.any((s) => s.isGranted);
}

Future<bool> isAudioPermissionPermanentlyDenied() async {
  if (!isAndroid) return false;
  return await Permission.audio.isPermanentlyDenied &&
      await Permission.storage.isPermanentlyDenied;
}

/// [ensureAudioPermission] without the prompt: what the system says now.
Future<bool> hasAudioPermission() async {
  if (!isAndroid) return true;
  return await Permission.audio.isGranted || await Permission.storage.isGranted;
}

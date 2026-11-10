import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

/// Tests set it to true to exercise the Android path on a Linux host.
@visibleForTesting
bool? debugIsAndroidOverride;

bool get isAndroid => debugIsAndroidOverride ?? Platform.isAndroid;
/// Tests set it to false to see the phone layout on a Linux host.
@visibleForTesting
bool? debugIsDesktopOverride;

bool get isDesktop =>
    debugIsDesktopOverride ??
    (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

Future<String> defaultMusicDir() async {
  if (Platform.isAndroid) return '/storage/emulated/0/Music';
  if (Platform.isWindows) {
    final profile = Platform.environment['USERPROFILE'] ?? '';
    return '$profile\\Music';
  }
  final home = Platform.environment['HOME'] ?? '';
  return '$home/Music';
}

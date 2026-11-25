import 'dart:io';

import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/restart/app_restart.dart';
import 'player_providers.dart' show playbackPersistenceProvider;
import 'tray_providers.dart';

final appRestartProvider = Provider<AppRestart>(
  (ref) => Platform.isAndroid ? AndroidRestart() : DesktopRestart(),
);

/// The one clean exit (Ctrl+Q, the window's X, the tray's «Esci»): the tray icon goes, the queue and
/// position are saved, then lifecycle observers get to answer.
final quitAppProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    ref.read(trayServiceProvider)?.dispose();
    await ref.read(playbackPersistenceProvider)?.flush();
    await ServicesBinding.instance.exitApplication(AppExitType.required);
  },
);

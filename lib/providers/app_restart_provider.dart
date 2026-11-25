import 'dart:io';

import 'dart:ui' show AppExitType;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/restart/app_restart.dart';

final appRestartProvider = Provider<AppRestart>(
  (ref) => Platform.isAndroid ? AndroidRestart() : DesktopRestart(),
);

/// Ctrl+Q: leaves like closing the window (lifecycle observers get to answer).
final quitAppProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    await ServicesBinding.instance.exitApplication(AppExitType.required);
  },
);

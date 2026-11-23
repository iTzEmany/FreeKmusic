import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/restart/app_restart.dart';

final appRestartProvider = Provider<AppRestart>(
  (ref) => Platform.isAndroid ? AndroidRestart() : DesktopRestart(),
);

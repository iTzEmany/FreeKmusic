import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/window/tray_service.dart';

/// Whether the desktop has a system tray the app could show its icon in (overridden in `main`).
final trayAvailableProvider = Provider<bool>((ref) => false);

/// The tray of the running desktop app, closed by the exit (overridden in `main`).
final trayServiceProvider = Provider<TrayService?>((ref) => null);

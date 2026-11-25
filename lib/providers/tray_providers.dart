import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the desktop has a system tray the app could show its icon in (overridden in `main`).
final trayAvailableProvider = Provider<bool>((ref) => false);

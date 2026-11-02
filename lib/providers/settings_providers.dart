import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/settings/settings_store.dart';

/// Overridden in `main` (and in tests) with an opened store.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider not overridden'),
);

class SettingsNotifier extends Notifier<AppSettings> {
  Timer? _debounce;

  @override
  AppSettings build() {
    ref.onDispose(() => _debounce?.cancel());
    return ref.read(settingsStoreProvider).readSettings();
  }

  void update(AppSettings Function(AppSettings) change) {
    final before = state;
    state = change(state);
    // Tracks passed over while AcoustID was off must be asked again.
    if (!before.acoustId && state.acoustId) {
      ref.read(settingsStoreProvider).writeRecogPassDone(0).catchError((Object e, StackTrace st) {
        AppLog.w('save settings failed', e, st);
      });
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(settingsStoreProvider).writeSettings(state).catchError((
        Object e,
        StackTrace st,
      ) {
        AppLog.w('save settings failed', e, st);
      });
    });
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

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
      ref.read(settingsStoreProvider).writeRecogPassDone(0).catchError((
        Object e,
        StackTrace st,
      ) {
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

/// Tracks whose «Testo sincronizzato» switch is off (D-472), kept in the settings.
class UnsyncedLyricsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.read(settingsStoreProvider).readUnsyncedLyrics();

  Future<void> setSynced(int id, bool synced) async {
    state = synced ? ({...state}..remove(id)) : {...state, id};
    await ref.read(settingsStoreProvider).writeUnsyncedLyrics(state);
  }
}

final unsyncedLyricsProvider =
    NotifierProvider<UnsyncedLyricsNotifier, Set<int>>(
      UnsyncedLyricsNotifier.new,
    );

/// Tracks whose lyrics the user typed in the editor (D-475): their
/// transliteration is never searched online. Kept in the settings (backup).
class HandWrittenLyricsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.read(settingsStoreProvider).readHandWrittenLyrics();

  Future<void> set(int id, bool handWritten) async {
    if (state.contains(id) == handWritten) return;
    state = handWritten ? {...state, id} : ({...state}..remove(id));
    await ref.read(settingsStoreProvider).writeHandWrittenLyrics(state);
  }

  /// Marks [ids] (the backup merge); the ones already marked stay.
  Future<void> addAll(Set<int> ids) async {
    if (state.containsAll(ids)) return;
    state = {...state, ...ids};
    await ref.read(settingsStoreProvider).writeHandWrittenLyrics(state);
  }
}

final handWrittenLyricsProvider =
    NotifierProvider<HandWrittenLyricsNotifier, Set<int>>(
      HandWrittenLyricsNotifier.new,
    );

/// Transliterations typed by hand, track id -> text (D-475), kept in the
/// settings so they travel in the backup like the other user data.
class ManualRomanizationNotifier extends Notifier<Map<int, String>> {
  @override
  Map<int, String> build() =>
      ref.read(settingsStoreProvider).readManualRomanizations();

  /// [text] null removes the entry.
  Future<void> setText(int id, String? text) =>
      _write(text == null ? ({...state}..remove(id)) : {...state, id: text});

  /// Adds what [texts] bring for tracks that have none (the backup merge).
  Future<void> addMissing(Map<int, String> texts) {
    final fresh = {
      for (final e in texts.entries)
        if (!state.containsKey(e.key)) e.key: e.value,
    };
    return fresh.isEmpty ? Future.value() : _write({...state, ...fresh});
  }

  Future<void> _write(Map<int, String> next) async {
    state = next;
    await ref.read(settingsStoreProvider).writeManualRomanizations(next);
  }
}

final manualRomanizationProvider =
    NotifierProvider<ManualRomanizationNotifier, Map<int, String>>(
      ManualRomanizationNotifier.new,
    );

/// «Scarica i brani da Shazam» (off by default).
class ShazamAutoDownloadNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).readShazamAutoDownload();

  Future<void> set(bool on) async {
    state = on;
    await ref.read(settingsStoreProvider).writeShazamAutoDownload(on);
  }
}

final shazamAutoDownloadProvider =
    NotifierProvider<ShazamAutoDownloadNotifier, bool>(ShazamAutoDownloadNotifier.new);

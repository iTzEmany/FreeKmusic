import 'dart:convert';

import '../../core/app_log.dart';
import '../../data/settings/settings_store.dart';
import '../online/update_checker.dart';
import 'release_notes.dart';

/// Keeps the notes of the newest release a check found (one version only).
Future<void> saveNewVersionNotes(SettingsStore store, UpdateInfo i) =>
    store.writeNewVersionNotes(jsonEncode({'version': i.version, 'url': i.url, 'notes': i.notes}));

/// Decides when «Aggiornata alla X» shows. Pure: the preferences, the «has the app any data»
/// question and the read of one release are injected.
class WhatsNew {
  WhatsNew(this._store, {required this.current, required this.hasData, required this.fetch});

  final SettingsStore _store;
  final String current;

  /// First install = no key yet and no track row at all (any older install has its library or
  /// streamed tracks by the time this runs, 2 s after the first frame).
  final Future<bool> Function() hasData;

  /// The release of [version] (tag `v<version>`), or null offline, on error or when unknown.
  final Future<UpdateInfo?> Function(String version) fetch;

  /// At start-up: the notes to show, or null. The decision is written before anything is shown,
  /// so the page comes once even if the app closes.
  Future<UpdateInfo?> atStart() async {
    final seen = _store.readLastSeenVersion();
    if (seen != null && compareVersions(current, seen) <= 0) return null;
    final first = seen == null && !await hasData();
    await _store.writeLastSeenVersion(current);
    if (first) return null;
    final info = await notes();
    return info == null || parseReleaseNotes(info.notes).isEmpty ? null : info;
  }

  /// The notes of the running version: the saved ones, else one read of GitHub; null if none.
  Future<UpdateInfo?> notes() async {
    final raw = _store.readNewVersionNotes();
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map;
        if (m['version'] == current) {
          return UpdateInfo(version: current, url: m['url'] as String, notes: m['notes'] as String);
        }
      } on Object catch (e, st) {
        AppLog.w('saved release notes unreadable', e, st);
      }
    }
    try {
      return await fetch(current);
    } on Object catch (e, st) {
      AppLog.w('release notes not read', e, st);
      return null;
    }
  }
}

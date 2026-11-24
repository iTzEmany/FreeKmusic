import '../../core/app_log.dart';
import '../../data/settings/settings_store.dart';
import '../online/update_checker.dart';
import 'release_notes.dart';

/// Decides when «Aggiornata alla X» shows. Pure: the preferences, the «has the app any data»
/// question and the read of the bundled notes are injected. No network (D-741).
class WhatsNew {
  WhatsNew(this._store, {required this.current, required this.url, required this.hasData, required this.load});

  final SettingsStore _store;
  final String current;

  /// «Tutte le novità»: opened only when the user taps it.
  final String url;

  /// First install = no key yet and no track row at all (any older install has its library or
  /// streamed tracks by the time this runs, 2 s after the first frame).
  final Future<bool> Function() hasData;

  /// The bundled `release-notes/<version>.md`, or null when the build has none (dev builds).
  final Future<String?> Function(String version) load;

  /// At start-up: the notes to show, or null. The decision is written before anything is shown,
  /// so the page comes once even if the app closes.
  Future<UpdateInfo?> atStart() async {
    final seen = _store.readLastSeenVersion();
    if (seen != null && compareVersions(current, seen) <= 0) return null;
    final first = seen == null && !await hasData();
    await _store.writeLastSeenVersion(current);
    if (first) return null;
    final info = await notes();
    return parseReleaseNotes(info.notes).isEmpty ? null : info;
  }

  /// The notes of the running version; empty notes when the file is missing.
  Future<UpdateInfo> notes() async {
    String? text;
    try {
      text = await load(current);
    } on Object catch (e) {
      AppLog.i('no release notes bundled for $current: $e');
    }
    return UpdateInfo(version: current, url: url, notes: text ?? '');
  }
}

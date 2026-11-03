import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_log.dart';

const jamBlockedKey = 'jamBlocked';
const jamSuspendedKey = 'jamSuspended';
const jamFriendsKey = 'jamFriends';
const jamAnnounceKeyKey = 'jamAnnounceKey';

/// Minimal key-value store for the Jam secrets. Backed by the async
/// shared_preferences API (a separate file from the one the backup exports,
/// and excluded from the Android backup).
abstract class JamSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class PrefsJamSecretStore implements JamSecretStore {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _prefs.getString(key);

  @override
  Future<void> write(String key, String value) => _prefs.setString(key, value);
}

/// Desktop: SharedPreferencesAsync shares `shared_preferences.json` with the
/// legacy settings and the two caches overwrite each other (D-269).
class FileJamSecretStore implements JamSecretStore {
  FileJamSecretStore(this.dir);
  final String dir;
  Map<String, String>? _cache;

  File get _file => File(p.join(dir, 'jam_secrets.json'));

  Future<Map<String, String>> _load() async {
    if (_cache != null) return _cache!;
    try {
      if (await _file.exists()) {
        final m = jsonDecode(await _file.readAsString()) as Map;
        return _cache = {for (final e in m.entries) '${e.key}': '${e.value}'};
      }
    } on Object catch (e, st) {
      AppLog.w('jam secrets: unreadable file, starting empty', e, st);
    }
    return _cache = {};
  }

  @override
  Future<String?> read(String key) async => (await _load())[key];

  Future<void> _last = Future.value();

  // One write at a time: they share the tmp file.
  @override
  Future<void> write(String key, String value) {
    final run = _last.then((_) => _write(key, value));
    _last = run.catchError((Object _) {}); // the caller of [run] sees the error
    return run;
  }

  Future<void> _write(String key, String value) async {
    final m = await _load();
    m[key] = value;
    final tmp = File('${_file.path}.tmp');
    await tmp.parent.create(recursive: true);
    await tmp.writeAsString(jsonEncode(m), flush: true);
    await tmp.rename(_file.path);
  }
}

class MemoryJamSecretStore implements JamSecretStore {
  MemoryJamSecretStore([Map<String, String>? data]) : data = data ?? {};
  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

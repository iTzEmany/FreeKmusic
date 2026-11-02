import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/app_log.dart';
import '../../../data/settings/jam_secret_store.dart';
import 'jam_protocol.dart';

/// A saved friend: [ak] is the friend's announce key, [fkp] the key of the pair (R-143).
class JamFriend {
  const JamFriend(this.id, this.name, this.ak, this.fkp, this.since);
  final String id, name;
  final Uint8List ak, fkp;
  final DateTime since;
}

Uint8List _secureBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList([for (var i = 0; i < n; i++) r.nextInt(256)]);
}

/// «Amici della Jam» and this device's announce key `AK`, kept in a
/// [JamSecretStore] (never in the backup). Removing a friend rotates `AK`, so
/// the removed friend no longer recognises this device (R-144). No key is
/// ever logged.
class JamFriends extends ChangeNotifier {
  JamFriends(this._store, {Uint8List Function(int)? random, DateTime Function()? now})
      : _random = random ?? _secureBytes,
        _now = now ?? DateTime.now {
    ready = _load();
  }

  final JamSecretStore _store;
  final Uint8List Function(int) _random;
  final DateTime Function() _now;

  /// Completes when the saved list and `AK` are loaded.
  late final Future<void> ready;

  Uint8List? _ak;
  final _friends = <String, JamFriend>{};
  bool _disposed = false;

  /// This device's `AK`; valid once [ready] has completed.
  Uint8List get announceKey => _ak ?? (throw StateError('JamFriends not ready'));

  List<JamFriend> get all => _friends.values.toList();
  JamFriend? byId(String id) => _friends[id];

  /// Saves, or updates, the friend [id] (D-236).
  Future<void> save(String id, String name, Uint8List ak, Uint8List fkp) {
    _friends[id] = JamFriend(id, name, Uint8List.fromList(ak), Uint8List.fromList(fkp), _friends[id]?.since ?? _now());
    notifyListeners();
    return _saveList();
  }

  /// Forgets [id] and rotates `AK`.
  Future<void> remove(String id) {
    if (_friends.remove(id) == null) return Future.value();
    _ak = _random(32);
    notifyListeners();
    return Future.wait([_saveList(), _store.write(jamAnnounceKeyKey, b64u(_ak!))]);
  }

  /// The friend whose label matches [label] around [nowMs]; null for a stranger.
  JamFriend? match(JamProtocol p, Uint8List label, int nowMs) {
    final list = all;
    final i = p.matchFriendLabel([for (final f in list) f.ak], label, nowMs);
    return i == null ? null : list[i];
  }

  Future<void> _saveList() => _store.write(
        jamFriendsKey,
        jsonEncode([
          for (final f in _friends.values)
            {'id': f.id, 'name': f.name, 'ak': b64u(f.ak), 'fkp': b64u(f.fkp), 'since': f.since.toIso8601String()},
        ]),
      );

  Future<void> _load() async {
    try {
      final raw = await _store.read(jamFriendsKey);
      if (raw != null) {
        for (final e in jsonDecode(raw) as List) {
          try {
            final m = e as Map;
            final ak = unb64u(m['ak']), fkp = unb64u(m['fkp']);
            if (ak == null || fkp == null || ak.length != 32 || fkp.length != 32) continue;
            final id = m['id'] as String;
            _friends[id] = JamFriend(id, m['name'] as String, ak, fkp,
                DateTime.tryParse('${m['since']}') ?? _now());
          } on Object catch (err, st) {
            AppLog.w('jam friends: entry dropped', err, st);
          }
        }
      }
    } on Object catch (e, st) {
      AppLog.w('jam friends: cannot load the list', e, st);
    }
    Uint8List? ak;
    try {
      ak = unb64u(await _store.read(jamAnnounceKeyKey));
    } on Object catch (e, st) {
      AppLog.w('jam friends: cannot load the announce key', e, st);
    }
    if (ak == null || ak.length != 32) {
      ak = _random(32);
      try {
        await _store.write(jamAnnounceKeyKey, b64u(ak));
      } on Object catch (e, st) {
        AppLog.w('jam friends: cannot save the announce key', e, st);
      }
    }
    _ak = ak;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

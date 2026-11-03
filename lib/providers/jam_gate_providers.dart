import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/paths.dart';
import '../data/settings/jam_secret_store.dart';
import '../services/jam/jam_gate.dart';
import '../services/jam/remote/jam_friends.dart';
import 'settings_providers.dart';

final jamSecretStoreProvider = Provider<JamSecretStore>(
  (_) => Platform.isAndroid ? PrefsJamSecretStore() : _LazyFileStore(),
);

/// The support dir is async: resolve it on first use.
class _LazyFileStore implements JamSecretStore {
  late final Future<FileJamSecretStore> _inner = appSupportDir().then(
    FileJamSecretStore.new,
  );
  @override
  Future<String?> read(String key) async => (await _inner).read(key);
  @override
  Future<void> write(String key, String value) async =>
      (await _inner).write(key, value);
}

/// Suspended and blocked senders of Jam requests (the UI reads and edits it; it is a Listenable).
final jamGateProvider = Provider<JamGate>((ref) {
  final gate = JamGate(ref.watch(jamSecretStoreProvider));
  ref.onDispose(gate.dispose);
  return gate;
});

/// «Amici della Jam» and this device's announce key (secrets, outside the backup).
final jamFriendsProvider = Provider<JamFriends>((ref) {
  final f = JamFriends(ref.watch(jamSecretStoreProvider));
  ref.onDispose(f.dispose);
  return f;
});

/// «Accetta gli amici senza chiedere»: off unless turned on (R-145).
class JamAutoAcceptFriendsNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).readJamAutoAcceptFriends();

  void set(bool v) {
    state = v;
    ref.read(settingsStoreProvider).writeJamAutoAcceptFriends(v).catchError((Object e, StackTrace st) {
      AppLog.w('could not save jamAutoAcceptFriends', e, st);
    });
  }
}

final jamAutoAcceptFriendsProvider =
    NotifierProvider<JamAutoAcceptFriendsNotifier, bool>(JamAutoAcceptFriendsNotifier.new);

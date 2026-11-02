import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/paths.dart';
import '../data/settings/jam_secret_store.dart';
import '../services/jam/jam_gate.dart';

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

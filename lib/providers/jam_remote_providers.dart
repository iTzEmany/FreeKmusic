import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/paths.dart';
import '../data/settings/jam_secret_store.dart';
import '../services/jam/jam_gate.dart';
import '../services/jam/remote/jam_bridge.dart';
import '../services/jam/remote/jam_bridge_host.dart';
import '../services/jam/remote/jam_crypto.dart';
import '../services/jam/remote/jam_protocol.dart';
import '../services/jam/remote/remote_jam_guest.dart';
import 'jam_broker_providers.dart';
import 'jam_providers.dart';
import 'share_hub.dart';

final jamSecretStoreProvider = Provider<JamSecretStore>(
  (_) => Platform.isAndroid ? PrefsJamSecretStore() : _LazyFileStore(),
);

/// The support dir is async: resolve it on first use.
class _LazyFileStore implements JamSecretStore {
  late final Future<FileJamSecretStore> _inner = appSupportDir().then(FileJamSecretStore.new);
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

/// Libsodium, initialised once on first use.
final jamCryptoProvider = FutureProvider<JamCrypto>((_) => SodiumJamCrypto.create());

/// Makes the guest side of a remote Jam; tests override it with a fake.
final remoteJamGuestFactoryProvider = Provider<RemoteJamGuest Function(JamProtocol)>(
  (ref) => (protocol) => RemoteJamGuest(
        protocol: protocol,
        linkFactory: ref.read(mqttLinkFactoryProvider),
        brokers: ref.read(jamBrokersProvider),
      ),
);

class JamBridgeState {
  const JamBridgeState({this.on = false, this.status = JamBridgeStatus.connecting});
  final bool on;
  final JamBridgeStatus status;
}

/// Runs the host's [JamBridgeHost] exactly while it is wanted: the speaker's Jam
/// (also waiting) or «Invita chi è vicino». Off, there is no timer and no
/// connection (invariant 1); the host's own 1 s timer ticks only while it runs.
class JamBridgeNotifier extends Notifier<JamBridgeState> {
  JamBridgeHost? _bh;
  JamBridge? _bridge;
  StreamSubscription<JamBridgeStatus>? _statusSub;
  StreamSubscription<void>? _codeSub;
  final _codeChanged = StreamController<void>.broadcast();
  bool _busy = false, _again = false;

  @override
  JamBridgeState build() {
    final jam = _jam = ref.read(jamProvider.notifier);
    _hub = ref.read(shareHubProvider.notifier);
    // Fires on every Jam state change and when the speaker's Jam starts or stops waiting.
    final sub = jam.speakerPort.changes.listen((_) => _apply());
    ref.listen(shareHubProvider.select((s) => s.active), (_, _) => _apply());
    ref.onDispose(() {
      sub.cancel();
      _codeChanged.close();
      unawaited(_stop());
    });
    return const JamBridgeState();
  }

  late ShareHubNotifier _hub;
  late JamController _jam;

  bool get _wanted => _hub.jamHost != null && (ref.read(jamProvider).inviting || _jam.speakerJam);

  /// QR of the current window; null while off.
  String? currentQr() => _bh?.currentQr();
  String? get code => _bh?.code;
  DateTime? get codeExpiresAt => _bh?.codeExpiresAt;

  /// Fires when the code changes; also when the bridge goes away.
  Stream<void> get codeChanges => _codeChanged.stream;

  Future<void> startCode() async => _bh?.startCode();
  void stopCode() => _bh?.stopCode();

  Future<void> _apply() async {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _step();
      } while (_again && ref.mounted);
    } finally {
      _busy = false;
    }
  }

  Future<void> _step() async {
    if (!_wanted) return _stop();
    if (_bh != null) return;
    final crypto = await ref.read(jamCryptoProvider.future);
    final host = _hub.jamHost;
    if (!ref.mounted || !_wanted || host == null) return;
    final bridge = _bridge = JamBridge(ref.read(mqttLinkFactoryProvider)(), ref.read(jamBrokersProvider));
    final bh = _bh = JamBridgeHost(protocol: JamProtocol(crypto), host: host, bridge: bridge);
    _statusSub = bridge.statuses.listen((s) => state = JamBridgeState(on: true, status: s));
    _codeSub = bh.codeChanges.listen(_codeChanged.add);
    await _hub.holdJam(remote: true);
    bh.start();
    state = JamBridgeState(on: true, status: bridge.status);
  }

  Future<void> _stop() async {
    final bh = _bh, bridge = _bridge;
    if (bh == null) return;
    _bh = _bridge = null;
    unawaited(_statusSub?.cancel());
    unawaited(_codeSub?.cancel());
    if (ref.mounted) state = const JamBridgeState();
    try {
      await bh.dispose(); // says goodbye, drops every key, disconnects
      bridge?.dispose();
    } on Object catch (e, st) {
      AppLog.w('jam bridge: stop failed', e, st);
    }
    if (!ref.mounted) return;
    _codeChanged.add(null);
    await _hub.releaseJam(remote: true);
  }
}

final jamBridgeProvider = NotifierProvider<JamBridgeNotifier, JamBridgeState>(JamBridgeNotifier.new);

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/platform.dart';
import '../services/jam/remote/jam_beacon.dart';
import '../services/jam/remote/jam_invite.dart';
import '../services/jam/remote/jam_protocol.dart';
import 'jam_gate_providers.dart';
import 'jam_providers.dart';
import 'jam_broker_providers.dart' show jamCryptoProvider;
import 'settings_providers.dart';
import 'share_hub.dart';

/// The Bluetooth beacon; inert off Android (nothing is supported there, R-146).
final jamBeaconProvider = Provider<JamBeacon>((_) {
  if (isAndroid) return ChannelJamBeacon();
  return FakeJamBeacon()
    ..caps = const JamBeaconCapabilities()
    ..perms = const JamBeaconPermissions();
});

/// Time source of the nearby list; tests replace it.
final jamNearbyNowProvider = Provider<DateTime Function()>((_) => DateTime.now);

/// An entry goes after this long without a packet (R-137).
const jamNearbyTtl = Duration(seconds: 90);

/// «Cerca Jam vicine»: off after a refused permission, back on from the settings (R-138).
class JamNearbyScanNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).readJamNearbyScan();

  void set(bool v) {
    state = v;
    ref.read(settingsStoreProvider).writeJamNearbyScan(v).catchError((Object e, StackTrace st) {
      AppLog.w('could not save jamNearbyScan', e, st);
    });
  }
}

final jamNearbyScanProvider = NotifierProvider<JamNearbyScanNotifier, bool>(JamNearbyScanNotifier.new);

/// A Jam heard over Bluetooth. [friendName] is set when a saved friend hosts it.
class JamNearbyJam {
  const JamNearbyJam({
    required this.key,
    required this.advert,
    required this.rssi,
    required this.seen,
    this.friendName,
    this.dismissed = false,
  });

  /// base64url of the Jam id: the same Jam keeps the same key across packets.
  final String key;
  final JamAdvert advert;
  final int rssi;
  final DateTime seen;
  final String? friendName;
  final bool dismissed;

  JamNearbyJam copyWith({JamAdvert? advert, int? rssi, DateTime? seen, String? friendName, bool? dismissed}) =>
      JamNearbyJam(
        key: key,
        advert: advert ?? this.advert,
        rssi: rssi ?? this.rssi,
        seen: seen ?? this.seen,
        friendName: friendName ?? this.friendName,
        dismissed: dismissed ?? this.dismissed,
      );

  /// What to ask with: the newest token seen (R-137).
  JamInvite get invite => JamInvite.fromAdvert(advert);
}

/// Jams announced nearby, friends first. Scans only in the foreground, with no
/// Jam going, with the permission and the setting on; otherwise it is empty and
/// holds no timer and no scan (RNF-16).
class JamNearbyNotifier extends Notifier<List<JamNearbyJam>> {
  late JamBeacon _beacon;
  bool _foreground = true;
  bool _busy = false, _again = false;
  bool _scanning = false;
  JamProtocol? _protocol;
  StreamSubscription<JamBeaconFound>? _sub;
  Timer? _prune;
  final _dismissed = <String>{};

  @override
  List<JamNearbyJam> build() {
    _beacon = ref.watch(jamBeaconProvider);
    final s = WidgetsBinding.instance.lifecycleState;
    _foreground = s == null || s == AppLifecycleState.resumed;
    final life = AppLifecycleListener(
      onStateChange: (s) {
        _foreground = s == AppLifecycleState.resumed;
        refresh();
      },
    );
    ref.listen(jamNearbyScanProvider, (_, _) => refresh());
    ref.listen(jamProvider.select((j) => j.phase != JamPhase.idle || j.inviting), (_, _) => refresh());
    ref.onDispose(() {
      life.dispose();
      unawaited(_stop(clear: false));
    });
    scheduleMicrotask(refresh);
    return const [];
  }

  /// Re-evaluates the conditions; also after a permission answer.
  void refresh() {
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    unawaited(_sync());
  }

  Future<void> _sync() async {
    try {
      do {
        _again = false;
        final want = await _wanted();
        if (!ref.mounted) return;
        if (want && !_scanning) {
          await _start();
        } else if (!want && _scanning) {
          await _stop();
        }
      } while (_again && ref.mounted);
    } on Object catch (e, st) {
      AppLog.w('jam nearby: could not sync', e, st);
    } finally {
      _busy = false;
    }
  }

  Future<bool> _wanted() async {
    if (!_foreground || !ref.read(jamNearbyScanProvider)) return false;
    final j = ref.read(jamProvider);
    if (j.phase != JamPhase.idle || j.inviting) return false;
    final caps = await _beacon.capabilities();
    if (!caps.scan || !caps.bluetoothOn || caps.locationOff) return false;
    return (await _beacon.permissions()).scan;
  }

  Future<void> _start() async {
    _protocol ??= JamProtocol(await ref.read(jamCryptoProvider.future));
    await ref.read(jamFriendsProvider).ready;
    if (!ref.mounted) return;
    _sub = _beacon.found.listen(_onFound);
    if (!await _beacon.startScan()) {
      await _sub?.cancel();
      _sub = null;
      return;
    }
    _scanning = true;
    _prune = Timer.periodic(const Duration(seconds: 10), (_) => _expire());
  }

  Future<void> _stop({bool clear = true}) async {
    final was = _scanning;
    _scanning = false;
    _prune?.cancel();
    _prune = null;
    unawaited(_sub?.cancel());
    _sub = null;
    if (was) await _beacon.stopScan();
    if (clear && ref.mounted && state.isNotEmpty) state = const [];
  }

  void _onFound(JamBeaconFound f) {
    final p = _protocol;
    if (p == null || !ref.mounted) return;
    final adv = p.decodeAdvert(f.bytes);
    if (adv == null) return;
    final now = ref.read(jamNearbyNowProvider)();
    final key = b64u(adv.jamId);
    final friend = ref.read(jamFriendsProvider).match(p, adv.friendLabel, now.millisecondsSinceEpoch);
    final old = state.where((e) => e.key == key).firstOrNull;
    final next = old == null
        ? JamNearbyJam(
            key: key,
            advert: adv,
            rssi: f.rssi,
            seen: now,
            friendName: friend?.name,
            dismissed: _dismissed.contains(key),
          )
        : old.copyWith(advert: adv, rssi: f.rssi, seen: now, friendName: friend?.name);
    final rest = state.where((e) => e.key != key);
    state = [...rest, next]..sort(_order);
  }

  static int _order(JamNearbyJam a, JamNearbyJam b) {
    if ((a.friendName != null) != (b.friendName != null)) return a.friendName != null ? -1 : 1;
    return b.rssi.compareTo(a.rssi);
  }

  void _expire() {
    final cutoff = ref.read(jamNearbyNowProvider)().subtract(jamNearbyTtl);
    final live = [
      for (final e in state)
        if (!e.seen.isBefore(cutoff)) e,
    ];
    if (live.length == state.length) return;
    // A Jam that stopped announcing is forgotten, so its next one invites again.
    _dismissed.retainAll({for (final e in live) e.key});
    state = live;
  }

  /// Closes the banner for this Jam (the row in «Dispositivi» stays).
  void dismiss(String key) {
    _dismissed.add(key);
    state = [
      for (final e in state) e.key == key ? e.copyWith(dismissed: true) : e,
    ];
  }
}

final jamNearbyProvider = NotifierProvider<JamNearbyNotifier, List<JamNearbyJam>>(JamNearbyNotifier.new);

/// Nearby Jams not already shown as a LAN row: on the same network the LAN row
/// of the same Jam id wins (R-137).
final jamNearbyVisibleProvider = Provider<List<JamNearbyJam>>((ref) {
  final lan = {
    for (final p in ref.watch(shareHubProvider.select((h) => h.peers)))
      if (p.jamRid != null) p.jamRid,
  };
  return [
    for (final e in ref.watch(jamNearbyProvider))
      if (!lan.contains(e.key)) e,
  ];
});

/// The Jam of the banner: the first one not closed.
final jamNearbyBannerProvider = Provider<JamNearbyJam?>(
  (ref) => ref.watch(jamNearbyVisibleProvider).where((e) => !e.dismissed).firstOrNull,
);

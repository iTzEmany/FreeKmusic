import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show setEquals;

import '../../core/app_log.dart';
import 'net_prefix.dart';
import 'offers.dart';

/// Magic string carried by every beacon; anything else is ignored.
const discoveryMagic = 'CODECORE/1';
const discoveryPort = 45671;

/// Retries (2 ms apart) for a send that would block: none for a target that
/// already blocked on the previous beat, so a network that never delivers
/// broadcasts costs nothing per beat.
int sendRetries(bool blockedBefore) => blockedBefore ? 0 : 50;

class Peer {
  const Peer({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.platform,
    this.tlsPort,
    this.jamName,
    this.jamRid,
  });

  final String id, name, host, platform;

  /// HTTP port of the peer's offer endpoint (also what a v2 device speaks).
  final int port;

  /// HTTPS port of the same endpoint; null for a device without identity (v2).
  final int? tlsPort;

  /// Name of the speaker Jam this device is hosting, if it announces one.
  final String? jamName;

  /// Id (base64url) of the remote Jam behind that LAN Jam, when the bridge is on (R-137).
  final String? jamRid;
}

/// Announces this device and lists the Codecore devices on the same network
/// using small UDP broadcast beacons. Only datagrams from local-network
/// addresses are considered, and beacons carry no secrets.
class LanDiscovery {
  LanDiscovery({
    required this.deviceId,
    required this.deviceName,
    this.port = discoveryPort,
    this.interval = const Duration(seconds: 2),
    this.peerTtl = const Duration(seconds: 7),
    this.allowLoopback = false,
    List<({InternetAddress address, int port})>? targets,
  }) : _fixedTargets = targets;

  final String deviceId, deviceName;
  final int port;
  final Duration interval, peerTtl;
  final bool allowLoopback;
  final List<({InternetAddress address, int port})>? _fixedTargets;

  RawDatagramSocket? _socket;
  Timer? _beat;
  // Targets whose last send would block; logged once, no retry loop.
  final _blocked = <String>{};
  int _httpPort = 0;
  int? _tlsPort;

  /// While set, the beacon carries `jam: {name}` (a speaker Jam to join).
  String? speakerJamName;

  /// With [speakerJamName]: the remote Jam id, so Bluetooth and LAN show one row.
  String? speakerJamRid;
  final _peers = <String, ({Peer peer, DateTime seen})>{};
  final _controller = StreamController<List<Peer>>.broadcast();

  Stream<List<Peer>> get peers => _controller.stream;
  List<Peer> get current =>
      [for (final e in _peers.values) e.peer]..sort((a, b) => a.name.compareTo(b.name));

  static String get platformName => Platform.isAndroid
      ? 'android'
      : Platform.isWindows
          ? 'windows'
          : Platform.isLinux
              ? 'linux'
              : 'other';

  Future<void> start(int httpPort, {int? tlsPort}) async {
    await stop();
    _tlsPort = tlsPort;
    _httpPort = httpPort;
    _socket = await _bind();
    _send();
    _beat = Timer.periodic(interval, (t) async {
      if (_socket == null) {
        final s = await _bind();
        // Stopped, or an overlapping tick already bound one.
        if (_beat != t || _socket != null) return s?.close();
        _socket = s;
      }
      _send();
      _prune();
    });
    AppLog.i('discovery: started on $port');
  }

  // The SDK reports a failed send (e.g. no network) asynchronously and closes
  // the socket: the beat binds a new one.
  Future<RawDatagramSocket?> _bind() async {
    try {
      // SO_REUSEPORT is unsupported by Dart on Android and Windows.
      final reusePort = Platform.isLinux || Platform.isMacOS;
      final s = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: reusePort,
      );
      s.broadcastEnabled = true;
      void lost() {
        if (_socket == s) _socket = null;
      }
      s.listen(_onEvent(s), onError: (Object e) {
        AppLog.d('discovery: socket error', e);
        lost();
        s.close();
      }, onDone: lost);
      return s;
    } on SocketException catch (e) {
      AppLog.w('discovery: bind on $port failed', e);
      return null;
    }
  }

  Future<void> stop() async {
    _beat?.cancel();
    _beat = null;
    _socket?.close();
    _socket = null;
    if (_peers.isNotEmpty) {
      _peers.clear();
      if (!_controller.isClosed) _controller.add(const []);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }

  void Function(RawSocketEvent) _onEvent(RawDatagramSocket s) => (event) {
        if (event != RawSocketEvent.read) return;
        Datagram? d;
        while ((d = s.receive()) != null) {
          _handle(d!);
        }
      };

  void _handle(Datagram d) {
    if (d.data.length > 512) return;
    final src = d.address.address;
    if (!isLocalNetworkAddress(src, allowLoopback: allowLoopback)) return;
    try {
      final j = jsonDecode(utf8.decode(d.data));
      if (j is! Map || j['m'] != discoveryMagic) return;
      final id = j['id'], name = j['name'], port = j['port'];
      if (id is! String || name is! String || port is! int) return;
      if (id == deviceId || id.isEmpty || id.length > 64) return;
      if (port < 1 || port > 65535) return;
      final old = _peers[id]?.peer;
      final jam = j['jam'];
      final rid = jam is Map && jam['rid'] is String && (jam['rid'] as String).length <= 16 ? jam['rid'] as String : null;
      final jn = jam is Map && jam['name'] is String && (jam['name'] as String).isNotEmpty
          ? (jam['name'] as String)
          : null;
      _peers[id] = (
        peer: Peer(
          id: id,
          name: name.length > 60 ? name.substring(0, 60) : name,
          host: src,
          port: port,
          tlsPort: j['tlsPort'] is int && (j['tlsPort'] as int) > 0 && (j['tlsPort'] as int) < 65536
              ? j['tlsPort'] as int
              : null,
          platform: j['p'] is String ? j['p'] as String : 'other',
          jamName: jn != null && jn.length > 60 ? jn.substring(0, 60) : jn,
          jamRid: jn == null ? null : rid,
        ),
        seen: DateTime.now(),
      );
      if ((old == null || old.jamName != _peers[id]!.peer.jamName || old.jamRid != _peers[id]!.peer.jamRid) &&
          !_controller.isClosed) {
        _controller.add(current);
      }
    } on FormatException {
      // Not one of ours.
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(peerTtl);
    final before = _peers.length;
    _peers.removeWhere((_, v) => v.seen.isBefore(cutoff));
    if (_peers.length != before && !_controller.isClosed) {
      _controller.add(current);
    }
  }

  Map<String, int> _prefixCache = const {};
  Set<String> _prefixFor = const {};
  DateTime _prefixAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Prefixes cost a process or a channel call: re-read when the set of local
  /// addresses changes (network switch, hotspot) or after 30 s.
  Future<Map<String, int>> _prefixes(Set<String> local) async {
    if (setEquals(local, _prefixFor) &&
        DateTime.now().difference(_prefixAt) < const Duration(seconds: 30)) {
      return _prefixCache;
    }
    _prefixAt = DateTime.now();
    _prefixFor = local;
    return _prefixCache = await readNetPrefixes();
  }

  Future<List<({InternetAddress address, int port})>> _targets() async {
    final fixed = _fixedTargets;
    if (fixed != null) return fixed;
    final out = <({InternetAddress address, int port})>[
      (address: InternetAddress('255.255.255.255'), port: port),
    ];
    try {
      final ifaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      final local = {for (final i in ifaces) for (final a in i.addresses) a.address};
      final bcast = broadcastTargets(
        local,
        await _prefixes(local),
        windows: Platform.isWindows,
      );
      for (final b in bcast) {
        out.add((address: InternetAddress(b), port: port));
      }
    } on SocketException catch (e) {
      AppLog.w('discovery: interface list failed', e);
    }
    return out;
  }

  Future<void> _send() async {
    final s = _socket;
    if (s == null) return;
    final data = utf8.encode(jsonEncode({
      'm': discoveryMagic,
      'id': deviceId,
      'name': deviceName,
      'port': _httpPort,
      'tlsPort': ?_tlsPort,
      'p': platformName,
      if (speakerJamName != null) 'jam': {'name': speakerJamName, 'rid': ?speakerJamRid},
    }));
    for (final t in await _targets()) {
      try {
        // send() returns 0 when it would block (on Windows only one datagram
        // can be in flight per socket): retry briefly while the target is
        // known to work, but only try once if it has been blocking.
        final key = '${t.address.address}:${t.port}';
        final blocked = _blocked.contains(key);
        var sent = s.send(data, t.address, t.port);
        for (var i = 0; sent == 0 && i < sendRetries(blocked); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          if (_socket != s) return;
          sent = s.send(data, t.address, t.port);
        }
        if (sent == 0 && _blocked.add(key)) {
          AppLog.d('discovery: send to ${t.address.address} would block');
        } else if (sent != 0 && _blocked.remove(key)) {
          AppLog.d('discovery: send to ${t.address.address} recovered');
        }
      } on SocketException catch (e) {
        AppLog.d('discovery: send failed to ${t.address.address}', e);
      }
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/app_log.dart';
import '../share/lan_server.dart';
import '../share/offers.dart';
import '../share/track_meta.dart';
import 'jam_gate.dart';
import 'jam_models.dart';
import 'jam_turns.dart';
import 'jam_state.dart';

const jamRequestTtl = Duration(minutes: 5);

/// A remote request nobody answers ends after this (R-150).
const jamRemoteRequestTtl = Duration(seconds: 60);

/// A remote guest silent this long shows «unreachable» (R-127).
const jamRemoteUnreachable = Duration(seconds: 60);

/// A remote guest silent this long is removed (R-127).
const jamRemoteStale = Duration(minutes: 10);
const jamPollWait = Duration(seconds: 25);

/// Header with the participant's identity token (state, commands, invites).
const jamTokenHeader = 'x-jam-token';

/// Header with the session-wide token that only gates file downloads.
const jamFileHeader = 'x-jam-file';

/// Resolves an item this device owns (via [JamItem.ref]) to a local file.
typedef JamFileResolver = Future<String?> Function(JamItem item);

/// Resolves an item this device owns to its [TrackMeta] (null: unknown).
typedef JamMetaResolver = Future<TrackMeta?> Function(JamItem item);

/// Path of the cover image of an item this device owns (null: none).
typedef JamCoverResolver = Future<String?> Function(JamItem item);

enum JamRequestStatus { pending, accepted, declined, expired, cancelled }

class JamRequest {
  JamRequest({
    required this.id,
    required this.fromId,
    required this.fromName,
    required this.fromHost,
    required this.fromPort,
    required this.token,
    required this.receivedAt,
    this.silent = false,
    this.remote = false,
    this.friend = false,
    this.ttl = jamRequestTtl,
  });

  final String id, fromId, fromName, fromHost, token;
  final int fromPort;
  final DateTime receivedAt;

  /// Came through the remote bridge (no address, no token of its own).
  final bool remote;

  /// The requester proved to be a saved friend.
  final bool friend;

  /// Unanswered, the request expires after this.
  final Duration ttl;

  /// Sender is blocked or suspended: kept only so it expires unanswered.
  final bool silent;
  JamRequestStatus status = JamRequestStatus.pending;

  /// Credentials handed to the requester once accepted.
  String? sessionId, sessionToken, fileToken;

  /// Where the requester must connect (set when a guest accepted for the host).
  String? base;
}

class _Member {
  _Member(this.id, this.name, this.host, this.port, this.token, this.seen,
      {this.remote = false});

  final String id, name, host, token;
  final int port;
  final bool remote;
  DateTime seen;
}

enum JamAdmitStatus { accepted, full, busy, tooMany, bad }

/// Outcome of [JamHost.admitRequest]; [request] is set when accepted.
typedef JamAdmission = ({JamAdmitStatus status, JamRequest? request});

/// Routes of the Jam protocol, mounted under `/jam` by [OfferNode].
///
/// The host serves `/request`, `/<sid>/state`, `/<sid>/cmd`, `/<sid>/invite`
/// and `/<sid>/leave`; every participant serves `/<sid>/file/<n>` for the
/// items it owns, and only for items currently in the queue.
class JamHost {
  JamHost({
    required this.deviceId,
    required this.deviceName,
    this.allowLoopback = false,
    DateTime Function()? now,
    this.pollWait = jamPollWait,
    this.maxRequestsPerMinute = 5,
    this.maxParticipants = maxJamParticipants,
    this.gate,
  }) : _now = now ?? DateTime.now;

  final String deviceId, deviceName;
  final bool allowLoopback;
  final Duration pollWait;
  final int maxRequestsPerMinute, maxParticipants;
  final DateTime Function() _now;
  final JamGate? gate;

  JamFileResolver? resolveFile;
  JamMetaResolver? resolveMeta;
  JamCoverResolver? resolveCover;

  /// A new valid request arrived (the UI asks the user).
  void Function(JamRequest request)? onRequest;

  /// Called instead of [onRequest] for a friend admitted with `autoAccept`. If
  /// it throws or leaves the request pending, [onRequest] gets it after all.
  FutureOr<void> Function(JamRequest request)? onAutoAccept;

  final requests = <String, JamRequest>{};
  final _recent = <String, List<DateTime>>{};
  final _changes = StreamController<void>.broadcast();

  // Active session as host.
  JamState? _state;
  String? _sid, _fileToken;
  final _members = <String, _Member>{};

  // Active session as guest (set by the client, see attachGuest).
  String? _gSid, _gFileToken;
  JamState? Function()? _gState;

  JamState? get state => _state;
  String? get sessionId => _sid;
  String? get fileToken => _fileToken;

  /// Ids of the guests currently in the session.
  List<String> get memberIds => _members.keys.toList();

  bool get hosting => _state != null && !_state!.ended;

  /// True while this device is a guest of somebody else's Jam.
  bool get isGuest => _gSid != null;

  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    _changes.close();
  }

  void expire() {
    final now = _now();
    var changed = false;
    for (final r in requests.values) {
      if (r.status == JamRequestStatus.pending && r.receivedAt.isBefore(now.subtract(r.ttl))) {
        r.status = JamRequestStatus.expired;
        changed = true;
      }
    }
    // Answerable for a while after the TTL, then gone (silent or not alike).
    final before = requests.length;
    requests.removeWhere((_, r) => r.receivedAt.isBefore(now.subtract(r.ttl * 2)));
    if (changed || requests.length != before) _notify();
  }

  // ---- host API ------------------------------------------------------------

  List<JamParticipant> _roster() => [
        JamParticipant(id: deviceId, name: deviceName),
        for (final m in _members.values)
          JamParticipant(
              id: m.id, name: m.name, host: m.host, port: m.port, remote: m.remote),
      ];

  void _publish(JamState s) {
    final roster = _roster();
    // Someone joined or left during together mode: the turns are redone (D-210).
    _state = s.copyWith(
      version: s.version + 1,
      participants: roster,
      items: s.mode == JamMode.together
          ? togetherOrder(
              s.items, s.currentIndex, [for (final p in roster) p.id])
          : null,
    );
    _notify();
  }

  /// Starts the session if it is not open yet (idempotent); no guest needed.
  void open() {
    if (_state != null) return;
    _sid = newToken();
    _fileToken = newToken();
    _state = JamState(
      hostDeviceId: deviceId,
      outputDeviceId: deviceId,
      positionAt: _now().millisecondsSinceEpoch,
      participants: [JamParticipant(id: deviceId, name: deviceName)],
    );
    AppLog.i('jam: session started');
  }

  /// A running Jam becomes the speaker's: the host is the only output (D-218).
  void makeSpeaker() {
    final s = _state;
    if (s == null || s.ended || s.speaker) return;
    _publish(s.copyWith(
        speaker: true, outputDeviceId: deviceId, outputDeviceIds: const []));
  }

  /// Registers a guest and returns its credentials; starts the session if
  /// this is the first one. Null when the session is full or over.
  ({String sid, String token, String fileToken})? addMember(
      {required String id,
      required String name,
      String host = '',
      int port = 0,
      bool remote = false}) {
    if (_state?.ended ?? false) return null;
    final existing = _members[id];
    if (existing != null && existing.remote == remote) {
      return (sid: _sid!, token: existing.token, fileToken: _fileToken!);
    }
    // A LAN guest back through the bridge (or vice versa) gets a fresh member.
    if (existing == null && _members.length + 1 >= maxParticipants || id == deviceId) {
      return null;
    }
    open();
    final m = _Member(id, name, host, port, newToken(), _now(), remote: remote);
    _members[id] = m;
    _publish(_state!);
    return (sid: _sid!, token: m.token, fileToken: _fileToken!);
  }

  /// Accepts a request that reached this device directly.
  JamState? accept(String requestId) {
    expire();
    final r = requests[requestId];
    if (r == null || r.status != JamRequestStatus.pending) return null;
    final c = addMember(
        id: r.fromId,
        name: r.fromName,
        host: r.fromHost,
        port: r.fromPort,
        remote: r.remote);
    if (c == null) return null;
    r.status = JamRequestStatus.accepted;
    r.sessionId = c.sid;
    r.sessionToken = c.token;
    r.fileToken = c.fileToken;
    _notify();
    return _state;
  }

  void decline(String id) {
    final r = requests[id];
    if (r != null && r.status == JamRequestStatus.pending) {
      r.status = JamRequestStatus.declined;
      _notify();
    }
  }

  /// Applies a command issued by the host itself (or an inbound one).
  JamResult apply(JamCommand cmd, {String? from}) {
    final s = _state;
    if (s == null) return const JamResult.fail(JamError.notFound);
    final r = applyCommand(s, cmd,
        from: from ?? deviceId, nowMs: _now().millisecondsSinceEpoch);
    if (r.isOk) {
      if (cmd.type == JamCommandType.add &&
          s.mode == JamMode.host &&
          r.state!.items.length == s.items.length) {
        AppLog.i('jam: queue full, dropped an inherited track for ${cmd.item?.title}');
      }
      _state = r.state;
      _notify();
    }
    return r;
  }

  /// Removes a guest and the items it owns, except the online ones not yet played:
  /// the output downloads those by video id (D-93). The Jam stays open with the host
  /// alone, who goes on with the queue (D-221).
  void removeMember(String id) {
    if (_members.remove(id) == null || _state == null) return;
    var s = _state!;
    final now = _now().millisecondsSinceEpoch;
    for (final item in s.items.where((i) => i.ownerDeviceId == id).toList()) {
      final upcoming = s.items.indexOf(item) >= s.currentIndex;
      // A fed part (partKey) goes back to its owner on exit: keeping it would double it.
      if (upcoming && item.selfFetchable && item.partKey == null) continue;
      final r = applyCommand(s, JamCommand.remove(item.id),
          from: deviceId, nowMs: now);
      if (r.isOk) s = r.state!;
    }
    // The speaker's only output left: the host takes over, paused (D-220).
    final away = s.speaker && s.outputs.contains(id)
        ? applyCommand(s, const JamCommand.speakerAway(), from: deviceId, nowMs: now)
        : null;
    if (away != null && away.isOk) {
      s = away.state!;
    } else if (s.outputs.contains(id)) {
      // The output cannot be a device that left.
      final left = s.outputs.where((o) => o != id).toList();
      s = left.isEmpty
          ? s.copyWith(
              outputDeviceId: deviceId,
              outputDeviceIds: const [],
              playing: false)
          : s.copyWith(
              outputDeviceId: left.first,
              outputDeviceIds: left.length == 1 ? const [] : left);
    }
    _publish(s);
  }

  /// Drops guests that have not been heard from for [timeout] (remote ones:
  /// [jamRemoteStale]); returns them.
  List<String> dropStale(Duration timeout) {
    final now = _now();
    final stale = [
      for (final m in _members.values)
        if (now.difference(m.seen) > (m.remote ? jamRemoteStale : timeout)) m.id
    ];
    for (final id in stale) {
      removeMember(id);
    }
    return stale;
  }

  /// A valid message arrived from a remote guest: it is reachable.
  void touch(String id) => _members[id]?.seen = _now();

  /// Remote guests silent for more than [silence] (the «unreachable» sign).
  List<String> unreachableIds([Duration silence = jamRemoteUnreachable]) {
    final now = _now();
    return [
      for (final m in _members.values)
        if (m.remote && now.difference(m.seen) > silence) m.id
    ];
  }

  /// Marks the session ended; guests see `ended` on their next poll.
  void endSession() {
    if (_state != null && !_state!.ended) apply(const JamCommand.end());
  }

  /// Drops every trace of the session (after the guests had time to see it).
  void clearSession() {
    _state = null;
    _sid = null;
    _fileToken = null;
    _members.clear();
    gate?.clearEndOfJam();
    _notify();
  }

  // ---- guest API -----------------------------------------------------------

  void attachGuest(String sid, String fileToken, JamState? Function() state) {
    _gSid = sid;
    _gFileToken = fileToken;
    _gState = state;
  }

  void detachGuest() {
    _gSid = _gFileToken = null;
    _gState = null;
  }

  // ---- HTTP ----------------------------------------------------------------

  String _ip(Request r, String Function(Request)? override) {
    if (override != null) return override(r);
    final info = r.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
  }

  static bool _tokenOk(String? expected, String? given) {
    // Remote requests have an empty token: never let '' match.
    if (expected == null || expected.isEmpty || given == null || given.length != expected.length) {
      return false;
    }
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ given.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Response _json(Object body, [int status = 200]) => Response(status,
      body: jsonEncode(body), headers: {'content-type': 'application/json'});

  static Response _fail(JamError e) => switch (e) {
        JamError.forbidden => Response.forbidden('forbidden'),
        JamError.notFound => Response.notFound('not found'),
        JamError.invalid => Response(400, body: 'invalid'),
        JamError.full => Response(409, body: 'queue full'),
        JamError.ended => Response(410, body: 'ended'),
        JamError.noSpeaker => Response(409, body: 'no speaker'),
      };

  /// The guest that owns the identity token of [r], if the session matches.
  _Member? _memberFor(Request r, String sid) {
    if (_sid == null || sid != _sid) return null;
    final given = r.headers[jamTokenHeader];
    for (final m in _members.values) {
      if (_tokenOk(m.token, given)) {
        m.seen = _now();
        return m;
      }
    }
    return null;
  }

  /// Validates and registers a join request. [ip] is null for requests that
  /// do not come from the LAN (the remote bridge, which passes [remote] and no
  /// [port]/[token]); the per-IP limit lives in the router. The gate comes
  /// before full and busy: on the bridge every refusal costs an encryption.
  /// Blocked or suspended senders get a normal acceptance but the request
  /// stays silent: never shown, never "busy", it just expires.
  JamAdmission admitRequest({
    required String id,
    required String name,
    int? port,
    String? token,
    bool remote = false,
    bool friend = false,
    bool autoAccept = false,
    Duration? ttl,
    String? ip,
  }) {
    const bad = (status: JamAdmitStatus.bad, request: null);
    if (id.isEmpty || id.length > 64) return bad;
    if (!remote && (port == null || token == null)) return bad;
    if (port != null && (port < 1 || port > 65535)) return bad;
    if (token != null && (token.length < 8 || token.length > 64)) return bad;
    expire();
    // The gate runs before full/busy, LAN too (the LAN guest maps 409 and 429 to busy).
    if (gate != null && !gate!.allow(id)) {
      return (status: JamAdmitStatus.tooMany, request: null);
    }
    // Muted senders go through the same checks as everybody else.
    if (hosting && _members.length + 1 >= maxParticipants) {
      return (status: JamAdmitStatus.full, request: null);
    }
    // The slot is taken by a stranger: a friend (proof checked) goes first (R-144).
    if (friend) {
      for (final q in requests.values) {
        if (q.status == JamRequestStatus.pending && !q.silent && !q.friend && q.fromId != id) {
          q.status = JamRequestStatus.expired;
        }
      }
    }
    if (requests.values
        .any((q) => q.status == JamRequestStatus.pending && (!q.silent || q.fromId == id))) {
      return (status: JamAdmitStatus.busy, request: null);
    }
    final silent = gate?.isMuted(id) ?? false;
    final req = JamRequest(
      id: newToken(),
      fromId: id,
      fromName: name.length > 60 ? name.substring(0, 60) : name,
      fromHost: ip ?? '',
      fromPort: port ?? 0,
      token: token ?? '',
      receivedAt: _now(),
      silent: silent,
      remote: remote,
      friend: friend,
      ttl: ttl ?? (remote ? jamRemoteRequestTtl : jamRequestTtl),
    );
    requests[req.id] = req;
    if (!silent) {
      _notify();
      // A friend with «Accetta gli amici senza chiedere» on skips the sheet.
      final auto = onAutoAccept;
      if (friend && autoAccept && auto != null) {
        unawaited(_autoAccept(req, auto));
      } else {
        onRequest?.call(req);
      }
    }
    return (status: JamAdmitStatus.accepted, request: req);
  }

  Future<void> _autoAccept(JamRequest req, FutureOr<void> Function(JamRequest) auto) async {
    try {
      await auto(req);
    } on Object catch (e, st) {
      AppLog.w('jam: automatic acceptance failed, asking the user', e, st);
    }
    // Not started (no controller yet, one already starting): the user decides.
    if (req.status == JamRequestStatus.pending) onRequest?.call(req);
  }

  Router buildRouter({String Function(Request)? clientIp}) {
    final router = Router();

    // Any Jam device: someone asks to join. A host adds them itself; a guest
    // forwards the invitation to the host once the user accepts.
    router.post('/request', (Request r) async {
      final ip = _ip(r, clientIp);
      if (!isLocalNetworkAddress(ip, allowLoopback: allowLoopback)) {
        return Response.forbidden('local network only');
      }
      expire();
      final times = _recent.putIfAbsent(ip, () => []);
      final cutoff = _now().subtract(const Duration(minutes: 1));
      times.removeWhere((t) => t.isBefore(cutoff));
      if (times.length >= maxRequestsPerMinute) {
        return Response(429, body: 'too many requests');
      }
      Object? body;
      try {
        body = jsonDecode(await r.readAsString());
      } on FormatException {
        return Response(400, body: 'bad json');
      }
      if (body is! Map) return Response(400, body: 'bad request');
      final id = body['fromId'], name = body['fromName'];
      final port = body['port'], token = body['token'];
      if (id is! String || name is! String || port is! int || token is! String) {
        return Response(400, body: 'bad request');
      }
      final res = admitRequest(id: id, name: name, port: port, token: token, ip: ip);
      if (res.status == JamAdmitStatus.accepted) times.add(_now());
      return switch (res.status) {
        JamAdmitStatus.accepted => _json({'requestId': res.request!.id}, 202),
        JamAdmitStatus.full => Response(409, body: 'full'),
        JamAdmitStatus.busy => Response(409, body: 'busy'),
        JamAdmitStatus.tooMany => Response(429, body: 'too many requests'),
        JamAdmitStatus.bad => Response(400, body: 'bad request'),
      };
    });

    // The requester polls the answer (token = its own request token).
    router.get('/request/<id>', (Request r, String id) {
      expire();
      final q = requests[id];
      if (q == null || !_tokenOk(q.token, r.headers['x-token'])) {
        return Response(401, body: 'unauthorized');
      }
      return _json({
        'status': q.status.name,
        'hostId': deviceId,
        'hostName': deviceName,
        if (q.status == JamRequestStatus.accepted) ...{
          'sessionId': q.sessionId,
          'token': q.sessionToken,
          'fileToken': q.fileToken,
          if (q.base != null) 'base': q.base,
        },
      });
    });

    // The requester withdraws.
    router.post('/request/<id>/cancel', (Request r, String id) {
      final q = requests[id];
      if (q == null || !_tokenOk(q.token, r.headers['x-token'])) {
        return Response(401, body: 'unauthorized');
      }
      if (q.status == JamRequestStatus.pending) {
        q.status = JamRequestStatus.cancelled;
        _notify();
      }
      return Response.ok('ok');
    });

    // Host: state, long polling on `since`.
    router.get('/<sid>/state', (Request r, String sid) async {
      if (_memberFor(r, sid) == null) {
        return Response(401, body: 'unauthorized');
      }
      final since = int.tryParse(r.url.queryParameters['since'] ?? '') ?? -1;
      var s = _state;
      if (s == null) return Response.notFound('no session');
      if (s.version <= since && !s.ended) {
        try {
          await _changes.stream.first.timeout(pollWait);
        } on TimeoutException {
          // fall through: the client just polls again
        }
        s = _state ?? s;
      }
      return _json(s.toJson());
    });

    // Host: commands from a guest.
    router.post('/<sid>/cmd', (Request r, String sid) async {
      final m = _memberFor(r, sid);
      if (m == null) return Response(401, body: 'unauthorized');
      Object? body;
      try {
        body = jsonDecode(await r.readAsString());
      } on FormatException {
        return Response(400, body: 'bad json');
      }
      final cmd = JamCommand.tryParse(body);
      if (cmd == null) return Response(400, body: 'bad command');
      final res = apply(cmd, from: m.id);
      if (!res.isOk) return _fail(res.error!);
      return _json(res.state!.toJson());
    });

    // Any participant: the host's clock, for synchronised playback.
    router.get('/<sid>/time', (Request r, String sid) {
      if (_memberFor(r, sid) == null) {
        return Response(401, body: 'unauthorized');
      }
      return _json({'t': _now().millisecondsSinceEpoch});
    });

    // Host: a guest forwards an invitation accepted on its screen.
    router.post('/<sid>/invite', (Request r, String sid) async {
      if (_memberFor(r, sid) == null) {
        return Response(401, body: 'unauthorized');
      }
      Object? body;
      try {
        body = jsonDecode(await r.readAsString());
      } on FormatException {
        return Response(400, body: 'bad json');
      }
      if (body is! Map) return Response(400, body: 'bad request');
      final id = body['id'], name = body['name'];
      final host = body['host'], port = body['port'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 64 ||
          name is! String ||
          host is! String ||
          port is! int ||
          port < 1 ||
          port > 65535 ||
          !isLocalNetworkAddress(host, allowLoopback: allowLoopback)) {
        return Response(400, body: 'bad request');
      }
      // A muted device cannot get in through a guest either.
      if (gate?.isMuted(id) ?? false) return Response(409, body: 'blocked');
      final c = addMember(
          id: id,
          name: name.length > 60 ? name.substring(0, 60) : name,
          host: host,
          port: port);
      if (c == null) return Response(409, body: 'full');
      return _json({'token': c.token, 'fileToken': c.fileToken});
    });

    // Host: a guest leaves (only that guest and its items go away).
    router.post('/<sid>/leave', (Request r, String sid) {
      final m = _memberFor(r, sid);
      if (m == null) return Response(401, body: 'unauthorized');
      removeMember(m.id);
      return Response.ok('ok');
    });

    // Owner: stream a queued item that this device owns.
    router.get('/<sid>/file/<n>', (Request r, String sid, String n) async {
      final (:err, :item) = _ownedItem(r, sid, n);
      if (item == null) return err!;
      final path = await resolveFile?.call(item);
      if (path == null) return Response.notFound('not found');
      final file = File(path);
      if (!await file.exists()) return Response.notFound('not found');
      final size = await file.length();
      final range = parseRange(r.headers['range'], size);
      if (identical(range, RangeResult.invalid)) {
        return Response(416, headers: {'content-range': 'bytes */$size'});
      }
      final base = {
        'content-type': 'application/octet-stream',
        'accept-ranges': 'bytes',
      };
      if (range.isFull) {
        return Response.ok(file.openRead(),
            headers: {...base, 'content-length': '$size'});
      }
      return Response(206,
          body: file.openRead(range.start, range.end + 1),
          headers: {
            ...base,
            'content-length': '${range.end - range.start + 1}',
            'content-range': 'bytes ${range.start}-${range.end}/$size',
          });
    });

    // Owner: the TrackMeta of a queued item that this device owns.
    router.get('/<sid>/meta/<n>', (Request r, String sid, String n) async {
      final (:err, :item) = _ownedItem(r, sid, n);
      if (item == null) return err!;
      final meta = await resolveMeta?.call(item);
      return meta == null ? Response.notFound('not found') : _json(meta.toJson());
    });

    // Owner: the cover image of a queued item that this device owns.
    router.get('/<sid>/cover/<n>', (Request r, String sid, String n) async {
      final (:err, :item) = _ownedItem(r, sid, n);
      if (item == null) return err!;
      final path = await resolveCover?.call(item);
      final file = path == null ? null : File(path);
      if (file == null || !await file.exists()) return Response.notFound('not found');
      return Response.ok(file.openRead(), headers: {
        'content-type': path!.endsWith('.png') ? 'image/png' : 'image/jpeg',
        'content-length': '${await file.length()}',
      });
    });

    return router;
  }

  /// Shared guard of the per-item routes: valid sid + file token, and the
  /// item is in the queue and owned by this device. Else [err] is the reply.
  ({Response? err, JamItem? item}) _ownedItem(Request r, String sid, String n) {
    final hostSide = _sid != null && sid == _sid;
    final guestSide = _gSid != null && sid == _gSid;
    final token = hostSide ? _fileToken : _gFileToken;
    if ((!hostSide && !guestSide) || !_tokenOk(token, r.headers[jamFileHeader])) {
      return (err: Response(401, body: 'unauthorized'), item: null);
    }
    final st = hostSide ? _state : _gState?.call();
    final id = int.tryParse(n);
    final item = id == null || st == null
        ? null
        : st.items.where((i) => i.id == id).firstOrNull;
    // Only items in the queue are ever exposed.
    if (item == null || item.ownerDeviceId != deviceId) {
      return (err: Response.notFound('not found'), item: null);
    }
    return (err: null, item: item);
  }
}

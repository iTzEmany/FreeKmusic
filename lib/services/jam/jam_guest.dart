import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/app_log.dart';
import '../share/offers.dart' show newToken;
import 'jam_clock.dart';
import 'jam_guest_link.dart';
import 'jam_host.dart';
import 'jam_models.dart';

enum JamJoinOutcome {
  accepted,
  declined,
  expired,
  busy,
  unreachable,
  cancelled,
  tooSoon,
  codeInvalid,
  codeExpired,
  customBroker,
}

/// Client side of a Jam: asks the host, follows its state by long polling and
/// sends commands. The guest also serves the files it owns through [local]
/// (its [JamHost] routes), using the state this client keeps up to date.
class JamGuest implements JamGuestLink {
  JamGuest({
    required this.local,
    Dio? dio,
    this.requestPoll = const Duration(seconds: 1),
    this.maxFailures = 6,
    this.lostAfter = const Duration(seconds: 60),
    this.backoff = const Duration(seconds: 1),
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: jamPollWait + const Duration(seconds: 5),
              validateStatus: (_) => true,
            ));

  final JamHost local;
  final Dio _dio;
  final Duration requestPoll, backoff;
  final int maxFailures;

  /// The session is given up when nothing came back for this long.
  final Duration lostAfter;

  String? _base, _sid, _token, _fileToken, _requestId;
  JamState? _state;
  bool _running = false, _cancel = false;
  final _states = StreamController<JamState>.broadcast();
  final _lost = StreamController<void>.broadcast();

  @override
  JamState? get state => _state;
  bool get active => _running;
  @override
  JamHostFiles? get files => _sid == null || _base == null || _fileToken == null
      ? null
      : JamHostFiles(sessionId: _sid!, hostBase: _base!, fileToken: _fileToken!);
  String? get sessionToken => _token;

  // The LAN link has no reconnection states of its own: a failure ends the Jam.
  @override
  JamLinkState get link => JamLinkState.ok;
  @override
  Stream<JamLinkState> get links => const Stream.empty();
  @override
  Stream<JamState> get states => _states.stream;

  /// Fires when the host stops answering (the session is gone).
  @override
  Stream<void> get lost => _lost.stream;

  Map<String, String> get _auth => {jamTokenHeader: _token ?? ''};

  /// Sends the request and waits for the host's answer (up to [timeout]).
  Future<JamJoinOutcome> join({
    required String host,
    required int port,
    required String ownDeviceId,
    required String ownName,
    required int ownPort,
    Duration timeout = jamRequestTtl,
  }) async {
    _cancel = false;
    final base = 'http://$host:$port/jam';
    final rtoken = newToken();
    try {
      final r = await _dio.post<dynamic>('$base/request',
          data: {
            'fromId': ownDeviceId,
            'fromName': ownName,
            'port': ownPort,
            'token': rtoken,
          });
      if (r.statusCode == 409 || r.statusCode == 429) return JamJoinOutcome.busy;
      if (r.statusCode != 202 || r.data is! Map) return JamJoinOutcome.unreachable;
      _requestId = (r.data as Map)['requestId'] as String?;
    } on DioException catch (e) {
      AppLog.w('jam: request failed', e);
      return JamJoinOutcome.unreachable;
    }
    final deadline = DateTime.now().add(timeout);
    var failures = 0;
    while (!_cancel && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(requestPoll);
      if (_cancel) break;
      try {
        final r = await _dio.get<dynamic>('$base/request/$_requestId',
            options: Options(headers: {'x-token': rtoken}));
        failures = 0;
        final d = r.data;
        if (r.statusCode != 200 || d is! Map) return JamJoinOutcome.unreachable;
        switch (d['status']) {
          case 'accepted':
            final sid = d['sessionId'], tok = d['token'];
            final ftok = d['fileToken'], through = d['base'];
            if (sid is! String || tok is! String || ftok is! String) {
              return JamJoinOutcome.unreachable;
            }
            // A guest that accepted us tells where the host really is.
            _base = through is String && through.startsWith('http://')
                ? through
                : base;
            _sid = sid;
            _token = tok;
            _fileToken = ftok;
            await _bootstrap();
            return _running ? JamJoinOutcome.accepted : JamJoinOutcome.unreachable;
          case 'declined':
            return JamJoinOutcome.declined;
          case 'expired':
            return JamJoinOutcome.expired;
          case 'cancelled':
            return JamJoinOutcome.cancelled;
        }
      } on DioException {
        if (++failures >= maxFailures) return JamJoinOutcome.unreachable;
      }
    }
    if (_cancel) {
      try {
        await _dio.post<dynamic>('$base/request/$_requestId/cancel',
            options: Options(headers: {'x-token': rtoken}));
      } on DioException {
        // The host will expire it anyway.
      }
      return JamJoinOutcome.cancelled;
    }
    return JamJoinOutcome.expired;
  }

  /// Gives up on a pending request.
  @override
  void cancelJoin() => _cancel = true;

  Future<void> _bootstrap() async {
    try {
      final r = await _dio.get<dynamic>('$_base/$_sid/state?since=-1',
          options: Options(headers: _auth));
      final s = r.statusCode == 200 ? JamState.tryParse(r.data) : null;
      if (s == null) return;
      _apply(s);
      local.attachGuest(_sid!, _fileToken!, () => _state);
      _running = true;
      unawaited(_loop());
    } on DioException catch (e) {
      AppLog.w('jam: bootstrap failed', e);
    }
  }

  void _apply(JamState s) {
    if (_state != null && s.version < _state!.version) return;
    _state = s;
    if (!_states.isClosed) _states.add(s);
  }

  Future<void> _loop() async {
    var failures = 0;
    var lastOk = DateTime.now();
    while (_running) {
      try {
        final since = _state?.version ?? -1;
        final r = await _dio.get<dynamic>('$_base/$_sid/state?since=$since',
            options: Options(headers: _auth));
        if (!_running) break;
        if (r.statusCode == 200) {
          failures = 0;
          lastOk = DateTime.now();
          final s = JamState.tryParse(r.data);
          if (s != null) {
            _apply(s);
            if (s.ended) break;
          }
          continue;
        }
        // 401/404/410: the session is over.
        if (r.statusCode == 401 || r.statusCode == 404 || r.statusCode == 410) {
          _markLost();
          return;
        }
        throw DioException(requestOptions: r.requestOptions, response: r);
      } on DioException {
        if (++failures >= maxFailures ||
            DateTime.now().difference(lastOk) > lostAfter) {
          _markLost();
          return;
        }
        await Future<void>.delayed(backoff * failures);
      }
    }
    await _close();
  }

  void _markLost() {
    if (!_lost.isClosed) _lost.add(null);
    unawaited(_close());
  }

  /// Sends [cmd] to the host. Returns the new state or the error.
  @override
  Future<JamResult> send(JamCommand cmd) async {
    if (!_running) return const JamResult.fail(JamError.ended);
    try {
      final r = await _dio.post<dynamic>('$_base/$_sid/cmd',
          data: cmd.toJson(), options: Options(headers: _auth));
      switch (r.statusCode) {
        case 200:
          final s = JamState.tryParse(r.data);
          if (s == null) return const JamResult.fail(JamError.invalid);
          _apply(s);
          return JamResult.ok(s);
        case 403:
          return const JamResult.fail(JamError.forbidden);
        case 404:
          return const JamResult.fail(JamError.notFound);
        case 409:
          // The host answers 409 for both; old guests keep reading `full`.
          return JamResult.fail(
              r.data.toString().trim() == 'no speaker' ? JamError.noSpeaker : JamError.full);
        case 410:
          return const JamResult.fail(JamError.ended);
        default:
          return const JamResult.fail(JamError.invalid);
      }
    } on DioException {
      return const JamResult.fail(JamError.notFound);
    }
  }

  Future<void> _close() async {
    _running = false;
    local.detachGuest();
  }

  /// One timestamp exchange with the host (null when it fails).
  @override
  Future<JamTimeSample?> probeHostTime(int Function() localNow) async {
    if (!_running || _base == null) return null;
    final t0 = localNow();
    try {
      final r = await _dio.get<dynamic>('$_base/$_sid/time',
          options: Options(
              headers: _auth, receiveTimeout: const Duration(seconds: 3)));
      final t1 = localNow();
      final d = r.data;
      if (r.statusCode != 200 || d is! Map || d['t'] is! int) return null;
      return (t0: t0, hostMs: d['t'] as int, t1: t1);
    } on DioException {
      return null;
    }
  }

  /// This device (a guest) accepted [request] from a newcomer: ask the host to
  /// admit it and hand it the host's address and credentials.
  @override
  Future<bool> invite(JamRequest request) async {
    if (!_running || _base == null) return false;
    try {
      final r = await _dio.post<dynamic>('$_base/$_sid/invite',
          data: {
            'id': request.fromId,
            'name': request.fromName,
            'host': request.fromHost,
            'port': request.fromPort,
          },
          options: Options(headers: _auth));
      final d = r.data;
      if (r.statusCode != 200 || d is! Map) return false;
      final tok = d['token'], ftok = d['fileToken'];
      if (tok is! String || ftok is! String) return false;
      request.status = JamRequestStatus.accepted;
      request.sessionId = _sid;
      request.sessionToken = tok;
      request.fileToken = ftok;
      request.base = _base;
      return true;
    } on DioException {
      return false;
    }
  }

  /// Leaves the Jam. The host keeps running with the guest gone.
  @override
  Future<void> leave() async {
    if (_running && _base != null) {
      try {
        await _dio.post<dynamic>('$_base/$_sid/leave',
            options: Options(
                headers: _auth, sendTimeout: const Duration(seconds: 2),
                receiveTimeout: const Duration(seconds: 2)));
      } on DioException {
        // The host notices the missing polls and ends the Jam by itself.
      }
    }
    await _close();
  }

  @override
  Future<void> dispose() async {
    await _close();
    await _states.close();
    await _lost.close();
    _dio.close(force: true);
  }
}

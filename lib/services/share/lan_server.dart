import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import '../../core/app_log.dart';
import 'track_meta.dart';

/// One shared track. The client only ever sees [id]; [path] stays server-side.
class ShareEntry {
  const ShareEntry({
    required this.id,
    required this.path,
    required this.title,
    this.artist,
    this.album,
    required this.sizeBytes,
    required this.durationMs,
    required this.ext,
    this.coverPath,
    this.meta,
    this.streamKey,
    this.shadow = false,
  });

  final int id;
  final String path;
  final String title;
  final String? artist, album, coverPath;
  final int sizeBytes, durationMs;
  final String ext;

  /// Built once from the library row; travels with the track.
  final TrackMeta? meta;

  /// `<source>:<id>` of a saved stream: there is no file, only the key and metadata travel (D-674).
  final String? streamKey;

  /// A stream that is not saved here (shadow row of a playlist, D-761); travels only with the playlist.
  final bool shadow;

  Map<String, Object?> toManifestJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'sizeBytes': sizeBytes,
        'durationMs': durationMs,
        'ext': ext,
        if (meta != null) 'meta': meta!.toJson(),
      };
}

typedef ShareInfo = ({String host, int port, String pin});

class LanGuard {
  LanGuard({
    required this.pin,
    this.maxFailures = 5,
    this.blockFor = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final String pin;
  final int maxFailures;
  final Duration blockFor;
  final DateTime Function() _now;
  final _failures = <String, int>{};
  final _blockedUntil = <String, DateTime>{};

  bool isBlocked(String ip) {
    final until = _blockedUntil[ip];
    if (until == null) return false;
    if (_now().isAfter(until)) {
      _blockedUntil.remove(ip);
      _failures.remove(ip);
      return false;
    }
    return true;
  }

  /// True when [given] is the right PIN; counts failures per IP.
  bool check(String ip, String? given) {
    if (isBlocked(ip)) return false;
    // Constant-ish time compare for a short secret.
    final ok = given != null && given.length == pin.length && _same(given);
    if (ok) {
      _failures.remove(ip);
      return true;
    }
    final n = (_failures[ip] ?? 0) + 1;
    _failures[ip] = n;
    if (n >= maxFailures) _blockedUntil[ip] = _now().add(blockFor);
    return false;
  }

  bool _same(String given) {
    var diff = 0;
    for (var i = 0; i < pin.length; i++) {
      diff |= pin.codeUnitAt(i) ^ given.codeUnitAt(i);
    }
    return diff == 0;
  }
}

/// Builds the request handler (kept separate from the socket for testing).
Handler buildShareHandler({
  required List<ShareEntry> entries,
  required LanGuard guard,
  required String deviceName,
  void Function()? onActivity,
  String Function(Request)? clientIp,
}) {
  // The PIN browse mode serves files only: a stream entry has none.
  entries = [for (final e in entries) if (e.streamKey == null) e];
  final byId = {for (final e in entries) e.id: e};
  final router = Router();

  String ip(Request r) {
    if (clientIp != null) return clientIp(r);
    final info = r.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
  }

  Response? denied(Request r) {
    final who = ip(r);
    if (guard.isBlocked(who)) {
      AppLog.w('share: $who blocked');
      return Response(429, body: 'blocked');
    }
    if (!guard.check(who, r.headers['x-pin'])) {
      AppLog.w('share: $who bad PIN for ${r.url.path}');
      return Response(401, body: 'unauthorized');
    }
    return null;
  }

  router.get('/hello', (Request r) {
    return Response.ok(
      jsonEncode({'app': 'codecore', 'name': deviceName, 'v': 1}),
      headers: {'content-type': 'application/json'},
    );
  });

  router.get('/manifest', (Request r) {
    final d = denied(r);
    if (d != null) return d;
    return Response.ok(
      jsonEncode([for (final e in entries) e.toManifestJson()]),
      headers: {'content-type': 'application/json'},
    );
  });

  router.get('/file/<id>', (Request r, String id) async {
    final d = denied(r);
    if (d != null) return d;
    final entry = _lookup(byId, id);
    if (entry == null) return Response.notFound('not found');
    final file = File(entry.path);
    if (!await file.exists()) return Response.notFound('not found');
    final size = await file.length();
    final range = parseRange(r.headers['range'], size);
    AppLog.i('share: ${ip(r)} file ${entry.id} range=${r.headers['range']}');
    if (range == RangeResult.invalid) {
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
    final length = range.end - range.start + 1;
    return Response(206,
        body: file.openRead(range.start, range.end + 1),
        headers: {
          ...base,
          'content-length': '$length',
          'content-range': 'bytes ${range.start}-${range.end}/$size',
        });
  });

  router.get('/cover/<id>', (Request r, String id) async {
    final d = denied(r);
    if (d != null) return d;
    final entry = _lookup(byId, id);
    final cover = entry?.coverPath;
    if (entry == null || cover == null) return Response.notFound('not found');
    final file = File(cover);
    if (!await file.exists()) return Response.notFound('not found');
    return Response.ok(file.openRead(), headers: {
      'content-type': cover.endsWith('.png') ? 'image/png' : 'image/jpeg',
      'content-length': '${await file.length()}',
    });
  });

  return const Pipeline()
      .addMiddleware((inner) => (Request r) {
            onActivity?.call();
            return inner(r);
          })
      .addHandler(router.call);
}

ShareEntry? _lookup(Map<int, ShareEntry> byId, String raw) {
  final id = int.tryParse(raw);
  return id == null ? null : byId[id];
}

/// Parsed `Range` header. [RangeResult.invalid] marks a 416, [isFull] no range.
class RangeResult {
  const RangeResult(this.start, this.end, {this.isFull = false});

  static const invalid = RangeResult(-1, -1);
  static const full = RangeResult(0, 0, isFull: true);

  final int start, end;
  final bool isFull;
}

RangeResult parseRange(String? header, int size) {
  if (header == null || header.isEmpty) return RangeResult.full;
  final m = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
  if (m == null || size <= 0) return RangeResult.invalid;
  final a = m.group(1)!, b = m.group(2)!;
  if (a.isEmpty && b.isEmpty) return RangeResult.invalid;
  int start, end;
  if (a.isEmpty) {
    final n = int.parse(b); // suffix: last n bytes
    if (n == 0) return RangeResult.invalid;
    start = n >= size ? 0 : size - n;
    end = size - 1;
  } else {
    start = int.parse(a);
    end = b.isEmpty ? size - 1 : int.parse(b);
    if (end >= size) end = size - 1;
  }
  if (start > end || start >= size) return RangeResult.invalid;
  return RangeResult(start, end);
}

class LanServer {
  LanServer({this.idleTimeout = const Duration(minutes: 10)});

  final Duration idleTimeout;
  HttpServer? _server;
  Timer? _idle;
  void Function()? onIdleStop;

  bool get running => _server != null;

  static String generatePin([Random? random]) {
    final r = random ?? Random.secure();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  Future<ShareInfo> start({
    required List<ShareEntry> entries,
    required String host,
    required String deviceName,
  }) async {
    await stop();
    final pin = generatePin();
    final handler = buildShareHandler(
      entries: entries,
      guard: LanGuard(pin: pin),
      deviceName: deviceName,
      onActivity: _touch,
    );
    // Bound to all interfaces only while sharing.
    final server = await io.serve(handler, InternetAddress.anyIPv4, 0);
    _server = server;
    _touch();
    AppLog.i('share: started on port ${server.port}');
    return (host: host, port: server.port, pin: pin);
  }

  void _touch() {
    _idle?.cancel();
    _idle = Timer(idleTimeout, () async {
      AppLog.i('share: idle timeout');
      await stop();
      onIdleStop?.call();
    });
  }

  Future<void> stop() async {
    _idle?.cancel();
    _idle = null;
    final s = _server;
    _server = null;
    if (s != null) {
      await s.close(force: true);
      AppLog.i('share: stopped');
    }
  }
}

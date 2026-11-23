import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../../core/app_log.dart';
import '../../core/text_utils.dart';
import '../stream/stream_key.dart' show isStreamKey;
import 'lan_server.dart';
import 'offer_node.dart' show callerFingerprint;
import 'track_meta.dart';

export 'offer_node.dart' show OfferNode, callerFingerprint, kCallerKey;

const _audioExts = {
  'mp3', 'flac', 'wav', 'ogg', 'oga', 'opus', 'm4a', 'aac', 'aiff', 'aif',
  'wma', 'webm',
};

const maxOfferItems = 500;
const offerTtl = Duration(minutes: 10);

/// True for addresses that can only live on a local network (never the
/// public Internet): RFC1918, link-local and (optionally) loopback.
bool isLocalNetworkAddress(String address, {bool allowLoopback = false}) {
  final a = InternetAddress.tryParse(address);
  if (a == null) return false;
  if (a.isLoopback) return allowLoopback;
  if (a.isLinkLocal) return true;
  final b = a.rawAddress;
  if (a.type == InternetAddressType.IPv4) {
    if (b[0] == 10) return true;
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true;
    if (b[0] == 192 && b[1] == 168) return true;
    return false;
  }
  return b[0] & 0xFE == 0xFC; // fc00::/7 unique local
}

String newToken([Random? random]) {
  final r = random ?? Random.secure();
  return List.generate(16, (_) => r.nextInt(256))
      .map((v) => v.toRadixString(16).padLeft(2, '0'))
      .join();
}

class OfferItem {
  const OfferItem({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    required this.sizeBytes,
    required this.ext,
    this.meta,
    this.hasCover = false,
  });

  final int id;
  final String title;
  final String? artist, album;
  final int sizeBytes;
  final String ext;
  final TrackMeta? meta;
  final bool hasCover;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'sizeBytes': sizeBytes,
        'ext': ext,
        if (meta != null) 'meta': meta!.toJson(),
        if (hasCover) 'hasCover': true,
      };

  /// Strict parsing of untrusted input; returns null for anything odd.
  static OfferItem? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final size = raw['sizeBytes'];
    final ext = raw['ext'];
    final title = raw['title'];
    if (id is! int || size is! int || ext is! String || title is! String) {
      return null;
    }
    final e = ext.toLowerCase();
    if (!_audioExts.contains(e) || size < 0) return null;
    String? clip(Object? v, int max) =>
        v is String ? (v.length > max ? v.substring(0, max) : v) : null;
    return OfferItem(
      id: id,
      title: clip(title, 200) ?? '',
      artist: clip(raw['artist'], 200),
      album: clip(raw['album'], 200),
      sizeBytes: size,
      ext: e,
      meta: TrackMeta.tryParse(raw['meta']),
      hasCover: raw['hasCover'] == true,
    );
  }

  /// `Artist - Title`, sanitised; never a path.
  String get baseName => sanitizeFileName(
      artist == null || artist!.isEmpty ? title : '$artist - $title');
}

/// A saved stream offered without a file (D-674): the receiver saves the row.
/// Travels in the optional `streams` list, which older versions never read.
const _maxStreamMs = 24 * 3600 * 1000;

class StreamOffer {
  const StreamOffer({required this.key, required this.title, this.artist, this.album, this.durationMs = 0, this.meta});

  final String key, title;
  final String? artist, album;
  final int durationMs;
  final TrackMeta? meta;

  Map<String, Object?> toJson() => {
        'key': key,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        if (meta != null) 'meta': meta!.toJson(),
      };

  /// Strict parsing of untrusted input; null for anything odd.
  static StreamOffer? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final key = raw['key'], title = raw['title'], dur = raw['durationMs'];
    if (key is! String || title is! String || title.isEmpty || !isStreamKey(key)) return null;
    String? clip(Object? v) => v is String ? (v.length > 200 ? v.substring(0, 200) : v) : null;
    return StreamOffer(
      key: key,
      title: clip(title) ?? '',
      artist: clip(raw['artist']),
      album: clip(raw['album']),
      durationMs: dur is int && dur >= 0 && dur <= _maxStreamMs ? dur : 0,
      meta: TrackMeta.tryParse(raw['meta']),
    );
  }
}

enum OfferStatus { pending, accepted, declined, cancelled, expired, done, failed }

class IncomingOffer {
  IncomingOffer({
    required this.offerId,
    required this.fromId,
    required this.fromName,
    required this.fromHost,
    required this.fromPort,
    this.fromTlsPort,
    this.callerFingerprint,
    required this.token,
    required this.items,
    this.streams = const [],
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  final String offerId, fromId, fromName, fromHost, token;
  final int fromPort;

  /// HTTPS port of the sender, when it has one: answers go there.
  final int? fromTlsPort;

  /// The certificate fingerprint that signed the request (null if it was not
  /// signed): who the sender really is, whatever it calls itself.
  final String? callerFingerprint;

  /// Set by the hub: the signer is a paired device with the id it claims.
  bool trusted = false;
  final List<OfferItem> items;

  /// Saved streams of the offer: no file, so they are not in [items] nor in [received].
  final List<StreamOffer> streams;
  final DateTime receivedAt;
  OfferStatus status = OfferStatus.pending;
  int received = 0; // files already stored

  int get totalBytes => items.fold(0, (a, b) => a + b.sizeBytes);
}

class OutgoingOffer {
  OutgoingOffer({
    required this.offerId,
    required this.toId,
    required this.toName,
    required this.token,
    required this.entries,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String offerId, toId, toName, token;
  final Map<int, ShareEntry> entries;
  final DateTime createdAt;
  OfferStatus status = OfferStatus.pending;

  bool get open =>
      status == OfferStatus.pending || status == OfferStatus.accepted;
}

/// Offer state plus the HTTP routes both roles need:
/// receiver: `POST /` (new offer), `POST /<id>/cancel`;
/// sender:   `POST /<id>/accept|decline|done`, `GET /<id>/file/<n>`.
/// Mounted under `/offer` by [OfferNode].
class OfferService {
  OfferService({
    required this.deviceId,
    required this.deviceName,
    DateTime Function()? now,
    this.allowLoopback = false,
    this.maxPendingIncoming = 5,
    this.maxOffersPerMinute = 5,
  }) : _now = now ?? DateTime.now;

  final String deviceId, deviceName;
  final bool allowLoopback;
  final int maxPendingIncoming, maxOffersPerMinute;
  final DateTime Function() _now;

  final incoming = <String, IncomingOffer>{};
  final outgoing = <String, OutgoingOffer>{};
  final _changes = StreamController<void>.broadcast();
  final _recent = <String, List<DateTime>>{}; // ip -> offer timestamps

  /// Fired when a new valid offer arrives (the UI asks the user).
  void Function(IncomingOffer offer)? onIncoming;

  Stream<void> get changes => _changes.stream;

  bool get hasOpenOutgoing {
    expire();
    return outgoing.values.any((o) => o.open);
  }

  void notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() => _changes.close();

  void expire() {
    final limit = _now().subtract(offerTtl);
    for (final o in outgoing.values) {
      if (o.open && o.createdAt.isBefore(limit)) o.status = OfferStatus.expired;
    }
    for (final o in incoming.values) {
      if (o.status == OfferStatus.pending && o.receivedAt.isBefore(limit)) {
        o.status = OfferStatus.expired;
      }
    }
  }

  // ---- sender side -------------------------------------------------------

  OutgoingOffer createOutgoing({
    required String toId,
    required String toName,
    required List<ShareEntry> entries,
  }) {
    final offer = OutgoingOffer(
      offerId: newToken(),
      toId: toId,
      toName: toName,
      token: newToken(),
      entries: {for (final e in entries) e.id: e},
      createdAt: _now(),
    );
    outgoing[offer.offerId] = offer;
    notify();
    return offer;
  }

  Map<String, Object?> offerPayload(OutgoingOffer o, int port, {int? tlsPort}) => {
        'offerId': o.offerId,
        'fromId': deviceId,
        'fromName': deviceName,
        'port': port,
        'tlsPort': ?tlsPort,
        'token': o.token,
        'items': [
          for (final e in o.entries.values)
            if (e.streamKey == null)
              OfferItem(
                id: e.id,
                title: e.title,
                artist: e.artist,
                album: e.album,
                sizeBytes: e.sizeBytes,
                ext: e.ext,
                meta: e.meta,
                hasCover: e.coverPath != null,
              ).toJson(),
        ],
        // Optional: an older receiver ignores it and sees only the files.
        if (o.entries.values.any((e) => e.streamKey != null))
          'streams': [
            for (final e in o.entries.values)
              if (e.streamKey != null)
                StreamOffer(
                  key: e.streamKey!,
                  title: e.title,
                  artist: e.artist,
                  album: e.album,
                  durationMs: e.durationMs,
                  meta: e.meta,
                ).toJson(),
          ],
      };

  // ---- HTTP ----------------------------------------------------------------

  String _ip(Request r, String Function(Request)? override) {
    if (override != null) return override(r);
    final info = r.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
  }

  bool _tokenOk(String expected, String? given) {
    if (given == null || given.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= expected.codeUnitAt(i) ^ given.codeUnitAt(i);
    }
    return diff == 0;
  }

  Router buildRouter({String Function(Request)? clientIp}) {
    final router = Router();

    // Receiver: someone offers files.
    router.post('/', (Request r) async {
      final ip = _ip(r, clientIp);
      if (!isLocalNetworkAddress(ip, allowLoopback: allowLoopback)) {
        AppLog.w('offer: refused non-local $ip');
        return Response.forbidden('local network only');
      }
      expire();
      final times = _recent.putIfAbsent(ip, () => []);
      final cutoff = _now().subtract(const Duration(minutes: 1));
      times.removeWhere((t) => t.isBefore(cutoff));
      final pending =
          incoming.values.where((o) => o.status == OfferStatus.pending).length;
      if (times.length >= maxOffersPerMinute || pending >= maxPendingIncoming) {
        return Response(429, body: 'too many offers');
      }
      Object? body;
      try {
        body = jsonDecode(await r.readAsString());
      } on FormatException {
        return Response(400, body: 'bad json');
      }
      if (body is! Map) return Response(400, body: 'bad request');
      final offerId = body['offerId'], fromId = body['fromId'];
      final fromName = body['fromName'], port = body['port'];
      final token = body['token'], rawItems = body['items'];
      final tlsRaw = body['tlsPort'];
      // Optional and lenient: a bad entry is skipped, an absent list is no streams.
      final rawStreams = body['streams'];
      final streams = <StreamOffer>[
        if (rawStreams is List)
          for (final raw in rawStreams.take(maxOfferItems))
            ?StreamOffer.tryParse(raw),
      ];
      final tlsPort = tlsRaw is int && tlsRaw > 0 && tlsRaw < 65536 ? tlsRaw : null;
      if (offerId is! String ||
          fromId is! String ||
          fromName is! String ||
          port is! int ||
          token is! String ||
          rawItems is! List ||
          offerId.isEmpty ||
          offerId.length > 64 ||
          token.length < 8 ||
          token.length > 64 ||
          port < 1 ||
          port > 65535 ||
          (rawItems.isEmpty && streams.isEmpty) ||
          rawItems.length + streams.length > maxOfferItems) {
        return Response(400, body: 'bad request');
      }
      final items = <OfferItem>[];
      for (final raw in rawItems) {
        final it = OfferItem.tryParse(raw);
        if (it != null) items.add(it);
      }
      if (items.length != rawItems.length) {
        return Response(400, body: 'invalid items');
      }
      if (incoming.containsKey(offerId)) {
        return Response(409, body: 'duplicate');
      }
      times.add(_now());
      final offer = IncomingOffer(
        offerId: offerId,
        fromId: fromId,
        // The name is only a label; it is shown, never trusted.
        fromName: fromName.length > 60 ? fromName.substring(0, 60) : fromName,
        // Where to pull from: the observed address, not a claimed one.
        fromHost: ip,
        fromPort: port,
        fromTlsPort: tlsPort,
        callerFingerprint: callerFingerprint(r),
        token: token,
        items: items,
        streams: streams,
        receivedAt: _now(),
      );
      incoming[offerId] = offer;
      notify();
      AppLog.i('offer: ${items.length} items from $ip');
      onIncoming?.call(offer);
      return Response(202,
          body: jsonEncode({'status': 'pending'}),
          headers: {'content-type': 'application/json'});
    });

    // Receiver: the sender withdraws a pending offer.
    router.post('/<id>/cancel', (Request r, String id) {
      final o = incoming[id];
      if (o == null) return Response.notFound('not found');
      if (!_tokenOk(o.token, r.headers['x-token'])) {
        return Response(401, body: 'unauthorized');
      }
      if (o.status == OfferStatus.pending) o.status = OfferStatus.cancelled;
      notify();
      return Response.ok('ok');
    });

    OutgoingOffer? authorised(Request r, String id) {
      final o = outgoing[id];
      if (o == null || !_tokenOk(o.token, r.headers['x-token'])) return null;
      return o;
    }

    // Sender: the receiver answers.
    router.post('/<id>/accept', (Request r, String id) {
      expire();
      final o = authorised(r, id);
      if (o == null) return Response(401, body: 'unauthorized');
      if (o.status != OfferStatus.pending) {
        return Response(409, body: 'not pending');
      }
      o.status = OfferStatus.accepted;
      notify();
      return Response.ok('ok');
    });

    router.post('/<id>/decline', (Request r, String id) {
      final o = authorised(r, id);
      if (o == null) return Response(401, body: 'unauthorized');
      if (o.status == OfferStatus.pending) o.status = OfferStatus.declined;
      notify();
      return Response.ok('ok');
    });

    router.post('/<id>/done', (Request r, String id) {
      final o = authorised(r, id);
      if (o == null) return Response(401, body: 'unauthorized');
      if (o.status == OfferStatus.accepted) o.status = OfferStatus.done;
      notify();
      return Response.ok('ok');
    });

    // Sender: the cover of one item of an accepted offer.
    router.get('/<id>/cover/<n>', (Request r, String id, String n) async {
      expire();
      final o = authorised(r, id);
      if (o == null) return Response(401, body: 'unauthorized');
      if (o.status != OfferStatus.accepted) {
        return Response.forbidden('offer not accepted');
      }
      final itemId = int.tryParse(n);
      final cover = itemId == null ? null : o.entries[itemId]?.coverPath;
      if (cover == null) return Response.notFound('not found');
      final file = File(cover);
      if (!await file.exists()) return Response.notFound('not found');
      return Response.ok(file.openRead(), headers: {
        'content-type': cover.endsWith('.png') ? 'image/png' : 'image/jpeg',
        'content-length': '${await file.length()}',
      });
    });

    // Sender: stream one file of an accepted offer.
    router.get('/<id>/file/<n>', (Request r, String id, String n) async {
      expire();
      final o = authorised(r, id);
      if (o == null) return Response(401, body: 'unauthorized');
      if (o.status != OfferStatus.accepted) {
        return Response.forbidden('offer not accepted');
      }
      final itemId = int.tryParse(n);
      final entry = itemId == null ? null : o.entries[itemId];
      if (entry == null) return Response.notFound('not found');
      final file = File(entry.path);
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

    return router;
  }
}

/// The HTTP endpoint of this device while discovery/receiving is on.
/// Bound to all interfaces; every route refuses non-local peers.

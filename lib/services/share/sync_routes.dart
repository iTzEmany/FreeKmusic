import 'dart:convert';
import 'dart:isolate';
import 'dart:io' show HttpConnectionInfo;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../backup/user_data.dart';
import 'collection_sync.dart';
import 'offer_node.dart' show callerFingerprint;
import 'playlist_sync.dart';
import 'tables_sync.dart';

// Top level so the isolate's closure holds nothing but [body] (the router's callbacks cannot cross isolates).
Future<String> _encodeOffThread(Object body) => Isolate.run(() => jsonEncode(body));

/// A request to be sent these tracks («Chiedi i brani mancanti»).
class TrackRequest {
  const TrackRequest({required this.refs, required this.port, this.tlsPort});

  final List<TrackRef> refs;

  /// Where the requester receives offers; the host is the caller's address.
  final int port;
  final int? tlsPort;
}

const kMaxWantedTracks = 500;

/// The sync routes, mounted at `/sync` on the HTTPS server only and answered
/// only to a **trusted** signer: a device that merely knows the address gets 403.
///
/// * `GET /playlists` — every playlist in the portable format.
/// * `GET /collections` — everything else but the lyrics, mine only: favourite albums and playlists, streamed tracks
///   saved or hearted (`StreamEntry`, with dates), deletions (`{kind, key, deletedAt}`), the settings that do not
///   depend on the device ([syncedSettings]), the latest listens, the tags and the tags of each track. Any other
///   trusted caller gets every list empty (and the server reads nothing), so nothing is deleted there.
/// * `POST /texts` `{after}` — lyrics and curiosities of the library tracks with an id above `after`, one page
///   ([kTextsPerPage]) with the id to continue from (`next`, null at the end), mine only (empty to anyone else).
/// * `POST /want` — «send me these tracks»: answered by an offer in the other direction.
Router buildSyncRouter({
  required Future<List<RemotePlaylist>> Function() export,
  required Future<List<FavoriteCollectionData>> Function() exportFavorites,
  required Future<List<StreamEntry>> Function() exportStreams,
  required Future<List<TombstoneData>> Function() exportTombstones,
  required Future<Map<String, Object>> Function() exportSettings,
  required Future<List<PlayEntry>> Function() exportPlays,
  required Future<({List<TagEntry> tags, List<TaggedTrack> tagged})> Function() exportTags,
  required Future<({List<TextEntry> texts, int? next})> Function(int after) exportTexts,
  required bool Function(String fingerprint) isTrusted,
  required bool Function(String fingerprint) isMine,
  required Future<int> Function(String callerHost, String callerFingerprint, TrackRequest request) onWant,
}) {
  Response json(int code, Object body) =>
      Response(code, body: jsonEncode(body), headers: {'content-type': 'application/json'});

  String? trustedCaller(Request r) {
    final fp = callerFingerprint(r);
    return fp != null && isTrusted(fp) ? fp : null;
  }

  final router = Router();
  router.get('/playlists', (Request r) async {
    if (trustedCaller(r) == null) return json(403, {'error': 'not trusted'});
    return json(200, {'playlists': [for (final p in await export()) p.toJson()]});
  });

  router.get('/collections', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    if (!isMine(fp)) {
      return json(200, {
        'favorites': const [], 'streams': const [], 'tombstones': const [], 'settings': const {},
        'plays': const [], 'tags': const [], 'tagged': const [],
      });
    }
    final tags = await exportTags();
    final body = {
      'favorites': [for (final f in await exportFavorites()) f.toJson()],
      'streams': [for (final e in await exportStreams()) e.toJson()],
      'tombstones': [for (final t in await exportTombstones()) t.toJson()],
      'settings': await exportSettings(),
      'plays': [for (final p in await exportPlays()) p.toJson()],
      'tags': [for (final t in tags.tags) t.toJson()],
      'tagged': [for (final t in tags.tagged) t.toJson()],
    };
    // Several MB of JSON: encoded in an isolate so the server's own thread (the UI's) does not stall.
    return Response(200, body: await _encodeOffThread(body), headers: {'content-type': 'application/json'});
  });

  router.post('/texts', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    final Object? body;
    try {
      body = jsonDecode(await r.readAsString());
    } on FormatException {
      return json(400, {'error': 'bad json'});
    }
    if (body is! Map) return json(400, {'error': 'bad request'});
    final after = body['after'];
    final page = isMine(fp) ? await exportTexts(after is int && after > 0 ? after : 0) : (texts: const <TextEntry>[], next: null);
    return json(200, {'texts': [for (final t in page.texts) t.toJson()], 'next': page.next});
  });

  router.post('/want', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    final Object? body;
    try {
      body = jsonDecode(await r.readAsString());
    } on FormatException {
      return json(400, {'error': 'bad json'});
    }
    if (body is! Map || body['refs'] is! List || body['port'] is! int) return json(400, {'error': 'bad request'});
    final raw = body['refs'] as List;
    if (raw.isEmpty || raw.length > kMaxWantedTracks) return json(400, {'error': 'bad count'});
    final tls = body['tlsPort'];
    final info = r.context['shelf.io.connection_info'];
    final host = info is HttpConnectionInfo ? info.remoteAddress.address : '';
    if (host.isEmpty) return json(400, {'error': 'no address'});
    final sent = await onWant(
      host,
      fp,
      TrackRequest(
        refs: [for (final e in raw) if (e is Map<String, dynamic>) TrackRef.fromJson(e)],
        port: body['port'] as int,
        tlsPort: tls is int ? tls : null,
      ),
    );
    return json(202, {'offered': sent});
  });
  return router;
}

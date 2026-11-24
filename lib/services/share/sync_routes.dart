import 'dart:convert';
import 'dart:io' show HttpConnectionInfo;

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../backup/user_data.dart';
import 'collection_sync.dart';
import 'offer_node.dart' show callerFingerprint;
import 'playlist_sync.dart';
import 'tables_sync.dart';

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
/// * `GET /favorites` — the favourite albums and playlists (`{kind, key, addedAt}`), only to a caller that is one
///   of the user's own devices ([isMine]); any other trusted caller gets an empty list.
/// * `GET /streams` — the streamed tracks saved to the library or hearted (`StreamEntry`, with their dates), mine only.
/// * `POST /tombstones` `{since?}` — the deletions (`{kind, key, deletedAt}`), mine only; any other trusted caller
///   gets an empty list, so nothing is deleted there. A POST so that `since` is in the signed body.
/// * `GET /settings` — the settings that do not depend on the device ([syncedSettings]), mine only.
/// * `GET /plays` — the latest listens (`PlayEntry`), mine only.
/// * `GET /tags` — the user's tags and the tags of each track, mine only.
/// * `POST /texts` `{after}` — lyrics and curiosities of the library tracks with an id above `after`, one page
///   ([kTextsPerPage]) with the id to continue from (`next`, null at the end), mine only.
///   Anything the route sends to a caller that is not mine is empty.
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

  router.get('/favorites', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    return json(200, {
      'favorites': [
        if (isMine(fp))
          for (final f in await exportFavorites()) f.toJson(),
      ],
    });
  });

  router.get('/streams', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    return json(200, {
      'streams': [
        if (isMine(fp))
          for (final e in await exportStreams()) e.toJson(),
      ],
    });
  });

  router.get('/settings', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    return json(200, {'settings': isMine(fp) ? await exportSettings() : const {}});
  });

  router.get('/plays', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    return json(200, {
      'plays': [
        if (isMine(fp))
          for (final p in await exportPlays()) p.toJson(),
      ],
    });
  });

  router.get('/tags', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    final all = isMine(fp) ? await exportTags() : (tags: const <TagEntry>[], tagged: const <TaggedTrack>[]);
    return json(200, {
      'tags': [for (final t in all.tags) t.toJson()],
      'tagged': [for (final t in all.tagged) t.toJson()],
    });
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

  router.post('/tombstones', (Request r) async {
    final fp = trustedCaller(r);
    if (fp == null) return json(403, {'error': 'not trusted'});
    final all = isMine(fp) ? await exportTombstones() : const <TombstoneData>[];
    return json(200, {'tombstones': [for (final t in all) t.toJson()]});
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

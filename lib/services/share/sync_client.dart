import '../../core/app_log.dart';
import '../backup/user_data.dart';
import 'collection_sync.dart';
import 'lan_client.dart';
import 'playlist_sync.dart';
import 'settings_sync.dart';
import 'tables_sync.dart';

enum SyncError { notTrusted, unreachable, identityChanged, failed }

class SyncException implements Exception {
  const SyncException(this.error);

  final SyncError error;

  @override
  String toString() => 'SyncException($error)';
}

/// A 404 on the first collection route: the other device predates it (a thrown marker, never leaves [SyncClient]).
class _NoCollectionRoutes implements Exception {
  const _NoCollectionRoutes();
}

/// The initiator side of the sync: reads the other device's playlists and asks
/// for the tracks this one lacks. Always over HTTPS, signed, pinned.
class SyncClient {
  SyncClient(this._client);

  final LanClient _client;

  Never _fail(Object e) {
    if (e is LanException) {
      throw SyncException(e.error == LanError.identityChanged ? SyncError.identityChanged : SyncError.unreachable);
    }
    throw const SyncException(SyncError.failed);
  }

  /// The JSON object of a sync answer: what the other device sends is not trusted.
  Future<Map<String, dynamic>> _reply(Future<SecureReply> Function() call, {bool firstNewRoute = false}) async {
    try {
      final r = await call();
      if (firstNewRoute && r.status == 404) throw const _NoCollectionRoutes();
      if (r.status == 403) throw const SyncException(SyncError.notTrusted);
      final body = r.json;
      if (r.status != 200 || body == null) throw const SyncException(SyncError.failed);
      return body;
    } on SyncException {
      rethrow;
    } on _NoCollectionRoutes {
      rethrow;
    } on Object catch (e) {
      _fail(e);
    }
  }

  /// The list under [key] of an answer, cut to [limit] (default [kMaxSyncItems]).
  List<Object?> _list(Map<String, dynamic> body, String key, [int limit = kMaxSyncItems]) {
    final list = body[key];
    if (list is! List) throw const SyncException(SyncError.failed);
    return list.take(limit).toList();
  }

  Future<List<Object?>> _items(Future<SecureReply> Function() call, String key) async => _list(await _reply(call), key);

  /// A malformed playlist fails the whole sync: dropping it, or a track of it, could replace a playlist here with less.
  Future<List<RemotePlaylist>> playlists(
    String host,
    int tlsPort, {
    required String pin,
  }) async {
    final raw = await _items(
      () => _client.secureGet(host, tlsPort, '/sync/playlists', pin: pin),
      'playlists',
    );
    try {
      return [
        for (final p in raw) RemotePlaylist.fromJson(p as Map<String, dynamic>),
      ];
    } on Object catch (e) {
      AppLog.w('sync: malformed playlist from the other device: $e');
      throw const SyncException(SyncError.failed);
    }
  }

  /// The other device's favourites, saved and hearted streamed tracks, deletions, settings, lyrics, listens and tags: asked only when [mine]
  /// (it is one of the user's own devices; it also has to think so of this one), else they are empty and
  /// only the playlists are synced. Malformed entries, unknown kinds, settings out of the list and impossible dates are dropped.
  Future<SyncSide> collections(
    String host,
    int tlsPort, {
    Future<List<TextEntry>> Function(List<TextEntry> page)? keepTexts,
    int maxTextChars = kMaxSyncTextChars,
    required String pin,
    required bool mine,
  }) async {
    if (!mine) return const SyncSide();
    final List<Object?> favorites;
    try {
      favorites = _list(
        await _reply(() => _client.secureGet(host, tlsPort, '/sync/favorites', pin: pin), firstNewRoute: true),
        'favorites',
      );
    } on _NoCollectionRoutes {
      AppLog.w('sync: the other device is of an older version, only the playlists are synced');
      return const SyncSide();
    }
    final streams = await _items(
      () => _client.secureGet(host, tlsPort, '/sync/streams', pin: pin),
      'streams',
    );
    final tombstones = await _items(
      () => _client.securePost(
        host,
        tlsPort,
        '/sync/tombstones',
        const {},
        pin: pin,
      ),
      'tombstones',
    );
    final settings = await _reply(() => _client.secureGet(host, tlsPort, '/sync/settings', pin: pin));
    final plays = await _items(() => _client.secureGet(host, tlsPort, '/sync/plays', pin: pin), 'plays');
    final tags = await _reply(() => _client.secureGet(host, tlsPort, '/sync/tags', pin: pin));
    return SyncSide(
      favorites: [for (final f in favorites) ?FavoriteCollectionData.tryParse(f)],
      streams: [for (final s in streams) ?StreamEntry.tryParse(s)],
      tombstones: latestTombstones(tombstones),
      settings: parseSyncedSettings(settings['settings']),
      tables: TablesBundle(
        texts: await _texts(host, tlsPort, pin, keepTexts, maxTextChars),
        plays: [for (final p in plays) ?PlayEntry.tryParse(p)],
        tags: [for (final t in _list(tags, 'tags')) ?TagEntry.tryParse(t)],
        tagged: limitTagged([for (final t in _list(tags, 'tagged')) ?TaggedTrack.tryParse(t)]),
      ),
    );
  }

  /// The texts page by page, only the ones [keep] lets through (the news, so the rest is never held in memory),
  /// until the other device has no more. Bounded: at most [kMaxSyncItems] rows read (the first ones by track id,
  /// empty pages included), [maxChars] characters kept; a page that does not move forward ends the reading.
  Future<List<TextEntry>> _texts(
    String host,
    int tlsPort,
    String pin,
    Future<List<TextEntry>> Function(List<TextEntry> page)? keep,
    int maxChars,
  ) async {
    final out = <TextEntry>[];
    var after = 0, chars = 0;
    for (var pages = 0; pages < kMaxSyncItems ~/ kTextsPerPage && chars < maxChars; pages++) {
      final body = await _reply(() => _client.securePost(host, tlsPort, '/sync/texts', {'after': after}, pin: pin));
      var page = [for (final t in _list(body, 'texts', kTextsPerPage)) ?TextEntry.tryParse(t)];
      if (keep != null) page = await keep(page);
      for (final t in page) {
        chars += (t.plain?.length ?? 0) + (t.synced?.length ?? 0) + (t.curiosities?.length ?? 0);
        out.add(t);
        if (chars >= maxChars) break;
      }
      final next = body['next'];
      if (next is! int || next <= after) break;
      after = next;
    }
    return out;
  }

  /// Asks the other device to offer [refs] back (to [port]/[tlsPort] here).
  /// Returns how many tracks it found and is offering.
  Future<int> want(String host, int tlsPort, List<TrackRef> refs,
      {required String pin, required int port, int? tlsPortHere}) async {
    try {
      final r = await _client.securePost(host, tlsPort, '/sync/want', {
        'refs': [for (final t in refs) t.toJson()],
        'port': port,
        'tlsPort': ?tlsPortHere,
      }, pin: pin);
      if (r.status == 403) throw const SyncException(SyncError.notTrusted);
      if (r.status != 202) throw const SyncException(SyncError.failed);
      return (r.json?['offered'] as num?)?.toInt() ?? 0;
    } on SyncException {
      rethrow;
    } on Object catch (e) {
      _fail(e);
    }
  }
}

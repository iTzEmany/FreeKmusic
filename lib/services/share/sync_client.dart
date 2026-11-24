import '../../core/app_log.dart';
import '../backup/user_data.dart';
import 'collection_sync.dart';
import 'lan_client.dart';
import 'playlist_sync.dart';

enum SyncError { notTrusted, unreachable, identityChanged, failed }

class SyncException implements Exception {
  const SyncException(this.error);

  final SyncError error;

  @override
  String toString() => 'SyncException($error)';
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

  /// The list under [key] of a sync answer, cut to [kMaxSyncItems]: what the other device sends is not trusted.
  Future<List<Object?>> _items(Future<SecureReply> Function() call, String key) async {
    try {
      final r = await call();
      if (r.status == 403) throw const SyncException(SyncError.notTrusted);
      final list = r.json?[key];
      if (r.status != 200 || list is! List) throw const SyncException(SyncError.failed);
      return list.take(kMaxSyncItems).toList();
    } on SyncException {
      rethrow;
    } on Object catch (e) {
      _fail(e);
    }
  }

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

  /// The other device's favourites, saved and hearted streamed tracks and its deletions: asked only when [mine]
  /// (it is one of the user's own devices; it also has to think so of this one), else they are empty and
  /// only the playlists are synced. Malformed entries, unknown kinds and impossible dates are dropped.
  Future<SyncSide> collections(
    String host,
    int tlsPort, {
    required String pin,
    required bool mine,
  }) async {
    if (!mine) return const SyncSide();
    final favorites = await _items(
      () => _client.secureGet(host, tlsPort, '/sync/favorites', pin: pin),
      'favorites',
    );
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
    return SyncSide(
      favorites: [for (final f in favorites) ?FavoriteCollectionData.tryParse(f)],
      streams: [for (final s in streams) ?StreamEntry.tryParse(s)],
      tombstones: latestTombstones(tombstones),
    );
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

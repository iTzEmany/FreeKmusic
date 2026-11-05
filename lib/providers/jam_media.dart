import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart';
import '../services/jam/jam_cache.dart';
import '../services/jam/jam_guest_link.dart' show JamHostFiles;
import '../services/jam/jam_host.dart';
import '../services/jam/jam_models.dart';
import '../services/jam/jam_output.dart';
import '../services/jam/jam_online_adder.dart';
import '../services/jam/jam_part_feeder.dart' show jamPartKeyId;
import '../services/jam/remote/jam_remote_meta.dart';
import '../services/share/track_meta.dart';
import 'database_providers.dart';
import 'jam_providers.dart'
    show
        JamRole,
        JamUiState,
        jamCacheKey,
        jamFetchMeta,
        jamLocalFile,
        jamPinKeys;
import 'library_providers.dart' show coverStoreProvider;
import 'online_providers.dart'
    show
        creditsRepositoryProvider,
        curiosityServiceProvider,
        lyricsChainProvider;
import 'settings_providers.dart';
import 'stream_providers.dart';
import 'youtube_providers.dart' show downloadIndexProvider;

/// Where the Jam's files, metadata and covers come from: our library or stream cache, the owner
/// over the LAN, or the video id. Owns the Jam's file cache, pins and the HTTP client.
class JamMedia {
  JamMedia(this._ref, this._ownId, this._state, this._host, this._guestFiles);

  /// A getter, not the Ref: a rebuilt provider gets a new Ref and the first goes unmounted.
  final Ref Function() _ref;
  final String Function() _ownId;
  final JamUiState Function() _state;
  final JamHost? Function() _host;
  final JamHostFiles? Function() _guestFiles;

  /// The Jam's file cache; set when the Jam begins, cleared when it ends.
  JamCache? cache;

  /// Cache keys pinned for the queue (counted pins: the player's own pins add up).
  final _pinned = <String>{};

  /// Keys whose own download failed: not retried on every state change.
  final _selfFailed = <String>{};

  Dio? _dio;
  Dio get _http =>
      _dio ??= Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));

  @visibleForTesting
  Uri? remoteUri(JamItem item, {String route = 'file'}) {
    final s = _state().jam;
    final sid = _state().role == JamRole.guest
        ? _guestFiles()?.sessionId
        : _host()?.sessionId;
    if (s == null || sid == null) return null;
    final owner = s.participant(item.ownerDeviceId);
    if (owner == null) return null;
    // The host is reached at the address a guest used to join; a guest at
    // the one the host saw for it.
    String? base;
    if (owner.id == s.hostDeviceId) {
      base = _state().role == JamRole.guest ? _guestFiles()?.hostBase : null;
    } else if (owner.host.isNotEmpty) {
      base = 'http://${owner.host}:${owner.port}/jam';
    }
    return base == null ? null : Uri.parse('$base/$sid/$route/${item.id}');
  }

  Map<String, String> get _headers => {
    jamFileHeader:
        (_state().role == JamRole.guest
            ? _guestFiles()?.fileToken
            : _host()?.fileToken) ??
        '',
  };

  Future<JamSource?> resolve(JamItem item) async {
    if (item.ownerDeviceId == _ownId()) {
      final path = await localFile(item);
      return path == null ? null : JamSource.local(path);
    }
    final uri = remoteUri(item);
    final remote = uri == null ? null : JamSource.remote(uri, _headers);
    // Synchronised outputs play from the local copy: no network jitter.
    if (uri != null && (_state().jam?.synced ?? false) && cache != null) {
      await cache!.fetch(item, uri, _headers);
    }
    // Owner gone or not answering: an online track comes from its YouTube id.
    final sj = _state().jam;
    if (sj != null && uri == null) {
      final own = await _selfSource(item, sj);
      if (own != null) return own;
    }
    return cache?.sourceFor(item, remote);
  }

  /// The item from its YouTube id. A synchronised Jam waits for the whole file; otherwise it
  /// starts from the stream address as the player does (R-71) while the download goes on.
  Future<JamSource?> _selfSource(JamItem item, JamState s) async {
    if (s.synced || !item.selfFetchable) {
      final f = await _selfFetch(item);
      return f == null ? null : JamSource.local(f.path);
    }
    final p = _ref().read(streamPreparerProvider);
    final key = jamVideoKey(item), r = jamYtResult(item);
    try {
      final begin = await p.start(key, r);
      final file = begin.file;
      if (file != null) return JamSource.local(file.path);
      unawaited(
        p
            .ready(key, r)
            .then<void>(
              (_) {},
              onError: (Object e, StackTrace st) =>
                  AppLog.w('jam: own download of $key failed', e, st),
            ),
      );
      return JamSource.remote(begin.url!, begin.headers);
    } on Object catch (e, st) {
      AppLog.w('jam: own start of $key failed', e, st);
      return null;
    }
  }

  /// The row of an item this device owns: library, or the shadow row of a `yt:` track.
  /// Full rows: lyrics and curiosities are there.
  Future<Track?> _localRow(JamItem item) async {
    final tracks = _ref().read(trackRepositoryProvider);
    final key = jamCacheKey(item);
    final id = int.tryParse(item.ref ?? '');
    if (key != null) {
      final path = (await _ref().read(downloadIndexProvider.future))
          .pathForKey(key);
      final row =
          await tracks.streamRow(key) ??
          (path == null ? null : await tracks.byPath(path));
      if (row != null) return row;
    }
    // A remote guest's own library item is `yt:`-keyed: its row id is in the part key.
    final rowId =
        id ?? (item.partKey == null ? null : jamPartKeyId(item.partKey!));
    return rowId == null ? null : tracks.getById(rowId);
  }

  Future<TrackMeta?> localMeta(JamItem item) async {
    final row = await _localRow(item);
    if (row == null) return null;
    final c = await _ref().read(creditsRepositoryProvider).portableOf(row.id);
    return TrackMeta.fromTrack(row, credits: c.credits, details: c.details);
  }

  Future<String?> localCover(JamItem item) async {
    final key = (await _localRow(item))?.coverKey;
    return key == null
        ? null
        : _ref().read(coverStoreProvider).fileFor(key)?.path;
  }

  /// The owner's cover image, or null (ours: the screen has it locally; any failure: no cover).
  Future<Uint8List?> fetchCover(JamItem item) async {
    // A remote guest has no route to the owner: covers come from the video id (R-154).
    final uri = item.ownerDeviceId == _ownId() || _state().remote
        ? null
        : remoteUri(item, route: 'cover');
    if (uri == null) return null;
    try {
      final r = await _http.getUri<List<int>>(
        uri,
        options: Options(
          headers: _headers,
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final d = r.data;
      return d == null ? null : Uint8List.fromList(d);
    } on DioException catch (e) {
      AppLog.w('jam: no cover for ${item.title}', e);
      return null;
    }
  }

  /// What the info screen shows: from the owner (ours: local), else the item's own fields.
  Future<TrackMeta> fetchMeta(JamItem item) async {
    if (item.ownerDeviceId == _ownId()) {
      final local = await localMeta(item);
      if (local != null) return local;
      return _state().remote
          ? _remoteMeta.of(item)
          : TrackMeta(
              title: item.title,
              artist: item.artist,
              album: item.album,
            );
    }
    // No route to the owner (a remote guest, or a remote guest's track): lyrics and
    // curiosities looked up here and written nowhere (R-155).
    final uri = remoteUri(item, route: 'meta');
    if (uri == null) return _remoteMeta.of(item);
    return jamFetchMeta(item, uri, _headers, dio: _http);
  }

  late final _remoteMeta = JamRemoteMeta(
    lyrics: (t) => _ref().read(lyricsChainProvider).find(t),
    curiosity: (t) => _ref()
        .read(curiosityServiceProvider)
        .find(t, _ref().read(settingsProvider).language),
  );

  Future<File?> _selfFetch(JamItem item) {
    if (!item.selfFetchable) return Future.value();
    return jamFetchByVideoId(
      item,
      (k, r) => _ref().read(streamPreparerProvider).ready(k, r),
    );
  }

  Future<String?> localFile(JamItem item) async => jamLocalFile(
    item,
    _ref().read(streamCacheProvider),
    _ref().read(trackRepositoryProvider),
    index: await _ref().read(downloadIndexProvider.future),
  );

  /// Our own online items still to play (current and upcoming) stay in the cache (D-81).
  void syncPins(JamState? s) {
    final want = jamPinKeys(s, _ownId());
    // No cache needed in a library-only Jam.
    if (want.isEmpty && _pinned.isEmpty) return;
    final streams = _ref().read(streamCacheProvider);
    for (final k in _pinned.difference(want)) {
      streams.unpin(k);
    }
    for (final k in want.difference(_pinned)) {
      streams.pin(k);
    }
    _pinned
      ..clear()
      ..addAll(want);
  }

  /// Next remote item goes to the cache; everything else is dropped.
  void precache(JamState s) {
    final c = cache;
    if (c == null) return;
    final keep = <int>{};
    final cur = s.current;
    final nextIdx = s.currentIndex + 1;
    final next = nextIdx >= 0 && nextIdx < s.items.length
        ? s.items[nextIdx]
        : null;
    for (final i in [cur, next]) {
      if (i == null) continue;
      keep.add(i.id);
    }
    unawaited(c.prune(keep));
    for (final i in jamSelfFetchTargets(s, _ownId(), failed: _selfFailed)) {
      unawaited(
        _selfFetch(i).then((f) {
          if (f == null) _selfFailed.add(jamCacheKey(i)!);
        }),
      );
    }
    for (final i in [cur, next]) {
      if (i == null || i.ownerDeviceId == _ownId()) continue;
      final uri = remoteUri(i);
      if (uri != null) unawaited(c.fetch(i, uri, _headers));
    }
  }

  /// Ends the Jam's side: pins, cache, failed keys and the HTTP client.
  Future<void> dispose() async {
    _remoteMeta.clear();
    await cache?.clear();
    cache = null;
    syncPins(null);
    _selfFailed.clear();
    _dio?.close();
    _dio = null;
  }
}

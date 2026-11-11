import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../core/paths.dart';
import '../core/platform.dart';
import 'player_providers.dart' show audioHandlerProvider, onlineEntriesProvider;
import '../data/db/app_database.dart';
import '../data/repositories/folder_repository.dart';
import '../services/import/playlist_import_service.dart' show parseImportTag;
import '../services/online/direct_search_service.dart';
import '../services/online/download_index.dart';
import '../services/online/download_queue.dart';
import '../services/online/innertube_client.dart';
import '../services/online/media_publisher.dart';
import '../services/online/retry_policy.dart';
import '../services/online/android_yt_dlp_service.dart';
import '../services/online/yt_dlp_process_service.dart';
import '../services/online/yt_dlp_version.dart';
import '../services/online/youtube_service.dart';
import '../services/stream/stream_promoter.dart' show StreamPromoteException;
import 'database_providers.dart';
import 'library_providers.dart';
import 'online_providers.dart';
import 'yt_dlp_update_providers.dart' show locateYtDlp, ytDlpUpdateProvider;
import 'ytm_catalog_providers.dart' show ytmCatalogProvider;
import 'settings_providers.dart';
import 'pending_playlist_adds.dart' show parseAddToPlaylistTag;
import 'stream_providers.dart' show streamPromoterProvider;

/// The videos of a pasted playlist or channel address, read once per address.
final playlistListingProvider =
    FutureProvider.autoDispose.family<PlaylistListing, String>(
  (ref, url) => ref.read(youtubeServiceProvider).listPlaylist(url),
  // A failure is shown with its own «Riprova»: no silent retries behind a spinner.
  retry: (_, _) => null,
);

/// yt-dlp: the desktop executable or the copy embedded in the Android app.
YoutubeService createYtDlpService() => isAndroid
    ? AndroidYtDlpService()
    : YtDlpProcessService(locate: locateYtDlp);

final ytDlpServiceProvider = Provider<YoutubeService>((ref) {
  final s = createYtDlpService();
  ref.onDispose(s.close);
  return s;
});

/// Searches with one direct request, everything else with yt-dlp.
final innerTubeClientProvider = Provider<InnerTubeClient>((ref) {
  final c = InnerTubeClient();
  ref.onDispose(c.close);
  return c;
});

final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final s = DirectSearchService(
    ref.watch(ytDlpServiceProvider),
    ref.watch(innerTubeClientProvider),
    catalog: ref.watch(ytmCatalogProvider),
  );
  return s;
});

/// What `yt-dlp --version` said; [outdated] drives the banner on desktop.
class YtDlpStatus {
  const YtDlpStatus(this.version);

  final String? version;
  bool get outdated => isYtDlpOutdated(version);
}

final ytDlpStatusProvider = FutureProvider<YtDlpStatus>((ref) async {
  final v = await ref.watch(youtubeServiceProvider).toolVersion();
  // Desktop builds ship no yt-dlp: fetch it (or a fresh one) in the background.
  // Not in `flutter test`, which must never reach the network.
  if (isDesktop && !Platform.environment.containsKey('FLUTTER_TEST')) {
    unawaited(Future(
        () => ref.read(ytDlpUpdateProvider.notifier).autoUpdate(v)));
  }
  return YtDlpStatus(v);
});

final downloadIndexProvider = FutureProvider<DownloadIndex>((ref) async {
  final idx = DownloadIndex(DownloadIndex.defaultFile(await appSupportDir()));
  await idx.load();
  return idx;
});

final mediaPublisherProvider = Provider<MediaPublisher>((ref) => MediaPublisher());

/// Destination folder for downloads (`<Music>/FreeKmusic`), registered as a
/// scanned folder. On Android it is the public folder the files are published
/// to; the download itself happens in [downloadWorkDir].
Future<(Directory, Folder)?> resolveDownloadFolder(FolderRepository repo) async {
  final dir = Directory((await resolveDefaultFolders()).downloads);
  return (dir, await repo.add(dir.path));
}

/// Any `.part` found before the first download of a session belongs to a
/// download that was interrupted (app killed) and will never be completed.
/// Never call it while downloads are running.
Future<void> removeStalePartFiles(Directory dir) async {
  try {
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.part')) await e.delete();
    }
  } on FileSystemException catch (e, st) {
    AppLog.w('stale .part cleanup failed: ${dir.path}', e, st);
  }
}

class DownloadsNotifier extends Notifier<List<DownloadItem>> {
  late final DownloadQueue _queue;

  /// The one-off cleanup of leftovers; later downloads just wait for it.
  Future<void>? _stale;
  final _settled = StreamController<DownloadItem>.broadcast();

  /// Every item that finished (done, failed or cancelled), after the file was
  /// scanned into the library.
  Stream<DownloadItem> get settled => _settled.stream;

  @override
  List<DownloadItem> build() {
    final yt = ref.watch(youtubeServiceProvider);
    Folder? folder;
    _queue = DownloadQueue(
      maxParallel: ref.read(settingsProvider).downloadParallel,
      retryPolicy: RetryPolicy(),
      downloader: (r, dir, cancel) {
        final s = ref.read(settingsProvider);
        return yt.download(r, dir,
            cancel: cancel,
            options: DownloadOptions(
              rateLimitKBps: s.downloadRateLimitKBps,
              format: s.downloadFormat,
            ));
      },
      outDir: () async {
        final res = await resolveDownloadFolder(
          ref.read(folderRepositoryProvider),
        );
        folder = res?.$2;
        final dir = isAndroid ? await downloadWorkDir() : res?.$1;
        if (dir != null) await (_stale ??= removeStalePartFiles(dir));
        return dir;
      },
      onChanged: (items) => state = items,
      onSettled: (item) {
        if (!_settled.isClosed) _settled.add(item);
      },
      onDownloaded: (workPath) async {
        final f = folder;
        if (f == null) return null;
        // Android: the finished file goes public now (the tags are written on that copy).
        final path = await ref.read(mediaPublisherProvider).publish(workPath);
        await for (final _ in ref.read(libraryScannerProvider).scanFiles(f, [
          path,
        ])) {}
        final item = _queue.items.where((e) => e.path == workPath).firstOrNull;
        if (item != null) {
          final idx = await ref.read(downloadIndexProvider.future);
          await idx.add(item.result.id, path, source: item.result.source);
          ref.invalidate(downloadIndexProvider);
          await _mergeShadowRow(item.result, path);
          _resyncPlayer();
        }
        // An import enriches its songs itself, after putting the CSV tags on.
        if (parseImportTag(item?.tag) == null) await _enrichAfterDownload(path);
        return path;
      },
    );
    ref.listen(settingsProvider.select((s) => s.downloadParallel),
        (_, n) => _queue.maxParallel = n);
    ref.onDispose(() {
      _queue.dispose();
      _settled.close();
      _promoteErrors.close();
    });
    return const [];
  }

  Future<void> _enrichAfterDownload(String path) async {
    try {
      final id = await ref.read(trackRepositoryProvider).idForPath(path);
      if (id != null) afterDownload(ref, id);
    } on Object catch (e, st) {
      AppLog.w('auto enrich after download failed', e, st);
    }
  }

  /// The listens of the shadow row of a track that was streamed before (46.3).
  Future<void> _mergeShadowRow(YtResult r, String path) async {
    try {
      final tracks = ref.read(trackRepositoryProvider);
      final id = await tracks.idForPath(path);
      final gone = id == null ? null : await tracks.mergeStreamRow(r.indexKey, id);
      if (gone != null) {
        ref.read(audioHandlerProvider).replaceQueueId(gone, id!);
        // The entry now playing keeps streaming: point it at the library row.
        final online = ref.read(onlineEntriesProvider);
        for (final e in online?.idsOf(r) ?? const <int>[]) {
          online!.bindRow(e, id);
        }
      }
    } on Object catch (e, st) {
      AppLog.w('merge of the stream row failed for ${r.indexKey}', e, st);
    }
  }

  /// The song is a library track now: the player's queue stops prefetching it.
  void _resyncPlayer() {
    try {
      unawaited(ref.read(audioHandlerProvider).resyncPreparer());
    } on Object catch (e) {
      AppLog.d('player not told about the download', e); // no player (tests)
    }
  }

  /// Why the last promotion from the stream cache failed (e.g. disk full).
  Stream<bool> get promoteErrors => _promoteErrors.stream; // true = disk full
  final _promoteErrors = StreamController<bool>.broadcast();

  /// A track already in the stream cache is moved to the downloads (R-10);
  /// anything else, and every import, goes to the queue as before.
  /// True when the song joined the library at once (no download started).
  Future<bool> add(YtResult r, {String? tag}) async {
    // Imports (any tag but addto:) always download.
    if (tag != null && parseAddToPlaylistTag(tag) == null) {
      _queue.add(r, tag: tag);
      return false;
    }
    final idx = ref.read(downloadIndexProvider).value;
    if (idx != null && idx.contains(r.id, source: r.source)) {
      // Already a library file: never a second copy (`Title (2).m4a`).
      final playlist = parseAddToPlaylistTag(tag);
      if (playlist != null) unawaited(_joinPlaylist(r, playlist));
      return false;
    }
    if (!_promoting.add(r.indexKey)) return false; // double tap while it is moving
    return _promoteOrQueue(r, tag).whenComplete(() => _promoting.remove(r.indexKey));
  }

  final _promoting = <String>{};

  Future<bool> _promoteOrQueue(YtResult r, String? tag) async {
    try {
      if (await ref.read(streamPromoterProvider).promote(r)) {
        ref.invalidate(downloadIndexProvider); // rows and player watch the index
        await _joinPlaylist(r, parseAddToPlaylistTag(tag));
        _resyncPlayer();
        return true;
      }
    } on StreamPromoteException catch (e) {
      AppLog.w('promotion failed: ${e.message}');
      if (!_promoteErrors.isClosed) _promoteErrors.add(e.noSpace);
      if (e.noSpace) return false; // a download would fail the same way
    } on Object catch (e, st) {
      AppLog.w('promotion failed, downloading instead', e, st);
    }
    if (ref.mounted) _queue.add(r, tag: tag);
    return false;
  }

  /// A promoted song is a library track already: the playlist of an `addto:` tag takes it now.
  Future<void> _joinPlaylist(YtResult r, int? playlistId) async {
    if (playlistId == null) return;
    try {
      final path = (await ref.read(downloadIndexProvider.future)).pathFor(r.id, source: r.source);
      final id = path == null ? null : await ref.read(trackRepositoryProvider).idForPath(path);
      if (id != null) await ref.read(playlistRepositoryProvider).addTracks(playlistId, [id]);
    } on Object catch (e, st) {
      AppLog.w('add to playlist after promotion failed for ${r.indexKey}', e, st);
    }
  }

  void cancel(int id) => _queue.cancel(id);
  void cancelWhere(bool Function(DownloadItem item) test) =>
      _queue.cancelWhere(test);
  void clearFinished() => _queue.clearFinished();
}

final downloadsProvider =
    NotifierProvider<DownloadsNotifier, List<DownloadItem>>(
      DownloadsNotifier.new,
    );

/// One failed promotion. No `==` on purpose: two identical messages are two
/// events, and a provider would drop the second as «unchanged».
class PromoteError {
  PromoteError({required this.noSpace});
  final bool noSpace;
}

/// Why a «Scarica» from the stream cache failed (shown by the app).
final promoteErrorsProvider = StreamProvider<PromoteError>(
  (ref) => ref.watch(downloadsProvider.notifier).promoteErrors.map((noSpace) => PromoteError(noSpace: noSpace)),
);

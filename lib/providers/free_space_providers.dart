import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform.dart';
import '../services/android/media_deleter.dart';
import 'library_providers.dart' show scanStateProvider;
import 'player_providers.dart' show audioHandlerProvider, onlineEntriesProvider;
import '../services/library/free_space.dart';
import 'database_providers.dart';
import '../services/online/download_queue.dart' show DownloadStatus;
import 'youtube_providers.dart' show downloadIndexProvider, downloadsProvider;

/// «Libera spazio»: converts downloads back to streams and deletes the files.
final freeSpaceServiceProvider = FutureProvider<FreeSpaceService>(
  (ref) async => FreeSpaceService(
    tracks: ref.watch(trackRepositoryProvider),
    index: await ref.watch(downloadIndexProvider.future),
    platform: isAndroid ? deleteWithSystemDialog : null,
    // The entry now playing keeps its negative id after a download: its row is the one bound to it.
    playingIds: () {
      final id = ref.read(audioHandlerProvider).currentTrack?.id;
      return {?id, ?(id == null ? null : ref.read(onlineEntriesProvider)?[id]?.trackId)};
    },
    activeKeys: () => {
      for (final i in ref.read(downloadsProvider))
        if (i.status == DownloadStatus.queued ||
            i.status == DownloadStatus.downloading ||
            i.status == DownloadStatus.waitingRetry)
          i.result.indexKey,
    },
    scanRunning: () => ref.read(scanStateProvider).running,
    onShadowMerged: (gone, keep) => ref.read(audioHandlerProvider).replaceQueueId(gone, keep),
    onFreed: () {
      unawaited(ref.read(audioHandlerProvider).resyncPreparer());
      ref.invalidate(downloadIndexProvider); // the index was edited in place
    },
  ),
);

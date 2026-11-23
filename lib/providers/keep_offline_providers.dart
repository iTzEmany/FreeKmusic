import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart' show kStreamKind;
import '../services/online/download_queue.dart' show DownloadStatus;
import '../services/online/youtube_service.dart' show YtResult;
import '../services/stream/stream_key.dart';
import 'database_providers.dart';
import 'library_add_providers.dart';
import 'youtube_providers.dart';

/// Queues a real download for each of [tracks] that is a stream row (saved or not) with no file;
/// [pathForKey] is the download index lookup; keys in [inQueue] are already queued or downloading (no `Title (2)`). Returns how many were queued (D-578, R-236).
int keepOffline(
  Iterable<Track> tracks, {
  required String? Function(String key) pathForKey,
  Set<String> inQueue = const {},
  required void Function(YtResult r) download,
}) {
  final skip = {...inQueue};
  var n = 0;
  for (final t in tracks) {
    final key = t.kind == kStreamKind ? keyOfStreamPath(t.path) : null;
    if (key == null || pathForKey(key) != null || !skip.add(key)) continue;
    download(streamResultOfRow(key, t));
    n++;
  }
  return n;
}

/// «Tieni offline» for the tracks of a playlist or album: an explicit «download to device»,
/// so it goes through `LibraryAdder.download` whatever the storage mode (downloading saves, D-695). Returns how many were queued.
final keepOfflineProvider = Provider<Future<int> Function(Iterable<Track> tracks)>((ref) => (tracks) async {
      final index = await ref.read(downloadIndexProvider.future);
      final adder = ref.read(libraryAdderProvider);
      const live = {DownloadStatus.queued, DownloadStatus.downloading, DownloadStatus.waitingRetry};
      final inQueue = {for (final i in ref.read(downloadsProvider)) if (live.contains(i.status)) i.result.indexKey};
      return keepOffline(tracks, pathForKey: index.pathForKey, inQueue: inQueue, download: (r) => unawaited(adder.download(r)));
    });

/// [keepOfflineProvider] for library rows given by id (the tracks of an import).
final keepOfflineIdsProvider = Provider<Future<int> Function(List<int> ids)>(
  (ref) => (ids) async => ref.read(keepOfflineProvider)(await ref.read(trackRepositoryProvider).getByIds(ids)),
);

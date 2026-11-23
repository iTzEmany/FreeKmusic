import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart' show kStreamKind;
import '../services/online/download_queue.dart' show DownloadStatus;
import '../services/online/youtube_service.dart' show YtResult;
import '../services/stream/stream_key.dart';
import 'database_providers.dart';
import 'library_add_providers.dart';
import 'shuffle_plus_providers.dart' show networkProbeProvider;
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

/// Rough size of one download without a known duration, and of a second of audio (about 128 kbit/s).
const _unknownDuration = Duration(minutes: 4);
const _bytesPerSecond = 16000;

/// What [keepOffline] would queue for [tracks]: how many and the estimated MB, or null when nothing (D-656 asks
/// before a metered download).
typedef KeepOfflineEstimate = ({int count, int mb});

final keepOfflineEstimateProvider = Provider<Future<KeepOfflineEstimate?> Function(Iterable<Track> tracks)>(
  (ref) => (tracks) async {
    final index = await ref.read(downloadIndexProvider.future);
    var bytes = 0;
    final n = keepOffline(
      tracks,
      pathForKey: index.pathForKey,
      inQueue: _liveKeys(ref),
      download: (r) => bytes += (r.duration ?? _unknownDuration).inSeconds * _bytesPerSecond,
    );
    return n == 0 ? null : (count: n, mb: (bytes / 1048576).ceil().clamp(1, 1 << 30));
  },
);

/// The estimate when the network is metered (so the user must be asked), else null.
final keepOfflineMeteredAskProvider = Provider<Future<KeepOfflineEstimate?> Function(Iterable<Track> tracks)>(
  (ref) => (tracks) async {
    if (!(await ref.read(networkProbeProvider).current()).metered) return null;
    return ref.read(keepOfflineEstimateProvider)(tracks);
  },
);

Set<String> _liveKeys(Ref ref) {
  const live = {DownloadStatus.queued, DownloadStatus.downloading, DownloadStatus.waitingRetry};
  return {for (final i in ref.read(downloadsProvider)) if (live.contains(i.status)) i.result.indexKey};
}

/// «Tieni offline» for the tracks of a playlist or album: an explicit «download to device»,
/// so it goes through `LibraryAdder.download` whatever the storage mode (downloading saves, D-695). Returns how many were queued.
final keepOfflineProvider = Provider<Future<int> Function(Iterable<Track> tracks)>((ref) => (tracks) async {
      final index = await ref.read(downloadIndexProvider.future);
      final adder = ref.read(libraryAdderProvider);
      return keepOffline(
        tracks,
        pathForKey: index.pathForKey,
        inQueue: _liveKeys(ref),
        download: (r) => unawaited(adder.download(r).catchError((Object e, StackTrace st) {
          AppLog.w('keep offline: download of ${r.indexKey} failed', e, st);
          return null;
        })),
      );
    });

/// Library rows given by id (the tracks of an import), for [keepOfflineProvider].
final keepOfflineTracksOfIdsProvider = Provider<Future<List<Track>> Function(List<int> ids)>(
  (ref) => ref.read(trackRepositoryProvider).getByIds,
);

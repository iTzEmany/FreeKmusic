import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart' show kStreamKind;
import '../services/online/youtube_service.dart' show YtResult;
import '../services/stream/stream_key.dart';
import 'youtube_providers.dart';

/// Queues a real download for each of [tracks] that is a stream row (saved or not) with no file;
/// [pathForKey] is the download index lookup. Returns how many were queued (D-578, R-236).
int keepOffline(
  Iterable<Track> tracks, {
  required String? Function(String key) pathForKey,
  required void Function(YtResult r) download,
}) {
  var n = 0;
  for (final t in tracks) {
    final key = t.kind == kStreamKind ? keyOfStreamPath(t.path) : null;
    if (key == null || pathForKey(key) != null) continue;
    download(streamResultOfRow(key, t));
    n++;
  }
  return n;
}

/// «Tieni offline» for the tracks of a playlist or album: an explicit «download to device»,
/// so it goes through `downloadsProvider` whatever the storage mode. Returns how many were queued.
final keepOfflineProvider = Provider<Future<int> Function(Iterable<Track> tracks)>((ref) => (tracks) async {
      final index = await ref.read(downloadIndexProvider.future);
      final downloads = ref.read(downloadsProvider.notifier);
      return keepOffline(tracks, pathForKey: index.pathForKey, download: (r) => downloads.add(r));
    });

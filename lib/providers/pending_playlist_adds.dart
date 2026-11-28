import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_log.dart';
import '../services/online/download_queue.dart';
import '../services/online/youtube_service.dart';
import 'database_providers.dart';
import 'player_providers.dart';
import 'youtube_providers.dart';

const _prefix = 'addto:';
final _id = RegExp(r'^[1-9][0-9]*$');

/// The download tag that asks for the song to join every playlist in
/// [playlistIds] once it is a library track (`addto:3,7`).
String addToPlaylistTag(List<int> playlistIds) => '$_prefix${playlistIds.join(',')}';

/// The playlists of an `addto:` tag; empty for any other tag or a malformed one.
List<int> parseAddToPlaylistTag(String? tag) {
  if (tag == null || !tag.startsWith(_prefix)) return const [];
  final parts = tag.substring(_prefix.length).split(',');
  // Only positive decimal ids; a tag with anything else is not ours.
  if (!parts.every(_id.hasMatch)) return const [];
  return {for (final s in parts) int.parse(s)}.toList();
}

/// Puts a downloaded suggestion into the playlist it was asked for.
class PendingPlaylistAdds {
  PendingPlaylistAdds({
    required Stream<DownloadItem> settled,
    required this.trackIdForPath,
    required this.addTracks,
    this.replaceStream,
  }) {
    _sub = settled.listen((i) => unawaited(_onSettled(i)));
  }

  final Future<int?> Function(String path) trackIdForPath;
  final Future<void> Function(int playlistId, List<int> trackIds) addTracks;

  /// Called for every finished download with its result and the new library
  /// track id: swaps the stream entries of that song in the queue.
  final void Function(YtResult result, int trackId)? replaceStream;
  late final StreamSubscription<DownloadItem> _sub;

  Future<void> _onSettled(DownloadItem item) async {
    final playlists = parseAddToPlaylistTag(item.tag);
    final path = item.path;
    if (item.status != DownloadStatus.done || path == null) return;
    if (playlists.isEmpty && replaceStream == null) return;
    try {
      final id = await trackIdForPath(path);
      if (id == null) return;
      // The queue must play the file now, not the stream address (it expires).
      replaceStream?.call(item.result, id);
      for (final p in playlists) {
        try {
          await addTracks(p, [id]);
        } on Object catch (e, st) {
          AppLog.w('add to playlist $p after download failed', e, st);
        }
      }
    } on Object catch (e, st) {
      AppLog.w('add to playlist after download failed', e, st);
    }
  }

  void dispose() => unawaited(_sub.cancel());
}

/// Started by the shell, which reads it.
final pendingPlaylistAddsProvider = Provider<PendingPlaylistAdds>((ref) {
  final adds = PendingPlaylistAdds(
    settled: ref.watch(downloadsProvider.notifier).settled,
    trackIdForPath: ref.watch(trackRepositoryProvider).idForPath,
    addTracks: (playlist, ids) =>
        ref.read(playlistRepositoryProvider).addTracks(playlist, ids),
    replaceStream: (result, trackId) {
      final online = ref.read(onlineEntriesProvider);
      final handler = ref.read(audioHandlerProvider);
      for (final old in online?.idsOf(result) ?? const <int>[]) {
        handler.replaceQueueId(old, trackId);
      }
    },
  );
  ref.onDispose(adds.dispose);
  return adds;
});

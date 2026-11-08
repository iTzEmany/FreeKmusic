import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/audio/online_entries.dart';
import '../services/online/youtube_service.dart';
import '../services/shuffle_plus/dislike_store.dart';
import '../services/shuffle_plus/suggestion_log.dart';
import '../services/shuffle_plus/suggestion_pool.dart' show suggestionArtistKey;
import 'dislike_store_provider.dart';
import 'pending_playlist_adds.dart';
import 'player_providers.dart';
import 'shuffle_plus_providers.dart';
import 'youtube_providers.dart';

/// What [SuggestionActions.undo] needs to put a «Non mi piace» back.
class DislikeUndo {
  const DislikeUndo({
    this.trackId,
    this.artistKey,
    this.outcomeBefore,
    this.removed = const [],
  });

  final String? trackId, artistKey;
  final SuggestionOutcome? outcomeBefore;

  /// Entries taken out of the queue, ascending by their old index.
  final List<({int index, int id, bool wasCurrent})> removed;
}

/// What the user can do with a streamed (suggested) entry of the queue.
class SuggestionActions {
  SuggestionActions({
    required this.online,
    required this.log,
    required this.store,
    required this.download,
    required this.removeQueueId,
    required this.queueIds,
    required this.currentQueueId,
    required this.insertAt,
    required this.playIndex,
  });

  final OnlineEntries? online;
  final SuggestionLog log;
  final Future<bool> Function(YtResult result, {String? tag}) download;
  final DislikeStore store;
  final Future<void> Function(int id) removeQueueId;
  final List<int> Function() queueIds;
  final int? Function() currentQueueId;
  final void Function(int index, int id) insertAt;
  final Future<void> Function(int index) playIndex;

  /// Starts the download (the song joins the library when it arrives) or, with
  /// the file already cached, adds it at once. Null: no such entry; true: added at once.
  Future<bool?> downloadEntry(int id) async {
    final r = online?[id]?.result;
    if (r == null) return null;
    log.setOutcome(r.id, SuggestionOutcome.downloaded);
    return download(r);
  }

  /// Downloads it and adds it to [playlistId] when the file is ready (at once
  /// if cached). Null: no such entry; true: added at once.
  Future<bool?> addToPlaylist(int id, int playlistId) async {
    final r = online?[id]?.result;
    if (r == null) return null;
    log.setOutcome(r.id, SuggestionOutcome.downloaded);
    return download(r, tag: addToPlaylistTag(playlistId));
  }

  /// «Non mi piace» on a song: blocked (SuggestionGate), out of the queue (the
  /// next song plays if it was the current one).
  Future<DislikeUndo> dislikeTrack(int queueId) async {
    final r = online?[queueId]?.result;
    if (r == null) return const DislikeUndo();
    final before = log.latest(r.id)?.outcome;
    log.setOutcome(r.id, SuggestionOutcome.disliked);
    store.blockTrack(
      DislikedTrack(
        videoId: r.id,
        title: r.title,
        artist: r.artists.isEmpty ? r.channel : r.artists.join(', '),
      ),
    );
    return DislikeUndo(
      trackId: r.id,
      outcomeBefore: before,
      removed: await _take({queueId}),
    );
  }

  /// «Non mi piace» on the artist: blocked, and the song and every suggested
  /// song of the same artist leave the queue (D-469); the user's own stay.
  Future<DislikeUndo> dislikeArtist(int queueId) async {
    final r = online?[queueId]?.result;
    if (r == null) return const DislikeUndo();
    final key = suggestionArtistKey(r);
    store.blockArtist(
      DislikedArtist(
        key: key,
        name: r.artists.isEmpty ? r.channel : r.artists.first,
      ),
    );
    final ids = {
      queueId,
      for (final id in queueIds())
        if (online?[id] case final e?
            when e.suggested && suggestionArtistKey(e.result) == key)
          id,
    };
    return DislikeUndo(artistKey: key, removed: await _take(ids));
  }

  /// Unblocks and puts the removed entries back where they were; the song
  /// that was playing starts again (D-446).
  Future<void> undo(DislikeUndo u) async {
    if (u.trackId case final id?) {
      store.unblockTrack(id);
      if (u.outcomeBefore != null) log.setOutcome(id, u.outcomeBefore!);
    }
    if (u.artistKey case final key?) store.unblockArtist(key);
    for (final e in u.removed) {
      insertAt(e.index, e.id);
    }
    for (final e in u.removed) {
      if (e.wasCurrent) await playIndex(e.index);
    }
  }

  /// Takes [ids] out of the queue, the playing one last; returns where they were.
  Future<List<({int index, int id, bool wasCurrent})>> _take(
    Set<int> ids,
  ) async {
    final queue = queueIds();
    final current = currentQueueId();
    final removed = [
      for (var i = 0; i < queue.length; i++)
        if (ids.contains(queue[i]))
          (index: i, id: queue[i], wasCurrent: queue[i] == current),
    ];
    for (final e in removed.where((e) => !e.wasCurrent)) {
      await removeQueueId(e.id);
    }
    for (final e in removed.where((e) => e.wasCurrent)) {
      await removeQueueId(e.id);
    }
    return removed;
  }

  Future<void> remove(int id) => removeQueueId(id);
}

final suggestionActionsProvider = Provider<SuggestionActions>((ref) {
  final handler = ref.read(audioHandlerProvider);
  return SuggestionActions(
    online: ref.watch(onlineEntriesProvider),
    log: ref.watch(suggestionLogProvider),
    store: ref.watch(dislikeStoreProvider),
    download: (r, {tag}) =>
        ref.read(downloadsProvider.notifier).add(r, tag: tag),
    removeQueueId: handler.removeQueueId,
    queueIds: () => handler.queueIds,
    currentQueueId: () => handler.currentQueueId,
    insertAt: handler.insertAt,
    playIndex: handler.skipToQueueItem,
  );
});

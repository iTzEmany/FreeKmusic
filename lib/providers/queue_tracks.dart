import '../data/db/app_database.dart';
import '../data/repositories/track_repository.dart';
import '../services/audio/codecore_audio_handler.dart';
import '../services/audio/online_entries.dart';

/// The on-screen queue: one track per position that can be shown. Library ids
/// come from the database, online ids (negative) from the registry as
/// synthetic tracks. Ids that resolve to nothing (a deleted row, a forgotten
/// online entry) are skipped.
Future<List<Track>> queueTracks(
  List<int> ids,
  TrackRepository repo,
  OnlineEntries? online,
) async {
  final library = await repo.getByIdsLight([
    for (final id in ids)
      if (!isOnlineId(id)) id,
  ]);
  final byId = {for (final t in library) t.id: t};
  return [
    for (final id in ids)
      if (isOnlineId(id))
        ?online?.trackOf(id)
      else
        ?byId[id],
  ];
}

/// The tracks of the manual queue (what the user added after the current one), in order.
Future<List<Track>> manualQueueTracks(
  CodecoreAudioHandler handler,
  TrackRepository repo,
  OnlineEntries? online,
) {
  final from = handler.currentIndex + 1;
  final ids = handler.queueIds;
  final n = handler.userAhead;
  if (from <= 0 || n == 0 || from >= ids.length) return Future.value(const []);
  return queueTracks(ids.sublist(from, (from + n).clamp(from, ids.length)), repo, online);
}

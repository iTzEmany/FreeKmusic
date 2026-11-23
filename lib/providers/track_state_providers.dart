import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/app_database.dart' show Track;
import '../data/repositories/track_kinds.dart';
import '../services/audio/online_entries.dart' show isOnlineId;
import '../services/stream/stream_key.dart';
import 'database_providers.dart';
import 'library_add_providers.dart';
import 'youtube_providers.dart';

/// Where a track lives right now (D-695, D-696): not in the library, a saved stream, or a file.
enum TrackState { online, savedStream, downloaded }

/// Key of [trackStateProvider] for [t]. A streamed song is keyed by its stream key `<source>:<id>`
/// (`downloadIndexKey`), which survives a download changing the row id; a file or an episode by `#<id>`.
/// Pass [streamKey] for an online entry (negative id) that has no row path to read it from.
String trackStateKey(Track t, {String? streamKey}) =>
    streamKey ??
    (t.kind == kStreamKind ? keyOfStreamPath(t.path) : null) ??
    // The synthetic track of an online entry: `online:<source>:<id>` is the stream key.
    (isOnlineId(t.id) && t.path.startsWith(_onlinePrefix) ? t.path.substring(_onlinePrefix.length) : null) ??
    '#${t.id}';

const _onlinePrefix = 'online:';

/// The part of a row that decides its [TrackState] (not its play counts).
typedef _RowKind = ({int kind, bool saved, bool missing})?;

final _rowKindProvider = Provider.autoDispose.family<_RowKind, int>((ref, id) {
  final row = ref.watch(_rowStreamProvider(id).select((a) => a.value));
  return row == null ? null : (kind: row.kind, saved: row.saved, missing: row.missing);
});

final _rowStreamProvider = StreamProvider.autoDispose.family<Track?, int>(
  (ref, id) => ref.watch(trackRepositoryProvider).watchById(id),
);

/// Live [TrackState] of [key] (see [trackStateKey]); follows the saved-stream keys, the download index and,
/// for `#<id>` keys, the DB row. Loading reads as [TrackState.online].
final trackStateProvider = Provider.autoDispose.family<TrackState, String>((ref, key) {
  if (key.startsWith('#')) {
    final row = ref.watch(_rowKindProvider(int.parse(key.substring(1))));
    if (row == null) return TrackState.online;
    return switch (row.kind) {
      kStreamKind => row.saved ? TrackState.savedStream : TrackState.online,
      kEpisodeKind => TrackState.online,
      _ => row.missing ? TrackState.online : TrackState.downloaded,
    };
  }
  final index = ref.watch(downloadIndexProvider).value;
  if (index?.pathForKey(key) != null) return TrackState.downloaded;
  final saved = ref.watch(savedStreamKeysProvider).value;
  return saved != null && saved.contains(key) ? TrackState.savedStream : TrackState.online;
});

import 'dart:async';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../online/curiosity_service.dart';
import '../../online/lyrics_chain.dart';
import '../../online/synthetic_track.dart';
import '../../share/track_meta.dart';
import '../jam_models.dart';

/// Lyrics and curiosities of a track nobody can be asked about (R-155): looked up
/// here, written nowhere, cached by item id until [clear].
class JamRemoteMeta {
  JamRemoteMeta({required this.lyrics, required this.curiosity});

  final Future<LyricsChainResult> Function(Track) lyrics;
  final Future<CuriosityLookup> Function(Track) curiosity;
  final _cache = <int, TrackMeta>{};

  void clear() => _cache.clear();

  Future<TrackMeta> of(JamItem item) async {
    final cached = _cache[item.id];
    if (cached != null) return cached;
    final t = syntheticTrack(
      title: item.title,
      artist: item.artist,
      album: item.album,
      durationMs: item.durationMs,
      format: item.ext,
    );
    Future<T?> part<T>(Future<T> Function() f) async {
      try {
        return await f().timeout(const Duration(seconds: 15));
      } on Object catch (e, st) {
        AppLog.w('jam: no lookup for ${item.title}', e, st);
        return null;
      }
    }

    final (lyr, cur) = await (part(() => lyrics(t)), part(() => curiosity(t))).wait;
    // Only the song's own text: the artist's bio is not a curiosity of the track.
    final song = cur?.pair.song;
    final meta = TrackMeta(
      title: item.title,
      artist: item.artist,
      album: item.album,
      lyricsPlain: lyr?.lyrics?.plain,
      lyricsSynced: lyr?.lyrics?.synced,
      // Same text the library saves: the text, then its source address.
      curiosities: song == null ? null : '${song.text}\n${song.source}',
    );
    final unsure = (lyr?.failed ?? true) || (lyr?.limited ?? true) ||
        cur == null || cur.outcome.failed || cur.outcome.limited;
    if (!unsure) _cache[item.id] = meta; // a failed or refused lookup is tried again
    return meta;
  }
}

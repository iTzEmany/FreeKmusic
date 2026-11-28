import '../../core/app_log.dart';
import '../../data/repositories/credits_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/track_repository.dart';
import '../backup/track_resolver.dart';
import '../backup/user_data.dart' show TrackRef;
import '../stream/stream_key.dart' show streamResultOf;
import 'offers.dart';

/// Writes the playlist of an accepted offer (D-760): the elements in the sender's order, each as the row it has
/// here. [pathOfItem] maps the id of a received file to where it was stored; a file that did not arrive is looked
/// up in the library by [resolver] and skipped when absent. Saved streams are found by key (the caller saved
/// them first); shadow rows are made with `ensureStreamRow` and stay out of the library (`saved = false`, D-761).
/// A part after the first appends to [appendTo]. Returns the playlist id, null when nothing could be written.
Future<int?> writeReceivedPlaylist({
  required OfferPlaylist playlist,
  required List<OfferItem> items,
  required List<StreamOffer> streams,
  required Map<int, String> pathOfItem,
  required TrackRepository tracks,
  required PlaylistRepository playlists,
  required TrackResolver resolver,
  CreditsRepository? credits,
  int? appendTo,
}) async {
  final itemById = {for (final i in items) i.id: i};
  final streamByKey = {for (final s in streams) s.key: s};
  final ids = <int>[];
  for (final ref in playlist.order) {
    try {
      final int? id;
      if (ref.item != null) {
        final path = pathOfItem[ref.item];
        final item = itemById[ref.item];
        id = path != null
            ? (await tracks.byPath(path))?.id
            : item == null
                ? null
                : resolver.resolve(TrackRef(title: item.title, artist: item.artist));
      } else {
        final s = streamByKey[ref.stream];
        if (s == null) {
          id = null;
        } else if (s.shadow) {
          id = await tracks.ensureStreamRow(
              streamResultOf(s.key, title: s.title, artist: s.artist, album: s.album, durationMs: s.durationMs));
          final m = s.meta;
          if (m != null && credits != null) await credits.saveIfNone(id, m.credits, m.details);
        } else {
          id = (await tracks.streamRow(s.key))?.id;
        }
      }
      if (id != null) ids.add(id);
    } on Object catch (e, st) {
      AppLog.w('received playlist: element skipped', e, st);
    }
  }
  if (ids.isEmpty) return null;
  final id = appendTo ?? await playlists.create(await playlists.freeName(playlist.name.trim()));
  await playlists.addStreamTracks(id, ids);
  return id;
}

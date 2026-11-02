import 'track_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/jam_providers.dart';
import '../../providers/player_providers.dart';
import '../../providers/playlist_ops.dart';
import '../../providers/track_ops.dart';
import '../screens/cleanup/move_to_album_dialog.dart';
import '../screens/playlists/playlist_dialogs.dart';
import '../screens/tags/tags_sheet.dart';
import 'confirm.dart';
import 'delete_tracks.dart';
import 'track_actions.dart';
import 'show_msg.dart';

/// Where a selection lives: decides which actions make sense.
class BulkContext {
  const BulkContext({this.playlistId});

  /// Inside a playlist: «Rimuovi dalla playlist» is offered.
  final int? playlistId;
}

/// The actions for many tracks at once, in the same model as the single-track
/// menu. [tracks] must be in the order of the picks (not of the list); [done]
/// leaves the selection after an action that went through.
///
/// Only «Elimina dal dispositivo» touches a file (after a confirmation);
/// «remove» otherwise means rows of the library or of a playlist.
List<TrackActionGroup> bulkActions(
  BuildContext outer,
  WidgetRef ref,
  List<Track> picked,
  BulkContext ctx, {
  required VoidCallback done,
}) {
  // Streamed entries are not library rows: the group actions skip them.
  final tracks = [
    for (final t in picked)
      if (t.trackKind != TrackKind.online) t,
  ];
  if (tracks.isEmpty) return const [];
  final l = outer.l10n;
  final ctrl = ref.read(playerControllerProvider);
  final n = tracks.length;

  void snack(String text) => showMsg(outer, text);

  final allFavorite = tracks.isNotEmpty && tracks.every((t) => t.isFavorite);
  final allMissing = tracks.isNotEmpty && tracks.every((t) => t.missing);

  Future<void> favorites() async {
    final r = await ref.read(trackOpsProvider).toggleFavorites(tracks);
    if (!outer.mounted) return;
    showUndoSnack(
      outer,
      r.added ? l.favoritesAdded(r.count) : l.favoritesRemoved(r.count),
      r.undo,
    );
    done();
  }

  Future<void> removeFromPlaylist(int playlistId) async {
    final ok = await showConfirm(
      outer,
      title: l.removeManyFromPlaylistTitle(n),
      body: l.removeManyFromPlaylistBody,
      confirmLabel: l.removeFromList,
    );
    if (!ok) return;
    final undo = await ref.read(playlistOpsProvider).removeTracks(playlistId, [for (final t in tracks) t.id]);
    if (!outer.mounted) return;
    showUndoSnack(outer, l.removedManyFromPlaylist(n), undo);
    done();
  }

  Future<void> removeFromLibrary() async {
    final ok = await showConfirm(
      outer,
      title: l.removeManyFromLibraryTitle(n),
      body: l.removeManyFromLibraryBody,
      confirmLabel: l.removeFromList,
      destructive: true,
    );
    if (!ok) return;
    final removed = await ref.read(trackOpsProvider).deleteMissing(
      [for (final t in tracks) t.id],
    );
    snack(l.removedManyFromLibrary(removed));
    done();
  }

  final music = [
    for (final t in tracks)
      if (t.kind == 0) t,
  ];

  Future<void> deleteFromDevice() async {
    if (await confirmAndDeleteTracks(outer, ref, music)) done();
  }

  return [
    TrackActionGroup(l.groupQueue, [
      TrackAction(Icons.play_arrow_rounded, l.play, () async {
        await ctrl.playFromList(tracks, 0);
        done();
      }),
      TrackAction(Icons.playlist_play_rounded, l.playNext, () async {
        // Each one goes right after the playing track: reversed, so the order
        // of the picks is the play order.
        var added = 0, full = false;
        for (final t in tracks.reversed) {
          final r = await ctrl.playNext(t.id);
          added += r?.added ?? 1;
          if (r != null && r.full) {
            full = true;
            break;
          }
        }
        if (outer.mounted) showQueued(outer, (added: added, full: full), wanted: n, ok: l.playNextMany(n));
        done();
      }),
      TrackAction(Icons.queue_rounded, l.addToQueue, () async {
        var added = 0, full = false;
        for (final t in tracks) {
          final r = await ctrl.addToQueue(t.id);
          added += r?.added ?? 1;
          if (r != null && r.full) {
            full = true;
            break;
          }
        }
        if (outer.mounted) showQueued(outer, (added: added, full: full), wanted: n, ok: l.addedToQueueMany(n));
        done();
      }),
      if (ref.read(jamProvider).active)
        TrackAction(Icons.queue_music_rounded, l.jamAddToJam, () async {
          final remote = ref.read(jamProvider).remote;
          final r = await ref.read(jamProvider.notifier).addTracks(tracks);
          if (!outer.mounted) return;
          if (remote && r.added == 0 && !r.full) {
            showMsg(outer, l.jamNotFoundOnline);
          } else {
            showQueued(outer, r, wanted: n, ok: l.jamAdded(r.added));
          }
          done();
        }),
    ]),
    TrackActionGroup(l.groupCollection, [
      TrackAction(
        allFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        allFavorite ? l.bulkRemoveFromFavorites : l.bulkAddToFavorites,
        favorites,
      ),
      TrackAction(Icons.playlist_add_rounded, l.addToPlaylist, () async {
        if (await showAddToPlaylistSheet(outer, ref, tracks)) done();
      }),
      TrackAction(Icons.label_outline_rounded, l.tagAddToSelection, () async {
        await pickTagFor(outer, ref, tracks, remove: false, done: done);
      }),
      TrackAction(Icons.label_off_outlined, l.tagRemoveFromSelection, () async {
        await pickTagFor(outer, ref, tracks, remove: true, done: done);
      }),
      TrackAction(Icons.album_outlined, l.moveToAlbum, () async {
        if (await showMoveToAlbumDialog(outer, ref, tracks)) done();
      }),
      if (ctx.playlistId != null)
        TrackAction(
          Icons.playlist_remove_rounded,
          l.removeFromPlaylistAction,
          () => removeFromPlaylist(ctx.playlistId!),
        ),
    ]),
    if (allMissing || music.isNotEmpty)
      TrackActionGroup(l.groupOther, [
        // Only for tracks whose file is gone: the library row has nothing left
        // to point to. Music that still exists is never removable from here.
        if (allMissing)
          TrackAction(
            Icons.delete_outline_rounded,
            l.removeFromLibrary,
            removeFromLibrary,
          ),
        if (music.isNotEmpty)
          TrackAction(
            Icons.delete_forever_rounded,
            l.deleteFromDevice,
            deleteFromDevice,
            destructive: true,
          ),
      ]),
  ];
}

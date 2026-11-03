import '../../services/audio/online_entries.dart';
import 'cc_sheet.dart';
import 'cover_picker_sheet.dart';
import '../../providers/cover_ops.dart';
import 'track_artists_sheet.dart';
import '../../services/online/artist_link_resolver.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/app_log.dart';
import '../../core/constants.dart';
import '../../core/platform.dart';
import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/equalizer_providers.dart';
import '../../providers/pending_playlist_adds.dart' show addToPlaylistTag;
import '../../providers/player_providers.dart';
import '../../providers/preview_providers.dart';
import '../../providers/suggestion_actions.dart';
import '../../providers/track_ops.dart';
import '../../providers/youtube_providers.dart'
    show downloadIndexProvider, downloadsProvider;
import '../screens/playlists/playlist_dialogs.dart';
import '../screens/playlists/playlist_picker.dart';
import '../screens/tags/tags_sheet.dart';
import '../screens/enrich_preview_dialog.dart';
import '../screens/settings/equalizer_screen.dart';
import '../screens/devices/devices_sheet.dart';
import '../screens/track_edit_dialog.dart';
import '../screens/library/album_detail_screen.dart';
import '../screens/online/artist_picker_sheet.dart';
import '../shell/shell_nav.dart';
import '../../services/online/youtube_service.dart' show YtResult;
import '../../services/stream/stream_key.dart'
    show keyOfStreamPath, streamResultOfRow;
import '../../data/repositories/track_kinds.dart';
import '../../providers/library_providers.dart';
import '../theme/tokens.dart';
import 'track_art.dart';
import 'radio_now.dart';
import '../screens/radio/radio_actions.dart';
import '../../providers/radio_providers.dart' show savedRadioIdsProvider;
import '../../services/radio/radio_station.dart';
import 'delete_tracks.dart';
import 'favorite_actions.dart';
import 'format_utils.dart';
import 'quality_tag.dart';
import '../../services/jam/jam_models.dart' show jamFullResult;
import 'show_msg.dart';

/// One entry of the track menu.
class TrackAction {
  const TrackAction(
    this.icon,
    this.label,
    this.run, {
    this.destructive = false,
    this.onStreamRow = false,
  });

  final bool destructive;

  /// Kept in the menu of a streamed shadow row (kind 2).
  final bool onStreamRow;
  final IconData icon;
  final String label;
  final Future<void> Function() run;
}

class TrackActionGroup {
  const TrackActionGroup(this.title, this.actions);

  final String title;
  final List<TrackAction> actions;
}

/// The queue entry [id] was downloaded or promoted meanwhile (it still plays under its online id).
bool Function(String) _inLibrary(WidgetRef ref) =>
    isLibraryArtistIn(ref.read(artistsProvider).value ?? const []);

bool entryInLibrary(WidgetRef ref, int id) {
  final r = ref.read(onlineEntriesProvider)?[id]?.result;
  return r != null &&
      (ref
              .read(downloadIndexProvider)
              .value
              ?.contains(r.id, source: r.source) ??
          false);
}

/// Streamed (online) entries are not library rows: no favourites, tags,
/// playlists by id, edit, lyrics, share, details of a file or deletion. They
/// can be downloaded, downloaded into a playlist, disliked or taken out of
/// the queue.
List<TrackActionGroup> onlineTrackActions(
  BuildContext outer,
  WidgetRef ref,
  Track track,
) {
  final l = outer.l10n;
  final actions = ref.read(suggestionActionsProvider);
  void snack(String text) => showMsg(outer, text);

  return [
    TrackActionGroup(l.groupCollection, [
      // Gone as soon as the entry is in the library, also with the sheet open (R-93).
      if (!entryInLibrary(ref, track.id))
        TrackAction(Icons.download_rounded, l.ytDownload, () => downloadOnline(
              outer,
              inLibrary: entryInLibrary(ref, track.id),
              start: () => actions.downloadEntry(track.id),
            )),
      TrackAction(Icons.playlist_add_rounded, l.addToPlaylist, () async {
        final picked = await pickPlaylist(outer, ref);
        if (picked == null) return;
        final now = await actions.addToPlaylist(track.id, picked.id);
        if (now != null) {
          snack(now ? l.addedToPlaylist(picked.name) : l.suggestionAddWhenDownloaded(picked.name));
        }
      }),
    ]),
    TrackActionGroup(l.groupGoTo, [
      TrackAction(
        Icons.person_outline_rounded,
        l.goToArtist,
        () => goToArtists(
          outer,
          ref,
          artistsOfTrack(
            track,
            ref.read(onlineEntriesProvider)?[track.id]?.result,
            isLibraryArtist: _inLibrary(ref),
          ),
        ),
      ),
    ]),
    TrackActionGroup(l.groupQueue, [
      if (ref.read(onlineEntriesProvider)?[track.id]?.suggested ?? false)
        TrackAction(Icons.thumb_down_outlined, l.suggestionDislike, () async {
          await actions.dislike(track.id);
          snack(l.suggestionDisliked);
        }),
      TrackAction(
        Icons.remove_circle_outline_rounded,
        l.removeFromQueueAction,
        () => actions.remove(track.id),
      ),
    ]),
  ];
}

/// A radio in the queue is not a track: it can be saved in «Le mie radio» (or
/// taken out), the song on air looked up, and the station taken out of the
/// queue. No favourites, downloads, playlists or tags.
List<TrackActionGroup> radioTrackActions(
  BuildContext outer,
  WidgetRef ref,
  Track track,
  RadioStation station,
) {
  final l = outer.l10n;
  final saved = ref.read(savedRadioIdsProvider).contains(station.id);
  final onAir = ref.read(audioHandlerProvider).onAir;
  final isCurrent = ref.read(currentTrackProvider).value?.id == track.id;
  return [
    TrackActionGroup(l.groupCollection, [
      TrackAction(
        saved ? Icons.star_rounded : Icons.star_border_rounded,
        saved ? l.radioUnsave : l.radioSave,
        () => toggleSavedRadio(outer, ref, station),
      ),
      if (isCurrent && onAir != null && kEnableYoutube)
        TrackAction(
          Icons.search_rounded,
          l.radioSearchSong,
          () async => searchOnAir(outer, ref, onAir),
        ),
    ]),
    TrackActionGroup(l.groupQueue, [
      TrackAction(
        Icons.remove_circle_outline_rounded,
        l.removeFromQueueAction,
        () => ref.read(suggestionActionsProvider).remove(track.id),
      ),
    ]),
  ];
}

/// The single model of the track actions, used by the bottom sheet (mobile:
/// long press, ⋮) and by the pointer menu (desktop: right click).
/// [outer] is the context the effects (snackbars, pages) are tied to.
List<TrackActionGroup> trackActions(
  BuildContext outer,
  WidgetRef ref,
  Track track,
) {
  final radio = radioOfTrackRead(ref, track);
  if (radio != null) return radioTrackActions(outer, ref, track, radio);
  if (isOnlineId(track.id)) return onlineTrackActions(outer, ref, track);
  final l = outer.l10n;
  final ctrl = ref.read(playerControllerProvider);

  Future<void> goToAlbum() async {
    final albums = await ref.read(albumsProvider.future);
    final found = albums.where((a) => a.albumKey == track.albumKey).firstOrNull;
    if (found == null || !outer.mounted) return;
    ShellNav.openInLibrary(outer, ref, AlbumDetailScreen(album: found));
  }

  Future<void> goToArtist() => goToArtists(
    outer,
    ref,
    libraryArtists(track, isLibraryArtist: _inLibrary(ref)),
  );

  Future<void> artistOnYoutubeMusic() => openYtmArtist(
    outer,
    ref,
    track.artist!.trim(),
    open: (page) => ShellNav.openInLibrary(outer, ref, page),
  );

  final groups = [
    TrackActionGroup(l.groupQueue, [
      if (isDesktop)
        TrackAction(Icons.hearing_rounded, l.previewTrack, () async {
          await ref.read(previewProvider.notifier).start(track);
        }),
      if (track.resumePositionMs != null)
        TrackAction(
          Icons.restart_alt_rounded,
          l.restartFromBeginning,
          () async {
            // The bookmark goes first: the player reads it when it loads the track.
            await ref.read(trackOpsProvider).setResumePosition(track.id, null);
            await ctrl.playFromList([track], 0);
          },
        ),
      TrackAction(Icons.playlist_play_rounded, l.playNext, () async {
        final inJam = ctrl.inJam;
        final added = await ctrl.playNext(track.id);
        if (outer.mounted) showQueued(outer, added, ok: inJam ? l.addedToQueue : l.playNextDone);
      }, onStreamRow: true),
      TrackAction(Icons.queue_rounded, l.addToQueue, () async {
        final added = await ctrl.addToQueue(track.id);
        if (outer.mounted) showQueued(outer, added);
      }, onStreamRow: true),
    ]),
    TrackActionGroup(l.groupCollection, [
      // A streamed shadow row: the download promotes it to a real library track.
      if (track.kind == kStreamKind &&
          keyOfStreamPath(track.path) != null &&
          ref.read(downloadIndexProvider).value?.pathForKey(keyOfStreamPath(track.path)!) == null)
        TrackAction(Icons.download_rounded, l.ytDownload, () async {
          ref
              .read(downloadsProvider.notifier)
              .add(streamResultOfRow(keyOfStreamPath(track.path)!, track));
        }, onStreamRow: true),
      TrackAction(
        track.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        track.isFavorite ? l.removeFromFavorites : l.favorite,
        () => toggleFavorite(outer, ref, track),
      ),
      TrackAction(
        Icons.playlist_add_rounded,
        l.addToPlaylist,
        () async => showAddToPlaylistSheet(outer, ref, [track]),
      ),
      TrackAction(
        Icons.label_outline_rounded,
        l.tagsEllipsis,
        () async => showTagsSheet(outer, ref, [track]),
      ),
    ]),
    TrackActionGroup(l.groupGoTo, [
      TrackAction(Icons.album_outlined, l.goToAlbum, goToAlbum),
      if ((track.artist ?? '').trim().isNotEmpty)
        TrackAction(
          Icons.person_outline_rounded,
          l.goToArtist,
          goToArtist,
        ),
      if (kEnableYoutube && (track.artist ?? '').trim().isNotEmpty)
        TrackAction(
          Icons.smart_display_rounded,
          l.ytmArtistOnYoutubeMusic,
          artistOnYoutubeMusic,
        ),
    ]),
    TrackActionGroup(l.groupEdit, [
      if (track.kind == 0) ...[
        TrackAction(
          Icons.image_outlined,
          l.coverChange,
          () => showCoverPicker(
            outer,
            save: (ops, bytes, mime) => ops.setTrackCover(track.id, bytes, mime),
            online: (track.album ?? '').trim().isEmpty ? null : (album: track.album!, artist: track.artist ?? ''),
          ),
        ),
        if (track.coverSource > 0)
          TrackAction(
            Icons.restore_rounded,
            l.coverRestoreOriginal,
            () => ref.read(coverOpsProvider).restoreTrackCover(track.id),
          ),
      ],
      TrackAction(
        Icons.edit_outlined,
        l.editInfo,
        () async => showTrackEditDialog(outer, track),
      ),
      TrackAction(
        Icons.travel_explore_rounded,
        l.searchWeb,
        () async => showEnrichPreview(outer, track),
      ),
    ]),
    TrackActionGroup(l.groupOther, [
      // From Now Playing's ⋯ (the playing track's menu), where the equalizer is.
      if (ref.read(equalizerProvider) != null &&
          ref.read(currentTrackProvider).value?.id == track.id)
        TrackAction(Icons.equalizer_rounded, l.equalizer, () async {
          ShellNav.open<void>(outer, const EqualizerScreen());
        }),
      TrackAction(
        Icons.devices_rounded,
        l.shareMenu,
        () async => DevicesSheet.show(outer, trackIds: [track.id]),
      ),
      TrackAction(Icons.info_outline_rounded, l.details, () async {
        showDialog<void>(
          context: outer,
          builder: (_) => _DetailsDialog(track: track),
        );
      }, onStreamRow: true),
      if (isDesktop)
        TrackAction(
          Icons.folder_open_rounded,
          l.showInFolder,
          () async => revealInFolder(track.path),
        ),
      // The file itself, not just a list: music only (episodes have their own
      // cleanup).
      if (track.kind == 0)
        TrackAction(Icons.delete_forever_rounded, l.deleteFromDevice, () async {
          await confirmAndDeleteTracks(outer, ref, [track]);
        }, destructive: true),
    ]),
  ];
  // A streamed shadow row (kind 2) keeps only queue actions and Details until phase 46.
  if (track.kind != kStreamKind) return groups;
  return [
    for (final g in groups)
      if (g.actions.any((a) => a.onStreamRow))
        TrackActionGroup(
          g.title,
          g.actions.where((a) => a.onStreamRow).toList(),
        ),
  ];
}

/// The track sheet; [lead] goes first (e.g. «Rimuovi dalla playlist»). Also the
/// desktop right click, and the ⋮ of a selection through [showTrackActionGroups].
Future<void> showTrackActions(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  TrackAction? lead,
}) {
  List<TrackActionGroup> build() => [
    if (lead != null) TrackActionGroup('', [lead]),
    ...trackActions(context, ref, track),
  ];
  var last = build();
  // The caller may be gone while the sheet is open: keep the last groups then.
  List<TrackActionGroup> groups() => context.mounted ? last = build() : last;
  // An online entry or streamed row: the groups follow the download index while the sheet is open.
  final changed = isOnlineId(track.id) || track.kind == kStreamKind ? ValueNotifier(0) : null;
  final sub = changed == null
      ? null
      : ref.listenManual(downloadIndexProvider, (_, _) => changed.value++);
  return showTrackActionGroups(
    context,
    last,
    header: _TrackHeader(track: track),
    refresh: changed,
    regroup: groups,
  ).whenComplete(() {
    sub?.close();
    changed?.dispose();
  });
}

/// «Scarica» of an online song: «already in the library», or [start] (null: no
/// such entry; true: joined the library at once) and the matching message.
Future<void> downloadOnline(
  BuildContext context, {
  required bool inLibrary,
  required Future<bool?> Function() start,
}) async {
  final l = context.l10n;
  if (inLibrary) return showMsg(context, l.ytAlreadyInLibrary);
  final now = await start();
  if (now != null && context.mounted) {
    showMsg(context, now ? l.addedToLibrary : l.suggestionDownloadStarted);
  }
}

/// Shows [groups] as an action sheet; the chosen action runs once it is closed.
Future<void> showTrackActionGroups(
  BuildContext context,
  List<TrackActionGroup> groups, {
  Widget? header,
  String? title,
  Listenable? refresh,
  List<TrackActionGroup> Function()? regroup,
}) {
  List<List<CcAction<TrackAction>>> rows(List<TrackActionGroup> gs) => [
    for (final g in gs)
      [
        for (final a in g.actions)
          CcAction<TrackAction>(
            icon: a.icon,
            label: a.label,
            value: a,
            destructive: a.destructive,
            onTap: () => a.run(),
          ),
      ],
  ];
  return showCcActionSheet<TrackAction>(
    context: context,
    header: header,
    title: title,
    groups: rows(groups),
    refresh: refresh,
    regroup: regroup == null ? null : () => rows(regroup()),
  );
}

class _TrackHeader extends StatelessWidget {
  const _TrackHeader({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.gap16,
        CcDims.gap4,
        CcDims.gap16,
        CcDims.gap12,
      ),
      child: Row(
        children: [
          TrackArt(track: track, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleSmall,
                ),
                Text(
                  track.artist ?? l.unknownArtist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium,
                ),
                if (track.album != null && track.album!.isNotEmpty)
                  Text(
                    track.album!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall?.copyWith(color: cc.textFaint),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the containing folder without a shell; arguments are passed as a list.
Future<void> revealInFolder(String path) async {
  try {
    if (Platform.isWindows) {
      final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
      await Process.start('$windir\\explorer.exe', ['/select,$path']);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [p.dirname(path)]);
    }
  } on Object catch (e, st) {
    AppLog.w('reveal in folder failed: $path', e, st);
  }
}

class _DetailsDialog extends StatelessWidget {
  const _DetailsDialog({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    String mb(int bytes) => '${(bytes / 1048576).toStringAsFixed(1)} MB';
    final added = DateFormat.yMMMd(Localizations.localeOf(context).toString())
        .format(DateTime.fromMillisecondsSinceEpoch(track.addedAt));
    Widget row(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(k)),
          Expanded(child: SelectableText(v)),
        ],
      ),
    );
    return AlertDialog(
      title: Text(track.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row(l.detailPath, track.path),
            row(l.detailFormat, track.format.toUpperCase()),
            Align(alignment: Alignment.centerLeft, child: QualityTag(track)),
            row(l.detailSize, mb(track.sizeBytes)),
            row(l.detailDuration, formatDuration(track.durationMs)),
            row(l.detailAdded, added),
            row(l.detailPlays, '${track.playCount}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }
}

/// The menu of an online row: play after, queue, playlist, download, artist
/// (R-16). With a Jam on, the controller sends it to the shared queue (D-89).
List<TrackAction> onlineResultActions(
  BuildContext outer,
  WidgetRef ref,
  YtResult r,
) {
  final l = outer.l10n;
  final ctrl = ref.read(playerControllerProvider);
  return [
    TrackAction(Icons.playlist_play_rounded, l.playNext, () async {
      final full = ctrl.jamQueueFull;
      await ctrl.playOnlineNext(r);
      if (outer.mounted) {
        showQueued(outer, full ? jamFullResult : null, ok: ctrl.inJam ? l.addedToQueue : l.playNextDone);
      }
    }),
    TrackAction(Icons.queue_rounded, l.addToQueue, () async {
      final full = ctrl.jamQueueFull;
      await ctrl.enqueueOnline(r);
      if (outer.mounted) showQueued(outer, full ? jamFullResult : null);
    }),
    TrackAction(Icons.playlist_add_rounded, l.addToPlaylist, () async {
      final picked = await pickPlaylist(outer, ref);
      if (picked == null || !outer.mounted) return;
      final now = await ref
          .read(downloadsProvider.notifier)
          .add(r, tag: addToPlaylistTag(picked.id));
      if (outer.mounted) {
        showMsg(outer, now ? l.addedToPlaylist(picked.name) : l.suggestionAddWhenDownloaded(picked.name));
      }
    }),
    TrackAction(Icons.download_rounded, l.ytDownload, () => downloadOnline(
          outer,
          inLibrary: ref.read(downloadIndexProvider).value?.contains(r.id, source: r.source) ?? false,
          start: () => ref.read(downloadsProvider.notifier).add(r),
        )),
    TrackAction(
      Icons.person_outline_rounded,
      l.goToArtist,
      () => goToArtists(outer, ref, onlineArtists(r)),
    ),
  ];
}

Future<void> showOnlineActions(
  BuildContext context,
  WidgetRef ref,
  YtResult r,
) {
  final actions = onlineResultActions(context, ref, r);
  return showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                r.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                r.artists.isEmpty ? r.channel : r.artists.join(', '),
              ),
            ),
            for (final a in actions)
              ListTile(
                leading: Icon(a.icon),
                title: Text(a.label),
                onTap: () {
                  Navigator.of(sheet).pop();
                  a.run();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

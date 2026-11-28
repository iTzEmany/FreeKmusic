import 'dart:async';

import '../../services/audio/online_entries.dart';
import 'cc_sheet.dart';
import 'dislike_sheet.dart';
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
import '../../services/share/share_fragment.dart' show SharedKind;
import '../../data/settings/settings_store.dart' show StorageMode;
import '../../providers/library_add_providers.dart';
import '../../providers/pending_playlist_adds.dart' show addToPlaylistTag;
import '../../providers/settings_providers.dart' show settingsProvider;
import '../../providers/player_providers.dart';
import '../../providers/preview_providers.dart';
import '../../providers/suggestion_actions.dart';
import '../../providers/track_ops.dart';
import '../../providers/free_space_providers.dart';
import '../../providers/track_state_providers.dart';
import '../../providers/youtube_providers.dart' show downloadIndexProvider;
import 'download_bar.dart';
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
import 'confirm.dart';
import 'delete_tracks.dart';
import 'favorite_actions.dart';
import 'format_utils.dart';
import 'quality_tag.dart';
import '../../services/jam/jam_models.dart' show jamFullResult;
import 'share_collection.dart';
import 'show_msg.dart';
import 'action_catalog.dart';
import 'context_menu.dart';

/// One entry of the track menu.
class TrackAction {
  const TrackAction(
    this.icon,
    this.label,
    this.run, {
    this.destructive = false,
    this.onStreamRow = false,
    this.onOnlineEntry = false,
  });

  final bool destructive;

  /// Kept in the menu of a streamed shadow row (kind 2).
  final bool onStreamRow;

  /// Kept in the menu of a saved online entry that is bound to its library row (it plays under a negative id).
  final bool onOnlineEntry;
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
  return r != null && ref.read(trackStateProvider(r.indexKey)) != TrackState.online;
}

/// Streamed (online) entries are not library rows: no favourites, tags,
/// playlists by id, edit, lyrics, details of a file or deletion. They can be
/// shared (the link of the video), downloaded, downloaded into a playlist, disliked or taken out of
/// the queue.
List<TrackActionGroup> onlineTrackActions(
  BuildContext outer,
  WidgetRef ref,
  Track track, {
  Track? row,
  Rect? anchor,
}) {
  final l = outer.l10n;
  final actions = ref.read(suggestionActionsProvider);
  void snack(String text) => showMsg(outer, text);
  final entry = ref.read(onlineEntriesProvider)?[track.id];
  final saved = entry != null && ref.read(trackStateProvider(entry.result.indexKey)) == TrackState.savedStream;

  final groups = [
    TrackActionGroup(l.groupCollection, [
      // Gone as soon as the entry is in the library, also with the sheet open (R-93).
      if (!entryInLibrary(ref, track.id))
        TrackAction(
          CatalogAction.library.icon,
          CatalogAction.library.label(l),
          () => downloadOnline(
            outer,
            inLibrary: entryInLibrary(ref, track.id),
            start: () => actions.downloadEntry(track.id),
          ),
        ),
      // Saved without a file: «Scarica» puts it on the device (the player keeps the entry's negative id).
      if (saved)
        TrackAction(
          CatalogAction.download.icon,
          l.ytDownloadOnDevice,
          () => downloadOnline(
            outer,
            inLibrary: false,
            start: () => ref.read(libraryAdderProvider).download(entry.result),
          ),
        ),
      TrackAction(CatalogAction.playlist.icon, CatalogAction.playlist.label(l), () async {
        final picked = await pickPlaylist(outer, ref);
        if (picked.isEmpty) return;
        final now = await actions.addToPlaylist(track.id, [for (final p in picked) p.id]);
        if (now != null) {
          snack(pickedAddedText(l, picked, now: now));
        } else if (outer.mounted) {
          snack(l.libraryAddFailed);
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
    // Not saved yet: the entry's own video link; with a row, its «Condividi» is merged in below.
    if (row == null && entry != null)
      TrackActionGroup(l.groupOther, [
        _shareAction(outer, ref, track.copyWith(kind: kStreamKind, path: 'stream:${entry.result.indexKey}'), anchor),
      ]),
    TrackActionGroup(l.groupQueue, [
      if (ref.read(onlineEntriesProvider)?[track.id]?.suggested ?? false)
        TrackAction(
          Icons.thumb_down_outlined,
          l.suggestionDislike,
          () => showDislikeSheet(outer, ref, track.id),
        ),
      TrackAction(
        Icons.remove_circle_outline_rounded,
        l.removeFromQueueAction,
        () => actions.remove(track.id),
      ),
    ]),
  ];
  if (row == null) return groups;
  // The row's own actions that neither touch the queue nor delete a file; same-titled groups merge.
  final extra = [
    for (final g in trackActions(outer, ref, row, anchor: anchor))
      TrackActionGroup(g.title, [for (final a in g.actions) if (a.onOnlineEntry) a]),
  ].where((g) => g.actions.isNotEmpty);
  return [
    for (final g in groups)
      TrackActionGroup(g.title, [
        ...g.actions,
        for (final x in extra.where((x) => x.title == g.title)) ...x.actions,
      ]),
    for (final x in extra)
      if (!groups.any((g) => g.title == x.title)) x,
  ];
}

TrackAction _shareAction(BuildContext outer, WidgetRef ref, Track track, Rect? anchor) => TrackAction(
  CatalogAction.share.icon,
  CatalogAction.share.label(outer.l10n),
  () => shareTracks(outer, ref, SharedKind.track, track.title, [track], subtitle: track.artist, origin: anchor),
  onStreamRow: true,
  onOnlineEntry: true,
);

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
  Track track, {
  Track? row,
  bool isDownloadedFile = false,
  Rect? anchor, // the row's rectangle, when the menu was opened from one (a share sheet on iPad/desktop)
}) {
  final radio = radioOfTrackRead(ref, track);
  if (radio != null) return radioTrackActions(outer, ref, track, radio);
  if (isOnlineId(track.id)) return onlineTrackActions(outer, ref, track, row: row, anchor: anchor);
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

  final state = ref.read(trackStateProvider(trackStateKey(track)));
  final streamKey = track.kind == kStreamKind ? keyOfStreamPath(track.path) : null;
  final streaming = ref.read(settingsProvider).storageMode == StorageMode.stream;
  // A shadow row not saved yet keeps the short menu; a saved one has the full menu (D-696).
  final unsavedShadow = streamKey != null && state == TrackState.online;
  // The same rule as `freeSpaceCandidates`: the very file the app downloaded, not the one playing.
  // Not from `state`: the row's `#id` key may have no listener (an autoDispose read reads «online»).
  final playingId = ref.read(audioHandlerProvider).currentTrack?.id;
  final playingRow = playingId == null ? null : ref.read(onlineEntriesProvider)?[playingId]?.trackId;
  final inDownloads = track.kind == kMusicKind &&
      !track.missing &&
      playingId != track.id &&
      playingRow != track.id &&
      isDownloadedFile;

  final groups = [
    TrackActionGroup(l.groupQueue, [
      if (isDesktop && track.kind != kStreamKind)
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
          onStreamRow: true,
        ),
      TrackAction(CatalogAction.queue.icon, CatalogAction.queue.label(l), () async {
        final added = await ctrl.addToQueue(track.id);
        if (outer.mounted) showQueued(outer, added);
      }, onStreamRow: true),
    ]),
    TrackActionGroup(l.groupCollection, [
      // An unsaved shadow row in streaming mode joins the library without a file: never next to «Scarica».
      if (unsavedShadow && streaming)
        TrackAction(
          CatalogAction.library.icon,
          CatalogAction.library.label(l),
          () => downloadOnline(
            outer,
            inLibrary: false,
            start: () => ref.read(libraryAdderProvider).add(streamResultOfRow(streamKey, track)),
          ),
          onStreamRow: true,
        ),
      // «Scarica» saves too (D-695) and promotes the row to a file.
      if (streamKey != null && state != TrackState.downloaded && !(unsavedShadow && streaming))
        TrackAction(
          CatalogAction.download.icon,
          streaming ? l.ytDownloadOnDevice : l.ytDownload,
          () => downloadOnline(
            outer,
            inLibrary: false,
            start: () => ref.read(libraryAdderProvider).download(streamResultOfRow(streamKey, track)),
          ),
          onStreamRow: true,
        ),
      // Only a file the app downloaded itself (a user's mp3 is never touched).
      if (inDownloads)
        TrackAction(Icons.cleaning_services_rounded, l.freeSpaceTitle, () async {
          final ok = await showConfirm(
            outer,
            title: l.freeSpaceConfirmTitle,
            body: l.freeSpaceConfirmBody(1),
            confirmLabel: l.freeSpaceTitle,
            destructive: true,
          );
          if (!ok || !outer.mounted) return;
          final report = await (await ref.read(freeSpaceServiceProvider.future)).freeSpace([track.id]);
          if (!outer.mounted) return;
          showMsg(
            outer,
            report.freedIds.isEmpty
                ? l.freeSpaceFailed(1)
                : l.freeSpaceDone(report.freedIds.length, formatBytes(report.freedBytes, Localizations.localeOf(outer).toString())),
          );
        }),
      TrackAction(
        track.isFavorite
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
        track.isFavorite ? l.removeFromFavorites : l.bulkAddToFavorites,
        () => toggleFavorite(outer, ref, track),
        onOnlineEntry: true,
      ),
      TrackAction(
        CatalogAction.playlist.icon,
        CatalogAction.playlist.label(l),
        () async => showAddToPlaylistSheet(outer, ref, [track]),
      ),
      TrackAction(
        Icons.label_outline_rounded,
        l.tagsEllipsis,
        () async => showTagsSheet(outer, ref, [track]),
        onOnlineEntry: true,
      ),
    ]),
    TrackActionGroup(l.groupGoTo, [
      TrackAction(Icons.album_outlined, l.goToAlbum, goToAlbum, onOnlineEntry: true),
      if ((track.artist ?? '').trim().isNotEmpty)
        TrackAction(Icons.person_outline_rounded, l.goToArtist, goToArtist, onOnlineEntry: true),
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
            save: (ops, bytes, mime) =>
                ops.setTrackCover(track.id, bytes, mime),
            online: (track.album ?? '').trim().isEmpty
                ? null
                : (album: track.album!, artist: track.artist ?? ''),
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
        onOnlineEntry: true,
      ),
      TrackAction(
        Icons.travel_explore_rounded,
        l.searchWeb,
        () async => showEnrichPreview(outer, track),
      ),
    ]),
    TrackActionGroup(l.groupOther, [
      // A saved stream leaves the library only: it stays in its playlists and the history (D-524).
      if (track.kind == kStreamKind && track.saved && keyOfStreamPath(track.path) != null)
        TrackAction(Icons.delete_outline_rounded, l.removeFromLibrary, () async {
          final n = await ref.read(trackOpsProvider).removeSavedStreams([track]);
          if (outer.mounted) showMsg(outer, l.removedManyFromLibrary(n));
        }, onStreamRow: true),
      // From Now Playing's ⋯ (the playing track's menu), where the equalizer is.
      if (ref.read(equalizerProvider) != null &&
          ref.read(currentTrackProvider).value?.id == track.id)
        TrackAction(Icons.equalizer_rounded, l.equalizer, () async {
          ShellNav.openOnTop<void>(outer, ref, const EqualizerScreen());
        }),
      _shareAction(outer, ref, track, anchor),
      if (track.kind != kStreamKind)
        TrackAction(
          Icons.devices_rounded,
          l.sendToDeviceMenu,
          () async => DevicesSheet.show(outer, trackIds: [track.id]),
        ),
      TrackAction(Icons.info_outline_rounded, l.details, () async {
        showDialog<void>(
          context: outer,
          builder: (_) => _DetailsDialog(track: track),
        );
      }, onStreamRow: true),
      if (isDesktop && track.kind != kStreamKind)
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
  // A streamed shadow row (kind 2) keeps only queue actions and Details; so
  // does a podcast episode not downloaded yet (a row on an address), which has no file to act on.
  if (!unsavedShadow &&
      !(track.kind == kEpisodeKind && isRemoteEpisodePath(track.path))) {
    return groups;
  }
  return [
    for (final g in groups)
      if (g.actions.any((a) => a.onStreamRow))
        TrackActionGroup(
          g.title,
          g.actions.where((a) => a.onStreamRow).toList(),
        ),
  ];
}

/// A menu is being prepared (a double tap, or two rows tapped within the check, must not open two sheets).
var _opening = false;

/// Lives for the whole app, inside the root navigator: the menu takes its context and ref from here, so
/// they outlast the row that opened it (a dialog or a delete after the confirm, when the list changed).
class TrackMenuHost extends ConsumerStatefulWidget {
  const TrackMenuHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TrackMenuHost> createState() => _TrackMenuHostState();
}

_TrackMenuHostState? _host;

class _TrackMenuHostState extends ConsumerState<TrackMenuHost> {
  @override
  void initState() {
    super.initState();
    _host = this;
  }

  @override
  void dispose() {
    if (_host == this) _host = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The track sheet; [lead] goes first (e.g. «Rimuovi dalla playlist»). Also the
/// desktop right click, and the ⋮ of a selection through [showTrackActionGroups].
/// [context] is the row: its rectangle anchors a share sheet (iPad, desktop); the rest runs on [TrackMenuHost].
///
/// With [at] (a global point: right click, or the ⋮) a desktop shows the same entries as a menu there
/// ([showContextMenu]); a phone keeps the sheet.
Future<void> showTrackActions(
  BuildContext context,
  Track track, {
  TrackAction? lead,
  Offset? at,
}) async {
  final host = _host;
  assert(host != null, 'showTrackActions needs a TrackMenuHost above the app');
  if (host == null || !host.mounted) {
    AppLog.w('track menu: no TrackMenuHost mounted, menu not opened');
    return;
  }
  if (!context.mounted || _opening) return;
  final box = context.findRenderObject();
  final anchor = box is RenderBox && box.attached && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
  final container = ProviderScope.containerOf(host.context, listen: false);
  _opening = true;
  var isDownloadedFile = false;
  try {
    // «Libera spazio» needs the file to be the very one downloaded: checked (a stat) before the sheet
    // opens, so it does not appear under an open menu and push the entries down.
    if (track.kind == kMusicKind) {
      // The whole check under one timeout: a slow index or stat must not hold the menu back.
      isDownloadedFile = await (() async {
        final index = await container.read(downloadIndexProvider.future);
        return index.signatureMatchesPath(track.path);
      })().timeout(const Duration(milliseconds: 500));
    }
  } on TimeoutException {
    AppLog.d('track menu: download check too slow, opening without it');
  } on Object catch (e, st) {
    AppLog.w('track menu: download check failed', e, st);
  } finally {
    _opening = false;
  }
  // The row that was tapped may be gone by now (its list changed): the host stands in.
  if (!host.mounted) return;
  final sheetContext = context.mounted ? context : host.context;

  // The menu follows the state of the song, not the Track it was opened with: a download
  // or a save swaps it for the library row and the groups are rebuilt (D-697).
  final entryKey = container.read(onlineEntriesProvider)?[track.id]?.result.indexKey;
  final key = trackStateKey(track, streamKey: entryKey);

  var live = track;
  Track? liveRow; // the library row behind an online entry (negative id), once saved or downloaded
  // «Libera spazio» needs the file to be the very one downloaded: checked off the UI thread, not while building.
  Future<bool> pristine() async =>
      (await container.read(downloadIndexProvider.future)).signatureMatchesPath(live.path);
  List<TrackActionGroup> build() => [
    if (lead != null) TrackActionGroup('', [lead]),
    ...trackActions(host.context, host.ref, live, row: liveRow, isDownloadedFile: isDownloadedFile, anchor: anchor),
  ];

  if (at != null && isDesktop && sheetContext.mounted) {
    // shortcut: the pointer menu does not follow a download that finishes while it is open.
    return showContextMenu(sheetContext, at, menuGroups(build()));
  }

  final changed = ValueNotifier(0);
  var closed = false;
  var calls = 0; // only the last call counts: an older lookup finishing late must not undo a newer one
  Future<void> follow() async {
    final n = ++calls;
    try {
      final row = await container.read(trackRowLookupProvider)(track, key);
      if (n != calls) return;
      // An online entry (negative id) stays itself: the library row is another thing to act on.
      if (row != null) {
        if (isOnlineId(track.id)) {
          liveRow = row;
        } else {
          live = row;
        }
      }
      final ok = await pristine();
      if (n != calls) return;
      isDownloadedFile = ok;
    } on Object catch (e, st) {
      AppLog.w('track menu: row of $key not reloaded', e, st);
    }
    if (!closed) changed.value++;
  }

  // Listeners before the first build: an autoDispose provider read with none would build twice (a flicker).
  // A `#<id>` key with a negative id (a radio) has no row to follow.
  ProviderSubscription<dynamic>? sub;
  ProviderSubscription<dynamic>? indexSub;
  try {
    if (!(key.startsWith('#') && isOnlineId(track.id))) {
      sub = container.listen(trackStateProvider(key), (_, _) => follow());
    }
    // «Libera spazio» reads the download index (a user's file is not in it): keep it loaded and follow it.
    indexSub = container.listen(downloadIndexProvider, (_, _) => follow());
    // The row of an entry saved before the sheet opened, and a later change of «Libera spazio».
    if (track.kind == kMusicKind || container.read(onlineEntriesProvider)?[track.id]?.trackId != null) unawaited(follow());
    if (!sheetContext.mounted) return;
    await showTrackActionGroups(
      sheetContext,
      build(),
      header: _TrackHeader(track: track, downloadKey: key.startsWith('#') ? null : key),
      refresh: changed,
      regroup: build,
    );
  } on Object catch (e, st) {
    AppLog.w('track menu: sheet failed', e, st);
    rethrow;
  } finally {
    closed = true;
    sub?.close();
    indexSub?.close();
    changed.dispose();
  }
}

/// [groups] as the entries of a pointer menu.
List<List<MenuAction>> menuGroups(List<TrackActionGroup> groups) => [
  for (final g in groups)
    [for (final a in g.actions) MenuAction(a.icon, a.label, a.run, destructive: a.destructive)],
];

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
  if (!context.mounted) return;
  showMsg(context, now == null ? l.libraryAddFailed : now ? l.addedToLibrary : l.suggestionDownloadStarted);
}

/// Shows [groups] as an action sheet; the chosen action runs once it is closed.
Future<TrackAction?> showTrackActionGroups(
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
            onTap: () async {
              await a.run();
            },
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
  const _TrackHeader({required this.track, this.downloadKey});

  final Track track;

  /// `source:id` of the song when it can be downloaded: its progress shows under the title.
  final String? downloadKey;

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
                if (downloadKey != null) DownloadBar(entryKey: downloadKey!),
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
  bool inLibrary() => ref.read(libraryAdderProvider).alreadyThere(r.id, r.source);
  return [
    TrackAction(CatalogAction.queue.icon, CatalogAction.queue.label(l), () async {
      final full = ctrl.jamQueueFull;
      await ctrl.enqueueOnline(r);
      if (outer.mounted) showQueued(outer, full ? jamFullResult : null);
    }),
    TrackAction(CatalogAction.playlist.icon, CatalogAction.playlist.label(l), () async {
      final picked = await pickPlaylist(outer, ref);
      if (picked.isEmpty || !outer.mounted) return;
      final now = await ref
          .read(libraryAdderProvider)
          .add(r, tag: addToPlaylistTag([for (final p in picked) p.id]));
      if (outer.mounted) {
        showMsg(outer, now == null ? l.libraryAddFailed : pickedAddedText(l, picked, now: now));
      }
    }),
    TrackAction(
      CatalogAction.library.icon,
      CatalogAction.library.label(l),
      () => downloadOnline(outer, inLibrary: inLibrary(), start: () => ref.read(libraryAdderProvider).add(r)),
    ),
    // In device mode the first item already downloads.
    if (ref.read(settingsProvider).storageMode == StorageMode.stream)
      TrackAction(
        CatalogAction.download.icon,
        l.ytDownloadOnDevice,
        // A saved stream is no file: only a downloaded one blocks it.
        () => downloadOnline(
          outer,
          inLibrary: ref.read(trackStateProvider(r.indexKey)) == TrackState.downloaded,
          start: () => ref.read(libraryAdderProvider).download(r),
        ),
      ),
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
  YtResult r, {
  Offset? at,
}) {
  final actions = onlineResultActions(context, ref, r);
  if (at != null && isDesktop) {
    return showContextMenu(context, at, menuGroups([TrackActionGroup('', actions)]));
  }
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

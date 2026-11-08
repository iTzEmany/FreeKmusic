import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/youtube_providers.dart';
import '../../../services/online/download_queue.dart';
import '../../../services/online/youtube_service.dart';
import '../../../providers/player_providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/track_actions.dart' show showOnlineActions;
import '../../widgets/track_row.dart' show SwipeToQueue;
import '../now_playing/now_playing_screen.dart' show playFromSearchAndOpen;
import '../../widgets/format_utils.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/track_row_selection.dart';
import 'online_selection_scope.dart';
import '../../../services/jam/jam_models.dart' show jamFullResult;
import '../../widgets/show_msg.dart';

const kOnlineRowHeight = 72.0;

/// The row grows with the text scale so its three text lines never overflow;
/// lists that fix the row extent must use this too.
double onlineRowExtentOf(BuildContext context) =>
    kOnlineRowHeight * (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);

/// Starts a download for each of [picked] (in this order) that is not already
/// in the library or on its way, and says how many started and how many not.
void startOnlineDownloads(
  BuildContext context,
  WidgetRef ref,
  Iterable<YtResult> picked,
) {
  final l = context.l10n;
  final index = ref.read(downloadIndexProvider).value;
  final busy = {
    for (final d in ref.read(downloadsProvider))
      if (d.status == DownloadStatus.queued ||
          d.status == DownloadStatus.downloading ||
          d.status == DownloadStatus.waitingRetry)
        d.result.id,
  };
  var started = 0, skipped = 0;
  for (final r in picked) {
    if ((index?.contains(r.id, source: r.source) ?? false) ||
        busy.contains(r.id)) {
      skipped++;
      continue;
    }
    ref.read(downloadsProvider.notifier).add(r);
    started++;
  }
  showMsg(
    context,
    started == 0
        ? l.ytNothingToDownload
        : skipped == 0
        ? l.ytDownloadsStarted(started)
        : l.ytDownloadsSkipped(started, skipped),
  );
}

/// Tap on an online row: streams it and opens the player; the controller
/// sends it to the shared queue instead when a Jam is on (D-89), then no player opens.
void tapOnline(BuildContext context, WidgetRef ref, YtResult r) {
  unawaited(ref.read(playerControllerProvider).inJam
      ? queueOnline(context, ref, r)
      : playFromSearchAndOpen(context, ref, r));
}

/// Swipe or «In coda» on an online row; says so only when it worked.
Future<void> queueOnline(BuildContext context, WidgetRef ref, YtResult r) async {
  final ctrl = ref.read(playerControllerProvider);
  final full = ctrl.jamQueueFull;
  try {
    await ctrl.enqueueOnline(r);
  } on Object catch (e, st) {
    AppLog.w('enqueue online failed for ${r.indexKey}', e, st);
    return;
  }
  if (context.mounted) showQueued(context, full ? jamFullResult : null);
}

/// A song of an artist page, an album or a long list: the row, with its
/// download state, «Già in libreria» and the pick state of list [selectionKey]
/// (the song is id [index] of that list).
class OnlineSongTile extends ConsumerWidget {
  const OnlineSongTile({
    super.key,
    required this.result,
    required this.index,
    required this.selectionKey,
    this.ownedLocally = false,
    this.number,
  });

  final YtResult result;
  final int index;
  final String selectionKey;

  /// Found among the library's songs of the artist (a file, another video).
  final bool ownedLocally;

  /// Place on the record, shown instead of the picture.
  final int? number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pick = watchOnlinePick(ref, selectionKey, index);
    final inLibrary =
        ownedLocally ||
        (ref
                .watch(downloadIndexProvider)
                .value
                ?.contains(result.id, source: result.source) ??
            false);
    final item = ref.watch(
      downloadsProvider.select(
        (d) => d.where((x) => x.result.id == result.id).lastOrNull,
      ),
    );
    return OnlineSongRow(
      result: result,
      inLibrary: inLibrary,
      item: item,
      selecting: pick.selecting,
      selected: pick.selected,
      position: pick.position,
      number: number,
      square: true,
      onTap: pick.onTap ?? () => tapOnline(context, ref, result),
      onLongPress: pick.onLongPress,
      onQueue: () => queueOnline(context, ref, result),
      onMore: () => showOnlineActions(context, ref, result),
      onDownload: () => ref.read(downloadsProvider.notifier).add(result),
    );
  }
}

/// One online song: picture, title, artist and length, an optional
/// extra button and «Scarica» (or the state of the download), 72 px tall.
class OnlineSongRow extends StatelessWidget {
  const OnlineSongRow({
    super.key,
    required this.result,
    required this.inLibrary,
    required this.item,
    required this.onDownload,
    this.listen,
    this.selecting = false,
    this.selected = false,
    this.position,
    this.onTap,
    this.onLongPress,
    this.onQueue,
    this.onMore,
    this.onArtistTap,
    this.square = false,
    this.number,
    this.note,
    this.tagLine,
  });

  final YtResult result;
  final bool inLibrary;
  final DownloadItem? item;
  final VoidCallback onDownload;

  /// An extra button before «Scarica» (hidden while picking).
  final Widget? listen;

  /// While picking, a tick box leads the row and a tap picks or drops it.
  final bool selecting, selected;

  /// Place in the order of the picks (1-based) of a picked row.
  final int? position;
  final VoidCallback? onTap, onLongPress;

  /// Swipe to the right (not from the edge, D-59) and the ⋮ menu; neither
  /// while picking.
  final VoidCallback? onQueue, onMore;

  /// Makes the artist's name a button that opens the artist.
  final VoidCallback? onArtistTap;

  /// A square cover (songs of a record) instead of the 16:9 video picture.
  final bool square;

  /// Place on the record, shown in the picture's place.
  final int? number;

  /// A line under the artist (replaces «Già in libreria»).
  final String? note;

  /// A small line of its own under the artist (where the song comes from),
  /// before «Già in libreria».
  final Widget? tagLine;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final row = Semantics(
      selected: selecting ? selected : null,
      value: selected
          ? (position == null ? l.selectedRow : l.selectedRowAt(position!))
          : null,
      child: Material(
        color: selected
            ? cc.accentSoft.withValues(alpha: 0.16)
            : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            height: onlineRowExtentOf(context),
            child: Row(
              children: [
                if (selecting)
                  Padding(
                    padding: const EdgeInsets.only(left: CcDims.gap4),
                    child: SelectionBox(
                      selected: selected,
                      position: position,
                      size: 40,
                    ),
                  )
                else
                  const SizedBox(width: CcDims.margin),
                if (number != null && !selecting)
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$number',
                      textAlign: TextAlign.center,
                      style: theme.bodyMedium?.copyWith(color: cc.textMuted),
                    ),
                  )
                else if (square)
                  NetThumbnail(
                    url: result.thumbnailUrl,
                    width: 48,
                    height: 48,
                    icon: Icons.music_note,
                  )
                else
                  NetThumbnail(
                    url: result.thumbnailUrl,
                    width: 80,
                    height: 45,
                    icon: Icons.music_video,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SongText(
                    result: result,
                    inLibrary: inLibrary,
                    onArtistTap: onArtistTap,
                    note: note,
                    tagLine: tagLine,
                  ),
                ),
                ?listen,
                _DownloadState(
                  item: item,
                  inLibrary: inLibrary,
                  onDownload: onDownload,
                ),
                if (onMore != null && !selecting)
                  IconButton(
                    tooltip: l.moreOptions,
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: onMore,
                  )
                else
                  const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
    if (onQueue == null || selecting) return row;
    return SwipeToQueue(
      swipeKey: 'swipe-online-${result.indexKey}',
      onQueue: onQueue!,
      child: row,
    );
  }
}

class _DownloadState extends StatelessWidget {
  const _DownloadState({
    required this.item,
    required this.inLibrary,
    required this.onDownload,
  });

  final DownloadItem? item;
  final bool inLibrary;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final st = item?.status;
    final Widget trailing;
    if (st == DownloadStatus.queued ||
        st == DownloadStatus.downloading ||
        st == DownloadStatus.waitingRetry) {
      // As wide as a button: the download state keeps the width of the button.
      trailing = SizedBox(
        width: 48,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              value: st == DownloadStatus.downloading ? item!.progress : null,
            ),
          ),
        ),
      );
    } else if (st == DownloadStatus.done || inLibrary) {
      trailing = SizedBox(
        width: 48,
        child: Center(
          child: Icon(Icons.check_circle_rounded, color: cc.accentSoft),
        ),
      );
    } else if (st == DownloadStatus.failed) {
      trailing = IconButton(
        tooltip: l.retry,
        icon: Icon(Icons.warning_amber_rounded, color: cc.error),
        onPressed: onDownload,
      );
    } else {
      trailing = IconButton(
        tooltip: l.ytDownload,
        icon: const Icon(Icons.download_rounded),
        onPressed: onDownload,
      );
    }
    return trailing;
  }
}

class _SongText extends StatelessWidget {
  const _SongText({
    required this.result,
    required this.inLibrary,
    required this.onArtistTap,
    required this.note,
    required this.tagLine,
  });

  final YtResult result;
  final bool inLibrary;
  final VoidCallback? onArtistTap;
  final String? note;
  final Widget? tagLine;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final length = result.duration == null
        ? null
        : formatDuration(result.duration!.inMilliseconds);
    final artist = result.artists.isEmpty ? '' : result.artists.first;
    final linked = onArtistTap != null && artist.isNotEmpty;
    final meta = [if (!linked) result.channel, ?length].join(', ');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.bodyLarge,
        ),
        Row(
          children: [
            Icon(
              Icons.smart_display_rounded,
              key: ValueKey('from-${result.source.name}'),
              size: 14,
              color: cc.textMuted,
            ),
            const SizedBox(width: 4),
            if (linked)
              Flexible(
                child: InkWell(
                  key: ValueKey('artist-link-${result.id}'),
                  onTap: onArtistTap,
                  child: Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodyMedium?.copyWith(
                      color: cc.accentSoft,
                      decoration: TextDecoration.underline,
                      decorationColor: cc.accentSoft,
                    ),
                  ),
                ),
              ),
            if (meta.isNotEmpty && linked) const SizedBox(width: 8),
            if (meta.isNotEmpty)
              Flexible(
                fit: linked ? FlexFit.loose : FlexFit.tight,
                child: Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium,
                ),
              ),
          ],
        ),
        if (note != null)
          Text(
            note!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.labelSmall?.copyWith(color: cc.textMuted),
          )
        else if (tagLine != null || inLibrary)
          Row(
            children: [
              if (tagLine != null) Flexible(child: tagLine!),
              if (tagLine != null && inLibrary) const SizedBox(width: 8),
              if (inLibrary)
                Flexible(
                  child: Text(
                    l.ytAlreadyInLibrary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelSmall?.copyWith(color: cc.accentSoft),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

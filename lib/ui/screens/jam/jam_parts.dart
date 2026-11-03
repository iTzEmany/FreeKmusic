import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/import_providers.dart';
import '../../../providers/jam_providers.dart' show jamProvider, jamTrackCoverProvider;
import '../../../providers/library_providers.dart' show artistsProvider;
import '../../../providers/share_hub.dart';
import '../../../providers/youtube_providers.dart' show downloadIndexProvider, downloadsProvider;
import '../../../services/jam/jam_models.dart';
import '../../../services/jam/jam_online_adder.dart' show jamYtResult;
import '../../../services/online/artist_link_resolver.dart';
import '../../../services/online/youtube_service.dart' show smallVideoThumbnail;
import '../../theme/tokens.dart';
import '../../widgets/artist_avatar.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/track_actions.dart' show downloadOnline;
import '../../widgets/track_artists_sheet.dart';

/// A curiosity as the owner sends it, «text\nurl»: the text without the source
/// url (which is not shown); null when there is none.
String? jamTriviaText(String? raw) {
  if (raw == null) return null;
  final lines = raw.trim().split('\n');
  if (lines.last.trim().startsWith('http')) lines.removeLast();
  final text = lines.join('\n').trim();
  return text.isEmpty ? null : text;
}

/// The credited artists of a shared track (no YouTube Music ids on the wire).
List<ArtistName> jamArtists(JamItem item, WidgetRef ref) => creditedArtists(
      item.artist ?? '',
      isLibraryArtist: isLibraryArtistIn(ref.read(artistsProvider).value ?? const []),
    );

/// Initials on a tint taken from the name.
class JamAvatar extends StatelessWidget {
  const JamAvatar({super.key, required this.name, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = HSLColor.fromAHSL(1, artistHue(name), 0.45, 0.32).toColor();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        artistMonogram(name),
        style: Theme.of(context).textTheme.titleSmall!.sized(size * 0.38),
      ),
    );
  }
}

/// The cover of a queue item: the local one for this device's items, the
/// YouTube thumbnail for online ones, the owner's bytes (`/cover/<n>`) for the
/// other devices' library items; the note placeholder when there is none.
class JamCover extends ConsumerWidget {
  const JamCover({
    super.key,
    required this.item,
    required this.size,
    this.radius = CcDims.rList,
  });

  final JamItem? item;
  final double size, radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final it = item;
    final ownId = ref.read(shareHubProvider.notifier).deviceId;
    final own = it != null && it.ownerDeviceId == ownId;
    final id = own ? int.tryParse(it.ref ?? '') : null;
    final key = id == null
        ? null
        : ref.watch(importedTrackProvider(id)).value?.coverKey;
    if (key != null || it == null) {
      return CoverImage(coverKey: key, size: size, radius: radius);
    }
    final vid = it.videoId;
    final remote = ref.watch(jamProvider.select((j) => j.remote));
    // Another device's library item has a video id too, but in LAN its owner's bytes win.
    final libraryOfOther = !own && int.tryParse(it.ref ?? '') != null;
    if (vid != null && (remote || !libraryOfOther)) {
      return NetThumbnail(
        url: smallVideoThumbnail(vid),
        width: size,
        height: size,
        radius: radius,
        icon: Icons.music_note_rounded,
      );
    }
    // Cached per queue item by the autoDispose family while this widget watches it.
    final bytes = own || remote || !libraryOfOther
        ? null
        : ref.watch(jamTrackCoverProvider(it.id)).value;
    if (bytes == null) return CoverImage(coverKey: null, size: size, radius: radius);
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.memory(
        bytes,
        width: size,
        height: size,
        cacheWidth: px,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => CoverImage(coverKey: null, size: size, radius: radius),
      ),
    );
  }
}

/// A row of the shared queue, laid out like a row of the play queue.
class JamQueueRow extends ConsumerWidget {
  const JamQueueRow({
    super.key,
    required this.item,
    required this.who,
    required this.isCurrent,
    required this.index,
    required this.onTap,
    required this.onJump,
    this.onRemove,
    this.showHandle = true,
  });

  /// False in «Coda insieme»: the queue is not draggable.
  final bool showHandle;

  final JamItem item;
  final String who;
  final bool isCurrent;
  final int index;
  final VoidCallback onTap;

  /// «Salta qui» in the ⋮ sheet.
  final VoidCallback onJump;

  /// «Rimuovi» in the ⋮ sheet; null where the removal is not allowed.
  final VoidCallback? onRemove;

  /// The ⋮ sheet; «Scarica» (as the player's) follows the download index while open (D-181).
  void _openMenu(BuildContext context, WidgetRef ref, List<ArtistName> artists) {
    final l = context.l10n;
    bool inLibrary() => ref.read(downloadIndexProvider).value?.contains(item.videoId!) ?? false;
    List<List<CcAction<String>>> build() => [
          [
            CcAction(icon: Icons.near_me_outlined, label: l.jamJumpHere, onTap: onJump),
            if (item.selfFetchable && !inLibrary())
              CcAction(
                icon: Icons.download_rounded,
                label: l.ytDownload,
                onTap: () => downloadOnline(
                  context,
                  inLibrary: inLibrary(),
                  start: () => ref.read(downloadsProvider.notifier).add(jamYtResult(item)),
                ),
              ),
            if (artists.isNotEmpty)
              CcAction(
                icon: Icons.person_outline_rounded,
                label: l.goToArtist,
                onTap: () => goToArtists(context, ref, artists),
              ),
            if (onRemove != null)
              CcAction(
                icon: Icons.delete_outline_rounded,
                label: l.removeFromList,
                destructive: true,
                onTap: onRemove,
              ),
          ],
        ];
    var last = build();
    // The row may be gone while the sheet is open: keep the last groups then.
    List<List<CcAction<String>>> groups() => context.mounted ? last = build() : last;
    final changed = ValueNotifier(0);
    final sub = ref.listenManual(downloadIndexProvider, (_, _) => changed.value++);
    showCcActionSheet<String>(
      context: context,
      title: item.title,
      groups: last,
      refresh: changed,
      regroup: groups,
    ).whenComplete(() {
      sub.close();
      changed.dispose();
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final l = context.l10n;
    final artists = jamArtists(item, ref);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CcDims.margin,
          vertical: CcDims.gap4,
        ),
        child: Row(
          children: [
            // The playing item: a 2 dp accent ring round a round cover.
            SizedBox.square(
              dimension: 52,
              child: isCurrent
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: cc.accent, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: JamCover(item: item, size: 44, radius: 22),
                      ),
                    )
                  : Center(child: JamCover(item: item, size: 48)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isCurrent
                        ? theme.bodyLarge?.copyWith(color: cc.accentSoft)
                        : theme.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.artist != null) item.artist!,
                      l.jamAddedBy(who),
                      if (item.suggested) l.jamSuggested,
                      if (!item.available) l.jamUnavailable,
                    ].join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: l.moreActions,
              visualDensity: VisualDensity.standard,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: Icon(Icons.more_vert_rounded, color: cc.textMuted),
              onPressed: () => _openMenu(context, ref, artists),
            ),
            if (showHandle)
              ReorderableDragStartListener(
                index: index,
                child: SizedBox.square(
                  dimension: 48,
                  child: Icon(Icons.drag_handle_rounded, color: cc.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

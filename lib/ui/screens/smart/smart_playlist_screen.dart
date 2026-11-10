import '../../widgets/cc_sheet.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/playlist_ops.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/l10n_ext.dart';
import '../library/album_detail_screen.dart' show collectionMeta;
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/smart_playlist_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/confirm.dart';
import '../../widgets/smart_cover.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import 'smart_playlist_editor.dart';
import '../../widgets/show_msg.dart';
import '../../../providers/shuffle_plus_providers.dart' show listKeyOf;

/// A smart playlist: its tracks come from the rules and change by themselves,
/// so the page is read-only (no reordering, no «add songs»).
class SmartPlaylistScreen extends ConsumerWidget {
  const SmartPlaylistScreen({super.key, required this.id});

  final int id;

  Future<void> _convert(
    BuildContext context,
    WidgetRef ref,
    SmartPlaylist p,
    List<Track> tracks,
  ) async {
    await ref.read(playlistOpsProvider).createWith(p.name, [for (final t in tracks) t.id]);
    if (!context.mounted) return;
    showMsg(context, context.l10n.smartConverted(p.name));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, SmartPlaylist p) async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.smartDeleteTitle(p.name),
      body: l.smartDeleteBody,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(playlistOpsProvider).deleteSmart(p.id);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final p = ref.watch(smartPlaylistProvider(id)).value;
    final tracks = ref.watch(smartTracksProvider(id)).value ?? const <Track>[];
    if (p == null) return const Scaffold();
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final playCtx = PlayContext(PlayContextKind.playlist, p.name);
    final extent = trackRowExtentOf(context, compact);
    final key = SelectionKey.smartOf(id);
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in tracks) t.id],
    );
    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: CollectionScaffold(
        selectionBar: SelectionBarSlot(listKey: key, tracks: tracks),
        title: p.name,
        name: p.name,
        cover: (s) => SmartCover(size: s, radius: CcDims.rGrid),
        subtitle: Text(
          p.rules.isEmpty ? l.smartNoRules : p.rules,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cc.textMuted),
        ),
        meta: collectionMeta(
          l,
          tracks: tracks.length,
          durationMs: tracks.fold<int>(0, (sum, t) => sum + t.durationMs),
        ),
        onPlay: tracks.isEmpty
            ? null
            : () => ctrl.playAll(
                tracks,
                context: playCtx,
                listKey: listKeyOf([for (final t in tracks) t.id]),
              ),
        shuffleIds: tracks.isEmpty ? null : [for (final t in tracks) t.id],
        menu: IconButton(
          tooltip: l.moreActions,
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () async {
            final v = await showCcActionSheet<_SmartAction>(
              context: context,
              title: p.name,
              groups: [
                [
                  CcAction(icon: Icons.edit_outlined, label: l.smartPlaylistEdit, value: _SmartAction.edit),
                  CcAction(icon: Icons.playlist_add_check_rounded, label: l.smartConvert, value: _SmartAction.convert),
                  CcAction(icon: Icons.delete_outline_rounded, label: l.delete, value: _SmartAction.delete, destructive: true),
                ],
              ],
            );
            if (v == null || !context.mounted) return;
            switch (v) {
              case _SmartAction.edit:
                await ShellNav.open<bool>(context, SmartPlaylistEditor(existing: p));
              case _SmartAction.convert:
                await _convert(context, ref, p, tracks);
              case _SmartAction.delete:
                await _delete(context, ref, p);
            }
          },
        ),
        slivers: [
          SliverList.builder(
            itemCount: tracks.length,
            itemBuilder: (_, i) => SizedBox(
              height: extent,
              child: LiveTrackRow(
                track: tracks[i],
                compact: compact,
                selection: selection,
                onTap: () => ctrl.playFromList(tracks, i, context: playCtx),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SmartAction { edit, convert, delete }

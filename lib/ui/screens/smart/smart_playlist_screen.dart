import '../../widgets/cc_sheet.dart';
import '../../widgets/cc_search_field.dart';
import '../../../core/app_log.dart';
import '../../../providers/library_providers.dart';
import '../../../core/text_utils.dart';
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
import '../../theme/tokens.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/smart_cover.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import 'smart_playlist_editor.dart';
import '../../widgets/show_msg.dart';
import '../../../providers/shuffle_plus_providers.dart' show PlaylistShuffleKey, smartMixProvider;
import '../../widgets/action_catalog.dart';
import '../../../services/shuffle_plus/genre_mix.dart';
import '../search/genre_screen.dart' show mixItemsOf, mixSlivers;

/// A smart playlist: its tracks come from the rules and change by themselves,
/// so the page is read-only (no reordering, no «add songs»).
class SmartPlaylistScreen extends ConsumerStatefulWidget {
  const SmartPlaylistScreen({super.key, required this.id});

  final int id;

  @override
  ConsumerState<SmartPlaylistScreen> createState() => _SmartPlaylistScreenState();
}

class _SmartPlaylistScreenState extends ConsumerState<SmartPlaylistScreen> {
  int get id => widget.id;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _convert(
    SmartPlaylist p,
    List<Track> tracks,
  ) async {
    await ref.read(playlistOpsProvider).createWith(p.name, [for (final t in tracks) t.id]);
    if (!mounted) return;
    showMsg(context, context.l10n.smartConverted(p.name));
  }

  Future<void> _delete(SmartPlaylist p) async {
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
    ref.read(settingsProvider.notifier).update(
      (s) => s.copyWith(
        playlistShuffles: {...s.playlistShuffles}..remove('smart:${p.id}'),
        smartMixOff: {...s.smartMixOff}..remove(p.id),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final p = ref.watch(smartPlaylistProvider(id)).value;
    final tracks = ref.watch(smartTracksProvider(id)).value ?? const <Track>[];
    final shown = filterByText(tracks, _query, trackSearchFields);
    // Similar online songs (D-756): on unless this playlist is in `smartMixOff`; a search shows only what it finds.
    final mixOn = !ref.watch(settingsProvider.select((s) => s.smartMixOff.contains(id)));
    final mix = mixOn ? ref.watch(smartMixProvider(id)).value ?? GenreMixState.none : GenreMixState.none;
    final rows = interleave(shown, _query.isEmpty ? mix : GenreMixState.none);
    final (:items, :itemAt) = mixItemsOf(interleave(tracks, mix));
    final mixed = mix.suggested.isNotEmpty || mix.incoming > 0;
    // Rows of a search keep the place they have in the whole list.
    int whole(Track t) => tracks.indexWhere((x) => x.id == t.id);
    if (p == null) return const Scaffold();
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final playCtx = PlayContext(PlayContextKind.playlist, p.name);
    final key = SelectionKey.smartOf(id);
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in shown) t.id],
    );
    // One key for the pill and Play: they must be the same list (D-534).
    final shuffleKey = PlaylistShuffleKey(id, smart: true);
    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: CollectionScaffold(
        selectionBar: SelectionBarSlot(listKey: key, tracks: shown),
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
        downloadTracks: tracks,
        scrollerCount: shown.length,
        onPlay: tracks.isEmpty
            ? null
            : mixed
            ? () => ctrl.playMixed(items, context: playCtx, listKey: shuffleKey)
            : () => ctrl.playAll(
                tracks,
                context: playCtx,
                listKey: shuffleKey,
              ),
        shuffleIds: tracks.isEmpty ? null : [for (final i in items) ?i.track?.id],
        shuffleKey: shuffleKey,
        // Suggested songs in the list: Shuffle+ would go off anyway (R-18).
        shufflePlus: !mix.suggested.isNotEmpty,
        menu: IconButton(
          tooltip: l.moreActions,
          icon: Icon(CatalogAction.more.icon),
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
                await _convert(p, tracks);
              case _SmartAction.delete:
                await _delete(p);
            }
          },
        ),
        slivers: [
          if (tracks.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.margin,
                  CcDims.gap4,
                  CcDims.margin,
                  CcDims.gap8,
                ),
                child: CcSearchField(
                  controller: _search,
                  hint: l.searchHint,
                  onQuery: (v) async {
                    // A big list gets its search texts made off the UI thread.
                    if (v.isNotEmpty && tracks.length > 2000) {
                      try {
                        await primeHaystacks(tracks, trackSearchFields);
                      } on Object catch (e, st) {
                        AppLog.w('search prime failed', e, st);
                      }
                      // The field may have changed while the isolate worked.
                      if (!mounted || _search.text.trim() != v.trim()) return;
                    }
                    setState(() => _query = v);
                  },
                ),
              ),
            ),
          if (tracks.isNotEmpty && shown.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(icon: Icons.search_off_rounded, message: l.noResults),
            ),
          ...mixSlivers(
            context,
            rows: rows,
            mix: _query.isEmpty ? mix : GenreMixState.none,
            compact: compact,
            trackRow: (t, i) => LiveTrackRow(
              track: t,
              compact: compact,
              selection: selection,
              onTap: () => mixed && _query.isEmpty
                  ? ctrl.playMixed(items, index: itemAt[i], context: playCtx, listKey: shuffleKey)
                  : ctrl.playFromList(tracks, whole(t), context: playCtx, listKey: shuffleKey),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SmartAction { edit, convert, delete }

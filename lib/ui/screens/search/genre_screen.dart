import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/shuffle_plus_providers.dart';
import '../../../providers/youtube_providers.dart';
import '../../../services/online/youtube_service.dart';
import '../../../services/shuffle_plus/genre_mix.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/track_actions.dart' show showOnlineActions;
import '../online/online_song_row.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../library/album_detail_screen.dart' show collectionMeta;
import '../../widgets/cc_app_bar.dart';

String _offText(AppLocalizations l, GenreMixOff off) => switch (off) {
  GenreMixOff.jam => l.genreMixOffJam,
  GenreMixOff.metered => l.genreMixOffMetered,
  GenreMixOff.offline => l.genreMixOffOffline,
  GenreMixOff.noTool => l.genreMixOffNoTool,
  GenreMixOff.rateLimited => l.genreMixOffRateLimited,
};

/// Tracks of one genre, with an online suggestion every second one (D-356).
class GenreScreen extends ConsumerWidget {
  const GenreScreen({super.key, required this.genre});

  final String genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tracks =
        ref.watch(genreTracksProvider(genre)).value ?? const <Track>[];
    final mix = ref.watch(genreMixProvider(genre)).value ?? GenreMixState.none;
    final rows = interleave(tracks, mix);
    final onlineExtent = onlineRowExtentOf(context);
    final firstSkeleton = rows.indexWhere((r) => r.track == null && r.suggestion == null);
    // What is shown without the placeholders, and where each row stands in it.
    final items = <MixItem>[];
    final itemAt = <int>[];
    for (final r in rows) {
      itemAt.add(items.length);
      if (r.track != null || r.suggestion != null) {
        items.add((track: r.track, online: r.suggestion?.result, seedTitle: r.suggestion?.seedTitle));
      }
    }
    final extent = trackRowExtentOf(
      context,
      ref.watch(settingsProvider).compactMode,
    );
    final ctrl = ref.read(playerControllerProvider);
    final compact = ref.watch(settingsProvider).compactMode;
    final ctx = PlayContext(PlayContextKind.playlist, genre);
    final key = SelectionKey.genreOf(genre);
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in tracks) t.id],
    );
    if (tracks.isEmpty) {
      return Scaffold(
        appBar: CcAppBar(title: genre),
        body: EmptyState(icon: Icons.music_note_rounded, message: l.noResults),
      );
    }
    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: CollectionScaffold(
        selectionBar: SelectionBarSlot(listKey: key, tracks: tracks),
        title: genre,
        name: genre,
        meta: collectionMeta(
          l,
          tracks: tracks.length,
          durationMs: tracks.fold<int>(0, (sum, t) => sum + t.durationMs),
        ),
        // The list as shown: the suggested songs that have arrived, in place.
        onPlay: () => ctrl.playMixed(
          items,
          context: ctx,
          listKey: listKeyOf([for (final i in items) ?i.track?.id]),
        ),
        // The ids of the list ▶ plays: the songs shown (a suggested one has no id yet).
        shuffleIds: [for (final i in items) ?i.track?.id],
        slivers: [
          if (mix.off != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.margin,
                  0,
                  CcDims.margin,
                  CcDims.gap8,
                ),
                child: Text(
                  _offText(l, mix.off!),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.cc.textMuted),
                ),
              ),
            ),
          SliverVariedExtentList.builder(
            itemCount: rows.length,
            itemExtentBuilder: (i, _) =>
                rows[i].track == null ? onlineExtent : extent,
            itemBuilder: (_, i) {
              final row = rows[i];
              final t = row.track;
              if (t != null) {
                return LiveTrackRow(
                  track: t,
                  compact: compact,
                  selection: selection,
                  onTap: () => ctrl.playMixed(items, index: itemAt[i], context: ctx),
                );
              }
              final r = row.suggestion;
              if (r != null) return _SuggestedRow(result: r.result);
              // One semantic node for all the placeholder rows.
              final skeleton = Skeleton.list(
                rows: 1,
                rowHeight: onlineExtent,
                label: l.shufflePlusChoosing(mix.incoming),
              );
              return i == firstSkeleton ? skeleton : ExcludeSemantics(child: skeleton);
            },
          ),
        ],
      ),
    );
  }
}

/// A suggested online song: «Suggerito» with the online icon; a tap streams it.
class _SuggestedRow extends ConsumerWidget {
  const _SuggestedRow({required this.result});

  final YtResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final inLibrary =
        ref
            .watch(downloadIndexProvider)
            .value
            ?.contains(result.id, source: result.source) ??
        false;
    final item = ref.watch(
      downloadsProvider.select(
        (d) => d.where((x) => x.result.id == result.id).lastOrNull,
      ),
    );
    return OnlineSongRow(
      result: result,
      inLibrary: inLibrary,
      item: item,
      square: true,
      tagLine: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.public_rounded, size: 14, color: cc.accentSoft),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l.genreMixTag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: cc.accentSoft),
            ),
          ),
        ],
      ),
      onTap: () => tapOnline(context, ref, result),
      onQueue: () => queueOnline(context, ref, result),
      onMore: () => showOnlineActions(context, ref, result),
      onDownload: () => ref.read(downloadsProvider.notifier).add(result),
    );
  }
}

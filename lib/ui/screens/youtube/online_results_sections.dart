import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../data/db/app_database.dart' show Track;
import '../../../providers/library_providers.dart' show searchTracksProvider;
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/smart_search_providers.dart' show ownedTracksProvider;
import '../../../providers/youtube_providers.dart';
import '../../../services/online/merge_results.dart';
import '../../../services/online/query_match.dart' show MediaKind;
import '../../../services/online/smart_search.dart';
import '../../../services/online/ytm_artist.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_blocks.dart';
import '../../widgets/track_actions.dart' show showOnlineActions;
import '../../theme/app_theme.dart' show trackRowExtentOf;
import '../../widgets/track_row.dart';
import '../library/library_results.dart' show SearchTracksScreen;
import '../online/online_selection_scope.dart';
import '../online/online_song_row.dart';

String sourceName(AppLocalizations l, MediaKind k) => switch (k) {
  MediaKind.ytmSong => l.searchSourceYoutubeMusic,
  MediaKind.ytVideo => l.searchSourceYoutube,
};

/// «Nella tua libreria» (D-399): up to three of the library's tracks for the
/// text, «Mostra tutti (N)» for the rest. A tap plays the local file.
class LibraryTracksSection extends ConsumerWidget {
  const LibraryTracksSection({super.key, required this.query, this.owned});

  final String query;

  /// The library tracks of the hidden online rows come first, even when the
  /// text search does not find them, so «N nascosti» never stands alone.
  final OwnedSplit? owned;

  static const _preview = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byText = ref.watch(searchTracksProvider(query)).value;
    final o = owned;
    final extra = o == null || o.matchIds.isEmpty
        ? const <Track>[]
        : ref.watch(ownedTracksProvider(o)).value ?? const <Track>[];
    final extraIds = {for (final t in extra) t.id};
    final tracks = [
      ...extra,
      for (final t in byText ?? const <Track>[])
        if (!extraIds.contains(t.id)) t,
    ];
    if (tracks.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    final compact = ref.watch(settingsProvider.select((s) => s.compactMode));
    final extent = trackRowExtentOf(context, compact);
    final ctrl = ref.read(playerControllerProvider);
    final shown = tracks.take(_preview).toList();
    return Column(
      key: const ValueKey('online-library'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          l.onlineInLibrary,
          // «Mostra tutti» opens the text search, so it counts that one.
          actionLabel: (byText?.length ?? 0) > _preview
              ? l.onlineShowAllCount(byText!.length)
              : null,
          onAction: () =>
              ShellNav.open<void>(context, SearchTracksScreen(text: query)),
        ),
        for (var i = 0; i < shown.length; i++)
          SizedBox(
            key: ValueKey('library-${shown[i].id}'),
            height: extent,
            child: LiveTrackRow(
              track: shown[i],
              compact: compact,
              // The queue is every match, as in the Library search.
              onTap: () => ctrl.playFromList(
                tracks,
                i,
                context: const PlayContext(PlayContextKind.search),
              ),
            ),
          ),
      ],
    );
  }
}

/// «N risultati già in libreria nascosti».
class OwnedHiddenNote extends StatelessWidget {
  const OwnedHiddenNote({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('online-owned-hidden'),
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        0,
        CcDims.margin,
        CcDims.gap8,
      ),
      child: Text(
        context.l10n.onlineOwnedHidden(count),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.cc.textMuted,
        ),
      ),
    );
  }
}

/// «Tutte, YouTube Music, YouTube»: a filter on the rows already there.
class SourceFilterChips extends StatelessWidget {
  const SourceFilterChips({
    super.key,
    required this.filter,
    required this.onPick,
  });

  final MediaKind? filter;
  final ValueChanged<MediaKind?> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
      child: SegmentedBlocks<MediaKind?>(
        compact: true,
        selected: filter,
        onChanged: onPick,
        items: [
          BlockItem(
            value: null,
            label: l.onlineFilterAll,
          ),
          BlockItem(
            value: MediaKind.ytmSong,
            label: sourceName(l, MediaKind.ytmSong),
          ),
          BlockItem(
            value: MediaKind.ytVideo,
            label: sourceName(l, MediaKind.ytVideo),
          ),
        ],
      ),
    );
  }
}

/// One line per source that gave nothing, above the list.
class SearchNotices extends StatelessWidget {
  const SearchNotices({super.key, required this.notices});

  final List<SearchNotice> notices;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: context.cc.textMuted);
    String text(SearchNotice n) {
      final source = sourceName(l, n.source);
      final other = sourceName(
        l,
        MediaKind.values.firstWhere((k) => k != n.source),
      );
      return switch (n.kind) {
        NoticeKind.rateLimited => l.onlineNoticeRateLimited(source, other),
        NoticeKind.offline => l.ytErrNetwork,
        NoticeKind.failed => l.onlineNoticeFailed(source, other),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final n in notices)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              0,
              CcDims.margin,
              6,
            ),
            child: Text(
              text(n),
              key: ValueKey('notice-${n.source.name}'),
              style: style,
            ),
          ),
      ],
    );
  }
}

/// «Altri risultati (N)»: opens the list of the less sure rows below it.
class OthersChip extends StatelessWidget {
  const OthersChip({
    super.key,
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, CcDims.gap8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          key: const ValueKey('others-chip'),
          avatar: Icon(
            open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
          ),
          label: Text(context.l10n.onlineOthersChip(count)),
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// «YouTube Music» or «YouTube» in a small tag (D-413), named for TalkBack as
/// «Da YouTube Music» inside the row's own label.
class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.kind});

  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final name = sourceName(l, kind);
    return Semantics(
      label: l.onlineFromSource(name),
      excludeSemantics: true,
      child: DecoratedBox(
        key: ValueKey('source-${kind.name}'),
        decoration: BoxDecoration(
          color: cc.surface2,
          borderRadius: BorderRadius.circular(CcDims.rList),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: kind == MediaKind.ytmSong ? cc.accentSoft : cc.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// A row of the online results: the song of the best source, a small label of
/// where it comes from and, when there is also a video of it, a tap to listen
/// to that. [index] is its place in the list picks refer to.
class SmartRow extends ConsumerWidget {
  const SmartRow({
    super.key,
    required this.row,
    required this.index,
    required this.selectionKey,
    required this.onArtistTap,
    required this.onListenVideo,
  });

  final SmartResult row;
  final int index;
  final String selectionKey;
  final void Function(YtmArtistRef artist)? onArtistTap;
  final VoidCallback onListenVideo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final r = row.primary;
    final pick = watchOnlinePick(ref, selectionKey, index);
    final ids = row.ids.toSet();
    final inLibrary = ref.watch(
      downloadIndexProvider.select(
        (i) =>
            ids.any((id) => i.value?.contains(id, source: r.source) ?? false),
      ),
    );
    final item = ref.watch(
      downloadsProvider.select(
        (d) => d.where((x) => ids.contains(x.result.id)).lastOrNull,
      ),
    );
    final who = r.artistIds.indexWhere((id) => id.isNotEmpty);
    final kind = row.sources.contains(MediaKind.ytmSong) ? MediaKind.ytmSong : MediaKind.ytVideo;
    final small = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: cc.textMuted);
    return OnlineSongRow(
      result: r,
      inLibrary: inLibrary,
      item: item,
      selecting: pick.selecting,
      selected: pick.selected,
      position: pick.position,
      onTap: pick.onTap ?? () => tapOnline(context, ref, r),
      onLongPress: pick.onLongPress,
      onQueue: () => queueOnline(context, ref, r),
      onMore: () => showOnlineActions(context, ref, r),
      onDownload: () => ref.read(downloadsProvider.notifier).add(r),
      onArtistTap: onArtistTap == null || who < 0 || who >= r.artists.length
          ? null
          : () => onArtistTap!(
              YtmArtistRef(id: r.artistIds[who], name: r.artists[who]),
            ),
      tagLine: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: SourceTag(kind: kind)),
          if (row.hasVideo && !pick.selecting) ...[
            Text(', ', style: small),
            Flexible(
              child: Tooltip(
                message: l.onlineListenVideo,
                child: InkWell(
                  key: ValueKey('listen-video-${r.id}'),
                  onTap: onListenVideo,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      l.onlineAlsoVideo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: small?.copyWith(
                        color: cc.accentSoft,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

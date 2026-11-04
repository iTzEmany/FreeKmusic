
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../core/constants.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/library_search.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/credits_providers.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/selection_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../search/search_screen.dart' show SearchTracksScreen;
import '../search/search_section_screen.dart';

/// Library results grouped by kind (Tracks, Albums, Artists, Playlists); moved
/// from Search (D-355).
/// Local results for [query]; [read] is `ref.watch` (build) or `ref.read` (submit).
LibrarySearchResults localResults(
  T Function<T>(ProviderListenable<T>) read,
  SearchQuery query,
) => searchLibrary(
  text: query.text,
  credited: read(searchCreditedProvider(query)).value ?? const <Track>[],
  quickFilter: query.quick,
  tracks: read(searchTracksProvider(query)).value ?? const <Track>[],
  artists: read(artistsProvider).value ?? const [],
  albums: read(albumsProvider).value ?? const [],
  playlists: read(playlistsProvider).value ?? const [],
  trackLimit: 5,
  sectionLimit: 3,
);

class LibraryResults extends ConsumerWidget {
  const LibraryResults({super.key, required this.query, required this.onOnline});

  final SearchQuery query;
  final VoidCallback onOnline;

  /// Header, up to three rows, and «Tutti» when more matched; nothing when none.
  List<Widget> _section(
    BuildContext context,
    SearchSectionKind kind,
    LibrarySearchResults res,
  ) {
    final l = context.l10n;
    final (shown, total) = searchSectionCount(kind, res);
    if (shown == 0) return const [];
    return [
      SectionHeader(
        searchSectionTitle(context, kind),
        actionLabel: total > shown ? l.showAll : null,
        onAction: () => ShellNav.open<void>(
          context,
          SearchSectionScreen(query: query, kind: kind),
        ),
      ),
      ...searchSectionRows(context, kind, res),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final text = query.text;
    final tracks =
        ref.watch(searchTracksProvider(query)).value ?? const <Track>[];
    final res = localResults(ref.watch, query);
    final ctrl = ref.read(playerControllerProvider);
    final compact = ref.watch(settingsProvider.select((s) => s.compactMode));
    final extent = trackRowExtentOf(context, compact);
    final key = SelectionKey.search.key;
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in res.tracks) t.id],
    );

    final results = ListView(
      children: [
        if (res.isEmpty)
          Padding(
            padding: const EdgeInsets.all(CcDims.margin),
            child: Text(
              l.searchEmptyLibrary,
              style: theme.bodyMedium?.copyWith(color: cc.textMuted),
            ),
          )
        else ...[
          if (res.tracks.isNotEmpty) ...[
            SectionHeader(
              l.tracks,
              actionLabel: res.trackTotal > res.tracks.length
                  ? l.showAll
                  : null,
              onAction: () => ShellNav.open<void>(
                context,
                SearchTracksScreen(query: query),
              ),
            ),
            for (var i = 0; i < res.tracks.length; i++)
              SizedBox(
                key: ValueKey(res.tracks[i].id),
                height: extent,
                child: LiveTrackRow(
                  track: res.tracks[i],
                  compact: compact,
                  selection: selection,
                  onTap: () => ctrl.playFromList(
                    tracks,
                    i,
                    context: const PlayContext(PlayContextKind.search),
                  ),
                ),
              ),
          ],
          for (final kind in SearchSectionKind.values)
            ..._section(context, kind, res),
          if (res.credited.isNotEmpty) ...[
            SectionHeader(l.creditsInCredits),
            for (var i = 0; i < res.credited.length; i++)
              SizedBox(
                key: ValueKey('credited-${res.credited[i].id}'),
                height: extent,
                child: LiveTrackRow(
                  track: res.credited[i],
                  compact: compact,
                  onTap: () => ctrl.playFromList(
                    res.credited,
                    i,
                    context: const PlayContext(PlayContextKind.search),
                  ),
                ),
              ),
          ],
        ],
        if (kEnableYoutube && text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              CcDims.gap16,
              CcDims.margin,
              CcDims.gap24,
            ),
            child: OutlinedButton.icon(
              onPressed: onOnline,
              icon: const Icon(Icons.smart_display_outlined),
              label: Text(
                l.searchOnline(text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
      ],
    );
    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: Column(
        children: [
          SelectionBarSlot(
            listKey: key,
            tracks: res.tracks,
            belowStatusBar: false,
          ),
          Expanded(child: results),
        ],
      ),
    );
  }
}

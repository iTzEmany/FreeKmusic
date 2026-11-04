import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../data/db/app_database.dart';
import '../../../data/repositories/home_sections.dart';
import '../../../data/repositories/library_queries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/history_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/artist_avatar.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/section_header.dart';
import '../library/album_detail_screen.dart';
import '../releases/top_artists_card.dart';
import '../stats/stats_screen.dart';
import 'home_row.dart';

/// Three-line lists at the bottom: the month, top artists, most played and
/// albums to rediscover. Each shows only when it has something to say.
class HomeBottomRows extends ConsumerWidget {
  const HomeBottomRows({super.key, this.wide = false});

  /// Desktop: the three blocks side by side instead of one under the other.
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final albums = ref.watch(albumsProvider).value ?? const <AlbumSummary>[];
    final top = ref.watch(topTracksProvider).value ?? const <Track>[];
    final ctrl = ref.read(playerControllerProvider);
    final rediscover = rediscoverAlbums(
      albums,
      DateTime.now(),
    ).take(3).toList();
    final month = [
      const _MonthBlock(),
      if (kEnableYoutube) const TopArtistsCard(),
    ];
    final topRows = [
      if (top.isNotEmpty) ...[
        SectionHeader(l.homeTopTracks),
        HomeBlock(
          children: [
            for (var i = 0; i < math.min(3, top.length); i++)
            HomeRow(
              cover: CoverImage(coverKey: top[i].coverKey, size: kHomeCover),
              title: top[i].title,
              subtitle: top[i].artist ?? l.unknownArtist,
              onTap: () => ctrl.playFromList(
                top,
                i,
                context: const PlayContext(PlayContextKind.library),
              ),
            ),
          ],
        ),
      ],
    ];
    final redo = [
      if (rediscover.isNotEmpty) ...[
        SectionHeader(l.homeRediscover),
        HomeBlock(
          children: [
            for (final a in rediscover)
            HomeRow(
              cover: CoverImage(coverKey: a.coverKey, size: kHomeCover),
              title: a.title ?? l.unknownAlbum,
              subtitle: a.variousArtists
                  ? l.variousArtists
                  : (a.artist ?? l.unknownArtist),
              onTap: () =>
                  ShellNav.open<void>(context, AlbumDetailScreen(album: a)),
            ),
          ],
        ),
      ],
    ];
    if (!wide) return Column(children: [...month, ...topRows, ...redo]);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, c) in [month, topRows, redo].indexed) ...[
          if (i > 0) const SizedBox(width: CcDims.gap32),
          Expanded(child: Column(children: c)),
        ],
      ],
    );
  }
}

/// «Il tuo mese», once there are ten listens; a tap anywhere opens the stats.
class _MonthBlock extends ConsumerWidget {
  const _MonthBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final today = DateTime.now();
    final plays = ref.watch(monthPlaysProvider).value ?? 0;
    if (plays < 10) return const SizedBox.shrink();
    final month = ref
        .watch(
          periodStatsProvider((year: false, y: today.year, m: today.month)),
        )
        .value;
    if (month == null || month.isEmpty) return const SizedBox.shrink();
    void open() => ShellNav.open<void>(context, const StatsScreen());
    return InkWell(
      onTap: open,
      child: Column(
        children: [
          SectionHeader(
            l.statsYourMonth,
            actionLabel: l.showAll,
            onAction: open,
          ),
          HomeBlock(
            children: [
              HomeRow(
                cover: const HomeIconCover(Icons.bar_chart_rounded),
                title: formatListened(l, month.playedMs),
                onTap: open,
              ),
              for (final a in month.topArtists.take(2))
                HomeRow(
                  cover: ArtistAvatar(
                    name: a.name,
                    size: kHomeCover,
                    coverKey: a.coverKey,
                  ),
                  title: a.name ?? l.unknownArtist,
                  subtitle: l.statsPlays(a.plays),
                  onTap: open,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

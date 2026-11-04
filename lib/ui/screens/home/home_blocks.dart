import '../../../providers/track_ops.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/repositories/home_sections.dart';
import '../../../data/repositories/track_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/memory_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/radio_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shuffle_button.dart';
import '../library/all_tracks_screen.dart';
import '../library/favorites_screen.dart';
import '../playlists/playlists_screen.dart';
import '../radio/radio_screen.dart';
import 'cover_fan.dart';
import '../../widgets/cc_app_bar.dart';

/// «Casuale su tutto»: Play for the whole library (random start if shuffle is
/// on) next to the three-state shuffle button, which only changes the mode.
class ShuffleHero extends ConsumerWidget {
  const ShuffleHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final totals = ref.watch(memoryTotalsProvider).value;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap8,
        CcDims.margin,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unbounded 28 on one line, shrunk rather than wrapped.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(l.homeShuffleAll, style: theme.displaySmall),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  totals == null
                      ? ''
                      : l.homeShuffleAllSub(
                          l.tracksCount(totals.trackCount),
                          l.hoursCount(totals.durationMs ~/ 3600000),
                        ),
                  style: theme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                button: true,
                label: l.play,
                excludeSemantics: true,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: cc.accent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _play(ref),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(Icons.play_arrow, color: cc.onAccent),
                      ),
                    ),
                  ),
                ),
              ),
              ShuffleModeButton(
                // What Play plays: the whole library, not the queue of before (D-137).
                listIds: () async => [
                  for (final t in await ref.read(trackOpsProvider).all()) t.id,
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _play(WidgetRef ref) async {
    final ctrl = ref.read(playerControllerProvider);
    try {
      // The whole library, not what the «Tutti i brani» search shows.
      final tracks = await ref.read(trackOpsProvider).all();
      if (tracks.isEmpty) return;
      await ctrl.playAll(
        tracks,
        context: const PlayContext(PlayContextKind.library),
      );
    } on Object catch (e, st) {
      AppLog.e('play everything failed', e, st);
    }
  }
}

/// Favourites, Playlist and Radio: three boxes, each with one spoken label.
class ShortcutsRow extends ConsumerWidget {
  const ShortcutsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    int count<T>(AsyncValue<List<T>> v) => v.value?.length ?? 0;
    Widget tile(IconData icon, String label, String sub, Widget page) =>
        Expanded(
          child: _Shortcut(
            icon: icon,
            label: label,
            sub: sub,
            onTap: () => ShellNav.open<void>(context, page),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap8,
        CcDims.margin,
        0,
      ),
      child: Row(
        spacing: CcDims.gap8,
        children: [
          tile(
            Icons.favorite_border,
            l.navFavorites,
            l.tracksCount(count(ref.watch(tracksProvider(true)))),
            const FavoritesScreen(),
          ),
          tile(
            Icons.queue_music,
            l.navPlaylists,
            l.playlistsCount(count(ref.watch(playlistsProvider))),
            Scaffold(
              appBar: CcAppBar(title: l.navPlaylists),
              body: const PlaylistsScreen(),
            ),
          ),
          tile(Icons.radio, l.radioTitle, switch (count(
            ref.watch(savedRadiosProvider),
          )) {
            0 => l.homeRadioLive,
            final n => l.radioLibrarySubtitle(n),
          }, const RadioScreen()),
        ],
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final cc = context.cc;
    return Semantics(
      button: true,
      label: '$label, $sub',
      excludeSemantics: true,
      child: Material(
        color: cc.surface1,
        borderRadius: BorderRadius.circular(CcDims.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 88),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(CcDims.gap12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: cc.accentSoft),
                const SizedBox(height: CcDims.gap4),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyLarge,
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Aggiunti da poco»: the fan (20 albums once open), and «Mostra tutti» for the full list by date.
class AddedLately extends ConsumerWidget {
  const AddedLately({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final albums = recentlyAddedAlbums(
      ref.watch(albumsProvider).value ?? const [],
      limit: 20,
    );
    if (albums.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SectionHeader(
          l.homeAddedLately,
          actionLabel: l.showAll,
          onAction: () {
            ref
                .read(trackQueryProvider(false).notifier)
                .update((q) => q.copyWith(sort: SortOption.addedAt, text: ''));
            ShellNav.open<void>(context, const AllTracksScreen());
          },
        ),
        CoverFan(albums: albums),
      ],
    );
  }
}

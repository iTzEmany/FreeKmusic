import 'package:flutter/material.dart';


import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/database_providers.dart';
import '../../providers/library_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/playlist_ops.dart';
import '../../providers/track_ops.dart';
import '../screens/library/favorites_screen.dart';
import '../screens/playlists/playlist_detail_screen.dart';
import '../screens/playlists/playlist_dialogs.dart';
import '../screens/smart/smart_playlist_editor.dart';
import '../theme/tokens.dart';
import '../widgets/new_playlist_menu.dart';
import '../widgets/playlist_cover.dart';
import '../widgets/track_drag.dart';
import 'shell_nav.dart';
import '../widgets/show_msg.dart';

/// Left column of the desktop layout: Home, Search, the library with the
/// pinned Favourites and every playlist, then Memoria. Icons only when narrow.
class DesktopSidebar extends ConsumerWidget {
  const DesktopSidebar({super.key, required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final index = ref.watch(navIndexProvider);
    final keys = ref.watch(tabNavigatorKeysProvider);
    void select(NavTab t) {
      // Leaving a tab resets it (D-392): only the active one has pages to pop.
      if (index == t.index) {
        ShellNav.popToRoot(keys[t.index].currentState);
      }
      if (index != t.index) ref.read(navIndexProvider.notifier).set(t.index);
    }

    Widget item(
      IconData icon,
      String label,
      bool selected,
      VoidCallback onTap, {
      Widget? trailing,
    }) => _SidebarItem(
      collapsed: collapsed,
      icon: icon,
      label: label,
      selected: selected,
      onTap: onTap,
      trailing: trailing,
    );

    return SizedBox(
      width: collapsed ? CcDims.sidebarCollapsedWidth : CcDims.sidebarWidth,
      child: Material(
        color: cc.bg,
        child: Column(
          children: [
            const SizedBox(height: 12),
            item(
              index == 0 ? Icons.home_rounded : Icons.home_outlined,
              l.navHome,
              index == NavTab.home.index,
              () => select(NavTab.home),
            ),
            if (kEnableYoutube)
              item(
                Icons.search_rounded,
                l.navSearch,
                index == NavTab.search.index,
                () => select(NavTab.search),
              ),
            const Divider(height: 16),
            item(
              index == NavTab.library.index
                  ? Icons.library_music_rounded
                  : Icons.library_music_outlined,
              l.yourLibrary,
              index == NavTab.library.index,
              () => select(NavTab.library),
              trailing: NewPlaylistMenu(
                onSmart: () => ShellNav.openInLibrary(
                  context,
                  ref,
                  const SmartPlaylistEditor(),
                ),
              ),
            ),
            Expanded(child: _SidebarPlaylists(collapsed: collapsed)),
            const Divider(height: 1),
            item(
              index == NavTab.memory.index
                  ? Icons.storage_rounded
                  : Icons.storage_outlined,
              l.navMemory,
              index == NavTab.memory.index,
              () => select(NavTab.memory),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _SidebarPlaylists extends ConsumerWidget {
  const _SidebarPlaylists({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final lists = ref.watch(playlistsProvider).value ?? const [];
    final favoriteCount = ref.watch(favoriteCountProvider).value ?? 0;
    void say(String text) => showMsg(context, text);

    Future<void> dropOnPlaylist(int id, String name, List<int> ids) async {
      final added = await ref.read(playlistOpsProvider).addTracks(id, ids);
      say(addedToPlaylistText(l, total: ids.length, added: added, name: name));
    }

    Future<void> dropOnFavorites(List<int> ids) async {
      say(l.favoritesAdded(await ref.read(trackOpsProvider).addFavorites(ids)));
    }

    Widget rowWithCover(
      Widget cover,
      String title,
      String subtitle,
      VoidCallback onTap, {
      required void Function(List<int> ids) onDrop,
    }) => _CoverRow(
      collapsed: collapsed,
      cover: cover,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      onDrop: onDrop,
    );

    return ListView(
      children: [
        rowWithCover(
          const PlaylistCover(size: 40, favorites: true),
          l.navFavorites,
          l.playlistCountLabel(favoriteCount),
          () => ShellNav.openInLibrary(context, ref, const FavoritesScreen()),
          onDrop: dropOnFavorites,
        ),
        for (final p in lists)
          rowWithCover(
            PlaylistCover(
              size: 40,
              coverKeys: playlistCoverKeys(p.playlist.coverKey, [
                p.autoCoverKey,
              ]),
            ),
            p.playlist.name,
            l.playlistCountLabel(p.trackCount),
            () => ShellNav.openInLibrary(
              context,
              ref,
              PlaylistDetailScreen(playlist: p.playlist),
            ),
            onDrop: (ids) =>
                dropOnPlaylist(p.playlist.id, p.playlist.name, ids),
          ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.collapsed,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final bool collapsed;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final color = selected ? cc.text : cc.textMuted;
    // Static accent dot at the icon's top right (a list, not a row of tabs).
    final glyph = Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (selected)
          Positioned(
            top: -1,
            right: -3,
            child: Container(
              key: const Key('sidebar-dot'),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: cc.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
    final child = collapsed
        ? Center(child: glyph)
        : Row(
            children: [
              const SizedBox(width: 16),
              glyph,
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: color),
                ),
              ),
              ?trailing,
            ],
          );
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(height: 48, child: child),
      ),
    );
  }
}

class _CoverRow extends StatelessWidget {
  const _CoverRow({
    required this.collapsed,
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.onDrop,
  });

  final bool collapsed;
  final Widget cover;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final void Function(List<int> ids) onDrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return TrackDropTarget(
      onDrop: onDrop,
      child: Tooltip(
        message: title,
        child: InkWell(
          onTap: onTap,
          // Grows with the text size: two lines at 150 % no longer fit in 56.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                SizedBox(width: collapsed ? 16 : 12),
                cover,
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyLarge,
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


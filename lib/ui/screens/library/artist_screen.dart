import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/library_queries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/selection_providers.dart';
import '../../../services/online/credit_roles.dart';
import '../../../providers/credits_providers.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/settings_providers.dart';
import '../../../core/constants.dart';
import '../../shell/shell_nav.dart';
import '../../theme/app_theme.dart';
import '../../../providers/cover_ops.dart';
import '../../widgets/album_card.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/cover_picker_sheet.dart';
import '../../widgets/artist_avatar.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/error_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/selection_bar.dart';
import '../../widgets/track_row.dart';
import '../../widgets/track_row_selection.dart';
import '../online/artist_picker_sheet.dart';
import '../releases/follow_button.dart';
import 'album_detail_screen.dart';
import '../../../providers/shuffle_plus_providers.dart' show listKeyOf;

/// An artist: Play / Shuffle over all their tracks, the five most played and
/// the albums (rows if few, grid if many).
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artist});

  final ArtistSummary artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final albums = ref.watch(artistAlbumsProvider(artist.key));
    final tracks = ref.watch(artistTracksProvider(artist.key));
    final compact = ref.watch(settingsProvider).compactMode;
    final ctrl = ref.read(playerControllerProvider);
    final name = artist.name ?? l.unknownArtist;
    final playCtx = PlayContext(PlayContextKind.artist, name);
    final list = tracks.value ?? const <Track>[];
    final albumList = albums.value ?? const <AlbumSummary>[];
    // Most present cover among the albums, for the avatar and the backdrop.
    final picked = ref.watch(artistImagesProvider.select((m) => m.value?[artist.key]));
    final coverKey =
        picked ??
        artist.coverKey ??
        albumList.map((a) => a.coverKey).whereType<String>().firstOrNull;
    final top = ([
      ...list.where((t) => t.playCount > 0),
    ]..sort((a, b) => b.playCount.compareTo(a.playCount))).take(5).toList();
    final extent = trackRowExtentOf(context, compact);
    final meta = collectionMeta(
      l,
      albums: albumList.length,
      tracks: list.length,
      durationMs: list.fold<int>(0, (sum, t) => sum + t.durationMs),
    );
    // The rows shown here are the most played ones.
    final key = SelectionKey.artistOf(artist.key);
    final selection = RowSelection(
      listKey: key,
      visibleIds: [for (final t in top) t.id],
    );
    // One key for the pill and Play: they must be the same list (D-534).
    final shuffleKey = listKeyOf([for (final t in list) t.id]);
    return SelectionScope(
      listKey: key,
      visibleIds: selection.visibleIds,
      child: CollectionScaffold(
        selectionBar: SelectionBarSlot(listKey: key, tracks: top),
        title: name,
        name: name,
        coverKey: coverKey,
        cover: (s) => ArtistAvatar(
          name: artist.name,
          size: s.clamp(0.0, 160.0),
          coverKey: coverKey,
        ),
        meta: meta,
        menu: _ArtistMenu(artist: artist, picked: picked != null),
        onPlay: list.isEmpty
            ? null
            : () => ctrl.playAll(
                list,
                context: playCtx,
                listKey: shuffleKey,
              ),
        shuffleIds: list.isEmpty ? null : [for (final t in list) t.id],
        shuffleKey: shuffleKey,
        slivers: [
          if (tracks.hasError || albums.hasError)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 240,
                child: LoadError(
                  tracks.error ?? albums.error!,
                  tracks.stackTrace ?? albums.stackTrace ?? StackTrace.current,
                  onRetry: () {
                    ref.invalidate(artistTracksProvider(artist.key));
                    ref.invalidate(artistAlbumsProvider(artist.key));
                  },
                ),
              ),
            ),
          if (top.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.mostPlayed)),
            SliverList.builder(
              itemCount: top.length,
              itemBuilder: (_, i) => SizedBox(
                height: extent,
                child: LiveTrackRow(
                  track: top[i],
                  compact: compact,
                  selection: selection,
                  albumAsSubtitle: true,
                  onTap: () => ctrl.playFromList(top, i, context: playCtx),
                ),
              ),
            ),
          ],
          if (albumList.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(l.albumsSection)),
            SliverToBoxAdapter(
              child: AlbumShelf(
                albums: albumList,
                onOpen: (a) =>
                    ShellNav.open<void>(context, AlbumDetailScreen(album: a)),
              ),
            ),
          ],
          if (artist.name != null)
            _CreditedSection(
              name: artist.name!,
              own: {for (final t in list) t.id},
              playCtx: playCtx,
            ),
        ],
      ),
    );
  }
}

/// «Compare come»: tracks where the artist is only credited, by role (never
/// the ones where they are the main artist).
class _CreditedSection extends ConsumerWidget {
  const _CreditedSection({
    required this.name,
    required this.own,
    required this.playCtx,
  });

  final String name;
  final Set<int> own;
  final PlayContext playCtx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final byRole = <String, List<Track>>{};
    for (final c in ref.watch(artistCreditedProvider(name)).value ?? const []) {
      if (!own.contains(c.track.id)) (byRole[c.role] ??= []).add(c.track);
    }
    if (byRole.isEmpty) return const SliverToBoxAdapter();
    final compact = ref.watch(settingsProvider).compactMode;
    final extent = trackRowExtentOf(context, compact);
    final ctrl = ref.read(playerControllerProvider);
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: SectionHeader(l.creditsAppearsAs)),
        for (final e in byRole.entries) ...[
          SliverToBoxAdapter(child: SectionHeader(creditRoleLabel(l, e.key))),
          SliverList.builder(
            itemCount: e.value.length,
            itemBuilder: (_, i) => SizedBox(
              height: extent,
              child: LiveTrackRow(
                track: e.value[i],
                compact: compact,
                albumAsSubtitle: true,
                onTap: () => ctrl.playFromList(e.value, i, context: playCtx),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

enum _ArtistAction { cover, restoreCover }

/// The image of the artist, picked as for albums and playlists (D-566), and the
/// YouTube Music buttons.
class _ArtistMenu extends ConsumerWidget {
  const _ArtistMenu({required this.artist, required this.picked});

  final ArtistSummary artist;
  final bool picked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (kEnableYoutube && artist.name != null) _YtmButtons(name: artist.name!),
        IconButton(
          key: const ValueKey('artist-more'),
          tooltip: l.moreActions,
          icon: const Icon(Icons.more_vert_rounded),
          onPressed: () async {
            final v = await showCcActionSheet<_ArtistAction>(
              context: context,
              title: artist.name ?? l.unknownArtist,
              groups: [
                [
                  CcAction(icon: Icons.image_outlined, label: l.coverChange, value: _ArtistAction.cover),
                  if (picked)
                    CcAction(icon: Icons.restore_rounded, label: l.artistImageRestore, value: _ArtistAction.restoreCover),
                ],
              ],
            );
            if (v == null || !context.mounted) return;
            switch (v) {
              case _ArtistAction.cover:
                showCoverPicker(context, save: (ops, bytes, mime) => ops.setArtistCover(artist.key, bytes, mime));
              case _ArtistAction.restoreCover:
                ref.read(coverOpsProvider).restoreArtistCover(artist.key);
            }
          },
        ),
      ],
    );
  }
}

class _YtmButtons extends ConsumerWidget {
  const _YtmButtons({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('artist-follow-ytm'),
          tooltip: l.followOnYtm,
          onPressed: () => followFromLibrary(context, ref, name),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          key: const ValueKey('artist-on-ytm'),
          tooltip: l.ytmOnYoutubeMusic,
          onPressed: () => openYtmArtist(
            context,
            ref,
            name,
            open: (page) => ShellNav.open<void>(context, page),
          ),
          icon: const Icon(Icons.smart_display_rounded),
        ),
      ],
    );
  }
}

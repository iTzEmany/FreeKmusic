import '../../../providers/follow_ops.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart' show ArtistLookup, FollowedArtist;
import '../../../data/repositories/follow_repository.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/releases_providers.dart';
import '../../../providers/ytm_catalog_providers.dart';
import '../../../services/online/ytm_artist.dart';
import '../../theme/tokens.dart';
import '../../shell/shell_nav.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/net_thumbnail.dart';
import '../online/artist_page_sections.dart' show thumbAt;
import '../online/artist_picker_sheet.dart' show ArtistPickerSheet;
import 'new_releases_screen.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';

/// The artists whose new releases are checked: followed by hand and the most
/// listened (automatic), each with its bell and «Non seguire più».
class FollowedArtistsScreen extends ConsumerWidget {
  const FollowedArtistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final followed = ref.watch(followedArtistsProvider);
    final pending =
        ref.watch(pendingArtistsProvider).value ?? const <ArtistLookup>[];
    final rows = followed.value ?? const <FollowedArtist>[];
    final followedIds = {for (final r in rows) r.ytmId};
    final toConfirm = [
      for (final p in pending)
        if (!followedIds.contains(p.ytmId)) p,
    ];
    return Scaffold(
      appBar: CcAppBar(
        title: l.releasesFollowedTitle(rows.length),
        actions: [
          // The page is also the way to «Controlla ora» when the shelf is hidden.
          IconButton(
            key: const ValueKey('open-new-releases'),
            tooltip: l.newReleasesTitle,
            onPressed: () =>
                ShellNav.open<void>(context, const NewReleasesScreen()),
            icon: const Icon(Icons.new_releases_outlined),
          ),
        ],
      ),
      body: !followed.hasValue
          ? const LinearProgressIndicator(minHeight: 2)
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: rows.isEmpty && toConfirm.isEmpty
                    ? EmptyState(
                        icon: Icons.notifications_none_rounded,
                        message: l.followedEmpty,
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero.withDock(context),
                        itemCount: toConfirm.length + rows.length,
                        itemBuilder: (_, i) => i < toConfirm.length
                            ? _PendingRow(lookup: toConfirm[i])
                            : _FollowedRow(artist: rows[i - toConfirm.length]),
                      ),
              ),
            ),
    );
  }
}

class _FollowedRow extends ConsumerWidget {
  const _FollowedRow({required this.artist});

  final FollowedArtist artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final ops = ref.read(followOpsProvider);
    final subtitle = artist.notFound
        ? l.followedNotFound
        : artist.isAuto
        ? l.followedTopListened
        : null;
    return ListTile(
      key: ValueKey('followed-${artist.ytmId}'),
      leading: NetThumbnail(
        url: thumbAt(context, artist.thumbUrl, 48),
        width: 48,
        height: 48,
        icon: Icons.person_rounded,
        circle: true,
      ),
      title: Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: TextStyle(
                color: artist.notFound ? cc.error : cc.textMuted,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (artist.notFound)
            TextButton(
              key: ValueKey('retry-${artist.ytmId}'),
              onPressed: () => ops.retry(artist.ytmId),
              child: Text(l.followedRetry),
            ),
          IconButton(
            key: ValueKey('mute-${artist.ytmId}'),
            tooltip: artist.muted ? l.followUnmute : l.followMute,
            onPressed: () => ops.setMuted(artist.ytmId, !artist.muted),
            icon: Icon(
              artist.muted
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_none_rounded,
            ),
          ),
          IconButton(
            key: ValueKey('unfollow-${artist.ytmId}'),
            tooltip: l.followStop,
            onPressed: () async {
              final ok = await showConfirm(
                context,
                title: l.followStopTitle(artist.name),
                body: l.followStopBody,
                confirmLabel: l.followStop,
                destructive: true,
              );
              if (ok) await ops.unfollow(artist.ytmId);
            },
            icon: const Icon(Icons.person_remove_outlined),
          ),
        ],
      ),
    );
  }
}

/// A most-listened name with several matching artists: the user picks one.
class _PendingRow extends ConsumerWidget {
  const _PendingRow({required this.lookup});

  final ArtistLookup lookup;

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final List<YtmArtistRef> found;
    try {
      found = await ref
          .read(ytmCatalogProvider)
          .searchArtists(lookup.name, ref.read(ytmLanguageProvider));
    } on Object catch (e) {
      AppLog.w('artist lookup failed ($e)');
      if (!context.mounted) return;
      showMsg(context, l.loadFailed);
      return;
    }
    if (!context.mounted || found.isEmpty) return;
    final chosen = await showCcSheet<YtmArtistRef>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ArtistPickerSheet(artists: found.take(5).toList()),
    );
    if (chosen == null) return;
    await ref.read(followOpsProvider).followPicked(lookup.artistKey, lookup.name, chosen);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    return ListTile(
      key: ValueKey('pending-${lookup.artistKey}'),
      leading: const CircleAvatar(child: Icon(Icons.help_outline_rounded)),
      title: Text(lookup.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(l.followedToConfirm, style: TextStyle(color: cc.accent)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => unawaited(_pick(context, ref)),
    );
  }
}

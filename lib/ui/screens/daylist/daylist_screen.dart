import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/daylist_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/online_queue_row.dart' show SuggestedMarker;
import '../../widgets/play_buttons.dart';
import '../../widgets/playlist_cover.dart';
import '../settings/settings_screen.dart';
import 'daylist_labels.dart';

/// The daylist of the current slot: title, genres, Play and Shuffle, when it
/// changes next, and the songs (suggested ones marked as elsewhere).
class DaylistScreen extends ConsumerWidget {
  const DaylistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final d = ref.watch(daylistProvider).value;
    final actions = ref.read(daylistActionsProvider);
    return Scaffold(
      appBar: CcAppBar(
        title: l.daylistTitle,
        actions: [
          IconButton(
            tooltip: l.daylistSettingsOpen,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => ShellNav.open<void>(
              context,
              Scaffold(
                appBar: CcAppBar(title: l.settingsPageDaylist),
                body: const SettingsPageView(SettingsPage.daylist),
              ),
            ),
          ),
        ],
      ),
      body: d == null || d.result.tooFew
          ? Center(child: Text(l.daylistEmpty, style: text.bodyLarge?.copyWith(color: cc.textMuted)))
          : ListView(
              padding: const EdgeInsets.only(bottom: CcDims.gap24).withDock(context),
              children: [
                _header(context, d),
                if (d.result.genres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap12, CcDims.margin, 0),
                    child: Semantics(
                      label: l.daylistGenres,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final g in d.result.genres)
                            Chip(label: Text(g), visualDensity: VisualDensity.compact),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap12, CcDims.margin, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PlayPill(onPressed: () => actions.play()),
                      OutlinedButton.icon(
                        onPressed: () => actions.play(shuffle: true),
                        icon: const Icon(Icons.shuffle_rounded),
                        label: Text(l.shuffle),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap12, CcDims.margin, CcDims.gap8),
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 20, color: cc.accentSoft),
                      const SizedBox(width: CcDims.gap8),
                      Expanded(
                        child: Text(
                          l.daylistUpdates(
                            daylistSlotName(l, (d.slotIndex + 1) % 8),
                            daylistHour(d.nextChange.hour),
                          ),
                          style: text.bodySmall?.copyWith(color: cc.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final item in d.result.items)
                  item.track != null ? _OwnRow(item.track!.title, item.track!.artist, item.track!.coverKey, () => actions.play())
                      : _SuggestedRow(item.suggestion!.result.title, item.suggestion!.result.artists.join(', '), item.suggestion!.result.thumbnailUrl, () => actions.play()),
              ],
            ),
    );
  }

  Widget _header(BuildContext context, DaylistState d) {
    final l = context.l10n;
    final cc = context.cc;
    final text = Theme.of(context).textTheme;
    final r = d.result;
    final sug = r.items.where((i) => i.suggestion != null).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PlaylistCover(
            size: 112,
            radius: CcDims.rCard,
            coverKeys: playlistCoverKeys(null, [for (final i in r.items) i.track?.coverKey]),
          ),
          const SizedBox(width: CcDims.gap16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(daylistName(l, d.slotIndex, r.genres), style: text.titleLarge),
                const SizedBox(height: 6),
                Text(
                  l.tracksCount(r.items.length),
                  style: text.bodySmall?.copyWith(color: cc.textMuted),
                ),
                if (sug > 0)
                  Text(
                    l.daylistSuggestedCount(sug),
                    style: text.bodySmall?.copyWith(color: cc.textMuted),
                  ),
                // D-473: fewer than 50 songs says so under the title.
                if (r.isShort)
                  Text(
                    l.daylistShortNote(r.items.length),
                    style: text.bodySmall?.copyWith(color: cc.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnRow extends StatelessWidget {
  const _OwnRow(this.title, this.artist, this.coverKey, this.onPlay);

  final String title;
  final String? artist;
  final String? coverKey;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => _row(
    context,
    CoverImage(coverKey: coverKey, size: 48),
    title,
    Text(artist ?? context.l10n.unknownArtist, maxLines: 1, overflow: TextOverflow.ellipsis),
    onPlay,
  );
}

class _SuggestedRow extends StatelessWidget {
  const _SuggestedRow(this.title, this.artist, this.thumb, this.onPlay);

  final String title, artist;
  final String? thumb;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => _row(
    context,
    NetThumbnail(url: thumb, width: 48, height: 48, icon: Icons.music_note_rounded),
    title,
    Row(
      children: [
        const SuggestedMarker(),
        if (artist.isNotEmpty) ...[
          const Text(', '),
          Flexible(child: Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ],
    ),
    onPlay,
  );
}

Widget _row(BuildContext context, Widget cover, String title, Widget sub, VoidCallback onTap) {
  final text = Theme.of(context).textTheme;
  final cc = context.cc;
  return MergeSemantics(
    child: Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin, vertical: 6),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(CcDims.rList), child: cover),
              const SizedBox(width: CcDims.gap12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
                    DefaultTextStyle.merge(style: text.bodySmall?.copyWith(color: cc.textMuted), child: sub),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

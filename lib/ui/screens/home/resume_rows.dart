import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../data/repositories/home_sections.dart';
import '../../../data/repositories/radio_repository.dart';
import '../../../data/repositories/track_kinds.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/daylist_providers.dart';
import '../../../providers/player_providers.dart';
import '../../../providers/resume_providers.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/section_header.dart';
import '../library/album_detail_screen.dart';
import '../now_playing/now_playing_screen.dart' show playContextName;
import '../playlists/playlist_detail_screen.dart';
import 'home_row.dart';

/// Width of the block from which the grid has 3 columns instead of 2.
const _threeColumnsWidth = 560.0;

/// «Riprendi»: a grid with the latest item of each area (2 columns, 3 when the
/// block is at least [_threeColumnsWidth] wide). Hidden when empty.
class ResumeList extends ConsumerWidget {
  const ResumeList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(resumeItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final source = ref.watch(playContextProvider);
    final playing = ref.watch(isPlayingProvider).value ?? false;
    final ctrl = ref.read(playerControllerProvider);
    // What the queue plays now: a tap pauses/resumes it, never restarts it.
    final nowTap = playing ? null : ctrl.togglePlayPause;

    Widget tile(ResumeItem r) {
      final t = r.track, e = r.entry;
      final (icon, areaLabel) = switch (r.area) {
        ResumeArea.track => (Icons.music_note_rounded, l.resumeAreaTrack),
        ResumeArea.podcast => (Icons.podcasts_rounded, l.podcastsTitle),
        ResumeArea.album => (Icons.album_rounded, l.albums),
        ResumeArea.playlist => (Icons.queue_music, l.navPlaylists),
        ResumeArea.radio => (Icons.radio, l.radioTitle),
        ResumeArea.daylist => (Icons.auto_awesome, l.daylistTitle),
      };
      final title = switch (r.area) {
        ResumeArea.track || ResumeArea.podcast => t!.title,
        ResumeArea.album => e!.title ?? l.unknownAlbum,
        ResumeArea.playlist => e!.title ?? l.navPlaylists,
        ResumeArea.radio => r.radio!.name,
        ResumeArea.daylist => l.daylistTitle,
      };
      final subtitle = switch (r.area) {
        _ when r.queueIndex != null => _queueSubtitle(context, r, source),
        ResumeArea.track || ResumeArea.podcast =>
          t!.resumePositionMs != null
              ? _trackSubtitle(context, t)
              : (t.artist ?? l.unknownArtist),
        ResumeArea.album =>
          e!.variousArtists ? l.variousArtists : (e.artist ?? l.unknownArtist),
        ResumeArea.playlist => l.tracksCount(e!.count),
        ResumeArea.radio || ResumeArea.daylist => areaLabel,
      };
      return _ResumeTile(
        key: ValueKey('resume-${r.area.name}'),
        icon: icon,
        areaLabel: areaLabel,
        title: title,
        subtitle: subtitle,
        now: r.queueIndex != null,
        progress: t == null
            ? null
            : _fraction(t.resumePositionMs, t.durationMs),
        onTap: switch (r.area) {
          ResumeArea.track || ResumeArea.podcast =>
            r.queueIndex != null ? nowTap : () => ctrl.playFromList([t!], 0),
          ResumeArea.album => () => ShellNav.open<void>(
            context,
            AlbumDetailScreen(album: e!.album!),
          ),
          ResumeArea.playlist =>
            () => e!.playlist == null
                ? null
                : ShellNav.open<void>(
                    context,
                    PlaylistDetailScreen(playlist: e.playlist!.playlist),
                  ),
          ResumeArea.radio => () => ctrl.playStations(
            [r.radio!.toStation()],
            0,
            context: PlayContext(PlayContextKind.radio, r.radio!.name),
          ),
          ResumeArea.daylist =>
            r.queueIndex != null
                ? nowTap
                : () => ref.read(daylistActionsProvider).play(),
        },
      );
    }

    return HomeBlock(
      header: SectionHeader(l.homeResume),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.gap12,
            0,
            CcDims.gap12,
            CcDims.gap12,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              // The columns follow the block, not the window (a side panel narrows it).
              final columns = box.maxWidth >= _threeColumnsWidth ? 3 : 2;
              final w = (box.maxWidth - (columns - 1) * CcDims.gap8) / columns;
              return Wrap(
                spacing: CcDims.gap8,
                runSpacing: CcDims.gap8,
                children: [
                  for (final r in items) SizedBox(width: w, child: tile(r)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  String _queueSubtitle(
    BuildContext context,
    ResumeItem r,
    PlayContext? source,
  ) {
    final l = context.l10n;
    final from = playContextName(l, source);
    final n = r.queueIndex! + 1, m = r.queueLength!;
    return from == null
        ? l.homeResumeQueue(n, m)
        : l.homeResumeQueueFrom(from, n, m);
  }

  /// An episode names its podcast (the artist column) and where it was left.
  String _trackSubtitle(BuildContext context, Track t) {
    final l = context.l10n;
    if (t.kind != kEpisodeKind) return l.homeMinutesLeft(_minutesLeft(t));
    return [
      if (t.artist != null) t.artist!,
      l.resumeFrom(formatDuration(t.resumePositionMs ?? 0)),
      l.homeEpisodeLeft(_minutesLeft(t)),
    ].join(', ');
  }

  int _minutesLeft(Track t) {
    final left = t.durationMs - (t.resumePositionMs ?? 0);
    return (left / 60000).ceil().clamp(1, 1 << 30);
  }

  double _fraction(int? position, int? duration) =>
      duration == null || duration <= 0 || position == null
      ? 0
      : (position / duration).clamp(0.0, 1.0);
}

/// A tile of the grid: [CcColors.surface2], radius 12, the area's icon, two
/// lines; at least 48 dp tall. [now] marks what the queue plays.
class _ResumeTile extends StatelessWidget {
  const _ResumeTile({
    super.key,
    required this.icon,
    required this.areaLabel,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.now = false,
    this.progress,
  });

  final IconData icon;
  final String areaLabel, title, subtitle;
  final bool now;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: onTap != null,
      label: '$areaLabel, $title, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: cc.surface2,
        borderRadius: BorderRadius.circular(CcDims.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(CcDims.gap12),
                  child: Row(
                    children: [
                      Icon(icon, color: cc.accentSoft),
                      const SizedBox(width: CcDims.gap12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodyLarge?.copyWith(
                                color: now ? cc.accentSoft : null,
                              ),
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
                  ),
                ),
                if (progress != null && progress! > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: cc.surface3,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

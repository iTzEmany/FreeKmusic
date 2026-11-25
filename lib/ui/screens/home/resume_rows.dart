import 'dart:math' as math;

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
import '../../widgets/cover_image.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/marquee_text.dart';
import '../../widgets/playlist_cover.dart';
import '../../widgets/radio_art.dart';
import '../../widgets/section_header.dart';
import '../library/album_detail_screen.dart';
import '../now_playing/now_playing_screen.dart' show playContextName;
import '../playlists/playlist_detail_screen.dart';
import 'home_row.dart';

/// «Riprendi»: the latest thing played big in the middle, the others on an open arc
/// around it (D-725, F-21). Hidden when empty; with few items the arc has fewer slots.
class ResumeList extends ConsumerWidget {
  const ResumeList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final items = ref.watch(resumeItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();
    final source = ref.watch(playContextProvider);
    final ctrl = ref.read(playerControllerProvider);
    // What the queue plays now: a tap pauses/resumes it, never restarts it. The ring does
    // not watch the play state (it would rebuild at every play/pause).
    final nowTap = ctrl.togglePlayPause;

    _Slot slot(ResumeItem r, String key) {
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
        ResumeArea.album => _orElse(e!.title, l.unknownAlbum),
        ResumeArea.playlist => _orElse(e!.title, l.navPlaylists),
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
      return _Slot(
        key: key,
        radio: r.area == ResumeArea.radio,
        areaLabel: areaLabel,
        title: title,
        subtitle: subtitle,
        cover: (size, radius) => switch (r.area) {
          ResumeArea.track || ResumeArea.podcast => CoverImage(
            coverKey: t!.coverKey,
            size: size,
            radius: radius,
          ),
          ResumeArea.album => CoverImage(
            coverKey: e!.coverKey,
            size: size,
            radius: radius,
          ),
          ResumeArea.playlist => PlaylistCover(
            size: size,
            radius: radius,
            coverKeys: playlistCoverKeys(
              e!.playlist?.playlist.coverKey,
              e.coverKeys,
            ),
          ),
          ResumeArea.radio => RadioArt(
            station: r.radio!.toStation(),
            size: size,
            circle: true,
          ),
          ResumeArea.daylist => _IconCover(
            icon: icon,
            size: size,
            radius: radius,
          ),
        },
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

    final seen = <ResumeArea, int>{};
    final slots = [
      for (final r in items)
        slot(
          r,
          'resume-${r.area.name}${seen.update(r.area, (n) => n + 1, ifAbsent: () => 0) == 0 ? '' : '-${seen[r.area]}'}',
        ),
    ];
    final core = slots.first;
    final ring = slots.skip(1).toList();
    final text = Theme.of(context).textTheme;
    // The ring items name themselves below the cover: room for one line at this text scale.
    final labelH = MediaQuery.textScalerOf(context).scale(_labelLine);
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
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: _ringW,
                child: Column(
                  children: [
                    SizedBox(
                      width: _ringW,
                      height: ring.isEmpty ? _coreSize + 12 : _ringH + labelH,
                      child: Stack(
                        children: [
                          for (var i = 0; i < ring.length; i++)
                            _ringItem(ring[i], i, ring.length),
                          Positioned(
                            left: (_ringW - _coreSize) / 2,
                            top: ring.isEmpty ? 6 : _cy - _coreSize / 2,
                            child: _core(context, core, l.homeResume),
                          ),
                        ],
                      ),
                    ),
                    // The middle cover already speaks for it: the button is for the eyes.
                    ExcludeSemantics(
                      child: FilledButton.icon(
                        onPressed: core.onTap,
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        label: Text(l.homeResume),
                      ),
                    ),
                    const SizedBox(height: CcDims.gap8),
                    Text(
                      core.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge,
                    ),
                    Text(
                      core.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The others sit on the open arc, from the lower left over the top to the lower right.
  Widget _ringItem(_Slot s, int i, int n) {
    final step = n == 1 ? 0.0 : math.min(52.0, 260.0 / (n - 1));
    final a = (i - (n - 1) / 2) * step * math.pi / 180;
    return Positioned(
      left: _ringW / 2 + _r * math.sin(a) - _itemSize / 2,
      top: _cy - _r * math.cos(a) - _itemSize / 2,
      child: _SlotButton(
        slot: s,
        size: _itemSize,
        radius: s.radio ? _itemSize / 2 : CcDims.rList,
        named: true,
      ),
    );
  }

  Widget _core(BuildContext context, _Slot s, String lead) => Stack(
    alignment: Alignment.center,
    children: [
      if (s.progress != null && s.progress! > 0)
        SizedBox(
          width: _coreSize + 8,
          height: _coreSize + 8,
          child: CircularProgressIndicator(
            value: s.progress,
            strokeWidth: 3,
            backgroundColor: context.cc.surface3,
          ),
        ),
      _SlotButton(
        slot: s,
        size: _coreSize,
        radius: s.radio ? _coreSize / 2 : CcDims.rCard,
        lead: lead,
      ),
    ],
  );

  /// A blank title (empty tag or name) reads as the fallback too, not only null.
  String _orElse(String? title, String fallback) =>
      title == null || title.trim().isEmpty ? fallback : title;

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

const _ringW = 328.0, _ringH = 250.0, _cy = 140.0, _r = 108.0;
const _coreSize = 96.0, _itemSize = 56.0, _labelLine = 18.0;

/// What one item of the ring needs: its texts, cover and tap.
class _Slot {
  const _Slot({
    required this.key,
    required this.areaLabel,
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onTap,
    this.progress,
    this.radio = false,
  });

  final bool radio;
  final String key, areaLabel, title, subtitle;
  final Widget Function(double size, double radius) cover;
  final VoidCallback? onTap;
  final double? progress;
}

/// A cover that taps: at least 48 dp, read by screen readers as «lead, area, title, detail».
class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.slot,
    required this.size,
    required this.radius,
    this.lead,
    this.named = false,
  });

  final _Slot slot;
  final double size, radius;
  final String? lead;

  /// Shows the title as a scrolling line under the cover (the core has its own below).
  final bool named;

  @override
  Widget build(BuildContext context) {
    final button = Semantics(
      key: ValueKey(slot.key),
      container: true,
      button: slot.onTap != null,
      label:
          '${lead == null ? '' : '$lead, '}${slot.areaLabel}, ${slot.title}, ${slot.subtitle}',
      excludeSemantics: true,
      onTap: slot.onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: slot.onTap,
            child: slot.cover(size, radius),
          ),
        ),
      ),
    );
    if (!named) return button;
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          button,
          // The Semantics above is the only reading of the title.
          ExcludeSemantics(
            child: Center(
              child: MarqueeText(
                slot.title,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: context.cc.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The daylist has no cover of its own: its icon on a plain tile.
class _IconCover extends StatelessWidget {
  const _IconCover({
    required this.icon,
    required this.size,
    required this.radius,
  });

  final IconData icon;
  final double size, radius;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cc.surface2,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: cc.accentSoft, size: size / 2),
    );
  }
}

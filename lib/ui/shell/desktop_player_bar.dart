import '../widgets/track_kind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/jam_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/player_providers.dart';
import '../../providers/track_ops.dart' show trackOpsProvider;
import '../../services/audio/play_queue.dart';
import '../../services/jam/jam_models.dart';
import '../screens/devices/devices_sheet.dart';
import '../screens/jam/jam_screen.dart';
import '../screens/jam/speaker_notices.dart';
import '../screens/now_playing/now_playing_screen.dart';
import '../theme/tokens.dart';
import '../widgets/artist_links.dart';
import '../widgets/empty_player.dart';
import '../widgets/quality_tag.dart';
import '../widgets/speed_button.dart';
import '../widgets/favorite_actions.dart';
import '../widgets/focus_ring_button.dart';
import '../widgets/format_utils.dart';
import '../widgets/mini_player.dart' show kBarCoverHero;
import '../widgets/play_buttons.dart';
import '../widgets/motion.dart';
import '../widgets/track_art.dart';
import '../widgets/radio_now.dart';
import '../widgets/ring_progress.dart';
import '../widgets/seek_bar.dart';
import '../widgets/smooth_position.dart';
import '../../providers/radio_providers.dart' show onAirProvider;
import '../widgets/shuffle_button.dart';

/// The 80 px player of the desktop layout (replaces the mini-player).
class DesktopPlayerBar extends ConsumerWidget {
  const DesktopPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final jam = ref.watch(jamProvider);
    final track =
        ref.watch(liveCurrentTrackProvider).value ??
        ref.watch(currentTrackProvider).value;
    final inJam = jam.active;
    return Material(
      color: cc.surface1,
      child: Container(
        height: CcDims.desktopPlayerBarHeight,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cc.surface3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: inJam
                  ? _JamInfo(state: jam)
                  : (track == null
                        ? const _EmptyInfo()
                        : _TrackInfo(track: track)),
            ),
            Expanded(
              flex: 4,
              child: inJam
                  ? const _JamControls()
                  : _Center(
                      track: track,
                      live: track != null && radioOfTrack(ref, track) != null,
                    ),
            ),
            const Expanded(flex: 3, child: _Right()),
          ],
        ),
      ),
    );
  }
}

/// Nothing plays (D-364): the bar keeps its place, with the last queue named.
class _EmptyInfo extends ConsumerWidget {
  const _EmptyInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final subtitle = emptyPlayerSubtitle(context, ref.watch(lastQueueProvider).value);
    return Semantics(
      liveRegion: true,
      container: true,
      label: '${l.playerEmptyTitle}. $subtitle',
      excludeSemantics: true,
      child: Row(
        children: [
          const EmptyPlayerDisc(size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.playerEmptyTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyLarge?.copyWith(color: cc.textMuted),
                ),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackInfo extends ConsumerWidget {
  const _TrackInfo({required this.track});

  final Track track;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final radio = radioOfTrack(ref, track);
    final onAir = radio == null ? null : ref.watch(onAirProvider).value;
    final texts = radio == null ? null : radioTexts(l, radio, onAir);
    return Row(
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Semantics(
            button: true,
            label: l.nowPlaying,
            excludeSemantics: true,
            child: FocusRingButton(
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NowPlayingScreen(),
                ),
              ),
              child: RingProgress(
                size: 56,
                live: radio != null,
                child: TrackArt(
                  track: track,
                  size: RingProgress.innerSize(56),
                  radius: RingProgress.innerSize(56) / 2,
                  heroTag: kBarCoverHero,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                texts?.title ?? track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyLarge,
              ),
              if (radio == null)
                ArtistLinks(track, style: theme.bodyMedium, minHeight: 0)
              else
                Text(
                  texts!.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium,
                ),
            ],
          ),
        ),
        if (radio != null)
          RadioStarButton(station: radio, color: cc.textMuted)
        else if (track.trackKind != TrackKind.online)
          IconButton(
            tooltip: track.isFavorite ? l.removeFromFavorites : l.favorite,
            onPressed: () => toggleFavorite(context, ref, track),
            icon: HeartIcon(
              favorite: track.isFavorite,
              color: track.isFavorite ? cc.accent : cc.textMuted,
            ),
          ),
      ],
    );
  }
}

class _JamInfo extends StatelessWidget {
  const _JamInfo({required this.state});

  final JamUiState state;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final cur = state.jam?.current;
    return InkWell(
      onTap: () => Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => const JamScreen())),
      child: Row(
        children: [
          RingProgress(
            size: 56,
            live: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cc.surface3,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.queue_music_rounded, color: cc.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cur?.title ?? l.jamNothingPlaying,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyLarge,
                ),
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: cc.accent),
                    const SizedBox(width: 6),
                    Text(
                      l.jamPeople(state.jam?.participants.length ?? 1),
                      style: theme.bodyMedium,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JamControls extends ConsumerWidget {
  const _JamControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(jamProvider);
    final playing = s.jam?.playing ?? false;
    final ctrl = ref.read(jamProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PlayCircleButton(
          size: 40,
          playing: playing,
          onPressed: s.jam?.current == null
              ? null
              : () => sendJamCommand(
                  context,
                  ctrl,
                  playing ? const JamCommand.pause() : const JamCommand.play(),
                ),
        ),
        if (s.isHost)
          IconButton(
            tooltip: l.nextTrack,
            icon: const Icon(Icons.skip_next_rounded),
            onPressed: () =>
                sendJamCommand(context, ctrl, const JamCommand.next()),
          ),
      ],
    );
  }
}

/// Transport buttons and the seek line.
class _Center extends ConsumerWidget {
  const _Center({required this.track, this.live = false});

  final Track? track;

  /// A radio: no shuffle, repeat or seek line, a «In diretta» mark instead.
  final bool live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final ctrl = ref.read(playerControllerProvider);
    final playing = ref.watch(isPlayingProvider).value ?? false;
    final repeat = ref.watch(repeatProvider).value ?? PlayRepeat.off;
    final hasTrack = track != null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!live) const ShuffleModeButton(size: 20, dot: false),
              IconButton(
                tooltip: l.previousTrack,
                onPressed: hasTrack ? ctrl.previous : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              PlayCircleButton(
                size: 36,
                playing: playing,
                tooltip: hasTrack
                    ? null
                    : emptyPlayerAction(l, ref.watch(lastQueueProvider).value),
                onPressed: hasTrack ? ctrl.togglePlayPause : ref.read(trackOpsProvider).playWhenEmpty,
              ),
              IconButton(
                tooltip: l.nextTrack,
                onPressed: hasTrack ? ctrl.next : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
              if (!live)
                IconButton(
                  tooltip: l.repeat,
                  iconSize: 20,
                  onPressed: ctrl.cycleRepeat,
                  icon: Icon(
                    repeat == PlayRepeat.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    color: repeat == PlayRepeat.off ? cc.textMuted : cc.accent,
                  ),
                ),
            ],
          ),
        ),
        if (live)
          Text(
            l.radioLive,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: cc.accent),
          )
        else
          _BarSeek(track: track),
      ],
    );
  }
}

class _BarSeek extends ConsumerStatefulWidget {
  const _BarSeek({required this.track});

  final Track? track;

  @override
  ConsumerState<_BarSeek> createState() => _BarSeekState();
}

class _BarSeekState extends ConsumerState<_BarSeek> {
  final _smooth = SmoothPosition();

  @override
  void initState() {
    super.initState();
    _smooth.followPlayer(ref);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _smooth.bindTickerMode(context);
  }

  @override
  void dispose() {
    _smooth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: cc.textMuted);
    final dur = ref.watch(durationProvider).value ?? Duration.zero;

    // Equal side slots keep the slider centred.
    Widget slot(Widget? child) => SizedBox(
      width: 56,
      child: Center(child: child == null ? null : FittedBox(child: child)),
    );
    return Row(
      children: [
        slot(widget.track == null ? null : QualityTag(widget.track!)),
        SizedBox(
          width: 44,
          child: Align(
            alignment: Alignment.centerRight,
            child: SeekTime(position: _smooth, duration: dur, style: style),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 20,
            child: SeekBar(
              position: _smooth,
              duration: dur,
              onSeek: (d) => ref.read(playerControllerProvider).seek(d),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(formatDuration(dur.inMilliseconds), style: style),
        ),
        slot(const SpeedButton()),
      ],
    );
  }
}

/// Lyrics, queue, devices, mute and volume.
class _Right extends ConsumerWidget {
  const _Right();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final panel = ref.watch(sidePanelProvider);
    final panelCtl = ref.read(sidePanelProvider.notifier);
    final vol = ref.watch(volumeProvider);
    final volCtl = ref.read(volumeProvider.notifier);
    Color on(SidePanel p) => panel == p ? cc.accent : cc.textMuted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: l.lyrics,
          icon: Icon(Icons.lyrics_outlined, color: on(SidePanel.lyrics)),
          onPressed: () => panelCtl.toggle(SidePanel.lyrics),
        ),
        IconButton(
          tooltip: l.queue,
          icon: Icon(Icons.queue_music_rounded, color: on(SidePanel.queue)),
          onPressed: () => panelCtl.toggle(SidePanel.queue),
        ),
        IconButton(
          tooltip: l.devicesTitle,
          icon: Icon(Icons.devices_rounded, color: cc.textMuted),
          onPressed: () => DevicesSheet.show(context),
        ),
        IconButton(
          tooltip: l.mute,
          icon: Icon(
            vol == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            color: cc.textMuted,
          ),
          onPressed: volCtl.toggleMute,
        ),
        // The slider takes what the four buttons leave (up to 120 px): a
        // narrow window gives it little, or none.
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: LayoutBuilder(
              builder: (_, c) => c.maxWidth < 56
                  ? const SizedBox.shrink()
                  : Slider(value: vol, onChanged: volCtl.set),
            ),
          ),
        ),
      ],
    );
  }
}

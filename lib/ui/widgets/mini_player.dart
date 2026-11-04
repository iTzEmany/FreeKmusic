import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Track;
import '../../l10n/l10n_ext.dart';
import '../../providers/jam_providers.dart';
import '../../providers/player_providers.dart';
import '../../services/jam/jam_models.dart';
import '../../services/radio/radio_station.dart' show RadioStation;
import '../screens/devices/devices_sheet.dart';
import '../screens/jam/jam_screen.dart';
import '../screens/now_playing/now_playing_screen.dart';
import '../shell/bottom_bar.dart' show DockLayers;
import '../theme/app_theme.dart' show ccIconDensity;
import '../theme/tokens.dart';
import 'empty_player.dart';
import 'favorite_actions.dart';
import 'grow_route.dart';
import 'motion.dart';
import 'radio_now.dart';
import 'ring_progress.dart';
import '../../providers/radio_providers.dart' show onAirProvider;
import 'track_art.dart';

/// Shared-element tags of the cover between the player (mini player or desktop
/// bar, by width) and Now Playing.
const kMiniCoverHero = 'player-cover-mini';
const kBarCoverHero = 'player-cover-bar';

/// The cover tag of whichever of the two the shell shows at this [width].
String coverHeroTagFor(double width) =>
    width >= CcDims.wideBreakpoint ? kBarCoverHero : kMiniCoverHero;

const _swipeDistance = 72.0;
const _swipeVelocity = 700.0;
const _flingDuration = CcMotion.enter;

/// The row at the top of the dock (the dock gives it background and clip):
/// swipe sideways to change track, up or tap to open Now Playing. With a Jam
/// active it shows the Jam's track and controls.
class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _settle =
      AnimationController(vsync: this, duration: _flingDuration)
        ..addListener(() {
          final a = _anim;
          if (a != null) _dx.value = a.value;
        });
  Animation<double>? _anim;
  // Drag offset: only the translate rebuilds while dragging, not the card.
  final _dx = ValueNotifier<double>(0);

  @override
  void dispose() {
    _settle.dispose();
    _dx.dispose();
    super.dispose();
  }

  Future<void> _animateTo(double target) {
    _anim = Tween<double>(
      begin: _dx.value,
      end: target,
    ).animate(CurvedAnimation(parent: _settle, curve: CcMotion.curveIn));
    return _settle.forward(from: 0);
  }

  Future<void> _onDragEnd(
    DragEndDetails d,
    double width,
    PlayerController ctrl,
  ) async {
    final v = d.primaryVelocity ?? 0;
    final dx = _dx.value;
    final go = dx.abs() > _swipeDistance || v.abs() > _swipeVelocity;
    final wantsNext = (dx != 0 ? dx : -v) < 0;
    // Past the last track the player would stop and the card disappear.
    if (!go || (wantsNext && !ctrl.hasNext)) {
      await _animateTo(0);
      return;
    }
    final dir = (dx != 0 ? dx : -v).sign;
    await _animateTo(dir * width);
    if (!mounted) return;
    dir < 0 ? ctrl.next() : ctrl.previous();
    _dx.value = -dir * width * 0.4;
    await _animateTo(0);
  }

  /// Global rect of the dock layers this mini-player sits in (its own box if
  /// it is shown outside one).
  Rect _dockRect() {
    RenderBox? box;
    context.visitAncestorElements((e) {
      if (e.widget is! DockLayers) return true;
      box = e.findRenderObject() as RenderBox?;
      return false;
    });
    box ??= context.findRenderObject() as RenderBox;
    return box!.localToGlobal(Offset.zero) & box!.size;
  }

  void _openNowPlaying() => Navigator.of(context, rootNavigator: true).push(
    growRoute<void>(
      from: _dockRect(),
      builder: (_) => const NowPlayingScreen(),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    ),
  );

  void _openJam() => Navigator.of(
    context,
    rootNavigator: true,
  ).push(MaterialPageRoute<void>(builder: (_) => const JamScreen()));

  @override
  Widget build(BuildContext context) {
    final jam = ref.watch(jamProvider);
    final jamItem = jam.active ? jam.jam?.current : null;
    final track =
        ref.watch(liveCurrentTrackProvider).value ??
        ref.watch(currentTrackProvider).value;
    final inJam = jam.active;
    final empty = !inJam && track == null;

    final l = context.l10n;
    final ctrl = ref.read(playerControllerProvider);
    final width = MediaQuery.sizeOf(context).width;

    final radio = (!inJam && track != null) ? radioOfTrack(ref, track) : null;
    final onAir = radio == null ? null : ref.watch(onAirProvider).value;
    final String title;
    final String subtitle;
    final bool playing;
    if (inJam) {
      title = jamItem?.title ?? l.jamNothingPlaying;
      subtitle = l.jamPeople(jam.jam?.participants.length ?? 1);
      playing = jam.jam?.playing ?? false;
    } else if (empty) {
      title = l.playerEmptyTitle;
      subtitle = emptyPlayerSubtitle(context, ref.watch(lastQueueProvider).value);
      playing = false;
    } else {
      final texts = radio == null ? null : radioTexts(l, radio, onAir);
      final t = track!;
      title = texts?.title ?? t.title;
      final loading = ref.watch(streamLoadingProvider).value ?? false;
      subtitle = loading
          ? l.playerLoading
          : texts?.subtitle ?? t.artist ?? l.unknownArtist;
      playing = ref.watch(isPlayingProvider).value ?? false;
    }

    final card = _MiniCard(
      inJam: inJam,
      empty: empty,
      track: track,
      radio: radio,
      title: title,
      subtitle: subtitle,
      playing: playing,
    );

    return RiseIn(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: inJam || empty ? null : (_) => _settle.stop(),
        onHorizontalDragUpdate: inJam || empty ? null : (d) => _dx.value += d.delta.dx,
        onHorizontalDragEnd: inJam || empty ? null : (d) => _onDragEnd(d, width, ctrl),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -300) {
            inJam ? _openJam() : _openNowPlaying();
          }
        },
        child: ValueListenableBuilder<double>(
          valueListenable: _dx,
          // InkWell gives Enter/Space and the focus ring; the rest of the
          // gestures stay on the GestureDetector above.
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              button: true,
              // The empty card is announced once when it appears (F-48).
              liveRegion: empty,
              label: empty ? '$title. $subtitle' : l.nowPlaying,
              child: InkWell(
                onTap: inJam ? _openJam : _openNowPlaying,
                child: card,
              ),
            ),
          ),
          builder: (_, dx, c) =>
              Transform.translate(offset: Offset(dx, 0), child: c),
        ),
      ),
    );
  }
}

class _MiniCard extends ConsumerWidget {
  const _MiniCard({
    required this.inJam,
    required this.empty,
    required this.track,
    required this.radio,
    required this.title,
    required this.subtitle,
    required this.playing,
  });

  final bool inJam;

  /// Nothing plays and there is no Jam (D-364): a quiet card whose ▶ starts something.
  final bool empty;
  final Track? track;
  final RadioStation? radio;
  final String title;
  final String subtitle;
  final bool playing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final ctrl = ref.read(playerControllerProvider);
    final track = this.track;
    final radio = this.radio;
    return FocusTraversalGroup(
      child: ConstrainedBox(
        // Grows with the text so nothing overflows at 200 %.
        constraints: const BoxConstraints(minHeight: CcDims.miniPlayerHeight),
        child: Row(
          children: [
            const SizedBox(width: 4),
            if (inJam)
              RingProgress(
                size: 52,
                live: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cc.surface3,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.queue_music_rounded, color: cc.accent),
                ),
              )
            else if (empty)
              DecoratedBox(
                decoration: BoxDecoration(color: cc.surface3, shape: BoxShape.circle),
                child: SizedBox.square(
                  dimension: 52,
                  child: Icon(Icons.music_note_rounded, color: cc.textMuted),
                ),
              )
            else
              RingProgress(
                size: 52,
                live: radio != null,
                child: TrackArt(
                  track: track!,
                  size: RingProgress.innerSize(52),
                  radius: RingProgress.innerSize(52) / 2,
                  heroTag: kMiniCoverHero,
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: empty ? cc.textMuted : null,
                    ),
                  ),
                  Row(
                    children: [
                      if (inJam)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(Icons.circle, size: 8, color: cc.accent),
                        ),
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!empty)
              _MiniButton(
                icon: Icons.devices_rounded,
                tooltip: l.devicesTitle,
                onPressed: () => DevicesSheet.show(context),
              ),
            if (radio != null)
              RadioStarButton(station: radio, color: cc.textMuted)
            else if (!inJam && track != null)
              _MiniButton(
                icon: Icons.favorite_rounded,
                iconWidget: HeartIcon(favorite: track.isFavorite),
                color: track.isFavorite ? cc.accent : null,
                tooltip: track.isFavorite ? l.removeFromFavorites : l.favorite,
                onPressed: () => toggleFavorite(context, ref, track),
              ),
            _MiniButton(
              iconWidget: !inJam && (ref.watch(streamLoadingProvider).value ?? false)
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        key: const ValueKey('mini-loading'),
                        semanticsLabel: l.playerLoading,
                      ),
                    )
                  : null,
              icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: empty ? cc.accent : cc.text,
              size: 28,
              tooltip: empty
                  ? (ref.watch(lastQueueProvider).value == null ? l.playerShufflePlusLibrary : l.playerResumeLastQueue)
                  : playing ? l.pause : l.play,
              onPressed: empty
                  ? () => playWhenEmpty(ref)
                  : inJam
                  ? () => ref
                        .read(jamProvider.notifier)
                        .send(
                          playing
                              ? const JamCommand.pause()
                              : const JamCommand.play(),
                        )
                  : ctrl.togglePlayPause,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 22,
    this.iconWidget,
  });

  final IconData icon;

  /// In place of [icon] (the heart that beats).
  final Widget? iconWidget;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    iconSize: size,
    color: color ?? context.cc.textMuted,
    visualDensity: ccIconDensity,
    icon: iconWidget ?? Icon(icon),
  );
}

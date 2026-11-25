import '../../widgets/track_kind.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart' show Track;
import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../services/android/screen_flag.dart';
import '../../theme/tokens.dart';
import '../../widgets/cover_backdrop.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/favorite_actions.dart';
import 'car_playlists_sheet.dart';
import '../../widgets/motion.dart';
import '../../widgets/track_art.dart';
import '../../widgets/radio_now.dart';
import '../../../providers/radio_providers.dart' show onAirProvider;

/// Big-button player for the car: cover, title, ⏮ ⏯ ⏭, favourite, a short
/// playlist list. Opened by hand from Now Playing; nothing starts it.
class CarModeScreen extends ConsumerStatefulWidget {
  const CarModeScreen({super.key});

  @override
  ConsumerState<CarModeScreen> createState() => _CarModeScreenState();
}

class _CarModeScreenState extends ConsumerState<CarModeScreen> {
  bool _awake = false;

  @override
  void dispose() {
    if (_awake) setKeepScreenOn(false);
    super.dispose();
  }

  void _toggleAwake() {
    setState(() => _awake = !_awake);
    setKeepScreenOn(_awake);
  }

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final track =
        ref.watch(liveCurrentTrackProvider).value ??
        ref.watch(currentTrackProvider).value;
    final radio = track == null ? null : radioOfTrack(ref, track);
    final l = context.l10n;
    final texts = radio == null
        ? null
        : radioTexts(l, radio, ref.watch(onAirProvider).value);

    const controls = _CarControls();
    final info = _CarInfo(track: track, texts: texts);
    final topBar = _CarTopBar(
      track: track,
      awake: _awake,
      onToggleAwake: _toggleAwake,
    );

    return Scaffold(
      backgroundColor: cc.bg,
      body: CoverBackdrop(
        coverKey: track?.coverKey,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(CcDims.margin),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth > c.maxHeight * 1.2;
                final cover = _CarCover(track: track);
                if (wide) {
                  return Column(
                    children: [
                      topBar,
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(child: cover),
                            const SizedBox(width: 24),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    info,
                                    const SizedBox(height: 24),
                                    controls,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    topBar,
                    Expanded(child: cover),
                    const SizedBox(height: 12),
                    info,
                    const SizedBox(height: 16),
                    controls,
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _CarControls extends ConsumerWidget {
  const _CarControls();

  static const _big = 96.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final playing = ref.watch(isPlayingProvider).value ?? false;
    final ctrl = ref.read(playerControllerProvider);

    Widget big(
      IconData icon,
      String tip,
      VoidCallback? onTap, {
      bool main = false,
    }) => SizedBox(
      width: _big,
      height: _big,
      child: IconButton.filled(
        tooltip: tip,
        iconSize: 52,
        style: IconButton.styleFrom(
          backgroundColor: main ? cc.accent : cc.surface3,
          foregroundColor: main ? cc.onAccent : cc.text,
        ),
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        big(Icons.skip_previous_rounded, l.previousTrack, ctrl.previous),
        big(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          playing ? l.pause : l.play,
          ctrl.togglePlayPause,
          main: true,
        ),
        big(Icons.skip_next_rounded, l.nextTrack, ctrl.next),
      ],
    );
  }
}

class _CarInfo extends StatelessWidget {
  const _CarInfo({required this.track, required this.texts});

  final Track? track;
  final ({String title, String subtitle})? texts;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final track = this.track;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          texts?.title ?? track?.title ?? l.carNothing,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if ((texts?.subtitle ?? track?.artist) != null)
          Text(
            (texts?.subtitle ?? track?.artist)!,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.titleLarge?.copyWith(color: cc.textMuted),
          ),
      ],
    );
  }
}

class _CarTopBar extends ConsumerWidget {
  const _CarTopBar({
    required this.track,
    required this.awake,
    required this.onToggleAwake,
  });

  final Track? track;
  final bool awake;
  final VoidCallback onToggleAwake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final track = this.track;
    return Row(
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 64),
            backgroundColor: cc.surface3,
            foregroundColor: cc.text,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.close_rounded, size: 32),
          label: Text(l.carExit),
        ),
        const Spacer(),
        IconButton(
          tooltip: l.carKeepAwake,
          isSelected: awake,
          iconSize: 32,
          onPressed: onToggleAwake,
          icon: const Icon(Icons.brightness_high_outlined),
          selectedIcon: Icon(Icons.brightness_high, color: cc.accent),
        ),
        if (track != null && track.trackKind != TrackKind.online)
          IconButton(
            tooltip: track.isFavorite ? l.removeFromFavorites : l.bulkAddToFavorites,
            iconSize: 36,
            onPressed: () => toggleFavorite(context, ref, track),
            icon: HeartIcon(
              favorite: track.isFavorite,
              color: track.isFavorite ? cc.accent : cc.text,
            ),
          ),
        IconButton(
          tooltip: l.carPlaylists,
          iconSize: 36,
          onPressed: () => showCarPlaylists(context),
          icon: const Icon(Icons.queue_music_rounded),
        ),
      ],
    );
  }
}

class _CarCover extends StatelessWidget {
  const _CarCover({required this.track});

  final Track? track;

  @override
  Widget build(BuildContext context) {
    final track = this.track;
    return LayoutBuilder(
      builder: (_, cc2) => Center(
        child: track == null
            ? CoverImage(
                coverKey: null,
                size: cc2.biggest.shortestSide.clamp(80.0, 420.0),
                radius: CcDims.rGrid,
              )
            : TrackArt(
                track: track,
                size: cc2.biggest.shortestSide.clamp(80.0, 420.0),
                radius: CcDims.rGrid,
              ),
      ),
    );
  }
}

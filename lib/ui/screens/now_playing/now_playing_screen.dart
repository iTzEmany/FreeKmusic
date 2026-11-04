import '../../widgets/track_kind.dart';
import '../../../core/platform.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../car/car_mode_screen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/radio/radio_station.dart' show RadioStation;
import '../../../l10n/l10n_ext.dart';
import '../../../providers/player_providers.dart';
import '../../../services/audio/online_entries.dart' show isOnlineId;
import '../../../services/online/youtube_service.dart' show YtResult;
import '../../widgets/artist_links.dart';
import '../../widgets/empty_player.dart';
import '../../theme/tokens.dart';
import '../../widgets/track_art.dart';
import 'suggested_info.dart';
import '../../../providers/radio_providers.dart' show onAirProvider;
import '../../widgets/radio_now.dart';
import '../../widgets/favorite_actions.dart';
import '../../widgets/mini_player.dart' show coverHeroTagFor;
import '../../widgets/track_actions.dart';
import 'now_playing_cards.dart';
import 'credits_card.dart';
import 'proposal_card.dart';
import 'now_playing_controls.dart';
import '../../widgets/motion.dart';
import '../../widgets/ring_progress.dart';
import '../../../providers/theme_providers.dart';
import '../../theme/cover_tint.dart';

const _playerRouteName = 'now-playing';
const _wideBreakpoint = 900.0;
const _closeDistance = 120.0;
const _closeVelocity = 700.0;
const _cardsPlaceholderHeight = 480.0;

/// «In riproduzione da»: the name of where the queue came from.
String? playContextName(AppLocalizations l, PlayContext? c) {
  if (c == null) return null;
  return switch (c.kind) {
    PlayContextKind.album ||
    PlayContextKind.artist ||
    PlayContextKind.playlist ||
    PlayContextKind.podcast ||
    PlayContextKind.radio => c.name,
    PlayContextKind.favorites => l.navFavorites,
    PlayContextKind.library => l.allTracks,
    PlayContextKind.search => l.playContextSearch,
  };
}

/// Opens the player on top of everything, as the desktop bar does.
Future<void> _openPlayer(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: _playerRouteName),
        builder: (_) => const NowPlayingScreen(),
      ),
    );

/// Tap on an online result (rows and album call this): starts it and opens the
/// player at once, in loading (R-02). The route is pushed before the load ends.
Future<void> playOnlineAndOpen(
  BuildContext context,
  WidgetRef ref,
  YtResult r,
) => _playAndOpen(context, ref.read(playerControllerProvider).playOnline(r));

/// A second tap while the player is already on top plays but does not push again.
bool _playerOnTop(BuildContext context) {
  var onTop = false;
  Navigator.of(context, rootNavigator: true).popUntil((route) {
    onTop = route.settings.name == _playerRouteName;
    return true;
  });
  return onTop;
}

Future<void> playOnlineListAndOpen(
  BuildContext context,
  WidgetRef ref,
  List<YtResult> list, {
  bool shuffle = false,
}) => _playAndOpen(
  context,
  ref.read(playerControllerProvider).playOnlineList(list, shuffle: shuffle),
);

Future<void> _playAndOpen(BuildContext context, Future<void> playing) {
  if (context.mounted && !_playerOnTop(context)) {
    unawaited(_openPlayer(context));
  }
  return playing;
}

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.desktop});

  /// Overrides the platform check for the top bar (tests); null = the platform.
  final bool? desktop;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  // The close drag moves only the Transform: no rebuild per pointer move.
  final _dy = ValueNotifier<double>(0);
  bool _dragging = false;
  // Cards are built once the open transition is over (flat placeholder before).
  bool _cardsReady = false;
  Animation<double>? _routeAnim;

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dy.value > _closeDistance || v > _closeVelocity) {
      Navigator.of(context).maybePop();
      return;
    }
    _dragging = false;
    _dy.value = 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cardsReady || _routeAnim != null) return;
    final a = _routeAnim = ModalRoute.of(context)?.animation;
    if (a == null || a.isCompleted) {
      _cardsReady = true;
    } else {
      a.addStatusListener(_onRouteStatus);
    }
  }

  void _onRouteStatus(AnimationStatus s) {
    if (s != AnimationStatus.completed) return;
    _routeAnim?.removeStatusListener(_onRouteStatus);
    if (mounted) setState(() => _cardsReady = true);
  }

  @override
  void dispose() {
    _routeAnim?.removeStatusListener(_onRouteStatus);
    _dy.dispose();
    super.dispose();
  }

  List<Widget> _cards(bool online, Track track) {
    if (!_cardsReady) return const [SizedBox(height: _cardsPlaceholderHeight)];
    // A streamed track gets the cards of its shadow row (real id); a radio none.
    final radio = online && ref.watch(onlineEntriesProvider)?.isRadioId(track.id) == true;
    final row = isOnlineId(track.id) ? ref.watch(currentShadowRowProvider) : track;
    final wait = !radio && row == null;
    return [
      RiseIn(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wait) StreamCardsWait(key: ValueKey(track.id), trackId: track.id),
            if (row != null) ...[
              LyricsCard(track: row),
              const SizedBox(height: 12),
              if (!online) ProposalCard(track: row),
              InfoCard(track: row),
              const SizedBox(height: 12),
              CreditsCard(track: row, key: ValueKey(row.id)),
            ],
            const UpNextCard(),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final track =
        ref.watch(liveCurrentTrackProvider).value ??
        ref.watch(currentTrackProvider).value;
    final cc = context.cc;
    final online = track != null && track.trackKind == TrackKind.online;
    final wide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;
    final reduce = MediaQuery.disableAnimationsOf(context);
    // Option «tinta della copertina» (D-54): one flat colour, else `bg`.
    final tinted = ref.watch(themeBackgroundProvider).coverBackdrop;
    return Scaffold(
      backgroundColor: tinted
          ? resolvedHeroTint(context, ref, track?.coverKey)
          : cc.bg,
      body: SafeArea(
        child: ValueListenableBuilder<double>(
          valueListenable: _dy,
          builder: (_, dy, child) => AnimatedContainer(
            duration: _dragging || reduce ? Duration.zero : CcMotion.sheet,
            transform: Matrix4.translationValues(0, dy, 0),
            child: child,
          ),
          child: track == null
              ? _Empty(onClose: () => Navigator.of(context).maybePop())
              : LayoutBuilder(
                  builder: (context, c) {
                    final player = _Player(
                      track: track,
                      desktop: widget.desktop ?? isDesktop,
                      onDragUpdate: (d) {
                        _dragging = true;
                        _dy.value = (_dy.value + d.delta.dy).clamp(0.0, 600.0);
                      },
                      onDragEnd: _onDragEnd,
                    );
                    if (wide) {
                      // Player and cards form one group, centred, so no hole opens between them.
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1012),
                          child: Row(
                            children: [
                              Flexible(child: player),
                              const SizedBox(width: 32),
                              // The player pads its own side by CcDims.margin: mirror it.
                              Padding(
                                padding: const EdgeInsets.only(
                                  right: CcDims.margin,
                                ),
                                child: SizedBox(
                                  width: 420,
                                  child: ListView(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: CcDims.gap16,
                                    ),
                                    children: _cards(online, track),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(height: c.maxHeight, child: player),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                            CcDims.margin,
                            0,
                            CcDims.margin,
                            CcDims.gap24,
                          ),
                          sliver: SliverList.list(
                            children: _cards(online, track),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          tooltip: context.l10n.back,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: onClose,
        ),
      ),
      const Expanded(child: EmptyPlayerBody()),
    ],
  );
}

/// Header, cover, title row, seek, controls and the bottom row.
class _Player extends ConsumerWidget {
  const _Player({
    required this.track,
    required this.desktop,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Track track;
  final bool desktop;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = track.trackKind == TrackKind.online;
    final radio = radioOfTrack(ref, track);
    final onAir = radio == null ? null : ref.watch(onAirProvider).value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
      child: Column(
        children: [
          _PlayerHeader(
            track: track,
            desktop: desktop,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
          _PlayerCover(
            track: track,
            radio: radio,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
          ),
          const SizedBox(height: 16),
          _TitleRow(track: track, radio: radio, onAir: onAir),
          if (radio != null)
            NpRadioActions(station: radio, onAir: onAir)
          else if (online)
            SuggestedInfo(track: track),
          if (radio != null)
            NpLiveRow(station: radio)
          else
            NpSeekRow(track: track),
          const SizedBox(height: 8),
          NpControls(live: radio != null),
          const NpBottomRow(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _PlayerHeader extends ConsumerWidget {
  const _PlayerHeader({
    required this.track,
    required this.desktop,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Track track;
  final bool desktop;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final ctx = playContextName(l, ref.watch(playContextProvider));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onDragUpdate,
      onVerticalDragEnd: onDragEnd,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            // Equal side slots (two 48 px buttons) keep the title centred.
            SizedBox(
              width: 96,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: IconButton(
                  tooltip: l.back,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ctx == null ? l.nowPlaying : l.playingFrom,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelSmall,
                  ),
                  if (ctx != null)
                    Text(
                      ctx,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cc.text,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (!desktop)
                    IconButton(
                      tooltip: l.carMode,
                      icon: const Icon(Icons.directions_car_outlined),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CarModeScreen(),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: l.moreActions,
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () => showTrackActions(context, ref, track),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerCover extends ConsumerWidget {
  const _PlayerCover({
    required this.track,
    required this.radio,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Track track;
  final RadioStation? radio;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(playerControllerProvider);
    final loading = ref.watch(streamLoadingProvider).value ?? false;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: onDragUpdate,
        onVerticalDragEnd: onDragEnd,
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -300 && ctrl.hasNext) ctrl.next();
          if (v > 300) ctrl.previous();
        },
        child: LayoutBuilder(
          builder: (_, c) {
            final s = (c.biggest.shortestSide).clamp(80.0, 460.0);
            const stroke = 12.0;
            final inner = RingProgress.innerSize(s, stroke: stroke);
            return Center(
              child: RingProgress(
                size: s,
                stroke: stroke,
                seekable: true,
                live: radio != null,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SpinWhilePlaying(
                      trackKey: track.id,
                      child: TrackArt(
                        track: track,
                        size: inner,
                        radius: inner / 2,
                        semanticLabel: track.album ?? track.title,
                        heroTag: coverHeroTagFor(
                          MediaQuery.sizeOf(context).width,
                        ),
                      ),
                    ),
                    // The thumbnail stays (R-02); the ring turns over it.
                    if (loading)
                      SizedBox.square(
                        dimension: inner,
                        child: CircularProgressIndicator(
                          key: const ValueKey('np-cover-loading'),
                          semanticsLabel: context.l10n.playerLoading,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TitleRow extends ConsumerWidget {
  const _TitleRow({
    required this.track,
    required this.radio,
    required this.onAir,
  });

  final Track track;
  final RadioStation? radio;
  final String? onAir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final online = track.trackKind == TrackKind.online;
    final radio = this.radio;
    final texts = radio == null ? null : radioTexts(l, radio, onAir);
    return Row(
      children: [
        Expanded(
          child: Padding(
            // The heart's glyph ends at npEdge: the title mirrors it.
            padding: EdgeInsetsDirectional.only(
              start: npEdge,
              end: radio == null && online ? npEdge : 0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texts?.title ?? track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.titleLarge,
                ),
                if (radio == null)
                  ArtistLinks(
                    track,
                    style: theme.bodyLarge?.copyWith(color: cc.textMuted),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      // «In diretta» is already in the live row below.
                      onAir == null ? '' : texts!.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyLarge?.copyWith(color: cc.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (radio != null)
          RadioStarButton(station: radio)
        else if (!online)
          IconButton(
            tooltip: track.isFavorite ? l.removeFromFavorites : l.favorite,
            onPressed: () => toggleFavorite(context, ref, track),
            icon: HeartIcon(
              favorite: track.isFavorite,
              color: track.isFavorite ? cc.accent : cc.text,
            ),
          ),
      ],
    );
  }
}

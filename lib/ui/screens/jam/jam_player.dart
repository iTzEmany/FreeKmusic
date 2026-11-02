import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/share_hub.dart';
import '../../../providers/jam_providers.dart';
import '../../../services/jam/jam_models.dart';
import '../../theme/tokens.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/ring_progress.dart';
import '../../widgets/seek_bar.dart';
import '../../widgets/show_msg.dart';
import 'speaker_notices.dart';
import '../../widgets/smooth_position.dart';
import '../now_playing/now_playing_controls.dart';
import 'jam_cards.dart';
import 'jam_header.dart';
import 'jam_outputs_sheet.dart';
import 'jam_parts.dart';
import 'jam_queue_sheet.dart';

const _wideBreakpoint = 900.0;

/// The Jam screen is the player: same cover and ring, bar, controls and text
/// cards, on the Jam's clock; only [JamHeader] differs.
class JamPlayerView extends ConsumerStatefulWidget {
  const JamPlayerView({super.key, required this.state});

  final JamUiState state;

  @override
  ConsumerState<JamPlayerView> createState() => _JamPlayerViewState();
}

class _JamPlayerViewState extends ConsumerState<JamPlayerView> {
  // The Jam's position, frozen while paused (JamState.positionAtTime).
  final _smooth = SmoothPosition();
  // Own drag state: the Jam's clock is not the local player's (ring, bar, times).
  final _scope = [seekDragProvider.overrideWith(SeekDrag.new)];

  // The Jam clock is refined after the first state arrives: re-read it.
  Timer? _refresh;

  JamState get _jam => widget.state.jam!;

  bool _seeking = false; // a user seek waits for the host's answer

  void _feed({bool refresh = false}) {
    final jam = _jam;
    final shown = jam.positionAtTime(ref.read(jamProvider.notifier).jamNowMs());
    final was = _smooth.value.inMilliseconds;
    if (refresh && jam.playing && (was - shown).abs() > 100) {
      AppLog.d('jam ui: shown position moved ${shown - was}ms on refresh');
    }
    _smooth.update(
      Duration(milliseconds: shown),
      playing: jam.playing && jam.current != null,
      duration: Duration(milliseconds: jam.current?.durationMs ?? 0),
    );
  }

  @override
  void initState() {
    super.initState();
    _feed();
    _refresh = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_seeking) _feed(refresh: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _smooth.bindTickerMode(context);
  }

  @override
  void didUpdateWidget(JamPlayerView old) {
    super.didUpdateWidget(old);
    if (old.state.jam != widget.state.jam) _feed();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _smooth.dispose();
    super.dispose();
  }

  Future<void> _seek(Duration d) async {
    _seeking = true;
    final JamError? err;
    try {
      err = await ref
          .read(jamProvider.notifier)
          .send(JamCommand.seek(d.inMilliseconds));
    } finally {
      _seeking = false;
    }
    if (!mounted) return;
    if (err == JamError.noSpeaker) {
      _feed();
      showMsg(context, context.l10n.speakerAwayNotice);
    }
    if (err != JamError.invalid) return;
    _feed(); // back to the Jam's position
    showMsg(context, context.l10n.jamSeekInvalid);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final jam = _jam;
    final cur = jam.current;
    final ctrl = ref.read(jamProvider.notifier);
    final header = JamHeader(jam: jam, isHost: s.isHost, onEnd: ctrl.end, unreachable: ref.read(shareHubProvider.notifier).jamHost?.unreachableIds() ?? const []);
    if (jam.items.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: EmptyState(
              icon: Icons.queue_music_rounded,
              message: context.l10n.jamEmpty,
            ),
          ),
        ],
      );
    }
    final dur = Duration(milliseconds: cur?.durationMs ?? 0);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final cards = <Widget>[
      if (cur != null) ...[
        JamLyricsCard(item: cur),
        const SizedBox(height: 12),
        JamInfoCard(item: cur),
      ],
    ];
    return ProviderScope(
      overrides: _scope,
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= _wideBreakpoint;
          final player = _JamPlayer(
            header: header,
            jam: jam,
            smooth: _smooth,
            duration: dur,
            onSeek: _seek,
            // Phone: the taller header leaves the cover 260 dp at most.
            maxRing: wide ? 460 : 260,
            hasCurrent: cur != null,
          );
          if (wide) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1012),
                child: Row(
                  children: [
                    Flexible(child: player),
                    const SizedBox(width: 32),
                    Padding(
                      padding: const EdgeInsets.only(right: CcDims.margin),
                      child: SizedBox(
                        width: 420,
                        // Testo, Curiosità and the shared queue, as the
                        // desktop player keeps «Prossimi» in this column.
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.only(top: CcDims.gap16),
                              sliver: SliverList.list(children: cards),
                            ),
                            const JamQueueSliver(),
                          ],
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
                // At big text the content outgrows the screen: the page scrolls.
                child: SizedBox(
                  height: math.max(c.maxHeight, 200 + 360 * textScale),
                  child: player,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  CcDims.margin,
                  0,
                  CcDims.margin,
                  CcDims.gap24,
                ),
                sliver: SliverList.list(children: cards),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Header, cover with the ring, title, bar, controls and the bottom row.
class _JamPlayer extends ConsumerWidget {
  const _JamPlayer({
    required this.header,
    required this.jam,
    required this.smooth,
    required this.duration,
    required this.onSeek,
    required this.maxRing,
    required this.hasCurrent,
  });

  final double maxRing;
  final bool hasCurrent;
  final Widget header;
  final JamState jam;
  final SmoothPosition smooth;
  final Duration duration;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final ctrl = ref.read(jamProvider.notifier);
    final cur = jam.current;
    return Column(
      children: [
        header,
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (_, c) {
                      final s = c.biggest.shortestSide.clamp(80.0, maxRing);
                      const stroke = 12.0;
                      final inner = RingProgress.innerSize(s, stroke: stroke);
                      return Center(
                        child: RingProgress(
                          size: s,
                          stroke: stroke,
                          seekable: true,
                          position: smooth,
                          duration: duration,
                          onSeek: onSeek,
                          child: JamCover(
                            item: cur,
                            size: inner,
                            radius: inner / 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: npEdge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cur?.title ?? l.jamNothingPlaying,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.titleLarge,
                        ),
                        Text(
                          cur?.artist ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyLarge?.copyWith(
                            color: cc.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                NpSeekRow(
                  position: smooth,
                  duration: duration,
                  onSeek: onSeek,
                ),
                const SizedBox(height: 8),
                NpControls(
                  live: true,
                  playing: jam.playing,
                  // Nothing playing: the three buttons are disabled.
                  onPrevious: hasCurrent
                      ? () => _jamPrevious(context, ctrl)
                      : null,
                  onPlayPause: hasCurrent
                      ? () => sendJamCommand(
                          context,
                          ctrl,
                          jam.playing
                              ? const JamCommand.pause()
                              : const JamCommand.play(),
                        )
                      : null,
                  onNext: hasCurrent
                      ? () => sendJamCommand(
                          context,
                          ctrl,
                          const JamCommand.next(),
                        )
                      : null,
                ),
                NpBottomRow(
                  volume: false,
                  devicesLabel: l.devicesTitle,
                  onDevices: () => JamOutputsSheet.show(context),
                  onQueue: () => showJamQueueSheet(context),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// «Indietro»: like the other commands, tells when the speaker is away.
Future<void> _jamPrevious(BuildContext context, JamController ctrl) async {
  final msg = context.l10n.speakerAwayNotice;
  final err = await ctrl.previous();
  if (err == JamError.noSpeaker && context.mounted) showMsg(context, msg);
}

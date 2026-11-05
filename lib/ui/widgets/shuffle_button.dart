import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/player_providers.dart';
import '../../providers/shuffle_plus_providers.dart';
import 'shuffle_plus_text.dart';
import '../screens/now_playing/shuffle_plus_sheet.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// The «why no Shuffle+» message was shown (once per session, in memory; D-87).
bool _explained = false;

/// Test hook: a new session.
@visibleForTesting
void resetShuffleExplained() => _explained = false;

/// A tap of a shuffle control: the next state for the list it plays ([ids],
/// null: the current queue; D-137), with the once-per-session «why not» note.
Future<void> _cycleWithNotice(
  BuildContext context,
  WidgetRef ref,
  Future<List<int>> Function()? ids,
) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final block = await ref
      .read(playerControllerProvider)
      .cycleShuffle(ids: await ids?.call());
  if (block == null || _explained || !context.mounted) return;
  _explained = true;
  messenger.showSnackBar(
    SnackBar(content: Text(shufflePlusBlockText(l, block))),
  );
}

/// The three-state shuffle button of the players: off, shuffle, Shuffle+
/// (shuffle with a «+»). Tap goes to the next state, long press opens the
/// Shuffle+ settings.
class ShuffleModeButton extends ConsumerWidget {
  const ShuffleModeButton({
    super.key,
    this.size = 28,
    this.dot = true,
    this.listIds,
  });

  final double size;

  /// The dot under the icon (Now Playing); the desktop bar goes without.
  final bool dot;

  /// The ids of the list the button's Play plays (Home); null: the queue.
  final Future<List<int>> Function()? listIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final l = context.l10n;
    final mode = ref.watch(shuffleModeProvider);
    final on = mode != ShuffleMode.off;
    final color = on ? cc.accent : cc.textMuted;
    final icon = Icon(Icons.shuffle_rounded, size: size, color: color);
    // The tooltip must not react to a long press (manual trigger: hover only):
    // on touch it would win the gesture and the Shuffle+ sheet never opened.
    final message = switch (mode) {
      ShuffleMode.off => l.shuffleModeOff,
      ShuffleMode.shuffle => l.shuffleModeOn,
      ShuffleMode.plus => l.shuffleModePlus,
    };
    return GestureDetector(
      excludeFromSemantics:
          true, // the long press is on the labelled icon below
      onLongPress: () => showShufflePlusSheet(context),
      child: Tooltip(
        triggerMode: TooltipTriggerMode.manual,
        excludeFromSemantics: true, // the icon below already speaks the state
        message: message,
        child: IconButton(
          onPressed: () => _cycleWithNotice(context, ref, listIds),
          // The tooltip is hover-only, so the button needs its own label.
          icon: Semantics(
            label: message,
            onLongPress: () => showShufflePlusSheet(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                mode == ShuffleMode.plus
                    ? Stack(
                        clipBehavior: Clip.none,
                        children: [
                          icon,
                          Positioned(
                            right: -size * 0.25,
                            top: -size * 0.15,
                            child: Icon(
                              Icons.add_rounded,
                              key: const ValueKey('shuffle-plus-badge'),
                              size: size * 0.6,
                              color: color,
                            ),
                          ),
                        ],
                      )
                    : icon,
                if (dot) ...[
                  const SizedBox(height: 2),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: on ? cc.accent : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Casuale» word button of the collection headers: tap cycles the mode for
/// the list [ids] (it never starts playback), accent while shuffle is on, with
/// the «+» badge in Shuffle+; long press opens the Shuffle+ sheet.
class ShufflePill extends ConsumerWidget {
  const ShufflePill({super.key, required this.ids});

  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final mode = ref.watch(shuffleModeProvider);
    final color = mode == ShuffleMode.off ? cc.text : cc.accent;
    void cycle() => _cycleWithNotice(context, ref, () async => ids);
    // One node: the state is the name (the button's own «Casuale» would be a second).
    return Semantics(
      button: true,
      excludeSemantics: true,
      onTap: cycle,
      onLongPress: () => showShufflePlusSheet(context),
      toggled: mode != ShuffleMode.off,
      label: switch (mode) {
        ShuffleMode.off => context.l10n.shuffleModeOff,
        ShuffleMode.shuffle => context.l10n.shuffleModeOn,
        ShuffleMode.plus => context.l10n.shuffleModePlus,
      },
      child: PressScale(
        child: GestureDetector(
          onLongPress: () => showShufflePlusSheet(context),
          child: OutlinedButton.icon(
            onPressed: cycle,
            style: OutlinedButton.styleFrom(foregroundColor: color),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.shuffle_rounded, color: color),
                if (mode == ShuffleMode.plus)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Icon(
                      Icons.add_rounded,
                      key: const ValueKey('shuffle-plus-badge'),
                      size: 12,
                      color: color,
                    ),
                  ),
              ],
            ),
            label: Text(context.l10n.shuffle),
          ),
        ),
      ),
    );
  }
}

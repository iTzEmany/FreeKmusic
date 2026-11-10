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

/// What a shuffle control shows: the player's mode, or for a list page's
/// control [key] its own mode unless that list is the one playing (D-534).
ShuffleMode _modeOf(WidgetRef ref, Object? key) {
  final real = ref.watch(shuffleModeProvider);
  if (key == null) return real;
  final own = ref.watch(listShuffleProvider(key));
  return (ref.watch(listPlayingProvider(key))) ? real : own;
}

/// A tap of a shuffle control: the next state for the list it plays ([ids],
/// null: the current queue; D-137), with the once-per-session «why not» note.
/// [listKey]: a list page's control, which leaves the playing queue alone
/// unless its list is the one playing (D-534).
Future<void> _cycleWithNotice(
  BuildContext context,
  WidgetRef ref,
  Future<List<int>> Function()? ids, {
  Object? listKey,
  bool plus = true,
}) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final c = ref.read(playerControllerProvider);
  final list = await ids?.call();
  final block = listKey == null
      ? await c.cycleShuffle(ids: list)
      : await c.cycleListShuffle(listKey, ids: list, plus: plus);
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
    this.listKey,
  });

  final double size;

  /// The dot under the icon (Now Playing); the desktop bar goes without.
  final bool dot;

  /// The ids of the list the button's Play plays (Home); null: the queue.
  final Future<List<int>> Function()? listIds;

  /// The page's key for [listIds] (see [listKeyOf]): the button then keeps the
  /// mode of that list's next Play, not the player's (D-534).
  final Object? listKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final l = context.l10n;
    final mode = _modeOf(ref, listKey);
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
          onPressed: () =>
              _cycleWithNotice(context, ref, listIds, listKey: listKey),
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

/// «Casuale» word button of the list pages: tap cycles the mode of the list
/// [ids] (or [listKey]) for its next Play, never starting playback nor touching
/// the playing queue unless this list plays (D-534); accent while shuffle is
/// on, with the «+» badge in Shuffle+; long press opens the Shuffle+ sheet.
/// [plus] false: off and shuffle only (online lists).
class ShufflePill extends ConsumerWidget {
  const ShufflePill({
    super.key,
    this.ids = const [],
    this.listKey,
    this.plus = true,
  });

  final List<int> ids;
  final Object? listKey;
  final bool plus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final key = listKey ?? listKeyOf(ids);
    final mode = _modeOf(ref, key);
    final color = mode == ShuffleMode.off ? cc.text : cc.accent;
    void cycle() =>
        _cycleWithNotice(context, ref, () async => ids, listKey: key, plus: plus);
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

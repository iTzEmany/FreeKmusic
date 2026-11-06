import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';
import 'motion.dart';

/// Filled amethyst circle with the play/pause glyph.
class PlayCircleButton extends StatelessWidget {
  const PlayCircleButton({
    super.key,
    required this.onPressed,
    this.playing = false,
    this.size = 56,
    this.tooltip,
  });

  final VoidCallback? onPressed;
  final bool playing;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final l = context.l10n;
    final label = tooltip ?? (playing ? l.pause : l.play);
    // Its own node with a real label (a tooltip alone is not one for TalkBack).
    return Semantics(
      container: true,
      button: true,
      enabled: onPressed != null,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: cc.accent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: size * 0.6,
                color: cc.onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// «Riproduci» word button of the collection headers.
class PlayPill extends StatelessWidget {
  const PlayPill({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => PressScale(
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(context.l10n.play),
    ),
  );
}

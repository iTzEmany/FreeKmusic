import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A tappable card: `surface1` (or [color]) with the card radius, ripple and
/// one button node for screen readers that reads [semanticsLabel].
class CcTile extends StatelessWidget {
  const CcTile({
    super.key,
    required this.child,
    required this.onTap,
    required this.semanticsLabel,
    this.color,
    this.minHeight = 0,
    this.selected,
  });

  final Widget child;
  final VoidCallback onTap;
  final String semanticsLabel;
  final Color? color;
  final double minHeight;

  /// Null when the tile is not part of a choice.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: color ?? context.cc.surface1,
        borderRadius: BorderRadius.circular(CcDims.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: child,
          ),
        ),
      ),
    );
  }
}

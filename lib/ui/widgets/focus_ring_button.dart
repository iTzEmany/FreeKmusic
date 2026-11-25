import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A round tap target whose keyboard focus draws an accent ring OVER the
/// (opaque) cover, where an InkWell's own highlight would be hidden.
class FocusRingButton extends StatefulWidget {
  const FocusRingButton({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<FocusRingButton> createState() => _FocusRingButtonState();
}

class _FocusRingButtonState extends State<FocusRingButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => InkWell(
    customBorder: const CircleBorder(),
    onTap: widget.onTap,
    onFocusChange: (f) => setState(() => _focused = f),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional
            ? Border.all(color: context.cc.accent, width: 2)
            : null,
      ),
      child: widget.child,
    ),
  );
}

/// A 2 px accent ring (D-720) over [child] while a descendant has keyboard
/// focus. Never drawn for touch or mouse, and independent of "selected".
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.child, this.radius = BorderRadius.zero});

  final Widget child;
  final BorderRadius radius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  void _onMode(FocusHighlightMode _) => setState(() {});

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onFocusChange: (f) => setState(() => _focused = f),
    child: DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: widget.radius,
        border: _focused && FocusManager.instance.highlightMode == FocusHighlightMode.traditional
            ? Border.all(color: context.cc.accent, width: 2)
            : null,
      ),
      child: widget.child,
    ),
  );
}

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The one frame of every desktop page (D-720): from [CcDims.wideBreakpoint] up
/// it is at most [maxWidth] wide and centered (the pages keep their own side
/// margins); below it returns [child] as is.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child});

  static const maxWidth = 1136.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < CcDims.wideBreakpoint) return child;
      // The pages keep their own 16 px: from maxWidth + 2 * 16 the frame adds
      // another 16, so the real margin is 32 (D-720).
      final framed = box.maxWidth >= maxWidth + 2 * CcDims.gap16
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: CcDims.gap16),
              child: child,
            )
          : child;
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: framed,
        ),
      );
    },
  );
}

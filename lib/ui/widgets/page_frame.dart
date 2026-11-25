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
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
    },
  );
}

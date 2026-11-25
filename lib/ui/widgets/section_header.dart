import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Section title in lists and Home, with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.count,
  });

  final String title;

  /// Small muted text at the end of the line («12 brani»).
  final String? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // Fixed height: the 48 dp action button fits inside, so «Tutti» never grows the header.
    return SizedBox(
      height: CcDims.sectionHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
        child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (count != null)
            Text(
              count!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.cc.textMuted,
              ),
            ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
      ),
    );
  }
}

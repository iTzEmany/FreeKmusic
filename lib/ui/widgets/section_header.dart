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
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 20, CcDims.margin, CcDims.gap8),
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
    );
  }
}

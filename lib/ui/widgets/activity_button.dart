import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/activity_providers.dart';
import '../screens/activity/activity_sheet.dart';
import '../theme/tokens.dart';

/// Small spinner with the number of running activities; hidden when idle.
class ActivityButton extends ConsumerWidget {
  const ActivityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(activityProvider.select((a) => a.running.length));
    if (n == 0) return const SizedBox.shrink();
    final cc = context.cc;
    final label = context.l10n.activityRunning(n);
    // A node of its own (never merged into a header title), named by the tooltip.
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: () => ActivitySheet.show(context),
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(CcDims.rPill),
          onTap: () => ActivitySheet.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: CcDims.gap12,
              vertical: CcDims.gap8,
            ),
            decoration: BoxDecoration(
              color: cc.surface2,
              borderRadius: BorderRadius.circular(CcDims.rPill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RepaintBoundary(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cc.accentSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$n',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: cc.text),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

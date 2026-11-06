import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';
import 'cc_sheet.dart';

/// Single-choice blocks: pops 15/30/45/60 (minutes), -1 ([endLabel], when given) or 0 ([cancelLabel], when given).
Future<int?> showDurationChoiceSheet(
  BuildContext context, {
  required String title,
  String? endLabel,
  bool endSelected = false,
  String? cancelLabel,
}) {
  final l = context.l10n;
  return showCcSheet<int>(
    context: context,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          0,
          CcDims.margin,
          CcDims.margin,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(sheet).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in const [15, 30, 45, 60])
                  ChoiceChip(
                    key: ValueKey<Object>(m),
                    label: Text(l.sleepMinutes(m)),
                    selected: false,
                    onSelected: (_) => Navigator.of(sheet).pop(m),
                  ),
                if (endLabel != null)
                  ChoiceChip(
                    key: const ValueKey<Object>(-1),
                    label: Text(endLabel),
                    selected: endSelected,
                    onSelected: (_) => Navigator.of(sheet).pop(-1),
                  ),
                if (cancelLabel != null)
                  ChoiceChip(
                    key: const ValueKey<Object>(0),
                    label: Text(cancelLabel),
                    selected: false,
                    onSelected: (_) => Navigator.of(sheet).pop(0),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

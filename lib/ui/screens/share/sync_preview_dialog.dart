import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/share/playlist_sync.dart';

enum SyncDecision { apply, applyAndAsk }

/// Shows what a sync would do and waits for the user. Null = cancelled.
Future<SyncDecision?> showSyncPreview(BuildContext context, SyncPlan plan,
    {bool canAsk = false}) {
  return showDialog<SyncDecision>(
    context: context,
    builder: (_) => SyncPreviewDialog(plan: plan, canAsk: canAsk),
  );
}

/// «3 new, 2 updated, 14 tracks missing» and the list behind it. Nothing is
/// written before «Applica».
class SyncPreviewDialog extends StatelessWidget {
  const SyncPreviewDialog({super.key, required this.plan, this.canAsk = false});

  final SyncPlan plan;

  /// Offer «ask for the missing tracks» (the device can receive an offer).
  final bool canAsk;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final missing = plan.missing.length;
    final summary = [
      if (plan.toAdd.isNotEmpty) l.syncAdded(plan.toAdd.length),
      if (plan.toReplace.isNotEmpty) l.syncUpdated(plan.toReplace.length),
      if (missing > 0) l.syncMissing(missing),
    ];
    final muted = Theme.of(context).textTheme.bodySmall;
    return AlertDialog(
      title: Text(l.syncTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(summary.isEmpty ? l.syncUpToDate : summary.join(', ')),
              const SizedBox(height: 8),
              for (final e in plan.toWrite) _EntryTile(entry: e),
              if (plan.toReplace.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l.syncReplaceNote, style: muted),
              ],
              if (plan.keptCount > 0) ...[
                const SizedBox(height: 4),
                Text(l.syncKept(plan.keptCount), style: muted),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(plan.toWrite.isEmpty ? l.close : l.cancel),
        ),
        if (canAsk && missing > 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(SyncDecision.applyAndAsk),
            child: Text(l.syncAskMissing),
          ),
        // The collections are not shown here yet: a plan with only those has nothing to confirm.
        if (plan.toWrite.isNotEmpty)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(SyncDecision.apply),
            child: Text(l.apply),
          ),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final SyncEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final isNew = entry.action == SyncAction.add;
    final details = [
      isNew ? l.syncTagNew : l.syncTagUpdated,
      l.tracksCount(entry.trackIds.length),
      if (entry.renamed) l.syncDetailRenamed,
      if (entry.reordered) l.syncDetailReordered,
      if (entry.removed > 0) l.syncDetailRemoved(entry.removed),
      if (entry.missing.isNotEmpty) l.syncMissing(entry.missing.length),
    ];
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(isNew ? Icons.playlist_add : Icons.sync),
      title: Text(entry.remote.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(details.join(', ')),
    );
  }
}

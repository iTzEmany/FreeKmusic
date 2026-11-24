import 'package:flutter/material.dart';

import '../../../data/db/tables.dart' show TombstoneKind;
import '../../../l10n/l10n_ext.dart';
import '../../../services/share/playlist_sync.dart';
import 'sync_setting_labels.dart';

enum SyncDecision { apply, applyAndAsk }

/// What the user chose: the decision and the keys of the settings they ticked (none by default).
typedef SyncChoice = ({SyncDecision decision, Set<String> settings});

/// Shows what a sync would do and waits for the user. Null = cancelled. [mine]: the peer is one of the user's own devices.
Future<SyncChoice?> showSyncPreview(BuildContext context, SyncPlan plan,
    {bool canAsk = false, bool mine = false}) {
  return showDialog<SyncChoice>(
    context: context,
    builder: (_) => SyncPreviewDialog(plan: plan, canAsk: canAsk, mine: mine),
  );
}

/// «3 new, 1 removed, 2 favorites removed…» and the list behind it. Nothing is written before the confirm button,
/// which says how many items it removes.
class SyncPreviewDialog extends StatefulWidget {
  const SyncPreviewDialog({super.key, required this.plan, this.canAsk = false, this.mine = false});

  final SyncPlan plan;

  /// Offer «ask for the missing tracks» (the device can receive an offer).
  final bool canAsk;

  final bool mine;

  @override
  State<SyncPreviewDialog> createState() => _SyncPreviewDialogState();
}

class _SyncPreviewDialogState extends State<SyncPreviewDialog> {
  final _picked = <String>{};

  SyncChoice _choice(SyncDecision d) => (decision: d, settings: {..._picked});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final plan = widget.plan;
    final c = plan.collections;
    int gone(String kind) => c.deletes.where((t) => t.kind == kind).length;
    final missing = plan.missing.length;
    final playlists = [
      if (plan.toAdd.isNotEmpty) l.syncAdded(plan.toAdd.length),
      if (plan.toReplace.isNotEmpty) l.syncUpdated(plan.toReplace.length),
      if (gone(TombstoneKind.playlist) > 0) l.syncRemoved(gone(TombstoneKind.playlist)),
      if (missing > 0) l.syncMissing(missing),
    ];
    final favGone = gone(TombstoneKind.favoriteAlbum) + gone(TombstoneKind.favoritePlaylist);
    final t = c.tables;
    final incoming = [
      if (t.texts.isNotEmpty) l.syncTexts(t.texts.length),
      if (t.plays.isNotEmpty) l.syncPlays(t.plays.length),
      if (t.tags.isNotEmpty || t.taggedCount > 0) l.syncTags(t.tags.length + t.taggedCount),
    ];
    final lines = [
      if (playlists.isNotEmpty) playlists.join(', '),
      if (c.favoriteAdds.isNotEmpty) l.syncFavAdded(c.favoriteAdds.length),
      if (favGone > 0) l.syncFavRemoved(favGone),
      if (c.saves.isNotEmpty) l.syncSavedAdded(c.saves.length),
      if (gone(TombstoneKind.savedStream) > 0) l.syncSavedRemoved(gone(TombstoneKind.savedStream)),
      if (c.hearts.isNotEmpty) l.syncHeartAdded(c.hearts.length),
      if (gone(TombstoneKind.favoriteStream) > 0) l.syncHeartRemoved(gone(TombstoneKind.favoriteStream)),
      if (incoming.isNotEmpty) l.syncIncoming(incoming.join(', ')),
    ];
    final muted = Theme.of(context).textTheme.bodySmall;
    final removals = c.deletes.length;
    return AlertDialog(
      title: Text(widget.mine ? l.syncNow : l.syncTitle),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (lines.isEmpty && c.settings.isEmpty && plan.toWrite.isEmpty) Text(l.syncUpToDate),
              for (final line in lines) Text(line),
              if (removals > 0) ...[
                const SizedBox(height: 8),
                Text(l.syncRemovalNote, style: muted),
              ],
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
              if (widget.mine && c.isEmpty && plan.toWrite.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(l.syncNotMineNote, style: muted),
              ],
              if (c.settings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(l.syncSettingsTitle, style: Theme.of(context).textTheme.titleSmall),
                for (final s in c.settings)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _picked.contains(s.key),
                    onChanged: (v) => setState(() => v == true ? _picked.add(s.key) : _picked.remove(s.key)),
                    title: Text(syncSettingLabel(l, s.key)),
                    subtitle: Text(l.syncSettingValues(syncSettingValue(l, s.key, s.local), syncSettingValue(l, s.key, s.remote))),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(plan.isEmpty ? l.close : l.cancel),
        ),
        if (widget.canAsk && missing > 0)
          TextButton(
            onPressed: () => Navigator.of(context).pop(_choice(SyncDecision.applyAndAsk)),
            child: Text(l.syncAskMissing),
          ),
        if (!plan.isEmpty)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_choice(SyncDecision.apply)),
            child: Text(removals > 0 ? l.syncApplyRemoving(removals) : l.apply),
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

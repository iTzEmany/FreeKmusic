import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/track_ops.dart';
import '../../../providers/library_providers.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/cc_app_bar.dart';
import '../../theme/tokens.dart';

class MissingTracksScreen extends ConsumerStatefulWidget {
  const MissingTracksScreen({super.key});

  @override
  ConsumerState<MissingTracksScreen> createState() =>
      _MissingTracksScreenState();
}

class _MissingTracksScreenState extends ConsumerState<MissingTracksScreen> {
  final _ignored = <int>{};

  Future<void> _confirmRemove(int id) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.confirmRemoveTitle),
        content: Text(l.confirmRemoveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: Text(l.removeFromLibrary),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(trackOpsProvider).deleteTrack(id);
  }

  Future<void> _confirmRemoveAll(List<int> ids) async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.confirmRemoveAllTitle,
      body: l.confirmRemoveAllBody(ids.length),
      confirmLabel: l.removeAll,
      destructive: true,
    );
    if (!ok) return;
    final repo = ref.read(trackOpsProvider);
    for (final id in ids) {
      await repo.deleteTrack(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = (ref.watch(missingTracksProvider).value ?? const [])
        .where((t) => !_ignored.contains(t.id))
        .toList();
    return Scaffold(
      appBar: CcAppBar(
        title: l.missingTracksTitle,
        actions: [
          if (items.length > 1)
            TextButton(
              onPressed: () =>
                  _confirmRemoveAll(items.map((t) => t.id).toList()),
              child: Text(l.removeAll),
            ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.check_circle_outline,
              message: l.noMissingTracks,
            )
          : ListView.builder(
              padding: EdgeInsets.zero.withDock(context),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final t = items[i];
                return ListTile(
                  title: Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    t.path,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: l.moreActions,
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: () async {
                      final v = await showCcActionSheet<_MissingAction>(
                        context: context,
                        title: t.title,
                        groups: [
                          [
                            CcAction(icon: Icons.visibility_off_outlined, label: l.ignore, value: _MissingAction.ignore),
                            CcAction(icon: Icons.delete_outline_rounded, label: l.removeFromLibrary, value: _MissingAction.remove, destructive: true),
                          ],
                        ],
                      );
                      if (v == null || !mounted) return;
                      if (v == _MissingAction.ignore) {
                        setState(() => _ignored.add(t.id));
                      } else {
                        _confirmRemove(t.id);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

enum _MissingAction { ignore, remove }

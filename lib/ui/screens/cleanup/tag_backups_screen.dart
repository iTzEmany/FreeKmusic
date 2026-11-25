import '../../widgets/cc_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/library_providers.dart';
import '../../../providers/tag_backup_providers.dart';
import '../../../services/tags/tag_backups.dart';
import '../../../services/tags/tag_writer.dart';
import '../../theme/tokens.dart';
import '../../widgets/confirm.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/format_utils.dart';
import '../../widgets/tag_write_ui.dart';
import '../../widgets/show_msg.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/action_catalog.dart';

/// Settings → Tag backups: the original of every file whose tags were
/// rewritten, with «Restore original» and «Delete backup».
class TagBackupsScreen extends ConsumerWidget {
  const TagBackupsScreen({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    TagBackup b,
  ) async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.tagBackupRestore,
      body: l.tagBackupRestoreBody(p.basename(b.path)),
      confirmLabel: l.tagBackupRestore,
    );
    if (!ok) return;
    String msg;
    try {
      await ref.read(tagBackupOpsProvider).restore(b);
      msg = l.tagBackupRestored;
    } on TagWriteException catch (e) {
      msg = l.tagBackupRestoreFailed(tagReasonText(l, e.reason));
    } on Object catch (e, st) {
      AppLog.e('tag backup restore failed', e, st);
      msg = l.tagBackupRestoreFailed(tagReasonText(l, TagWriteReason.ioError));
    }
    if (!context.mounted) return;
    showMsg(context, msg);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, TagBackup b) async {
    final l = context.l10n;
    final ok = await showConfirm(
      context,
      title: l.tagBackupDelete,
      body: l.tagBackupDeleteBody,
      confirmLabel: l.tagBackupDelete,
      destructive: true,
    );
    if (!ok) return;
    await (await ref.read(tagBackupStoreProvider.future)).delete(b);
    ref.invalidate(tagBackupsProvider);
    if (!context.mounted) return;
    showMsg(context, l.tagBackupDeleted);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final backups = ref.watch(tagBackupsProvider).value ?? const <TagBackup>[];
    final fmt = DateFormat.yMd(Localizations.localeOf(context).toString())
        .add_Hm();
    return Scaffold(
      appBar: CcAppBar(title: l.tagBackupsTitle),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: backups.isEmpty
              ? EmptyState(
                  icon: Icons.history_rounded,
                  message: l.tagBackupsEmpty,
                )
              : ListView.builder(
                  itemCount: backups.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.all(CcDims.margin),
                        child: Text(l.tagBackupsHint),
                      );
                    }
                    final b = backups[i - 1];
                    return ListTile(
                      key: ValueKey('tag-backup-${b.id}'),
                      leading: const Icon(Icons.audio_file_outlined),
                      title: Text(p.basename(b.path), maxLines: 1),
                      subtitle: Text(
                        '${fmt.format(b.createdAt)}, ${formatBytes(b.sizeBytes, Localizations.localeOf(context).toString())}\n${p.dirname(b.path)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: l.moreActions,
                        icon: Icon(CatalogAction.more.icon),
                        onPressed: () async {
                          final v = await showCcActionSheet<_BackupAction>(
                            context: context,
                            title: p.basename(b.path),
                            groups: [
                              [
                                CcAction(icon: Icons.restore_rounded, label: l.tagBackupRestore, value: _BackupAction.restore),
                                CcAction(icon: Icons.delete_outline_rounded, label: l.tagBackupDelete, value: _BackupAction.delete, destructive: true),
                              ],
                            ],
                          );
                          if (v == null || !context.mounted) return;
                          if (v == _BackupAction.restore) {
                            _restore(context, ref, b);
                          } else {
                            _delete(context, ref, b);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

enum _BackupAction { restore, delete }

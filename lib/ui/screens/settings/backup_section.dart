import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/app_log.dart';
import '../../../data/repositories/backup_merge.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/backup_ops.dart';
import '../../../services/backup/backup_service.dart';
import '../../../services/backup/restore_service.dart';
import '../../../services/export/save_file.dart';
import '../../widgets/confirm.dart';
import 'restore_dialog.dart';
import '../../widgets/show_msg.dart';

/// «Crea backup» and «Ripristina da backup».
List<Widget> backupTiles(BuildContext context, WidgetRef ref) {
  final l = context.l10n;
  return [
    ListTile(
      leading: const Icon(Icons.backup_outlined),
      title: Text(l.backupCreate),
      subtitle: Text(l.backupCreateHint),
      onTap: () => _create(context, ref),
    ),
    ListTile(
      leading: const Icon(Icons.settings_backup_restore_rounded),
      title: Text(l.backupRestore),
      subtitle: Text(l.backupRestoreHint),
      onTap: () => _restore(context, ref),
    ),
  ];
}

Future<void> _create(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(content: Row(children: [
        const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 16),
        Expanded(child: Text(l.backupCreating)),
      ])),
    ),
  );
  File? tmp;
  String msg;
  try {
    final name = BackupService.fileName(DateTime.now());
    tmp = File(p.join((await Directory.systemTemp.createTemp('codecore-save')).path, name));
    await ref.read(backupOpsProvider).create(tmp.path);
    nav.pop();
    final saved = await saveFileAt(name, tmp.path, mimeType: 'application/zip');
    if (!saved) return;
    msg = l.backupSaved;
  } on Object catch (e, st) {
    AppLog.e('backup failed', e, st);
    if (nav.canPop()) nav.pop();
    msg = l.backupFailed;
  } finally {
    try {
      tmp?.parent.deleteSync(recursive: true);
    } on FileSystemException catch (e) {
      AppLog.w('backup temp not removed', e);
    }
  }
  if (!context.mounted) return;
  showMsg(context, msg);
}

Future<void> _restore(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final picked = await FilePicker.pickFiles();
  final path = picked.isEmpty ? null : picked.first.path;
  if (path == null) return;
  if (!context.mounted) return;
  if (!path.toLowerCase().endsWith('.zip')) return showMsg(context, l.restoreNotBackup);
  try {
    final plan = await ref.read(backupOpsProvider).inspect(File(path));
    if (!context.mounted) return;
    final choice = await showDialog<RestoreChoice>(context: context, builder: (_) => RestoreDialog(plan: plan));
    if (choice == null || !context.mounted) return;
    if (choice == RestoreChoice.replace) {
      final ok = await showConfirm(context,
          title: l.restoreReplaceConfirmTitle,
          body: l.restoreReplaceConfirmBody,
          confirmLabel: l.restoreReplaceGo,
          destructive: true);
      if (!ok) return;
      await ref.read(backupOpsProvider).stageReplace(File(path));
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Text(l.restoreRestartNeeded),
          actions: [
            FilledButton(
              onPressed: () => Platform.isAndroid ? SystemNavigator.pop() : Navigator.pop(ctx),
              child: Text(l.close),
            ),
          ],
        ),
      );
    } else {
      final report = await ref.read(backupOpsProvider).merge(File(path));
      if (!context.mounted) return;
      await _showMergeReport(context, report);
    }
  } on RestoreException catch (e) {
    AppLog.w('restore refused', e);
    if (!context.mounted) return;
    showMsg(context, l.restoreNotBackup);
  } on Object catch (e, st) {
    AppLog.e('restore failed', e, st);
    if (!context.mounted) return;
    showMsg(context, l.restoreFailed);
  }
}

Future<void> _showMergeReport(BuildContext context, MergeReport r) {
  final l = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.restoreMergeDone(r.recognized, r.notFound.length, r.playlistsCreated, r.favoritesAdded)),
          for (final line in [
            if (r.backupDbUnreadable) l.restoreMergeDbUnreadable,
            if (r.tables.playsAdded > 0) l.restoreMergePlays(r.tables.playsAdded),
            if (r.tables.tagsAdded > 0) l.restoreMergeTags(r.tables.tagsAdded),
            if (r.tables.smartPlaylistsAdded > 0) l.restoreMergeSmart(r.tables.smartPlaylistsAdded),
            if (r.tables.podcastsAdded > 0) l.restoreMergePodcasts(r.tables.podcastsAdded),
            if (r.themesDropped > 0) l.restoreMergeThemesDropped(r.themesDropped),
            if (r.tables.playsUnlinked > 0) l.restoreMergeUnlinked(r.tables.playsUnlinked),
          ])
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(line)),
          if (r.notFound.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.restoreNotFound, style: Theme.of(ctx).textTheme.titleSmall),
            SelectableText(r.notFound.join('\n')),
          ],
        ]),
      ),
      actions: [
        if (r.notFound.isNotEmpty)
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: r.notFound.join('\n'))),
            child: Text(l.restoreCopyList),
          ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.close)),
      ],
    ),
  );
}

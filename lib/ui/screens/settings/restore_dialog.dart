import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../core/app_log.dart';
import '../../../providers/backup_ops.dart';
import '../../../services/backup/restore_service.dart';

enum RestoreChoice { replace, merge }

/// What the chosen backup is, and the two ways to use it. «Sostituisci tutto»
/// is offered only for a backup of this very device.
class RestoreDialog extends StatelessWidget {
  const RestoreDialog({super.key, required this.plan});

  final RestorePlan plan;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final date = DateFormat.yMMMd(locale).add_Hm().format(DateTime.fromMillisecondsSinceEpoch(plan.createdAt));
    return AlertDialog(
      title: Text(l.restoreTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.restoreInfo(date, plan.appVersion, plan.trackCount, plan.playlistCount)),
            const SizedBox(height: 12),
            Text(l.restoreMergeHint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        if (plan.sameDevice)
          TextButton(onPressed: () => Navigator.pop(context, RestoreChoice.replace), child: Text(l.restoreReplace)),
        FilledButton(onPressed: () => Navigator.pop(context, RestoreChoice.merge), child: Text(l.restoreMerge)),
      ],
    );
  }
}

/// The restore is staged: the app restarts itself, or asks to be reopened when it cannot.
Future<void> showRestartDialog(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final ops = ref.read(backupOpsProvider);
  final started = ValueNotifier<bool?>(null);
  final dialog = showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ValueListenableBuilder<bool?>(
      valueListenable: started,
      builder: (_, ok, _) => AlertDialog(
        content: Text(ok == false ? l.restoreRestartNeeded : l.restoreRestarting),
        actions: [if (ok == false) FilledButton(onPressed: ops.quit, child: Text(l.close))],
      ),
    ),
  );
  try {
    started.value = await ops.restartAfterRestore();
  } on Object catch (e, st) {
    AppLog.w('restart failed', e, st);
    started.value = false;
  }
  if (started.value == true) {
    // The process should be gone by now: if not, ask the user to close it by hand.
    Timer(const Duration(seconds: 5), () => started.value = false);
    return;
  }
  await dialog;
  started.dispose();
}

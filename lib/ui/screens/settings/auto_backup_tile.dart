import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/backup_providers.dart';
import '../../../providers/settings_providers.dart';

/// R-241: the weekly automatic backup. Turning it on asks for the folder (it stays off
/// if none is chosen). In the settings ([onboarding] false) it also shows the folder and
/// the last backup, and lets the folder change.
class AutoBackupTile extends ConsumerWidget {
  const AutoBackupTile({super.key, this.onboarding = false});

  final bool onboarding;

  Future<void> _pick(WidgetRef ref, {required bool turnOn}) async {
    final path = await FilePicker.getDirectoryPath();
    if (path == null) return;
    ref.read(settingsProvider.notifier).update(
      (s) => s.copyWith(backupFolder: path, autoBackup: turnOn ? true : s.autoBackup),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final on = ref.watch(settingsProvider.select((s) => s.autoBackup));
    final folder = ref.watch(settingsProvider.select((s) => s.backupFolder));
    final last = ref.watch(backupLastAtProvider);
    final dir = isAndroid ? ref.watch(backupFolderProvider).value : null;
    final lastText = last == null ? l.autoBackupNever : DateFormat.yMMMd(l.localeName).format(last);
    final sw = SwitchListTile(
      contentPadding: onboarding ? EdgeInsets.zero : null,
      secondary: onboarding ? null : const Icon(Icons.backup_outlined),
      title: Text(l.autoBackup),
      subtitle: Text(
        isAndroid
            ? (dir == null || dir == kAndroidBackupDir ? l.autoBackupHintAndroid : l.autoBackupHintAndroidApp) +
                  (!onboarding && on ? '\n${l.autoBackupSummary(dir ?? '', lastText)}' : '')
            : onboarding || !on
            ? l.autoBackupHint
            : l.autoBackupSummary(folder, lastText),
      ),
      value: on,
      onChanged: (v) {
        if (!v) {
          ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoBackup: false));
        } else if (!isAndroid && folder.isEmpty) {
          _pick(ref, turnOn: true);
        } else {
          ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoBackup: true));
        }
      },
    );
    if (onboarding || !on || isAndroid) return sw;
    return Column(
      children: [
        sw,
        ListTile(
          leading: const Icon(Icons.folder_outlined),
          title: Text(l.autoBackupFolder),
          subtitle: Text(folder),
          onTap: () => _pick(ref, turnOn: false),
        ),
      ],
    );
  }
}

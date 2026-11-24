import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/update_providers.dart';
import '../../../services/online/update_checker.dart';
import '../../widgets/show_msg.dart' show CcSnackContent;
import 'update_page.dart';

/// «Controlla aggiornamenti» and «Controlla all'avvio». Nothing while no
/// release repository is configured.
List<Widget> updateTiles(BuildContext context, WidgetRef ref) {
  if (ref.watch(releaseRepoProvider).isEmpty) return const [];
  final l = context.l10n;
  return [
    ListTile(
      leading: const Icon(Icons.system_update_alt_rounded),
      title: Text(l.updateCheck),
      subtitle: Text(l.updateCheckHint),
      onTap: () => showUpdate(context),
    ),
    SwitchListTile(
      title: Text(l.updateOnStart),
      subtitle: Text(l.updateOnStartHint),
      value: ref.watch(checkUpdatesOnStartProvider),
      onChanged: ref.read(checkUpdatesOnStartProvider.notifier).set,
    ),
  ];
}

/// The start-up notice: «Aggiorna» opens the update page on the release found.
SnackBar updateSnackBar(BuildContext context, UpdateInfo info, Duration duration) {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  void open() {
    messenger.hideCurrentSnackBar();
    showUpdate(context, info: info);
  }

  return SnackBar(
    duration: duration,
    persist: false, // D-541: every snackbar times out
    content: Semantics(
      button: true,
      child: InkWell(onTap: open, child: CcSnackContent(l.updateAvailable(info.version), duration)),
    ),
    action: SnackBarAction(label: l.updateDo, onPressed: open),
  );
}

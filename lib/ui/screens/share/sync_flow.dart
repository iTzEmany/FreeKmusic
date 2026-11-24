import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/share_hub.dart';
import '../../../services/share/sync_client.dart';
import '../../../services/share/trusted_devices.dart';
import 'sync_preview_dialog.dart';
import '../../widgets/show_msg.dart';

/// «Sincronizza ora» with an own [device] (playlists and the rest) or «Sincronizza playlist» with another trusted one:
/// read, show what would change, and write only after the user confirms. Started only by the user.
Future<void> syncFlow(BuildContext context, WidgetRef ref, TrustedDevice device) async {
  final l = context.l10n;
  final hub = ref.read(shareHubProvider.notifier);
  try {
    final plan = await hub.planPlaylistSync(device);
    if (!context.mounted) return;
    final choice = await showSyncPreview(context, plan, canAsk: true, mine: device.mine);
    if (choice == null) return;
    final written = await hub.applyPlaylistSync(plan, collections: device.mine);
    if (device.mine) hub.applySettingsSync(plan, choice.settings);
    if (!context.mounted) return;
    if (choice.decision == SyncDecision.applyAndAsk) {
      final asked = await hub.askMissingTracks(device, plan);
      if (!context.mounted) return;
      showMsg(context, l.syncAsked(asked));
    } else if (device.mine) {
      final c = plan.collections;
      showMsg(context, l.syncDone(written + c.additions + c.deletes.length + choice.settings.length));
    } else {
      showMsg(context, l.syncApplied(written));
    }
  } on SyncException catch (e) {
    AppLog.w('sync failed', e);
    if (!context.mounted) return;
    showMsg(context, switch (e.error) {
      SyncError.unreachable => l.syncUnreachable,
      SyncError.identityChanged => l.shareErrIdentity,
      _ => l.syncFailed,
    });
  } on Object catch (e, st) {
    AppLog.e('playlist sync failed', e, st);
    if (!context.mounted) return;
    showMsg(context, l.syncFailed);
  }
}

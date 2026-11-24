import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/share_hub.dart';
import '../../../services/share/sync_client.dart';
import '../../../services/share/trusted_devices.dart';
import 'sync_preview_dialog.dart';
import '../../widgets/show_msg.dart';

/// «Sincronizza playlist» with [device]: read its playlists, show what would
/// change, and write only after «Applica». Started only by the user.
Future<void> syncFlow(BuildContext context, WidgetRef ref, TrustedDevice device) async {
  final l = context.l10n;
  final hub = ref.read(shareHubProvider.notifier);
  try {
    final plan = await hub.planPlaylistSync(device);
    if (!context.mounted) return;
    final decision = await showSyncPreview(context, plan, canAsk: true);
    if (decision == null) return;
    final written = await hub.applyPlaylistSync(plan);
    if (!context.mounted) return;
    if (decision == SyncDecision.applyAndAsk) {
      final asked = await hub.askMissingTracks(device, plan);
      if (!context.mounted) return;
      showMsg(context, l.syncAsked(asked));
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

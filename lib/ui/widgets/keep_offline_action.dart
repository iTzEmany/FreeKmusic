import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Track;
import '../../l10n/l10n_ext.dart';
import '../../providers/keep_offline_providers.dart';
import 'confirm.dart';
import 'show_msg.dart';

/// «Tieni offline» on a playlist or album (D-578): downloads the tracks that are streams with no file.
Future<void> keepOfflineFlow(BuildContext context, WidgetRef ref, Iterable<Track> tracks) async {
  final ask = await ref.read(keepOfflineMeteredAskProvider)(tracks);
  if (ask != null) {
    if (!context.mounted) return;
    final l = context.l10n;
    if (!await showConfirm(context, title: l.keepOfflineMeteredAsk(ask.count, ask.mb), confirmLabel: l.updateDownload)) return;
  }
  final n = await ref.read(keepOfflineProvider)(tracks);
  if (context.mounted) _report(context, n);
}

/// As [keepOfflineFlow], for library rows given by id.
Future<void> keepOfflineIdsFlow(BuildContext context, WidgetRef ref, List<int> ids) async {
  final tracks = await ref.read(keepOfflineTracksOfIdsProvider)(ids);
  if (context.mounted) await keepOfflineFlow(context, ref, tracks);
}

void _report(BuildContext context, int n) {
  final l = context.l10n;
  showMsg(context, n == 0 ? l.keepOfflineAlready : l.keepOfflineQueued(n));
}

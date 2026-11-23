import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Track;
import '../../l10n/l10n_ext.dart';
import '../../providers/keep_offline_providers.dart';
import 'show_msg.dart';

/// «Tieni offline» on a playlist or album (D-578): downloads the tracks that are streams with no file.
Future<void> keepOfflineFlow(BuildContext context, WidgetRef ref, Iterable<Track> tracks) async {
  final n = await ref.read(keepOfflineProvider)(tracks);
  if (context.mounted) _report(context, n);
}

/// As [keepOfflineFlow], for library rows given by id.
Future<void> keepOfflineIdsFlow(BuildContext context, WidgetRef ref, List<int> ids) async {
  final n = await ref.read(keepOfflineIdsProvider)(ids);
  if (context.mounted) _report(context, n);
}

void _report(BuildContext context, int n) {
  final l = context.l10n;
  showMsg(context, n == 0 ? l.keepOfflineAlready : l.keepOfflineQueued(n));
}

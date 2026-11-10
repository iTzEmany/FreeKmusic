import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/player_providers.dart';
import '../../providers/shazam_providers.dart';
import '../../providers/nav_providers.dart';
import '../../providers/ui_providers.dart';
import '../../services/online/shared_text.dart' show ShazamShare;
import '../widgets/show_msg.dart';
import 'shell_nav.dart';

/// Cerca with [query] already typed, on top of whatever is open in its tab.
void openSearchWith(BuildContext context, WidgetRef ref, String query) {
  ref.read(searchPrefillProvider.notifier).set(query);
  // A page pushed in the Search tab would hide the field.
  ref.read(tabNavigatorKeysProvider)[NavTab.search.index].currentState?.popUntil((r) => r.isFirst);
  ShellNav.showSearch(context, ref);
}

// A shared title is arbitrary text: keep the snackbar small.
String _short(String t) => t.length <= 80 ? t : '${t.substring(0, 80)}…';

/// A song shared from Shazam: adds it to «Da Shazam» and tells what happened.
Future<void> handleShazamShare(BuildContext context, WidgetRef ref, ShazamShare s) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  final r = await ref.read(shazamInboxProvider).add(s);
  if (!messenger.mounted || !context.mounted) return;
  switch (r) {
    case ShazamAdded(:final title, :final online, :final track):
      showMsgOn(
        messenger,
        l.shazamAdded(_short(title)),
        action: SnackBarAction(
          label: l.listenAction,
          onPressed: () => ref.read(playerControllerProvider).playFromSearch(online: online, track: track),
        ),
        persist: true,
      );
    case ShazamDuplicate(:final title):
      showMsgOn(messenger, l.shazamDuplicate(_short(title)));
    case ShazamNotFound():
      showMsgOn(
        messenger,
        l.shazamNotFound(_short(s.title)),
        action: SnackBarAction(
          label: l.searchHint,
          onPressed: () => openSearchWith(context, ref, '${s.title} ${s.artist}'),
        ),
        persist: true,
      );
    case ShazamRetry():
      showMsgOn(
        messenger,
        l.shazamOffline,
        action: SnackBarAction(label: l.retry, onPressed: () => handleShazamShare(context, ref, s)),
        persist: true,
      );
  }
}

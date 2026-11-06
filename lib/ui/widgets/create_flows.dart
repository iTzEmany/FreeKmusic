import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/playlist_ops.dart';
import '../../providers/tag_ops.dart';
import '../screens/import/import_flow.dart';
import '../screens/playlists/playlist_detail_screen.dart';
import '../screens/playlists/playlist_picker.dart' show PickedPlaylist;
import '../../providers/nav_providers.dart';
import '../shell/shell_nav.dart';
import 'playlist_sheet.dart';
import 'prompt_name.dart';

/// «New playlist» sheet (D-405): a tap on a playlist or «Crea» opens it; the
/// smart and CSV rows run [onSmart] and the CSV import. Null when dismissed or
/// when a shortcut was taken.
Future<PickedPlaylist?> createPlaylistFlow(BuildContext context, WidgetRef ref, {VoidCallback? onSmart}) async {
  final r = await showPlaylistSheet(context, shortcuts: onSmart != null);
  if (r == null || !context.mounted) return null;
  switch (r.shortcut) {
    case PlaylistSheetShortcut.smart:
      onSmart?.call();
    case PlaylistSheetShortcut.csv:
      await startCsvImport(context, ref);
    case null:
      final picked = r.playlist!;
      final p = (await ref.read(playlistOpsProvider).visible()).where((p) => p.id == picked.id).firstOrNull;
      if (p == null || !context.mounted) return picked;
      final page = PlaylistDetailScreen(playlist: p);
      // Without a shell (a lone screen) the page opens on the current navigator.
      if (ref.read(tabNavigatorKeysProvider)[NavTab.library.index].currentState == null) {
        ShellNav.open<void>(context, page);
      } else {
        ShellNav.openInLibrary(context, ref, page);
      }
      return picked;
  }
  return null;
}

/// «New tag» (max 40): asks the name and creates it, giving it to [assignTo] too.
/// Null when cancelled, or when the row read back is not the one just made.
Future<UserTag?> createTagFlow(BuildContext context, WidgetRef ref, {List<int> assignTo = const []}) async {
  final l = context.l10n;
  final name = await promptName(context, title: l.tagNew, confirmLabel: l.save, maxLength: 40);
  if (name == null || !context.mounted) return null;
  return ref.read(tagOpsProvider).create(name, assignTo: assignTo);
}

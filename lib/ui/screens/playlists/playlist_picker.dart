import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/playlist_sheet.dart';

/// A playlist chosen from the sheet (or created there).
typedef PickedPlaylist = ({int id, String name});

/// Asks which playlists to use (several can be ticked), without adding
/// anything yet. Empty when the sheet is dismissed.
Future<List<PickedPlaylist>> pickPlaylist(BuildContext context, WidgetRef ref) => pickPlaylistsMulti(context);

/// What to say after an online result went to [picked]: [now] false means it
/// joins when downloaded. [count] > 1 is a batch of songs into one playlist.
String pickedAddedText(AppLocalizations l, List<PickedPlaylist> picked, {required bool now, int count = 1}) {
  if (picked.length > 1) return l.addedToNPlaylists(picked.length);
  final name = picked.single.name;
  if (!now) return l.suggestionAddWhenDownloaded(name);
  return count > 1 ? l.addedToPlaylistMany(count, name) : l.addedToPlaylist(name);
}

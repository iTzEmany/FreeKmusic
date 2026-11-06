import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/playlist_sheet.dart';

/// A playlist chosen from the sheet (or created there).
typedef PickedPlaylist = ({int id, String name});

/// Asks which playlist to use, without adding anything yet. Null when the
/// sheet is dismissed.
Future<PickedPlaylist?> pickPlaylist(BuildContext context, WidgetRef ref) async =>
    (await showPlaylistSheet(context))?.playlist;

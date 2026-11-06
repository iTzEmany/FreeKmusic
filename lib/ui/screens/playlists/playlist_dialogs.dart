import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/playlist_sheet.dart';

/// What to say after adding [total] tracks of which [added] were new. One
/// track keeps the short message; several say how many were already there.
String addedToPlaylistText(
  AppLocalizations l, {
  required int total,
  required int added,
  required String name,
}) {
  final skipped = total - added;
  if (added == 0) return l.allAlreadyInPlaylist(name);
  if (total == 1) return l.addedToPlaylist(name);
  if (skipped == 0) return l.addedToPlaylistMany(added, name);
  return l.addedToPlaylistSkipped(added, skipped, name);
}

/// Bottom sheet to add tracks to an existing or a new playlist (the shared
/// [showPlaylistSheet]). Resolves to true when they were added.
Future<bool> showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<Track> tracks,
) async => await showPlaylistSheet(context, tracks: tracks) != null;

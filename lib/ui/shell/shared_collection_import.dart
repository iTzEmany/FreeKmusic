import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/online_collection_providers.dart' show saveToLibrary;
import '../../providers/youtube_providers.dart' show youtubeServiceProvider;
import '../../services/online/external_collection.dart';
import '../../services/online/shared_text.dart';
import '../widgets/show_msg.dart';

/// A link of the share page (D-702): looks the shared videos up and saves them as a
/// playlist with the existing «Salva in Libreria» (D-524). A bad link only tells so.
Future<void> handleSharedPage(BuildContext context, WidgetRef ref, SharedText s) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  if (s is! SharedCollection) return showMsgOn(messenger, l.loadFailed);
  final f = s.fragment;
  final yt = ref.read(youtubeServiceProvider);
  final matches = <TrackMatch>[];
  // shortcut: one lookup per id, four at a time; upgrade if a batch endpoint appears.
  for (var i = 0; i < f.ids.length; i += 4) {
    final batch = f.ids.skip(i).take(4);
    final found = await Future.wait([
      for (final id in batch)
        yt.search('https://www.youtube.com/watch?v=$id').then<TrackMatch>(
          (r) => r.isEmpty ? const TrackNotFound() : TrackReadyOnline(r.first),
          onError: (Object e, StackTrace st) {
            AppLog.w('shared page: lookup failed for $id', e, st);
            return const TrackNotFound();
          },
        ),
    ]);
    matches.addAll(found);
  }
  if (!context.mounted) return;
  final name = await saveToLibrary(ref, f.title, matches, fallback: l.newPlaylist);
  showMsgOn(messenger, name == null ? l.extSaveNothing : l.extSavedAs(name));
}

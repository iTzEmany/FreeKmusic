import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../core/constants.dart' show kEnableYoutube;
import '../../l10n/l10n_ext.dart';
import '../../providers/online_collection_providers.dart' show saveToLibrary;
import '../../providers/shuffle_plus_providers.dart' show networkProbeProvider;
import '../../providers/youtube_providers.dart' show youtubeServiceProvider;
import '../../services/online/external_collection.dart';
import '../../services/online/shared_text.dart';
import '../../services/share/share_fragment.dart' show SharedKind;
import '../widgets/confirm.dart';
import '../widgets/show_msg.dart';
import 'shazam_share.dart' show openSearchWith, shortTitle;

bool _busy = false; // one import at a time

/// A link of the share page (D-702): a track opens in Cerca; a list asks first, then looks the
/// videos up and saves them as a playlist with «Salva in Libreria» (D-524). A bad link only tells so.
Future<void> handleSharedPage(BuildContext context, WidgetRef ref, SharedText s) async {
  final messenger = ScaffoldMessenger.of(context);
  final l = context.l10n;
  if (s is! SharedCollection) return showMsgOn(messenger, l.shareLinkInvalid);
  final f = s.fragment;
  if (f.kind == SharedKind.track) {
    return openSearchWith(context, ref, 'https://music.youtube.com/watch?v=${f.ids.first}');
  }
  if (!kEnableYoutube) return showMsgOn(messenger, l.shareImportNeedsYoutube);
  if (_busy) return showMsgOn(messenger, l.shareImportBusy);
  _busy = true;
  try {
    if (!(await ref.read(networkProbeProvider).current()).online) {
      return showMsgOn(messenger, l.shareImportOffline);
    }
    if (!context.mounted) return;
    final ok = await showConfirm(
      context,
      title: shortTitle(f.title),
      body: l.tracksCount(f.ids.length),
      confirmLabel: l.extSaveToLibrary,
    );
    if (!ok || !context.mounted) return;
    showMsgOn(messenger, l.shareImportSearching(f.ids.length));
    final matches = await _lookUp(ref, f.ids);
    if (!context.mounted) return;
    final String? name;
    try {
      name = await saveToLibrary(ref, f.title, matches, fallback: l.newPlaylist);
    } on Object catch (e, st) {
      AppLog.w('shared page: playlist not saved', e, st);
      return showMsgOn(messenger, l.loadFailed);
    }
    if (!messenger.mounted) return;
    final found = matches.whereType<TrackReady>().length;
    showMsgOn(
      messenger,
      name == null
          ? l.extSaveNothing
          : found == f.ids.length
              ? l.extSavedAs(shortTitle(name))
              : l.extSavedPartial(shortTitle(name), found, f.ids.length),
    );
  } finally {
    _busy = false;
  }
}

// shortcut: one lookup per id, four at a time (innerTube.songOf lacks cover and ids that a
// saved row needs); upgrade if a batch endpoint appears.
Future<List<TrackMatch>> _lookUp(WidgetRef ref, List<String> ids) async {
  final yt = ref.read(youtubeServiceProvider);
  final matches = <TrackMatch>[];
  for (var i = 0; i < ids.length; i += 4) {
    matches.addAll(await Future.wait([
      for (final id in ids.skip(i).take(4))
        yt.search('https://www.youtube.com/watch?v=$id').then<TrackMatch>(
          (r) => r.isEmpty ? const TrackNotFound() : TrackReadyOnline(r.first),
          onError: (Object e, StackTrace st) {
            AppLog.w('shared page: lookup failed for $id', e, st);
            return const TrackNotFound();
          },
        ),
    ]));
  }
  return matches;
}

import 'dart:async' show TimeoutException;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../core/constants.dart' show kEnableYoutube;
import '../../l10n/l10n_ext.dart';
import '../../providers/online_collection_providers.dart' show saveToLibrary;
import '../../providers/shuffle_plus_providers.dart' show networkProbeProvider;
import '../../providers/smart_search_providers.dart' show collectionMatcherProvider;
import '../../providers/youtube_providers.dart' show youtubeServiceProvider;
import '../../services/online/external_collection.dart';
import '../../services/online/shared_text.dart';
import '../../services/online/youtube_service.dart' show YtErrorKind, YtException;
import '../../services/share/share_fragment.dart' show SharedKind, SharedRow;
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
    final r = f.rows.first;
    return openSearchWith(
      context,
      ref,
      r.id != null ? 'https://music.youtube.com/watch?v=${r.id}' : '${r.artist} ${r.title}'.trim(),
    );
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
      body: l.tracksCount(f.rows.length),
      confirmLabel: l.extSaveToLibrary,
    );
    if (!ok || !context.mounted) return;
    showMsgOn(messenger, l.shareImportSearching(f.rows.length));
    final matches = await _lookUp(ref, f.rows);
    if (!context.mounted) return;
    if (matches == null) return showMsgOn(messenger, l.shareImportNetwork);
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
          : found == f.rows.length
              ? l.extSavedAs(shortTitle(name))
              : l.extSavedPartial(shortTitle(name), found, f.rows.length),
    );
  } finally {
    _busy = false;
  }
}

/// The rows with an id are looked up by it, the others by artist + title like an imported playlist (D-713);
/// a row that is not found stays in the list as «non trovato». Null: the ids failed on the network.
Future<List<TrackMatch>?> _lookUp(WidgetRef ref, List<SharedRow> rows) async {
  final out = <TrackMatch>[for (final _ in rows) const TrackNotFound()];
  final idAt = [for (var i = 0; i < rows.length; i++) if (rows[i].id != null) i];
  if (idAt.isNotEmpty) {
    final found = await _lookUpIds(ref, [for (final i in idAt) rows[i].id!]);
    if (found == null) return null;
    for (var k = 0; k < idAt.length; k++) {
      out[idAt[k]] = found[k];
    }
  }
  final searchAt = [for (var i = 0; i < rows.length; i++) if (rows[i].id == null) i];
  if (searchAt.isEmpty) return out;
  final sub = ref.listenManual(collectionMatcherProvider(Object()), (_, _) {});
  try {
    final wanted = [
      for (final i in searchAt)
        ExternalTrack(title: rows[i].title!, artists: [if (rows[i].artist!.isNotEmpty) rows[i].artist!], key: '$i'),
    ];
    await for (final (k, m) in sub.read().match(wanted)) {
      out[searchAt[k]] = m;
    }
  } finally {
    sub.close();
  }
  // Every row failed for a passing reason (offline): tell the network, do not save a list of «non trovato».
  if (out.every((m) => m is TrackNotFound && m.transient)) return null;
  return out;
}

// shortcut: one lookup per id, four at a time (innerTube.songOf lacks cover and ids that a
// saved row needs); upgrade if a batch endpoint appears.
// Null: a whole batch failed on the network and nothing was found, so the rest is not tried.
Future<List<TrackMatch>?> _lookUpIds(WidgetRef ref, List<String> ids) async {
  final yt = ref.read(youtubeServiceProvider);
  final matches = <TrackMatch>[];
  for (var i = 0; i < ids.length; i += 4) {
    var netFails = 0;
    final batch = await Future.wait([
      for (final id in ids.skip(i).take(4))
        yt.search('https://www.youtube.com/watch?v=$id').then<TrackMatch>(
          (r) => r.isEmpty ? const TrackNotFound() : TrackReadyOnline(r.first),
          onError: (Object e, StackTrace st) {
            AppLog.w('shared page: lookup failed for $id', e, st);
            if (e is TimeoutException || (e is YtException && e.kind == YtErrorKind.network)) netFails++;
            return const TrackNotFound();
          },
        ),
    ]);
    matches.addAll(batch);
    if (netFails == batch.length && !matches.any((m) => m is TrackReady)) return null;
  }
  return matches;
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/dislike_lists_provider.dart';
import '../../../providers/dislike_store_provider.dart';
import '../../../services/shuffle_plus/dislike_store.dart';
import '../../theme/tokens.dart';
import '../../widgets/async_body.dart' show RowsLoading;
import '../../widgets/cc_app_bar.dart';
import '../../widgets/show_msg.dart';

/// Settings → «Non mi piace»: the blocked songs and artists, each with «Togli» (and Annulla).
class DislikesScreen extends ConsumerStatefulWidget {
  const DislikesScreen({super.key});

  @override
  ConsumerState<DislikesScreen> createState() => _DislikesScreenState();
}

class _DislikesScreenState extends ConsumerState<DislikesScreen> {
  bool _artists = false;

  void _removed(String name, VoidCallback undo) {
    final l = context.l10n;
    showMsg(
      context,
      l.dislikesRemoved(name),
      action: SnackBarAction(label: l.undo, onPressed: undo),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(dislikeListsProvider);
    final lists = async.value;
    if (async.hasError) {
      AppLog.w('dislikes list failed', async.error, async.stackTrace);
    }
    final store = ref.read(dislikeStoreProvider);
    final tracks = lists?.tracks ?? const <DislikedTrack>[];
    final artists = lists?.artists ?? const <DislikedArtist>[];
    final loading = lists == null && !async.hasError;
    final empty = _artists ? artists.isEmpty : tracks.isEmpty;
    // Not a ListTile: it would merge «Togli» into the row and hide its own tap action.
    Widget row(
      String title,
      String? subtitle,
      int? at,
      IconData icon,
      VoidCallback remove,
    ) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CcDims.margin,
        vertical: CcDims.gap4,
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: CcDims.gap16),
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (subtitle != null && subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (at != null)
                    Text(
                      l.dislikesBlockedOn(
                        DateFormat.MMMd(
                          Localizations.localeOf(context).toString(),
                        ).format(DateTime.fromMillisecondsSinceEpoch(at)),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          Semantics(
            container: true,
            button: true,
            label: l.dislikesRemoveLabel(title),
            excludeSemantics: true,
            onTap: remove,
            child: TextButton(onPressed: remove, child: Text(l.dislikesRemove)),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: CcAppBar(title: l.dislikesTitle),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CcDims.margin,
              0,
              CcDims.margin,
              CcDims.gap8,
            ),
            child: Text(
              l.dislikesHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            child: Wrap(
              spacing: CcDims.gap8,
              children: [
                ChoiceChip(
                  key: const ValueKey('dislikes-tab-tracks'),
                  label: Text(l.dislikesTracksTab(tracks.length)),
                  selected: !_artists,
                  onSelected: (_) => setState(() => _artists = false),
                ),
                ChoiceChip(
                  key: const ValueKey('dislikes-tab-artists'),
                  label: Text(l.dislikesArtistsTab(artists.length)),
                  selected: _artists,
                  onSelected: (_) => setState(() => _artists = true),
                ),
              ],
            ),
          ),
          if (loading)
            const SizedBox(height: 300, child: RowsLoading())
          else if (empty)
            Padding(
              key: const ValueKey('dislikes-empty'),
              padding: const EdgeInsets.all(CcDims.margin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _artists ? l.dislikesEmptyArtists : l.dislikesEmptyTracks,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: CcDims.gap4),
                  Text(l.dislikesEmptyHint),
                ],
              ),
            )
          else if (_artists)
            for (final a in artists)
              row(a.name, null, a.at, Icons.person_outline, () {
                store.unblockArtist(a.key);
                _removed(a.name, () => store.blockArtist(a));
              })
          else
            for (final t in tracks)
              row(t.title, t.artist, t.at, Icons.music_note_outlined, () {
                store.unblockTrack(t.videoId);
                _removed(t.title, () => store.blockTrack(t));
              }),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_log.dart';
import '../../core/artist_key.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/dislike_store_provider.dart';
import '../../providers/player_providers.dart';
import '../../providers/suggestion_actions.dart';
import 'cc_sheet.dart';
import 'show_msg.dart';

/// «Non ti piace il brano o l'artista?» for the queue entry [queueId]: two
/// choices, then a 4 s notice whose «Annulla» unblocks and restarts the song (D-446).
Future<void> showDislikeSheet(
  BuildContext context,
  WidgetRef ref,
  int queueId,
) async {
  final r = ref.read(onlineEntriesProvider)?[queueId]?.result;
  if (r == null) return;
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final artist = r.artists.isEmpty ? r.channel : r.artists.first;
  var picked =
      false; // a second tap while the sheet closes must not pop the page below
  final artistChoice = await showCcSheet<bool>(
    context: context,
    barrierLabel: l.close,
    builder: (sheet) {
      void pick(bool? v) {
        if (picked) return;
        picked = true;
        Navigator.pop(sheet, v);
      }

      return SafeArea(
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: l.dislikeSheetTitle,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.dislikeSheetTitle,
                    style: Theme.of(sheet).textTheme.titleMedium,
                  ),
                ),
              ),
              _Choice(
                key: const ValueKey('dislike-track'),
                icon: Icons.thumb_down_outlined,
                title: l.dislikeSheetTrack,
                hint: l.dislikeSheetTrackHint(r.title),
                onTap: () => pick(false),
              ),
              // A name with no letters has an empty key: it would block them all.
              if (artistKey(artist).isNotEmpty)
                _Choice(
                  key: const ValueKey('dislike-artist'),
                  icon: Icons.close_rounded,
                  title: l.dislikeSheetArtist(artist),
                  hint: l.dislikeSheetArtistHint(artist),
                  onTap: () => pick(true),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () => pick(null),
                    child: Text(l.cancel),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (artistChoice == null || !context.mounted) return;
  final actions = ref.read(suggestionActionsProvider);
  // The notice shows at once; the action (the next song may load) runs meanwhile.
  final done = () async {
    try {
      return await (artistChoice
          ? actions.dislikeArtist(queueId)
          : actions.dislikeTrack(queueId));
    } on Object catch (e, st) {
      AppLog.w('dislike failed', e, st);
      return null;
    }
  }();
  showMsgOn(
    messenger,
    artistChoice ? l.dislikeArtistDone(artist) : l.suggestionDisliked,
    action: SnackBarAction(
      label: l.undo,
      onPressed: () async {
        try {
          final u = await done;
          if (u != null) await actions.undo(u);
        } on Object catch (e, st) {
          AppLog.w('dislike undo failed', e, st);
        }
      },
    ),
    duration: const Duration(seconds: 4),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final IconData icon;
  final String title, hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 72,
    leading: Icon(icon),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(hint, maxLines: 2, overflow: TextOverflow.ellipsis),
    onTap: onTap,
  );
}

/// Lock mark next to the name of a blocked artist (D-468); nothing otherwise.
/// With [label] it also says «Artista bloccato» (the artist's page).
class BlockedArtistMark extends ConsumerWidget {
  const BlockedArtistMark(this.name, {super.key, this.label = false});

  final String name;
  final bool label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = artistKey(name);
    final blocked = ref.watch(
      blockedArtistKeysProvider.select((v) => v.value?.contains(key) ?? false),
    );
    if (!blocked) return const SizedBox.shrink();
    final l = context.l10n;
    final color = Theme.of(context).textTheme.bodySmall?.color;
    return Semantics(
      label: l.artistBlockedLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.block, size: 14, color: color),
          ),
          if (label)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                l.artistBlockedLabel,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

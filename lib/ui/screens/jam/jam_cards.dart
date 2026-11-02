import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../services/jam/jam_models.dart';
import '../../theme/tokens.dart';
import '../now_playing/now_playing_cards.dart' show NpCard;
import '../now_playing/proposal_card.dart' show CoverLine;
import 'jam_parts.dart' show jamTriviaText;
import 'jam_track_info_screen.dart';

// The player's LyricsCard and InfoCard are built on a local `Track` (synced
// lyrics, a curiosity search that writes to the library): a shared item has
// neither, so the Jam shows what its owner sends (fetchMeta) on the same card.

void _openInfo(BuildContext context, JamItem item) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => JamTrackInfoScreen(itemId: item.id),
      ),
    );

/// The first lines of the plain lyrics of the playing item; tap opens the info.
class JamLyricsCard extends ConsumerWidget {
  const JamLyricsCard({super.key, required this.item});

  final JamItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final lyrics = ref.watch(jamTrackMetaProvider(item.id)).value?.lyricsPlain;
    final has = lyrics != null && lyrics.isNotEmpty;
    return NpCard(
      title: l.lyrics,
      onTap: () => _openInfo(context, item),
      child: has
          ? Text(
              lyrics,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: theme.bodyMedium,
            )
          : Text(
              l.noLyrics,
              style: theme.bodyMedium?.copyWith(color: context.cc.textMuted),
            ),
    );
  }
}

/// The song's curiosity as sent by its owner («text\nurl»: the url is the
/// source and stays out of the card).
class JamInfoCard extends ConsumerWidget {
  const JamInfoCard({super.key, required this.item});

  final JamItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final raw = ref.watch(jamTrackMetaProvider(item.id)).value?.curiosities;
    final text = jamTriviaText(raw);
    final has = text != null;
    final remote = ref.watch(jamProvider.select((j) => j.remote));
    return NpCard(
      title: l.fieldCuriosity,
      onTap: () => _openInfo(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A LAN library item has a video id too, but asking about it would hit the network.
          CoverLine(videoId: item.selfFetchable || remote ? item.videoId : null),
          Text(
            has ? text : l.curiosityNoSong,
            maxLines: 8,
            overflow: TextOverflow.ellipsis,
            style: has
                ? theme.bodyMedium
                : theme.bodyMedium?.copyWith(color: context.cc.textMuted),
          ),
        ],
      ),
    );
  }
}

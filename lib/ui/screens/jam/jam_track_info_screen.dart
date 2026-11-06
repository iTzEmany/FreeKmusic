import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/jam_providers.dart';
import '../../../services/jam/jam_models.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/credits_section.dart';
import '../../widgets/track_artists_sheet.dart';
import 'jam_parts.dart';

/// Info on a track of the shared queue: cover (own tracks), tags and lyrics from
/// its owner. Light: the data comes from [jamTrackMetaProvider].
class JamTrackInfoScreen extends ConsumerWidget {
  const JamTrackInfoScreen({super.key, required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final s = ref.watch(jamProvider);
    final item = s.jam?.items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) {
      return Scaffold(appBar: CcAppBar(title: l.trackInfo));
    }
    final meta = ref.watch(jamTrackMetaProvider(itemId)).value;
    final line = [
      meta?.artist ?? item.artist,
      meta?.album ?? item.album,
      meta?.year?.toString(),
      meta?.genre,
    ].whereType<String>().join(', ');
    final lyrics = meta?.lyricsPlain;
    final cover = ref.watch(jamTrackCoverProvider(itemId)).value;
    final trivia = jamTriviaText(meta?.curiosities);
    return Scaffold(
      appBar: CcAppBar(title: l.trackInfo),
      body: ListView(
        padding: const EdgeInsets.all(CcDims.margin).withDock(context),
        children: [
          Center(
            child: cover == null
                ? JamCover(item: item, size: 200, radius: CcDims.rList)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(CcDims.rList),
                    child: Image.memory(
                      cover,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(height: CcDims.gap16),
          Text(meta?.title ?? item.title, style: theme.headlineSmall),
          if (line.isNotEmpty) Text(line, style: theme.bodyMedium),
          if (jamArtists(item, ref).isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.person_outline_rounded),
                label: Text(l.goToArtist),
                onPressed: () =>
                    goToArtists(context, ref, jamArtists(item, ref)),
              ),
            ),
          const SizedBox(height: CcDims.gap16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: () {
                ref.read(jamProvider.notifier).send(JamCommand.jump(item.id));
                Navigator.of(context).maybePop();
              },
              child: Text(l.jamJumpHere),
            ),
          ),
          if (trivia != null) ...[
            const SizedBox(height: CcDims.gap24),
            Text(l.fieldCuriosity, style: theme.titleMedium),
            const SizedBox(height: CcDims.gap8),
            Text(trivia, style: theme.bodyMedium),
          ],
          // fetchMeta already reads local data for our own tracks.
          if (meta != null &&
              CreditsSection.hasContent(meta.credits, meta.details)) ...[
            const SizedBox(height: CcDims.gap24),
            Text(l.creditsTitle, style: theme.titleMedium),
            const SizedBox(height: CcDims.gap8),
            CreditsSection(meta.credits, meta.details),
          ],
          if (lyrics != null && lyrics.isNotEmpty) ...[
            const SizedBox(height: CcDims.gap24),
            Text(l.lyrics, style: theme.titleMedium),
            const SizedBox(height: CcDims.gap8),
            Text(lyrics, style: theme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

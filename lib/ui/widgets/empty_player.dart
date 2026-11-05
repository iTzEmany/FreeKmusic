import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Track;
import '../../l10n/app_localizations.dart' show AppLocalizations;
import '../../l10n/l10n_ext.dart';
import '../../providers/library_providers.dart' show recentlyAddedTracksProvider;
import '../../providers/player_providers.dart';
import '../../providers/track_ops.dart';
import '../theme/tokens.dart';
import 'cc_tile.dart';
import 'track_art.dart';

/// «Title, artist» of a song, for the line under «Niente in riproduzione».
String songName(Track t) => t.artist == null ? t.title : '${t.title}, ${t.artist}';

/// The line under «Niente in riproduzione»: the last queue, else a hint.
String emptyPlayerSubtitle(BuildContext context, LastQueue? last) => last == null
    ? context.l10n.playerEmptyNoQueue
    : context.l10n.playerLastQueue(songName(last.first));

/// The tooltip of ▶ when nothing plays: what it starts (see `TrackOps.playWhenEmpty`).
String emptyPlayerAction(AppLocalizations l, LastQueue? last) =>
    last == null ? l.playerShufflePlusLibrary : l.playerResumeLastQueue;

/// The quiet disc of the mini player and the desktop bar with nothing playing.
class EmptyPlayerDisc extends StatelessWidget {
  const EmptyPlayerDisc({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return DecoratedBox(
      decoration: BoxDecoration(color: cc.surface3, shape: BoxShape.circle),
      child: SizedBox.square(
        dimension: size,
        child: Icon(Icons.music_note_rounded, color: cc.textMuted),
      ),
    );
  }
}

/// The body of the open player with nothing in it: a live title and three
/// ways to start (D-364).
class EmptyPlayerBody extends ConsumerWidget {
  const EmptyPlayerBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final last = ref.watch(lastQueueProvider).value;
    final recent = ref.watch(recentlyAddedTracksProvider).value ?? const <Track>[];
    final ctrl = ref.read(playerControllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, 0, CcDims.margin, CcDims.gap24),
      children: [
        Semantics(
          liveRegion: true,
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.playerEmptyTitle, style: theme.headlineSmall),
              const SizedBox(height: CcDims.gap8),
              Text(l.playerEmptyHint, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: CcDims.gap16),
        if (last != null)
          _Tile(
            accent: true,
            icon: Icons.play_arrow_rounded,
            title: l.playerResumeLastQueue,
            subtitle: l.playerResumeLastQueueSub(songName(last.first), l.tracksCount(last.count)),
            onTap: ctrl.resumeLastQueue,
          ),
        _Tile(
          icon: Icons.shuffle_rounded,
          title: l.playerShufflePlusLibrary,
          subtitle: l.playerShufflePlusLibrarySub,
          onTap: ref.read(trackOpsProvider).playLibraryPlus,
        ),
        if (recent.isNotEmpty)
          _Tile(
            icon: Icons.schedule_rounded,
            title: l.playerRecentlyAdded,
            subtitle: l.tracksCount(recent.length),
            covers: recent.take(3).toList(),
            onTap: () => ctrl.playFromList(recent, 0, context: const PlayContext(PlayContextKind.library)),
          ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
    this.covers = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;
  final List<Track> covers;

  static const _cover = 34.0;
  static const _step = 20.0;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final fg = accent ? cc.onAccent : cc.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: CcDims.gap12),
      child: CcTile(
        color: accent ? cc.accent : cc.surface2,
        minHeight: 80,
        semanticsLabel: '$title. $subtitle',
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CcDims.gap16),
          child: Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: CcDims.gap16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.bodyLarge?.copyWith(color: fg)),
                    Text(
                      subtitle,
                      style: theme.bodySmall?.copyWith(color: accent ? fg : cc.textMuted),
                    ),
                  ],
                ),
              ),
              if (covers.isNotEmpty)
                SizedBox(
                  width: _cover + _step * (covers.length - 1),
                  height: _cover,
                  child: Stack(
                    children: [
                      for (var i = 0; i < covers.length; i++)
                        Positioned(
                          left: i * _step,
                          child: ExcludeSemantics(
                            child: TrackArt(track: covers[i], size: _cover, radius: CcDims.rList),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

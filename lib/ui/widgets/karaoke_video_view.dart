import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/db/app_database.dart' show Track;
import '../../l10n/l10n_ext.dart';
import '../../providers/karaoke_video_providers.dart';
import '../screens/now_playing/karaoke_video_fullscreen.dart';
import 'track_art.dart';

/// Builds the real video surface; tests replace it (no libmpv there).
final karaokeVideoBuilderProvider = Provider<Widget Function(VideoController)>(
  (_) =>
      (c) => Video(controller: c, controls: NoVideoControls),
);

/// The 16:9 karaoke video in the player (R-254): the cover with «Carico il video…» while it
/// loads, the video once ready. A tap opens it full screen (R-257).
class KaraokeVideoView extends ConsumerWidget {
  const KaraokeVideoView({super.key, required this.track, required this.width});

  final Track track;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final st = ref.watch(karaokeVideoProvider);
    final c = st.controller;
    final ready = st.status == KaraokeVideoStatus.ready && c != null;
    return Semantics(
      label: l.karaokeVideoLabel,
      button: ready,
      child: GestureDetector(
        onTap: ready
            ? () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => KaraokeVideoFullscreen(controller: c),
                ),
              )
            : null,
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ready
                ? ref.watch(karaokeVideoBuilderProvider)(c)
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      TrackArt(track: track, size: width, radius: 0),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 8),
                          Text(l.karaokeVideoLoading),
                        ],
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

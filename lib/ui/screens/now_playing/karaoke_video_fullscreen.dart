import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../widgets/karaoke_video_view.dart';

/// The karaoke video over the whole screen (R-257). Android turns landscape and immersive,
/// and goes back to portrait on exit; on desktop the video just fills the window.
class KaraokeVideoFullscreen extends ConsumerStatefulWidget {
  const KaraokeVideoFullscreen({super.key, required this.controller});

  final VideoController controller;

  @override
  ConsumerState<KaraokeVideoFullscreen> createState() =>
      _KaraokeVideoFullscreenState();
}

class _KaraokeVideoFullscreenState
    extends ConsumerState<KaraokeVideoFullscreen> {
  @override
  void initState() {
    super.initState();
    if (!isAndroid) return;
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    if (isAndroid) {
      // Same as main.dart: a phone stays upright.
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Semantics(
        label: context.l10n.karaokeVideoLabel,
        child: SizedBox.expand(
          child: ref.watch(karaokeVideoBuilderProvider)(widget.controller),
        ),
      ),
    ),
  );
}

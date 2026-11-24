import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../../core/platform.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/karaoke_video_providers.dart';
import '../../widgets/karaoke_video_surface.dart';

/// The karaoke video over the whole screen (R-257). Android turns landscape and immersive,
/// and goes back to portrait on exit; on desktop the video just fills the window.
class KaraokeVideoFullscreen extends ConsumerStatefulWidget {
  const KaraokeVideoFullscreen({super.key, this.provider});

  final ProviderListenable<KaraokeVideoState>? provider;

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
      // The app sets no UI mode elsewhere: back to the default, bars shown.
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider ?? karaokeVideoProvider;
    // The state always holds the current controller (a new one per track), never keep an old one.
    ref.listen(provider.select((v) => v.status), (_, s) {
      if (s == KaraokeVideoStatus.none || s == KaraokeVideoStatus.failed) {
        Navigator.of(context).maybePop();
      }
    });
    final c = ref.watch(provider).controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).maybePop(),
        child: Semantics(
          label: context.l10n.karaokeVideoLabel,
          child: SizedBox.expand(
            child: c == null
                ? const SizedBox()
                : ref.watch(karaokeVideoBuilderProvider)(c),
          ),
        ),
      ),
    );
  }
}

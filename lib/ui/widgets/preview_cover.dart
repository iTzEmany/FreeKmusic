import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/preview_providers.dart';
import '../theme/tokens.dart';

/// Hold the cover to listen to the track for 20 s; let go to stop. A ring fills
/// over the cover while it plays. The rest of the row keeps its own gestures.
class PreviewCover extends ConsumerWidget {
  const PreviewCover({
    super.key,
    required this.track,
    required this.size,
    required this.child,
  });

  final Track track;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      previewProvider.select((s) => s.trackId == track.id),
    );
    final notifier = ref.read(previewProvider.notifier);
    // A custom action keeps the row's own label and long press for TalkBack.
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: context.l10n.previewTrack): () =>
            active ? notifier.stop() : notifier.start(track),
      },
      child: GestureDetector(
        // Its long press would clash with the row's and split it in two nodes.
        excludeFromSemantics: true,
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => notifier.start(track),
        onLongPressEnd: (_) => notifier.stop(),
        onLongPressCancel: notifier.stop,
        child: Stack(
          alignment: Alignment.center,
          children: [
            child,
            if (active) _Ring(size: size),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cc.bg.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(CcDims.rList),
      ),
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 20),
        builder: (_, v, _) => SizedBox(
          width: size * 0.6,
          height: size * 0.6,
          child: CircularProgressIndicator(
            value: v,
            strokeWidth: 3,
            color: cc.accent,
            backgroundColor: cc.textMuted.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/progress_frame.dart';

/// Cover side inside the frame of a row.
const kHomeCover = 44.0;

/// Frame of the cover: the cover plus a [CcDims.gap4] margin all around.
const _kHomeFrame = kHomeCover + 2 * CcDims.gap4;

/// A cover in a frame and two lines; rows sit inside a [HomeBlock].
/// [progress] draws the 2 dp ring around the cover; [now] marks the playing
/// row (full ring, title in the soft accent).
class HomeRow extends StatelessWidget {
  const HomeRow({
    super.key,
    required this.cover,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.progress,
    this.now = false,
  });

  final Widget cover;
  final String title;
  final String? subtitle;
  final double? progress;
  final bool now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final cc = context.cc;
    final framed = Padding(
      padding: const EdgeInsets.all(CcDims.gap4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CcDims.rList),
        child: SizedBox.square(dimension: kHomeCover, child: cover),
      ),
    );
    return MergeSemantics(
      child: Semantics(
        button: onTap != null,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CcDims.gap12,
              vertical: CcDims.gap8,
            ),
            child: Row(
              children: [
                if (now || progress != null)
                  ProgressFrame(
                    size: _kHomeFrame,
                    progress: now ? null : progress,
                    child: framed,
                  )
                else
                  SizedBox.square(dimension: _kHomeFrame, child: framed),
                const SizedBox(width: CcDims.gap12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyLarge?.copyWith(
                          color: now ? cc.accentSoft : null,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The box of a block (Riprendi, Più ascoltati…): [CcColors.surface1], no lines.
class HomeBlock extends StatelessWidget {
  const HomeBlock({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
    child: Material(
      color: context.cc.surface1,
      borderRadius: BorderRadius.circular(CcDims.rCard),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    ),
  );
}

/// Placeholder cover with an icon.
class HomeIconCover extends StatelessWidget {
  const HomeIconCover(this.icon, {super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    color: context.cc.surface3,
    child: Icon(icon, color: context.cc.accentSoft),
  );
}

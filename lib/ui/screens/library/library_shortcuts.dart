import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../../widgets/motion.dart';

class LibraryShortcut {
  const LibraryShortcut({
    required this.label,
    this.icon,
    this.meta,
    required this.onTap,
  });

  final String label;

  /// Home and Libreria have none (mockup); Memoria tools keep theirs.
  final IconData? icon;

  /// The second line under the label, count with its unit («87 brani»).
  final String? meta;
  final VoidCallback onTap;
}

/// Grid of equal-width blocks. Blocks without an icon (Home, Libreria): up to 3 on one row, else
/// 2 columns; from 720 dp more than 3 become chips as wide as their text that wrap. Blocks with an
/// icon (Memoria): one column per 160 dp, up to 4.
class LibraryShortcuts extends StatelessWidget {
  const LibraryShortcuts({super.key, required this.items});

  final List<LibraryShortcut> items;

  static const _gap = 8.0;
  static const _radius = BorderRadius.all(Radius.circular(CcDims.rSheet));

  Widget _block(BuildContext context, LibraryShortcut s, {bool wrap = false}) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: [s.label, ?s.meta].join(', '),
      excludeSemantics: true,
      onTap: s.onTap,
      child: PressScale(
        child: Material(
          color: cc.surface1,
          borderRadius: _radius,
          child: InkWell(
            borderRadius: _radius,
            onTap: s.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                // 6 dp like the mockup, so nine labels fit one row at 1280 px.
                padding: s.icon == null
                    ? EdgeInsets.symmetric(horizontal: wrap ? 10 : 6, vertical: 4)
                    : const EdgeInsets.symmetric(
                        horizontal: CcDims.gap12,
                        vertical: 10,
                      ),
                child: s.icon == null
                    ? Column(
                        mainAxisSize: wrap ? MainAxisSize.min : MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.label,
                            // Wide chips are as wide as their text, never cut (F-108).
                            maxLines: wrap ? null : 1,
                            overflow: wrap ? null : TextOverflow.ellipsis,
                            style: theme.labelLarge,
                          ),
                          if (s.meta != null)
                            Text(
                              s.meta!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodySmall?.copyWith(
                                color: cc.textMuted,
                              ),
                            ),
                        ],
                      )
                    : Row(
                        children: [
                          Icon(s.icon, size: 22, color: cc.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.label,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.labelLarge,
                                ),
                                if (s.meta != null)
                                  Text(
                                    s.meta!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.bodySmall?.copyWith(
                                      color: cc.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = items;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap8,
        CcDims.margin,
        CcDims.gap8,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / scale;
          // Iconless: wide = every block on one row; phone = 2 columns, an odd
          // last one takes the whole row (D-28, D-53). Icons: as before 43.
          final iconic = visible.any((s) => s.icon != null);
          if (!iconic && w >= 720 && visible.length > 3) {
            return Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [for (final s in visible) _block(context, s, wrap: true)],
            );
          }
          final cols = iconic
              ? (w ~/ 160).clamp(1, 4)
              : (visible.length <= 3 ? visible.length : 2);
          return Column(
            children: [
              for (var i = 0; i < visible.length; i += cols) ...[
                if (i > 0) const SizedBox(height: _gap),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (
                        var j = i;
                        j < i + cols && (iconic || j < visible.length);
                        j++
                      ) ...[
                        if (j > i) const SizedBox(width: _gap),
                        Expanded(
                          child: j < visible.length
                              ? _block(context, visible[j])
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

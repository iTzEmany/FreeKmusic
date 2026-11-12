import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/settings_providers.dart';
import '../theme/tokens.dart';

/// A `surface2` floating surface (dock, Library island). With the setting
/// `blurredChrome` on it blurs what is behind (sigma 20, `surface2` at 0.78);
/// off: no BackdropFilter at all in the tree (it costs on weak phones).
class BlurredChrome extends ConsumerWidget {
  const BlurredChrome({super.key, required this.radius, required this.child});

  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blurred = ref.watch(settingsProvider.select((s) => s.blurredChrome));
    final shape = BorderRadius.circular(radius);
    // Material (not a coloured Container) so the ink of the taps shows.
    final surface = Material(
      color: blurred
          ? context.cc.surface2.withValues(alpha: context.cc.surface2.a * 0.78)
          : context.cc.surface2,
      shape: RoundedRectangleBorder(borderRadius: shape),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    return !blurred
        ? surface
        : ClipRRect(
            borderRadius: shape,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: surface,
            ),
          );
  }
}

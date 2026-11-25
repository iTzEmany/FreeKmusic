import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'cover_image.dart';
import 'action_catalog.dart';

/// Which cover keys a playlist mosaic shows: a custom cover wins, otherwise
/// the first four distinct ones.
List<String> playlistCoverKeys(String? custom, Iterable<String?> trackCovers) {
  if (custom != null) return [custom];
  final seen = <String>{};
  for (final k in trackCovers) {
    if (k != null && seen.add(k) && seen.length == 4) break;
  }
  return seen.toList();
}

class PlaylistCover extends StatelessWidget {
  const PlaylistCover({
    super.key,
    required this.size,
    this.coverKeys = const [],
    this.favorites = false,
    this.radius = CcDims.rList,
  });

  final double size, radius;

  /// Already reduced with [playlistCoverKeys].
  final List<String> coverKeys;

  /// The «Preferiti» variant: amethyst gradient with a heart.
  final bool favorites;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final Widget child;
    if (favorites) {
      child = DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [cc.accent, cc.heroBase],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.favorite_rounded,
            size: size * 0.45,
            color: cc.onAccent,
          ),
        ),
      );
    } else if (coverKeys.isEmpty) {
      child = ColoredBox(
        color: cc.surface3,
        child: Icon(
          CatalogAction.playlist.icon,
          size: size * 0.5,
          color: cc.textMuted,
        ),
      );
    } else if (coverKeys.length < 4) {
      child = CoverImage(coverKey: coverKeys.first, size: size, radius: 0);
    } else {
      final half = size / 2;
      child = Column(
        children: [
          for (var r = 0; r < 2; r++)
            Row(
              children: [
                for (var c = 0; c < 2; c++)
                  CoverImage(
                    coverKey: coverKeys[r * 2 + c],
                    size: half,
                    radius: 0,
                  ),
              ],
            ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(dimension: size, child: child),
    );
  }
}

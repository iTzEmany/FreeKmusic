import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../providers/library_providers.dart';
import '../../services/covers/cover_store.dart';
import '../../services/covers/cover_thumbnails.dart';
import '../theme/tokens.dart';

/// The covers folder as the UI knows it: listed once, then kept up to date by
/// [CoverStore.changes], so scrolling never touches the disk.
class CoverIndexNotifier extends Notifier<Map<String, CoverFiles>> {
  @override
  Map<String, CoverFiles> build() {
    final store = ref.watch(coverStoreProvider);
    final sub = CoverStore.changes.listen((c) {
      final original = c.files.original;
      if (original == null || !p.equals(p.dirname(original), store.dir.path)) return;
      state = {...state, c.key: c.files};
    });
    ref.onDispose(sub.cancel);
    return store.listAll();
  }
}

final coverIndexProvider =
    NotifierProvider<CoverIndexNotifier, Map<String, CoverFiles>>(CoverIndexNotifier.new);

/// The original cover of [key] (Now Playing, big sizes).
final coverFileProvider = Provider.family<File?, String>((ref, key) {
  final path = ref.watch(coverIndexProvider.select((m) => m[key]?.original));
  return path == null ? null : File(path);
});

/// The thumbnail of [key], or the original while there is none.
final coverThumbProvider = Provider.family<File?, String>((ref, key) {
  final path = ref.watch(coverIndexProvider.select((m) => m[key]?.thumb ?? m[key]?.original));
  return path == null ? null : File(path);
});

/// Golden tests swap the picture for a flat colour: decoding files inside a
/// fake-async test is slow and never comes out the same twice.
@visibleForTesting
Widget Function(String coverKey)? coverImageStub;

class CoverImage extends ConsumerWidget {
  const CoverImage({
    super.key,
    required this.coverKey,
    required this.size,
    this.radius = CcDims.rList,
    this.heroTag,
    this.semanticLabel,
  });

  final String? coverKey;
  final double size, radius;

  /// Shared-element tag (mini-player ↔ Now Playing); null = no Hero.
  final Object? heroTag;

  /// Spoken label; null hides the cover from screen readers (the row already
  /// says title and artist). Set it only where the cover is the sole content.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cc = context.cc;
    final placeholder = ColoredBox(
      color: cc.surface3,
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.5,
        color: cc.textMuted,
      ),
    );
    final key = coverKey;
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final file = key == null
        ? null
        : ref.watch(px <= coverThumbSide ? coverThumbProvider(key) : coverFileProvider(key));
    Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: file == null
            ? placeholder
            : coverImageStub?.call(key!) ??
                Image.file(
                  file,
                  cacheWidth: px,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => placeholder,
                ),
      ),
    );
    if (heroTag != null) image = coverHero(heroTag!, image);
    return coverSemantics(image, semanticLabel);
  }
}

/// The cover's [Hero]. Closing the player (pop), the flying cover stays round
/// all the way down to the mini player instead of turning square halfway (D-382).
Widget coverHero(Object tag, Widget child) => Hero(
  tag: tag,
  flightShuttleBuilder: (_, _, direction, from, to) {
    final c = ((direction == HeroFlightDirection.push ? to : from).widget as Hero).child;
    return direction == HeroFlightDirection.pop ? ClipOval(child: c) : c;
  },
  child: child,
);

/// Covers are hidden from the screen reader unless they have a label (D-16).
Widget coverSemantics(Widget art, String? label) {
  final hidden = ExcludeSemantics(child: art);
  return label == null ? hidden : Semantics(image: true, label: label, child: hidden);
}

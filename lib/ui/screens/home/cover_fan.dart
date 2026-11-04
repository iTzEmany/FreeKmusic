import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/library_queries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../library/album_detail_screen.dart';

const _maxCovers = 5;
const _gap = CcDims.gap12;
const _size = 84.0; // open squares never shrink
const _top = 8.0;

/// Closed: the first five albums as overlapping flat covers. The first tap,
/// Enter/Space or the mouse pointer spreads them into a row, which then turns
/// into a scrolling list of all the albums (fixed squares, title and artist).
/// It closes on a tap outside or on its empty area, not on pointer exit. A tap
/// on an open cover opens that album. Only transforms move, on their own layer.
class CoverFan extends StatefulWidget {
  const CoverFan({super.key, required this.albums});

  final List<AlbumSummary> albums;

  @override
  State<CoverFan> createState() => _CoverFanState();
}

class _CoverFanState extends State<CoverFan>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _open = false;
  Offset? _downOutside;
  bool _focused = false;
  final _node = FocusNode(debugLabel: 'CoverFan');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.duration = ccDuration(context, CcMotion.sheet);
  }

  @override
  void dispose() {
    _c.dispose();
    _node.dispose();
    super.dispose();
  }

  void _setOpen(bool open) {
    if (open == _open) return;
    setState(() => _open = open);
    open ? _c.forward() : _c.reverse();
    // Opened by hover: take focus so Esc (DismissIntent) reaches the fan.
    if (open && !_node.hasFocus) _node.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final all = widget.albums;
    if (all.isEmpty) return const SizedBox.shrink();
    final albums = all.take(_maxCovers).toList();
    final n = albums.length;
    final l = context.l10n;
    final ts = MediaQuery.textScalerOf(context);
    final titleStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
      height: 1.3,
      color: context.cc.text,
    );
    final artistStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
      height: 1.3,
      color: context.cc.textMuted,
    );
    // Square + gap + 2 title lines + 1 artist line, following the text scale.
    final openHeight =
        _top +
        _size +
        6 +
        ts.scale(titleStyle.fontSize! * 1.3) * 2 +
        ts.scale(artistStyle.fontSize! * 1.3) +
        8;
    // Full width: the open row scrolls edge to edge, its margins are list padding.
    return LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final size = math.min((w - 2 * CcDims.margin) * 0.26, _size);
          // Built once per layout: the animation only moves the Transforms.
          final covers = [
            for (var i = 0; i < n; i++) _cover(albums[i], i, size),
          ];
          // Back closes an open fan first; the shell's Back then stays on Home.
          return PopScope(
            canPop: !_open,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _setOpen(false);
            },
            child: TapRegion(
            // A real tap only: a drag (page scroll) that starts outside keeps it open.
            onTapOutside: (e) => _downOutside = e.position,
            onTapUpOutside: (e) {
              final d = _downOutside;
              if (d != null && (e.position - d).distance < kTouchSlop) {
                _setOpen(false);
              }
            },
            child: MouseRegion(
              onEnter: (_) => _setOpen(true),
              child: FocusableActionDetector(
                focusNode: _node,
                // Always enabled, so the focus stays on the fan once it is open.
                onShowFocusHighlight: (v) => setState(() => _focused = v),
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                actions: {
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      _setOpen(true);
                      return null;
                    },
                  ),
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      _setOpen(false);
                      return null;
                    },
                  ),
                },
                // A tap on the empty area of the open row closes it.
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _setOpen(false),
                  // The same wrapper open or closed, so the covers are never remounted.
                  child: Semantics(
                    button: !_open,
                    label: _open ? null : l.homeFanOpen,
                    excludeSemantics: !_open,
                    onTap: _open ? null : () => _setOpen(true),
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (context, _) {
                          final t = CcMotion.curveIn.transform(_c.value);
                          if (_open && _c.isCompleted) {
                            return _row(all, openHeight, titleStyle, artistStyle);
                          }
                          return DecoratedBox(
                            position: DecorationPosition.foreground,
                            decoration: BoxDecoration(
                              border: _focused && !_open
                                  ? Border.all(color: context.cc.accent, width: 2)
                                  : null,
                              borderRadius: BorderRadius.circular(CcDims.rGrid),
                            ),
                            child: SizedBox(
                            height: _lerp(size + 16, openHeight, t),
                            width: w,
                            child: Stack(
                              alignment: Alignment.topCenter,
                              children: [
                                for (var i = 0; i < n; i++)
                                  _place(covers[i], i, size, w, t),
                              ],
                            ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          );
        },
      );
  }

  /// Open: every album in a scrolling row of fixed squares.
  Widget _row(
    List<AlbumSummary> albums,
    double height,
    TextStyle titleStyle,
    TextStyle artistStyle,
  ) {
    final l = context.l10n;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(CcDims.margin, _top, CcDims.margin, 0),
        itemCount: albums.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, i) {
          final a = albums[i];
          final title = a.title ?? l.unknownAlbum;
          final artist = a.variousArtists
              ? l.variousArtists
              : (a.artist ?? l.unknownArtist);
          return Semantics(
            button: true,
            label: '$title, $artist',
            excludeSemantics: true,
            child: InkWell(
              key: ValueKey('fan-cover-$i'),
              borderRadius: BorderRadius.circular(CcDims.rList),
              onTap: () =>
                  ShellNav.open<void>(context, AlbumDetailScreen(album: a)),
              child: SizedBox(
                width: _size,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FanCard(album: a, size: _size, radius: CcDims.rList),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: artistStyle,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Slides cover [i] from the overlap to its slot in the open row, where the
  /// list takes over without a jump.
  Widget _place(Widget cover, int i, double size, double w, double t) {
    final mid = i - (widget.albums.take(_maxCovers).length - 1) / 2;
    final dx = _lerp(mid * size * 0.67, CcDims.margin + i * (_size + _gap) + _size / 2 - w / 2, t);
    // The Transform wraps the padding: only it hit-tests moved children.
    return Transform.translate(
      offset: Offset(dx, 0),
      child: Padding(
        padding: const EdgeInsets.only(top: _top),
        child: cover,
      ),
    );
  }

  Widget _cover(AlbumSummary a, int i, double size) => GestureDetector(
    key: ValueKey('fan-cover-$i'),
    onTap: () => _setOpen(true),
    child: _FanCard(album: a, size: size),
  );

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// The cover, or, when the album has no cover file, its title on the same square.
class _FanCard extends ConsumerWidget {
  const _FanCard({
    required this.album,
    required this.size,
    this.radius = CcDims.rGrid,
  });

  final AlbumSummary album;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = album.coverKey;
    final hasCover =
        key != null &&
        ref.watch(coverIndexProvider.select((m) => m[key]?.original != null));
    if (hasCover) {
      return CoverImage(coverKey: key, size: size, radius: radius);
    }
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(CcDims.gap12),
      alignment: Alignment.topLeft,
      decoration: BoxDecoration(
        color: context.cc.surface3,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        album.title ?? context.l10n.unknownAlbum,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: context.cc.text),
      ),
    );
  }
}

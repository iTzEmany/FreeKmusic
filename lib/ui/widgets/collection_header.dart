import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Track;
import '../../data/repositories/track_kinds.dart' show kStreamKind;

import '../../core/app_log.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/settings_providers.dart' show settingsProvider;
import '../theme/tokens.dart';
import 'alpha_scroller.dart';
import 'show_msg.dart' show showMsgOn;
import 'keep_offline_action.dart';
import 'play_buttons.dart';
import 'shuffle_button.dart';
import 'action_catalog.dart';

/// Page of one collection (album, artist, playlist, favourites): a pinned bar
/// whose title appears while scrolling, the cover at the left of name and meta
/// (above them when the text is large), then the actions and the page's slivers.
class CollectionScaffold extends ConsumerStatefulWidget {
  const CollectionScaffold({
    super.key,
    required this.title,
    required this.name,
    this.cover,
    required this.slivers,
    this.coverKey,
    this.subtitle,
    this.meta,
    this.extra,
    this.menu,
    this.onPlay,
    this.downloadTracks,
    this.onShare,
    this.favorite = false,
    this.onFavorite,
    this.scrollerCount,
    this.shuffleIds,
    this.shuffleKey,
    this.shufflePlus = true,
    this.barActions = const [],
    this.selectionBar,
  });

  /// Shown in the pinned bar once the big name has scrolled away.
  final String title;
  final String name;

  /// Builds the cover at the given size; null lays out the text only.
  final Widget Function(double size)? cover;
  final List<Widget> slivers;

  /// Identifies the cover (kept for callers).
  final String? coverKey;

  /// A line under the name (e.g. the artist link).
  final Widget? subtitle;
  final String? meta;

  /// Genre… (wide header only, under [meta]).
  final String? extra;
  final Widget? menu;
  final VoidCallback? onPlay;

  /// The tracks «Scarica» keeps offline: the icon shows only when one of them is a stream (a page of files
  /// has nothing to download); null hides it.
  final List<Track>? downloadTracks;

  /// «Condividi»: gets the icon's rectangle (it anchors the share sheet on iPad and desktop); null hides it.
  final ValueChanged<Rect?>? onShare;

  /// The heart next to «Condividi»: [favorite] is its state, [onFavorite] toggles it and says whether it did (the same call undoes it);
  /// null hides the heart (a playlist without uuid, D-726).
  final bool favorite;
  final Future<bool> Function()? onFavorite;

  /// How many rows the page lists: past [alphaScrollerMinItems] a by-position
  /// scroll bar is laid over the page; null: none.
  final int? scrollerCount;

  /// The ids the «Casuale» pill cycles Shuffle+ for; null: no pill.
  final List<int>? shuffleIds;

  /// The list's key for the pill (D-534), the one its Play passes; default: the ids'.
  final Object? shuffleKey;

  /// False: the list has online songs, so no Shuffle+ (R-18).
  final bool shufflePlus;
  final List<Widget> barActions;

  /// Laid over the pinned bar while tracks are picked (a `SelectionBarSlot`).
  final Widget? selectionBar;

  @override
  ConsumerState<CollectionScaffold> createState() => _CollectionScaffoldState();
}

class _CollectionScaffoldState extends ConsumerState<CollectionScaffold> {
  final _scroll = ScrollController();
  bool _showTitle = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 220;
      if (show != _showTitle) setState(() => _showTitle = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = collectionActions(
      context,
      ref,
      onPlay: widget.onPlay,
      shuffleIds: widget.shuffleIds,
      shuffleKey: widget.shuffleKey,
      shufflePlus: widget.shufflePlus,
      downloadTracks: widget.downloadTracks,
      favorite: widget.favorite,
      onFavorite: widget.onFavorite,
      onShare: widget.onShare,
      menu: widget.menu,
    );
    final scroll = CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverAppBar(
          pinned: true,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: AnimatedOpacity(
            duration: ccDuration(context, CcMotion.press),
            opacity: _showTitle ? 1 : 0,
            child: Text(
              widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: widget.barActions,
        ),
        SliverToBoxAdapter(
          child: CollectionHeader(
            cover: widget.cover,
            name: widget.name,
            subtitle: widget.subtitle,
            meta: widget.meta,
            extra: widget.extra,
            actions: actions,
          ),
        ),
        ...widget.slivers,
        SliverToBoxAdapter(child: SizedBox(height: 24 + context.dockInset)),
      ],
    );
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            // Always wrapped: a changing tree would remount the scroll view.
            child: AlphaScroller(
              controller: _scroll,
              itemCount: widget.scrollerCount ?? 0,
              topInset: () =>
                  MediaQuery.paddingOf(context).top + kToolbarHeight,
              child: scroll,
            ),
          ),
          if (widget.selectionBar != null)
            Positioned(top: 0, left: 0, right: 0, child: widget.selectionBar!),
        ],
      ),
    );
  }
}

/// The action row of a collection header: Play, Casuale, Scarica, the heart, Condividi, ⋮ (each only when given).
/// Shared by [CollectionScaffold] and the online album and playlist pages.
List<Widget> collectionActions(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onPlay,
  List<int>? shuffleIds,
  Object? shuffleKey,
  bool shufflePlus = true,
  List<Track>? downloadTracks,
  bool favorite = false,
  Future<bool> Function()? onFavorite,
  bool favoriteEnabled = true,
  ValueChanged<Rect?>? onShare,
  Widget? menu,
}) {
  final l = context.l10n;
  return [
    if (onPlay != null) PlayCircleButton(onPressed: onPlay),
    if (shuffleIds != null)
      ShufflePill(iconOnly: true, ids: shuffleIds, listKey: shuffleKey, plus: shufflePlus),
    if (downloadTracks?.any((t) => t.kind == kStreamKind) ?? false)
      SizedBox.square(
        dimension: 48,
        child: IconButton(
          onPressed: () => keepOfflineFlow(context, ref, downloadTracks!),
          tooltip: CatalogAction.download.label(l),
          icon: Icon(CatalogAction.download.icon),
        ),
      ),
    if (onFavorite != null)
      _FavoriteButton(favorite: favorite, enabled: favoriteEnabled, onFavorite: onFavorite),
    if (onShare != null)
      SizedBox.square(
        dimension: 48,
        child: Builder(
          builder: (ctx) => IconButton(
            onPressed: () {
              final box = ctx.findRenderObject();
              onShare(box is RenderBox ? box.localToGlobal(Offset.zero) & box.size : null);
            },
            tooltip: CatalogAction.share.label(l),
            icon: Icon(CatalogAction.share.icon),
          ),
        ),
      ),
    if (menu != null) ConstrainedBox(constraints: const BoxConstraints(minWidth: 48, minHeight: 48), child: menu),
  ];
}

/// The heart of a collection: one toggle at a time (a second tap while it runs is ignored), a snackbar with
/// «Annulla» only when the favourite really changed.
class _FavoriteButton extends ConsumerStatefulWidget {
  const _FavoriteButton({required this.favorite, required this.enabled, required this.onFavorite});

  final bool favorite, enabled;
  final Future<bool> Function()? onFavorite;

  @override
  ConsumerState<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<_FavoriteButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    _busy = true;
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final showUndo = ref.read(settingsProvider).showUndoSnackbar;
    final was = widget.favorite;
    final toggle = widget.onFavorite!;
    try {
      final done = await toggle();
      if (!done || !showUndo) return;
      showMsgOn(
        messenger,
        was ? l.removedFromFavorites : l.addedToFavorites,
        action: SnackBarAction(label: l.undo, onPressed: () => unawaited(_undo(toggle, messenger, l.loadFailed))),
      );
    } on Object catch (e, st) {
      AppLog.w('collection heart: toggle failed', e, st);
      showMsgOn(messenger, l.loadFailed);
    } finally {
      _busy = false;
    }
  }

  Future<void> _undo(Future<bool> Function() toggle, ScaffoldMessengerState messenger, String failed) async {
    try {
      await toggle();
    } on Object catch (e, st) {
      AppLog.w('collection heart: undo failed', e, st);
      showMsgOn(messenger, failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fav = widget.favorite;
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        key: const ValueKey('collection-favorite'),
        onPressed: widget.enabled ? _tap : null,
        tooltip: fav ? l.bulkRemoveFromFavorites : l.bulkAddToFavorites,
        icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded),
      ),
    );
  }
}

/// Cover at the left of name and meta (above them when the text is large),
/// then the actions in a wrapping row. Shared by the local and online pages.
class CollectionHeader extends StatelessWidget {
  const CollectionHeader({
    super.key,
    this.cover,
    required this.name,
    this.subtitle,
    this.meta,
    this.extra,
    this.actions = const [],
  });

  /// Builds the cover at the given size; null lays out the text only.
  final Widget Function(double size)? cover;
  final String name;

  /// A line under the name (e.g. the artist link).
  final Widget? subtitle;
  final String? meta;

  /// Genre…: shown on the wide header only.
  final String? extra;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= CcDims.wideBreakpoint;
    final stacked = !wide && (width / scale < 300 || width < 360);
    final coverSize = wide ? 200.0 : 128.0;
    final coverBox = cover == null
        ? null
        : KeyedSubtree(
            key: const ValueKey('collection-cover'),
            child: cover!(coverSize),
          );
    final actionRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FittedName(name, wide ? theme.displaySmall! : theme.headlineSmall!),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          DefaultTextStyle.merge(
            style: theme.bodyLarge?.copyWith(color: cc.textMuted),
            child: subtitle!,
          ),
        ],
        if (meta != null) ...[
          const SizedBox(height: 4),
          Text(meta!, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
        ],
        if (wide && extra != null) ...[
          const SizedBox(height: 4),
          Text(extra!, style: theme.bodyMedium?.copyWith(color: cc.textMuted)),
        ],
        // D-721: on the wide window the actions sit beside the cover, under the text.
        if (wide && coverBox != null && actions.isNotEmpty) ...[
          const SizedBox(height: 16),
          actionRow,
        ],
      ],
    );
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: wide ? 960 : double.infinity),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            CcDims.gap8,
            CcDims.margin,
            CcDims.gap12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (coverBox == null)
                info
              else if (stacked) ...[
                coverBox,
                const SizedBox(height: 16),
                info,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    coverBox,
                    SizedBox(width: wide ? 24 : 16),
                    Expanded(child: info),
                  ],
                ),
              if (actions.isNotEmpty && !(wide && coverBox != null)) ...[
                const SizedBox(height: 16),
                actionRow,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The collection name: when its longest word does not fit the width, the font
/// shrinks (down to half) so no word is broken in two; past that, it wraps.
class _FittedName extends StatelessWidget {
  const _FittedName(this.name, this.style);

  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, box) {
        var longest = 0.0;
        for (final word in name.split(RegExp(r'\s+'))) {
          if (word.isEmpty) continue;
          final p = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: dir,
            textScaler: scaler,
          )..layout();
          if (p.width > longest) longest = p.width;
          p.dispose();
        }
        final k = longest > box.maxWidth && longest > 0
            ? (box.maxWidth / longest).clamp(0.5, 1.0)
            : 1.0;
        return Text(
          name,
          key: const ValueKey('collection-name'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: k < 1 ? style.sized(style.fontSize! * k) : style,
        );
      },
    );
  }
}

/// «Disco 2» style label between groups of rows.
class DiscHeader extends StatelessWidget {
  const DiscHeader(this.disc, {super.key});

  final int disc;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      CcDims.margin,
      CcDims.gap16,
      CcDims.margin,
      CcDims.gap4,
    ),
    child: Text(
      context.l10n.discN(disc),
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: context.cc.textMuted),
    ),
  );
}

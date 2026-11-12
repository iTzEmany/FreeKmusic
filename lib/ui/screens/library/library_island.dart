import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/library_entries.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/folder_actions.dart';
import '../../shell/shell_nav.dart';
import '../../theme/tokens.dart';
import '../../widgets/activity_button.dart';
import '../../widgets/blurred_chrome.dart';
import '../../widgets/cc_sheet.dart';
import '../../widgets/new_playlist_menu.dart';
import '../../widgets/segmented_blocks.dart';
import '../activity/activity_log_screen.dart';
import '../devices/devices_sheet.dart';
import '../playlists/export_dialog.dart';
import '../smart/smart_playlist_editor.dart';
import 'folders_sheet.dart';
import 'library_toolbar.dart';
import 'scan_status.dart';

/// Heights of the rows that leave while the list scrolls (title first, then the
/// sort row); the tabs between them stay. They grow with the text scale.
class LibraryIslandRows {
  const LibraryIslandRows._(this.title, this.toolbar);

  factory LibraryIslandRows.of(BuildContext context) {
    final k = clampDouble(MediaQuery.textScalerOf(context).scale(1), 1, 2);
    return LibraryIslandRows._(56 * k, 48 * k);
  }

  final double title, toolbar;
  double get shrinkMax => title + toolbar;

  /// Padding of the island around its rows (top and bottom).
  static const _pad = 2 * CcDims.gap4;

  /// Full height for a tabs block (with [ScanStatus]) of [mid] dp.
  double fullHeight(double mid) => _pad + title + mid + toolbar;
}

/// Height of the tabs row at normal text size, before the first measure.
const libraryIslandTabsHeight = 48.0;

/// The Library's one floating surface (D-391, D-407, D-409): title (lens,
/// activity log, «+»), tabs, and count with sort and view. [shrink] (0 to
/// [LibraryIslandRows.shrinkMax] dp) retracts the title and then the sort row
/// 1:1 with the scroll; only the two retracting wrappers rebuild when it
/// moves. With the search open the lens turns into the field, the sort row
/// closes and the tabs stay.
class LibraryIsland extends StatelessWidget {
  const LibraryIsland({
    super.key,
    required this.shrink,
    required this.searching,
    required this.field,
    required this.onSearch,
    required this.kind,
    required this.onKind,
    required this.countLabel,
    required this.sort,
    required this.ascending,
    required this.grid,
    required this.onSort,
    required this.onToggleGrid,
    required this.onTabsHeight,
  });

  final ValueListenable<double> shrink;
  final bool searching;
  final Widget field;
  final VoidCallback onSearch;
  final LibraryKind? kind;
  final ValueChanged<LibraryKind?> onKind;
  final String countLabel;
  final LibrarySort sort;
  final bool ascending;
  final bool grid;
  final void Function(LibrarySort sort, bool ascending) onSort;
  final VoidCallback onToggleGrid;

  /// Height of the scan status plus the tabs; reported only when it changes.
  final ValueChanged<double> onTabsHeight;

  @override
  Widget build(BuildContext context) {
    final rows = LibraryIslandRows.of(context);
    // Own layer: the page under it (tab change, results) repaints without it.
    return RepaintBoundary(
      child: BlurredChrome(
        radius: CcDims.dockRadius,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: searching ? 1 : 0),
          duration: ccDuration(context, CcMotion.sheet),
          curve: CcMotion.curveIn,
          builder: (context, t, _) {
            // Built once per search frame, not per scroll frame.
            final title = _TitleRow(
              t: t,
              height: rows.title,
              searching: searching,
              field: field,
              onSearch: onSearch,
            );
            final tabs = _Tabs(
              kind: kind,
              onKind: onKind,
              onHeight: onTabsHeight,
            );
            final toolbar = SizedBox(
              height: rows.toolbar,
              child: LibraryToolbar(
                countLabel: countLabel,
                sort: sort,
                ascending: ascending,
                kind: kind,
                grid: grid,
                onSort: onSort,
                onToggleGrid: onToggleGrid,
              ),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: CcDims.gap4),
              child: ValueListenableBuilder<double>(
                valueListenable: shrink,
                builder: (context, s, _) {
                  final titleF = 1 - clampDouble(s, 0, rows.title) / rows.title;
                  final toolF =
                      (1 - t) *
                      (1 -
                          clampDouble(s - rows.title, 0, rows.toolbar) /
                              rows.toolbar);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Retract(
                        factor: titleF,
                        alignment: Alignment.bottomCenter,
                        child: title,
                      ),
                      tabs,
                      _Retract(
                        factor: toolF,
                        alignment: Alignment.topCenter,
                        child: toolbar,
                      ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Scan status and tabs; tells the screen its height when it changes (a
/// banner, large text), not on every scroll frame.
class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.kind,
    required this.onKind,
    required this.onHeight,
  });

  final LibraryKind? kind;
  final ValueChanged<LibraryKind?> onKind;
  final ValueChanged<double> onHeight;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> {
  void _report() => WidgetsBinding.instance.addPostFrameCallback((_) {
    final h = mounted ? context.size?.height : null;
    if (h != null) widget.onHeight(h);
  });

  @override
  void initState() {
    super.initState();
    _report(); // the notifier below only speaks about later changes
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _report();
        return true;
      },
      child: SizeChangedLayoutNotifier(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ScanStatus(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CcDims.gap8),
              child: _KindTabs(selected: widget.kind, onChanged: widget.onKind),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [factor] (0..1) of [child]'s height; at 0 it is also out of reach.
class _Retract extends StatelessWidget {
  const _Retract({
    required this.factor,
    required this.alignment,
    required this.child,
  });

  final double factor;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    excluding: factor == 0,
    child: ExcludeFocus(
      excluding: factor == 0,
      child: ClipRect(
        child: Align(alignment: alignment, heightFactor: factor, child: child),
      ),
    ),
  );
}

class _TitleRow extends ConsumerWidget {
  const _TitleRow({
    required this.t,
    required this.height,
    required this.searching,
    required this.field,
    required this.onSearch,
  });

  final double t; // 0 = title, 1 = search field
  final double height;
  final bool searching;
  final Widget field;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final normal = IgnorePointer(
      ignoring: searching,
      child: ExcludeFocus(
        excluding: searching,
        child: ExcludeSemantics(
          excluding: searching,
          child: Opacity(
            opacity: 1 - t,
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(
                  left: CcDims.margin,
                  right: CcDims.gap4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      // Scales down instead of cutting when the activity chip crowds the row.
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l.navLibrary,
                            maxLines: 1,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ),
                    ),
                    const ActivityButton(),
                    IconButton(
                      tooltip: l.activityLog,
                      icon: const Icon(Icons.receipt_long_rounded),
                      onPressed: () => ShellNav.open<void>(
                        context,
                        const ActivityLogScreen(),
                      ),
                    ),
                    IconButton(
                      tooltip: l.navSearch,
                      icon: const Icon(Icons.search_rounded),
                      onPressed: onSearch,
                    ),
                    NewPlaylistMenu(
                      onSmart: () => ShellNav.open<bool>(
                        context,
                        const SmartPlaylistEditor(),
                      ),
                    ),
                    IconButton(
                      tooltip: l.moreActions,
                      icon: const Icon(Icons.more_vert_rounded),
                      onPressed: () => _menu(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          normal,
          // Mounted only while open or animating: it takes focus on mount.
          if (searching || t > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CcDims.gap4),
              child: IgnorePointer(
                ignoring: !searching,
                child: ExcludeFocus(
                  excluding: !searching,
                  child: ExcludeSemantics(
                    excluding: !searching,
                    // Loose constraints: the field widens from the lens.
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: 0.12 + 0.88 * t,
                        child: Opacity(
                          opacity: math.min(1, t * 2),
                          child: RepaintBoundary(child: field),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final v = await showCcActionSheet<_LibraryMenuAction>(
      context: context,
      groups: [
        [
          CcAction(
            icon: Icons.folder_open_rounded,
            label: l.folders,
            value: _LibraryMenuAction.folders,
          ),
          CcAction(
            icon: Icons.refresh_rounded,
            label: l.refreshLibrary,
            value: _LibraryMenuAction.scan,
          ),
          CcAction(
            icon: Icons.share_rounded,
            label: l.shareTitle,
            value: _LibraryMenuAction.share,
          ),
          CcAction(
            icon: Icons.upload_file_rounded,
            label: l.exportAllPlaylists,
            value: _LibraryMenuAction.exportAll,
          ),
        ],
      ],
    );
    if (v == null || !context.mounted) return;
    switch (v) {
      case _LibraryMenuAction.folders:
        showCcSheet<void>(
          context: context,
          builder: (_) => const FoldersSheet(),
        );
      case _LibraryMenuAction.scan:
        scanWithPermission(ref);
      case _LibraryMenuAction.share:
        DevicesSheet.show(context);
      case _LibraryMenuAction.exportAll:
        exportAllPlaylistsFlow(context, ref);
    }
  }
}

enum _LibraryMenuAction { folders, scan, share, exportAll }

class _KindTabs extends StatelessWidget {
  const _KindTabs({required this.selected, required this.onChanged});

  final LibraryKind? selected;
  final ValueChanged<LibraryKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SegmentedBlocks<LibraryKind?>(
      items: [
        BlockItem(value: null, label: l.libraryAll),
        BlockItem(value: LibraryKind.playlist, label: l.navPlaylists),
        BlockItem(value: LibraryKind.album, label: l.albums),
        BlockItem(value: LibraryKind.artist, label: l.artists),
      ],
      selected: selected,
      onChanged: onChanged,
    );
  }
}

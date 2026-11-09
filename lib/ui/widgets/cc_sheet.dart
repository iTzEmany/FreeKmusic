import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_log.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';

/// Every bottom sheet opens through here: 250 ms, none with «Riduci animazioni».
Future<T?> showCcSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool? showDragHandle,
  BoxConstraints? constraints,
  String? barrierLabel,
}) {
  final d = ccDuration(context, CcMotion.sheet);
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    showDragHandle: showDragHandle,
    // Always the root route: its barrier covers the dock (phone) and the sidebar, side
    // panel and player bar (wide), so a sheet is never drawn under them.
    useRootNavigator: true,
    constraints: constraints,
    barrierLabel: barrierLabel,
    sheetAnimationStyle: AnimationStyle(duration: d, reverseDuration: d),
  );
}

/// One row of an action sheet. Closing returns [value]; [onTap] runs after the sheet is gone.
class CcAction<T> {
  const CcAction({
    required this.icon,
    required this.label,
    this.value,
    this.onTap,
    this.selected = false,
    this.destructive = false,
    this.semanticsLabel,
  });

  final IconData icon;
  final String label;
  final T? value;
  final FutureOr<void> Function()? onTap;

  /// Marks the current choice (sort orders): shows a check at the end.
  final bool selected;

  /// Drawn in `cc.error` and moved to the end of the sheet.
  final bool destructive;

  /// What a screen reader says instead of [label] (e.g. to add the state of a switch).
  final String? semanticsLabel;
}

/// Action sheet: optional [header] (or [title]/[subtitle]), [groups] of 59 dp rows
/// separated by dividers, destructive rows always last. Returns the chosen value.
Future<T?> showCcActionSheet<T>({
  required BuildContext context,
  required List<List<CcAction<T>>> groups,
  Widget? header,
  String? title,
  String? subtitle,
  Listenable? refresh,
  List<List<CcAction<T>>> Function()? regroup,
}) {
  // With [refresh] the open sheet takes the groups again from [regroup] on each notification.
  List<List<CcAction<T>>> layout(List<List<CcAction<T>>> gs) {
    final normal = [
      for (final g in gs)
        [
          for (final a in g)
            if (!a.destructive) a,
        ],
    ].where((g) => g.isNotEmpty).toList();
    final destructive = [
      for (final g in gs)
        for (final a in g)
          if (a.destructive) a,
    ];
    return [...normal, if (destructive.isNotEmpty) destructive];
  }

  final head =
      header ??
      (title == null
          ? null
          : ListTile(
              title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: subtitle == null ? null : Text(subtitle),
            ));
  return showCcSheet<T>(
    context: context,
    isScrollControlled: true,
    barrierLabel: context.l10n.close,
    builder: (sheet) {
      final cc = sheet.cc;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
        ),
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: title != null,
          label: title,
          child: SafeArea(
            child: SingleChildScrollView(
              child: ListenableBuilder(
                listenable: refresh ?? const AlwaysStoppedAnimation(0),
                builder: (_, _) {
                  final all = layout(regroup == null ? groups : regroup());
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (head != null) Semantics(header: true, child: head),
                      for (var i = 0; i < all.length; i++) ...[
                        if (i > 0 || head != null) const Divider(height: 1),
                        for (final (j, a) in all[i].indexed)
                          // At least 59 dp: a long label or a big text scale grows the row.
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 59),
                            child: ListTile(
                              key: ValueKey<Object>(a.value ?? a.label),
                              autofocus: i == 0 && j == 0,
                              leading: Icon(
                                a.icon,
                                color: a.destructive ? cc.error : null,
                              ),
                              title: Text(
                                a.label,
                                semanticsLabel: a.semanticsLabel,
                                style: a.destructive
                                    ? TextStyle(color: cc.error)
                                    : null,
                              ),
                              trailing: a.selected
                                  ? Icon(Icons.check_rounded, color: cc.accent)
                                  : null,
                              selected: a.selected,
                              onTap: () async {
                                Navigator.of(sheet).pop(a.value);
                                try {
                                  await a.onTap?.call();
                                } on Object catch (e, st) {
                                  AppLog.w(
                                    'sheet action failed: ${a.label}',
                                    e,
                                    st,
                                  );
                                }
                              },
                            ),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}

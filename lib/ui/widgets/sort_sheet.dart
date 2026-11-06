import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';
import 'cc_sheet.dart';
import 'segmented_blocks.dart';

/// One criterion of the «Ordina per» sheet.
class SortChoice<T> {
  const SortChoice(
    this.value,
    this.label, {
    this.hasDirection = true,
    this.ascendingByDefault = true,
  });

  final T value;
  final String label;

  /// False for an order with no direction («Ordine personale»): the
  /// ascending/descending switch is turned off while it is selected (D-410).
  final bool hasDirection;

  /// Direction the criterion starts with when it is picked.
  final bool ascendingByDefault;
}

/// The «Ordina per» sheet shared by the Library and the playlists: the
/// ascending/descending switch on top, then the criteria. Picking a criterion
/// reports it with its default direction and closes; the switch reports the
/// same criterion with the new direction and stays open.
Future<void> showSortSheet<T>({
  required BuildContext context,
  required List<SortChoice<T>> choices,
  required T selected,
  required bool ascending,
  required void Function(T value, bool ascending) onChanged,
}) {
  final l = context.l10n;
  var current = selected;
  var asc = ascending;
  return showCcSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierLabel: l.close,
    builder: (sheet) {
      final cc = sheet.cc;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
        ),
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: l.sortBy,
          child: SafeArea(
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (_, setState) {
                  final hasDirection = choices
                      .where((c) => c.value == current)
                      .every((c) => c.hasDirection);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: ListTile(title: Text(l.sortBy)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: CcDims.margin,
                          vertical: CcDims.gap8,
                        ),
                        child: Semantics(
                          enabled: hasDirection,
                          container: true,
                          child: IgnorePointer(
                            key: const ValueKey('sort-direction'),
                            ignoring: !hasDirection,
                            child: Opacity(
                              opacity: hasDirection ? 1 : 0.4,
                              child: ExcludeSemantics(
                                excluding: !hasDirection,
                                child: SegmentedBlocks<bool>(
                                  items: [
                                    BlockItem(value: true, label: l.sortAscending),
                                    BlockItem(value: false, label: l.sortDescending),
                                  ],
                                  selected: asc,
                                  onChanged: (v) {
                                    setState(() => asc = v);
                                    onChanged(current, v);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      for (final c in choices)
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 59),
                          child: ListTile(
                            key: ValueKey<Object?>(c.value),
                            title: Text(c.label),
                            trailing: c.value == current
                                ? Icon(Icons.check_rounded, color: cc.accent)
                                : null,
                            selected: c.value == current,
                            onTap: () {
                              Navigator.of(sheet).pop();
                              // The same criterion again keeps its direction.
                              if (c.value != current) {
                                onChanged(c.value, c.ascendingByDefault);
                              }
                            },
                          ),
                        ),
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

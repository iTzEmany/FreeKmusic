import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';
import 'shell_keys.dart';

/// One row per action of [group]: its text, then its keys as small badges.
List<Widget> shortcutRows(BuildContext context, ShortcutGroup group) {
  final l = context.l10n;
  final cc = context.cc;
  return [
    for (final a in ShortcutAction.values.where((a) => a.group == group))
      ListTile(
        key: ValueKey('shortcut-${a.name}'),
        dense: true,
        title: Text(a.text(l)),
        trailing: Wrap(
          spacing: CcDims.gap8,
          children: [
            for (final k in a.keys)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: CcDims.gap8, vertical: 2),
                decoration: BoxDecoration(
                  color: cc.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(shortcutKeyText(l, k.label), style: Theme.of(context).textTheme.bodySmall),
              ),
          ],
        ),
      ),
  ];
}

/// «?»: the whole list in a window (D-740).
Future<void> showShortcutsOverlay(BuildContext context) => showDialog<void>(
  context: context,
  builder: (c) {
    final l = c.l10n;
    return AlertDialog(
      title: Text(l.settingsPageShortcuts),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final g in ShortcutGroup.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: CcDims.gap12),
                child: Text(shortcutGroupText(l, g), style: Theme.of(c).textTheme.titleSmall),
              ),
              ...shortcutRows(c, g),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: Text(l.close))],
    );
  },
);

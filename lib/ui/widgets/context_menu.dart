import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';

/// One entry of a pointer menu. Same data as a sheet action; [shortcut] is the key shown at the end, when the action has one.
class MenuAction {
  const MenuAction(this.icon, this.label, this.run, {this.destructive = false, this.shortcut});

  final IconData icon;
  final String label;
  final FutureOr<void> Function() run;
  final bool destructive;
  final String? shortcut;
}

/// Menu of the desktop right click (and of ⋮): opens at [position] (global), entries of 36 px, a divider between
/// [groups]. The chosen action runs once the menu is closed. Arrows, Enter and Esc come from the Flutter popup;
/// focus starts on the first entry and goes back to where it was on close.
Future<void> showContextMenu(BuildContext context, Offset position, List<List<MenuAction>> groups) async {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final cc = context.cc;
  final style = Theme.of(context).textTheme.bodyMedium;
  final picked = await showMenu<MenuAction>(
    context: context,
    position: RelativeRect.fromRect(position & Size.zero, Offset.zero & overlay.size),
    semanticLabel: context.l10n.moreActions,
    items: [
      for (var g = 0; g < groups.length; g++) ...[
        if (g > 0) const PopupMenuDivider(height: 8),
        for (final a in groups[g])
          PopupMenuItem<MenuAction>(
            value: a,
            height: 36,
            child: Builder(builder: (c) {
              if (a == groups.first.first) _focusFirst(c);
              return Row(
              children: [
                Icon(a.icon, size: 18, color: a.destructive ? cc.error : cc.textMuted),
                const SizedBox(width: CcDims.gap12),
                Expanded(
                  child: Text(a.label, style: style?.copyWith(color: a.destructive ? cc.error : null)),
                ),
                if (a.shortcut != null) ...[
                  const SizedBox(width: CcDims.gap16),
                  Text(a.shortcut!, style: style?.copyWith(color: cc.textFaint)),
                ],
              ],
            );
            }),
          ),
      ],
    ],
  );
  if (picked != null) await picked.run();
}

/// The popup route puts focus on its scope, a frame or two after the first build: step to the first entry once it does.
void _focusFirst(BuildContext c, [int tries = 3]) => WidgetsBinding.instance.addPostFrameCallback((_) {
  if (!c.mounted) return;
  if (FocusManager.instance.primaryFocus is FocusScopeNode) {
    FocusScope.of(c).nextFocus();
  } else if (tries > 0) { _focusFirst(c, tries - 1);
  }
});

/// Opens the menu from the keyboard (Menu key, Shift+F10; Flutter has no intent for them) at the top left of [child].
class ContextMenuKey extends StatelessWidget {
  const ContextMenuKey({super.key, required this.onOpen, required this.child});

  final void Function(Offset position) onOpen;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    void open() {
      final box = context.findRenderObject();
      if (box is RenderBox && box.attached) onOpen(box.localToGlobal(Offset.zero));
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.contextMenu): open,
        const SingleActivator(LogicalKeyboardKey.f10, shift: true): open,
      },
      child: child,
    );
  }
}

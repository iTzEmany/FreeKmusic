import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';

/// Desktop-wide keyboard shortcuts that keep working wherever focus is.
///
/// Two things plain `CallbackShortcuts` gets wrong here:
/// - it marks a key handled even when the callback ignores it, so Space could
///   not be typed into a text field;
/// - when the focused widget disappears (tab switched, route popped) focus
///   falls back to a route or root scope, above this widget, and every shortcut dies
///   until the user clicks into something. [_ShellKeysState] takes it back.
class ShellKeys extends StatefulWidget {
  const ShellKeys({
    super.key,
    required this.bindings,
    required this.child,
    this.textOnly = const {},
  });

  final Map<ShortcutActivator, VoidCallback> bindings;

  /// Keys that must never fire while a text field has focus (they are text).
  final Set<ShortcutActivator> textOnly;
  final Widget child;

  @override
  State<ShellKeys> createState() => _ShellKeysState();
}

class _ShellKeysState extends State<ShellKeys> {
  final _node = FocusNode(debugLabel: 'ShellKeys');

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_reclaimFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_reclaimFocus);
    _node.dispose();
    super.dispose();
  }

  void _reclaimFocus() {
    if (!_lostFocus()) return;
    // Not inside the notification: requesting focus there would re-enter it.
    scheduleMicrotask(() {
      if (!mounted || _node.hasPrimaryFocus) return;
      if (!_lostFocus()) return;
      if (ModalRoute.of(context)?.isCurrent ?? true) _node.requestFocus();
    });
  }

  /// Focus sits on a scope itself (the route's, or the root): nothing below it
  /// is focused, so key events never reach [_node].
  /// Not the scope of a sheet or dialog: focus there is on purpose, and taking
  /// it would stop Esc from reaching the sheet.
  static bool _lostFocus() {
    final f = FocusManager.instance.primaryFocus;
    if (f is! FocusScopeNode) return false;
    final ctx = f.context;
    return ctx == null || ModalRoute.of(ctx) is! PopupRoute;
  }

  static bool _typing() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final keyboard = HardwareKeyboard.instance;
    final typing = _typing();
    for (final e in widget.bindings.entries) {
      if (!e.key.accepts(event, keyboard)) continue;
      if (typing && widget.textOnly.contains(e.key)) {
        return KeyEventResult.ignored;
      }
      e.value();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    focusNode: _node,
    autofocus: true,
    onKeyEvent: _onKey,
    child: widget.child,
  );
}

enum ShortcutGroup { playback, navigation, search, app }

/// One physical key (or chord) of an action. [textOnly]: it is text, so it
/// never fires while a text field has focus.
class ShortcutKey {
  const ShortcutKey(this.activator, this.label, {this.textOnly = false});

  final ShortcutActivator activator;

  /// Shown in the list; `Space` is translated by [shortcutKeyText].
  final String label;
  final bool textOnly;
}

/// The one table key -> action (D-732, D-738): it feeds the shell's bindings,
/// the «?» overlay and Settings > Scorciatoie. Hardware media keys and the Esc
/// that ends a preview stay in the shell, they are not user-facing shortcuts.
/// `/` and `?` match the typed character, whatever layout needs Shift for them.
enum ShortcutAction {
  playPause(ShortcutGroup.playback, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.space), 'Space', textOnly: true),
  ]),
  previous(ShortcutGroup.playback, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.arrowLeft, control: true), 'Ctrl+←'),
  ]),
  next(ShortcutGroup.playback, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.arrowRight, control: true), 'Ctrl+\u2192'),
  ]),
  volumeDown(ShortcutGroup.playback, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.arrowDown, control: true), 'Ctrl+↓', textOnly: true),
  ]),
  volumeUp(ShortcutGroup.playback, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.arrowUp, control: true), 'Ctrl+↑', textOnly: true),
  ]),
  back(ShortcutGroup.navigation, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true), 'Alt+←'),
    ShortcutKey(SingleActivator(LogicalKeyboardKey.backspace), 'Backspace', textOnly: true),
  ]),
  forward(ShortcutGroup.navigation, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.arrowRight, alt: true), 'Alt+\u2192'),
  ]),
  reload(ShortcutGroup.navigation, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.f5), 'F5'),
  ]),
  settings(ShortcutGroup.navigation, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.comma, control: true), 'Ctrl+,'),
  ]),
  search(ShortcutGroup.search, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.keyF, control: true), 'Ctrl+F'),
    ShortcutKey(CharacterActivator('/'), '/', textOnly: true),
  ]),
  pasteLink(ShortcutGroup.search, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.keyL, control: true), 'Ctrl+L'),
  ]),
  shortcuts(ShortcutGroup.app, [
    ShortcutKey(CharacterActivator('?'), '?', textOnly: true),
  ]),
  quit(ShortcutGroup.app, [
    ShortcutKey(SingleActivator(LogicalKeyboardKey.keyQ, control: true), 'Ctrl+Q'),
  ]);

  const ShortcutAction(this.group, this.keys);

  final ShortcutGroup group;
  final List<ShortcutKey> keys;

  String text(AppLocalizations l) => switch (this) {
    playPause => l.shortcutPlayPause,
    previous => l.shortcutPrevious,
    next => l.shortcutNext,
    volumeDown => l.shortcutVolumeDown,
    volumeUp => l.shortcutVolumeUp,
    back => l.shortcutBack,
    forward => l.shortcutForward,
    reload => l.shortcutReload,
    settings => l.shortcutSettings,
    search => l.shortcutSearch,
    pasteLink => l.shortcutPasteLink,
    shortcuts => l.shortcutShowList,
    quit => l.shortcutQuit,
  };
}

String shortcutGroupText(AppLocalizations l, ShortcutGroup g) => switch (g) {
  ShortcutGroup.playback => l.shortcutGroupPlayback,
  ShortcutGroup.navigation => l.shortcutGroupNavigation,
  ShortcutGroup.search => l.shortcutGroupSearch,
  ShortcutGroup.app => l.shortcutGroupApp,
};

String shortcutKeyText(AppLocalizations l, String label) =>
    label == 'Space' ? l.shortcutKeySpace : label;

/// The table turned into what [ShellKeys] takes. Every action needs a handler.
({Map<ShortcutActivator, VoidCallback> bindings, Set<ShortcutActivator> textOnly})
shortcutBindings(Map<ShortcutAction, VoidCallback> handlers) {
  final bindings = <ShortcutActivator, VoidCallback>{};
  final textOnly = <ShortcutActivator>{};
  for (final a in ShortcutAction.values) {
    for (final k in a.keys) {
      bindings[k.activator] = handlers[a]!;
      if (k.textOnly) textOnly.add(k.activator);
    }
  }
  return (bindings: bindings, textOnly: textOnly);
}

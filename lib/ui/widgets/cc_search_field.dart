import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';

/// Search field with a ✕ that is always there: with text it clears, empty and
/// focused it hides the keyboard, empty and unfocused it is dimmed and inert.
class CcSearchField extends StatefulWidget {
  const CcSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hint,
    this.onSubmitted,
    this.onChanged,
    this.onClear,
    this.onCloseEmpty,
    this.bare = false,
    this.autofocus = false,
  });

  final TextEditingController controller;

  /// Optional: without it the field owns (and disposes) its own node.
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  /// What the ✕ does with text in the field (default: clear the controller).
  final VoidCallback? onClear;

  /// Empty field: the ✕ runs this (closes the search) instead of hiding the keyboard.
  final VoidCallback? onCloseEmpty;

  /// No fill and no border (the dock draws its own surface).
  final bool bare;

  @override
  State<CcSearchField> createState() => _CcSearchFieldState();
}

class _CcSearchFieldState extends State<CcSearchField> {
  FocusNode? _own;

  FocusNode get _node => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void didUpdateWidget(CcSearchField old) {
    super.didUpdateWidget(old);
    // A node passed later replaces the internal one.
    if (widget.focusNode != null && _own != null) {
      _own!.dispose();
      _own = null;
    }
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final controller = widget.controller;
    final focusNode = _node;
    final bare = widget.bare;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (_, _) {
        final hasText = controller.text.isNotEmpty;
        final focused = focusNode.hasFocus;
        final VoidCallback? action = hasText
            ? (widget.onClear ?? controller.clear)
            : widget.onCloseEmpty ?? (focused ? focusNode.unfocus : null);
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          autofocus: widget.autofocus,
          onSubmitted: widget.onSubmitted,
          onChanged: widget.onChanged,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: !hasText && widget.onCloseEmpty != null
                  ? l.closeSearch
                  : !hasText && focused
                  ? l.closeKeyboard
                  : l.clearSearch,
              icon: const Icon(Icons.close_rounded),
              disabledColor: cc.textFaint,
              onPressed: action,
            ),
            filled: bare ? false : null,
            border: bare ? InputBorder.none : null,
            enabledBorder: bare ? InputBorder.none : null,
            focusedBorder: bare ? InputBorder.none : null,
          ),
        );
      },
    );
  }
}

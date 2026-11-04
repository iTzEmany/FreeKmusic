import 'package:flutter/material.dart';

import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';

/// Search field with a ✕ that is always there: with text it clears, empty and
/// focused it hides the keyboard, empty and unfocused it is dimmed and inert.
class CcSearchField extends StatelessWidget {
  const CcSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    this.onSubmitted,
    this.onClear,
    this.bare = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String>? onSubmitted;

  /// What the ✕ does with text in the field (default: clear the controller).
  final VoidCallback? onClear;

  /// No fill and no border (the dock draws its own surface).
  final bool bare;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (_, _) {
        final hasText = controller.text.isNotEmpty;
        final focused = focusNode.hasFocus;
        final VoidCallback? action = hasText
            ? (onClear ?? controller.clear)
            : focused
            ? focusNode.unfocus
            : null;
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: IconButton(
              tooltip: !hasText && focused ? l.closeKeyboard : l.clearSearch,
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/user_activity_provider.dart';
import '../theme/tokens.dart';

/// Search field with a ✕: with text it clears, empty and focused it hides the
/// keyboard, empty and unfocused (without [onCloseEmpty]) there is no ✕.
class CcSearchField extends ConsumerStatefulWidget {
  const CcSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hint,
    this.onSubmitted,
    this.onChanged,
    this.onQuery,
    this.debounce = CcTiming.debounce,
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

  /// Debounced, trimmed and de-duplicated text; at once on Enter and on ✕.
  final ValueChanged<String>? onQuery;

  /// Wait before [onQuery] while typing.
  final Duration debounce;
  final bool autofocus;

  /// What the ✕ does with text in the field (default: clear the controller).
  final VoidCallback? onClear;

  /// Empty field: the ✕ runs this (closes the search) instead of hiding the keyboard.
  final VoidCallback? onCloseEmpty;

  /// No fill and no border (the dock draws its own surface).
  final bool bare;

  @override
  ConsumerState<CcSearchField> createState() => _CcSearchFieldState();
}

class _CcSearchFieldState extends ConsumerState<CcSearchField> {
  FocusNode? _own;
  Timer? _debounce;
  String _last = '';
  String _query = '';

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
    _debounce?.cancel();
    _own?.dispose();
    super.dispose();
  }

  // clear() does not fire onChanged: do it so the results follow.
  void _clear() {
    widget.controller.clear();
    _changed('', now: true);
  }

  void _changed(String text, {bool now = false}) {
    widget.onChanged?.call(text);
    if (text != _last) {
      _last = text;
      ref.read(userActivityProvider).touch();
    }
    _schedule(text, now: now);
  }

  void _schedule(String text, {bool now = false}) {
    final onQuery = widget.onQuery;
    if (onQuery == null) return;
    _debounce?.cancel();
    final v = text.trim();
    if (v == _query) return;
    void run() {
      _query = v;
      onQuery(v);
    }

    if (now || v.isEmpty) {
      run();
    } else {
      _debounce = Timer(widget.debounce, run);
    }
  }

  void _submitted(String text) {
    widget.onSubmitted?.call(text);
    if (widget.onQuery != null) _schedule(text, now: true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final controller = widget.controller;
    final focusNode = _node;
    final bare = widget.bare;
    return ListenableBuilder(
      listenable: Listenable.merge([controller, focusNode]),
      builder: (_, _) {
        final hasText = controller.text.isNotEmpty;
        final focused = focusNode.hasFocus;
        final VoidCallback? action = hasText
            ? (widget.onClear ?? _clear)
            : widget.onCloseEmpty ?? (focused ? focusNode.unfocus : null);
        // The hint is also the field's name for TalkBack.
        return Semantics(
          label: widget.hint,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            textInputAction: TextInputAction.search,
            autofocus: widget.autofocus,
            onSubmitted: _submitted,
            onChanged: _changed,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixIcon: const Icon(Icons.search_rounded),
              // Nothing to clear and nothing to close: no ✕ at all.
              suffixIcon: action == null
                  ? null
                  : IconButton(
                tooltip: !hasText && widget.onCloseEmpty != null
                    ? l.closeSearch
                    : !hasText && focused
                    ? l.closeKeyboard
                    : l.clearSearch,
                icon: const Icon(Icons.close_rounded),
                onPressed: action,
              ),
              filled: bare ? false : null,
              border: bare ? InputBorder.none : null,
              enabledBorder: bare ? InputBorder.none : null,
              focusedBorder: bare ? InputBorder.none : null,
            ),
          ),
        );
      },
    );
  }
}

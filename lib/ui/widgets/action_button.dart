import 'package:flutter/material.dart';

import '../../core/app_log.dart';
import 'show_msg.dart';

/// A button that runs [action] one at a time (disabled meanwhile). It says so
/// when [action] throws or returns false (with [failed]).
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.semantics,
    required this.action,
    required this.failed,
    this.build = TextButton.new,
  });

  final String label, semantics, failed;
  final Future<bool> Function() action;
  final Widget Function({required VoidCallback? onPressed, required Widget child}) build;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.action();
    } on Object catch (e, st) {
      AppLog.w('${widget.semantics} failed', e, st);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) showMsg(context, widget.failed);
  }

  @override
  Widget build(BuildContext context) => widget.build(
    onPressed: _busy ? null : _run,
    // The label names the song; the visible text would be read twice.
    child: Semantics(label: widget.semantics, child: ExcludeSemantics(child: Text(widget.label))),
  );
}

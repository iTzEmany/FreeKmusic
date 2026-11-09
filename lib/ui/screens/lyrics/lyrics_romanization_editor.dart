import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/romanization_ops.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/show_msg.dart';

/// Opens the editor of the transliteration typed by hand (D-475).
Future<void> openRomanizationEditor(
  BuildContext context,
  int trackId,
  String initial,
) => Navigator.of(context, rootNavigator: true).push(
  MaterialPageRoute<void>(
    builder: (_) =>
        RomanizationEditorScreen(trackId: trackId, initial: initial),
  ),
);

/// One line of transliteration for each line of the lyrics, saved through
/// [RomanizationOps]; it takes precedence over the found one.
class RomanizationEditorScreen extends ConsumerStatefulWidget {
  const RomanizationEditorScreen({
    super.key,
    required this.trackId,
    required this.initial,
  });

  final int trackId;
  final String initial;

  @override
  ConsumerState<RomanizationEditorScreen> createState() =>
      _RomanizationEditorScreenState();
}

class _RomanizationEditorScreenState
    extends ConsumerState<RomanizationEditorScreen> {
  late final _ctrl = TextEditingController(text: widget.initial);
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _saving = true;
    try {
      final undo = await ref
          .read(romanizationOpsProvider)
          .save(widget.trackId, _ctrl.text);
      if (undo == null) {
        _saving = false;
        showMsgOn(messenger, l.romanizationEmptyWarn);
        return;
      }
      nav.pop();
      showMsgOn(
        messenger,
        l.romanizationSaved,
        action: SnackBarAction(label: l.undo, onPressed: undo),
      );
    } on Object catch (e, st) {
      AppLog.e('save romanization failed', e, st);
      _saving = false;
      showMsgOn(messenger, l.romanizationSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cc.bg,
      appBar: CcAppBar(
        title: l.romanizationEditorTitle,
        actions: [
          TextButton(
            key: const ValueKey('romanization-save-bar'),
            onPressed: _save,
            child: Semantics(
              label: l.romanizationSaveA11y,
              excludeSemantics: true,
              child: Text(l.save),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          CcDims.margin,
          CcDims.gap8,
          CcDims.margin,
          CcDims.gap24,
        ),
        children: [
          Text(
            l.romanizationEditorLabel,
            style: theme.bodySmall?.copyWith(color: cc.textMuted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ctrl,
            minLines: 11,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: l.romanizationEditorHint,
              border: _border(Colors.transparent),
              enabledBorder: _border(Colors.transparent),
              focusedBorder: _border(cc.accent),
            ),
          ),
          const SizedBox(height: CcDims.gap8),
          Text(
            l.romanizationEditorInfo,
            style: theme.bodySmall?.copyWith(color: cc.textMuted),
          ),
          const SizedBox(height: CcDims.gap16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l.cancel),
              ),
              const SizedBox(width: 4),
              FilledButton(
                key: const ValueKey('romanization-save'),
                onPressed: _save,
                child: Text(l.save),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Small radius, not the theme's pill: a multi-line field.
  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(CcDims.rCard),
    borderSide: BorderSide(color: c),
  );
}

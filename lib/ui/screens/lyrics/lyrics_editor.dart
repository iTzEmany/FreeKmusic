import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_log.dart';
import '../../../data/db/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/track_ops.dart';
import '../../../services/online/lrc_parser.dart' show lyricsFromText, parseLrc;
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/confirm.dart';
import '../../widgets/show_msg.dart';

/// Asks before an editor with unsaved changes ([dirty]) is left by back or
/// «Annulla»; an explicit `Navigator.pop` (after saving) is not asked.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.dirty,
    required this.child,
  });

  final bool dirty;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      final l = context.l10n;
      final nav = Navigator.of(context);
      final discard = await showConfirm(
        context,
        title: l.themeDiscardTitle,
        body: l.editorDiscardBody,
        confirmLabel: l.themeDiscard,
        destructive: true,
      );
      if (discard) nav.pop();
    },
    child: child,
  );
}

/// Opens the lyrics editor for [track] (F-110).
Future<void> openLyricsEditor(BuildContext context, Track track) =>
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => LyricsEditorScreen(track: track)),
    );

/// Type or paste the lyrics of a track. Timed lines make them synced; the text
/// is always saved as the user's own, so the automatic search leaves it alone.
class LyricsEditorScreen extends ConsumerStatefulWidget {
  const LyricsEditorScreen({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends ConsumerState<LyricsEditorScreen> {
  late final _initial =
      widget.track.lyricsSynced ?? widget.track.lyricsPlain ?? '';
  late final _ctrl = TextEditingController(text: _initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ops = ref.read(trackOpsProvider);
    _saving = true;
    try {
      final synced = await ops.saveLyricsText(widget.track.id, _ctrl.text);
      if (synced == null) {
        _saving = false;
        showMsgOn(messenger, l.lyricsEmptyWarn);
        return;
      }
      nav.pop();
      showMsgOn(messenger, synced ? l.lyricsSavedSynced : l.lyricsSavedPlain);
    } on Object catch (e, st) {
      AppLog.e('save lyrics failed', e, st);
      _saving = false;
      showMsgOn(messenger, l.lyricsSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return UnsavedChangesGuard(
      dirty: _ctrl.text != _initial,
      child: Scaffold(
        backgroundColor: cc.bg,
        appBar: CcAppBar(
          title: l.lyricsEditorTitle,
          actions: [
            TextButton(
              key: const ValueKey('lyrics-save-bar'),
              onPressed: _save,
              child: Semantics(
                label: l.lyricsEditorSaveA11y,
                excludeSemantics: true,
                child: Text(l.save),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(
            CcDims.margin,
            CcDims.gap8,
            CcDims.margin,
            CcDims.gap16,
          ),
          // The field takes what the keyboard leaves; the buttons stay below it.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.lyricsEditorLabel,
                style: theme.bodySmall?.copyWith(color: cc.textMuted),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: l.lyricsEditorHint,
                    border: _border(Colors.transparent),
                    enabledBorder: _border(Colors.transparent),
                    focusedBorder: _border(cc.accent),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: CcDims.gap8),
              Semantics(
                liveRegion: true,
                child: Text(_detection(l), style: theme.bodyMedium),
              ),
              if (!keyboard) ...[
                const SizedBox(height: CcDims.gap8),
                Text(
                  l.lyricsEditorInfo,
                  style: theme.bodySmall?.copyWith(color: cc.textMuted),
                ),
              ],
              const SizedBox(height: CcDims.gap8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    key: const ValueKey('lyrics-save'),
                    onPressed: _save,
                    child: Text(l.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Small radius, not the theme's pill: a multi-line field.
  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(CcDims.rCard),
    borderSide: BorderSide(color: c),
  );

  String _detection(AppLocalizations l) {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return l.lyricsDetectNone;
    final n = parseLrc(text).length;
    return lyricsFromText(text).synced != null
        ? l.lyricsDetectSynced(n)
        : l.lyricsDetectPlain;
  }
}

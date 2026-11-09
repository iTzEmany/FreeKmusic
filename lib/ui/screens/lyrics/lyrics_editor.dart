import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/l10n_ext.dart';
import '../../../providers/settings_providers.dart';
import '../../../providers/track_ops.dart';
import '../../../services/online/lrc_parser.dart';
import '../../theme/tokens.dart';
import '../../widgets/cc_app_bar.dart';
import '../../widgets/show_msg.dart';

/// Opens the lyrics editor for [track] (F-110).
Future<void> openLyricsEditor(BuildContext context, Track track) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => LyricsEditorScreen(track: track)));

/// Type or paste the lyrics of a track. Timed lines make them synced; the text
/// is always saved as the user's own, so the automatic search leaves it alone.
class LyricsEditorScreen extends ConsumerStatefulWidget {
  const LyricsEditorScreen({super.key, required this.track});

  final Track track;

  @override
  ConsumerState<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends ConsumerState<LyricsEditorScreen> {
  late final _ctrl = TextEditingController(text: widget.track.lyricsSynced ?? widget.track.lyricsPlain ?? '');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    final parsed = lyricsFromText(_ctrl.text);
    if (parsed.plain == null) {
      showMsg(context, l.lyricsEmptyWarn);
      return;
    }
    final nav = Navigator.of(context);
    final id = widget.track.id;
    await ref.read(trackOpsProvider).setLyrics(id, plain: parsed.plain, synced: parsed.synced, byUser: true);
    // A new synced text starts with the sync on.
    await ref.read(unsyncedLyricsProvider.notifier).setSynced(id, true);
    if (!mounted) return;
    nav.pop();
    showMsg(nav.context, parsed.synced != null ? l.lyricsSavedSynced : l.lyricsSavedPlain);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cc.bg,
      appBar: CcAppBar(
        title: l.lyricsEditorTitle,
        actions: [
          TextButton(
            key: const ValueKey('lyrics-save-bar'),
            onPressed: _save,
            child: Semantics(label: l.lyricsEditorSaveA11y, excludeSemantics: true, child: Text(l.save)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, CcDims.gap24),
        children: [
          TextField(
            controller: _ctrl,
            minLines: 11,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(labelText: l.lyricsEditorLabel, hintText: l.lyricsEditorHint),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CcDims.gap8),
          Semantics(liveRegion: true, child: Text(_detection(l), style: theme.bodyMedium)),
          const SizedBox(height: CcDims.gap8),
          Text(l.lyricsEditorInfo, style: theme.bodySmall?.copyWith(color: cc.textMuted)),
          const SizedBox(height: CcDims.gap16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
              const SizedBox(width: 4),
              FilledButton(key: const ValueKey('lyrics-save'), onPressed: _save, child: Text(l.save)),
            ],
          ),
        ],
      ),
    );
  }

  String _detection(AppLocalizations l) {
    final text = _ctrl.text;
    if (text.trim().isEmpty) return l.lyricsDetectNone;
    final n = parseLrc(text).length;
    return lyricsFromText(text).synced != null ? l.lyricsDetectSynced(n) : l.lyricsDetectPlain;
  }
}

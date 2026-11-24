import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n_ext.dart';
import '../../providers/issue_providers.dart' show linkOpenerProvider;
import '../../services/update/release_notes.dart';
import '../theme/tokens.dart';

const releaseNoteIcons = <String, IconData>{
  'mic': Icons.mic_rounded,
  'play': Icons.play_circle_rounded,
  'home': Icons.home_rounded,
  'sync': Icons.sync_rounded,
  'heart': Icons.favorite_rounded,
  'share': Icons.share_rounded,
  'download': Icons.download_rounded,
  'settings': Icons.settings_rounded,
  'bug': Icons.bug_report_rounded,
  'search': Icons.search_rounded,
  'music': Icons.music_note_rounded,
  'playlist': Icons.queue_music_rounded,
  'queue': Icons.playlist_play_rounded,
  'lyrics': Icons.lyrics_rounded,
  'cloud': Icons.cloud_rounded,
  'shield': Icons.shield_rounded,
  'speed': Icons.speed_rounded,
  'palette': Icons.palette_rounded,
  'language': Icons.language_rounded,
  'star': Icons.star_rounded,
};

/// What a release brings: the highlight, the news, the fixes (closed) and the link to GitHub.
/// Shared by «Aggiornamento disponibile» and «Aggiornata alla X». Without a block: «Correzioni e miglioramenti».
class ReleaseNotesView extends ConsumerWidget {
  const ReleaseNotesView({super.key, required this.notes, required this.url});

  final ReleaseNotes notes;
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final h = notes.highlight;
    Widget head(String t) => Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (notes.isEmpty)
          ListTile(leading: const Icon(Icons.auto_fix_high_rounded), title: Text(l.updateFixesGeneric)),
        if (h != null) ...[head(l.updateHighlight), _NoteTile(h, big: true)],
        if (notes.news.isNotEmpty) ...[
          head(h == null ? l.updateNews : l.updateAlsoHere),
          for (final n in notes.news) _NoteTile(n),
        ],
        if (notes.fixes.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Semantics(header: true, child: Text(l.updateFixes(notes.fixes.length))),
            children: [for (final f in notes.fixes) ListTile(dense: true, title: Text(f))],
          ),
        TextButton.icon(
          onPressed: () => ref.read(linkOpenerProvider).open(url),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(l.updateAllChanges),
        ),
      ],
    );
  }
}

/// One stop for TalkBack: icon, title and text read together.
class _NoteTile extends StatelessWidget {
  const _NoteTile(this.note, {this.big = false});

  final ReleaseNote note;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final icon = Icon(
      releaseNoteIcons[note.icon] ?? Icons.star_rounded,
      color: t.colorScheme.primary,
      size: big ? 32 : 24,
    );
    return MergeSemantics(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.all(big ? 16 : 4),
        decoration: big
            ? BoxDecoration(
                color: t.colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(CcDims.rCard),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.title, style: big ? t.textTheme.titleLarge : t.textTheme.titleSmall),
                  Text(note.text, style: t.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

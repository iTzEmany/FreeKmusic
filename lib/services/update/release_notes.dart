/// Icon names a release note may use; the UI maps each to a Material icon
/// (`release_notes_view.dart`). Anything else becomes [kReleaseNoteGenericIcon].
const kReleaseNoteIcons = [
  'mic',
  'play',
  'home',
  'sync',
  'heart',
  'share',
  'download',
  'settings',
  'bug',
  'search',
  'music',
  'playlist',
  'queue',
  'lyrics',
  'cloud',
  'shield',
  'speed',
  'palette',
  'language',
  'star',
];
const kReleaseNoteGenericIcon = 'star';

class ReleaseNote {
  const ReleaseNote(this.icon, this.title, this.text);

  /// One of [kReleaseNoteIcons].
  final String icon;
  final String title;
  final String text;
}

/// The hand-written block of a release body (D-711): `## Novità` and `## Correzioni`.
class ReleaseNotes {
  const ReleaseNotes({this.highlight, this.news = const [], this.fixes = const []});

  final ReleaseNote? highlight;
  final List<ReleaseNote> news;
  final List<String> fixes;

  bool get isEmpty => highlight == null && news.isEmpty && fixes.isEmpty;
}

/// Reads the block out of a release [body]; the rest (GitHub's «What's Changed») is ignored,
/// broken lines are skipped and nothing here throws.
ReleaseNotes parseReleaseNotes(String? body) {
  ReleaseNote? highlight;
  final news = <ReleaseNote>[];
  final fixes = <String>[];
  var section = '';
  for (final raw in (body ?? '').split('\n')) {
    final line = raw.trim();
    if (line.startsWith('#')) {
      // «## NOVITÀ:», «##Correzioni», «Novita»: case, accent, colon and spaces do not matter.
      section = line
          .replaceFirst(RegExp(r'^#+\s*'), '')
          .replaceAll(RegExp(r'[\s:]+$'), '')
          .toLowerCase()
          .replaceAll('à', 'a');
      continue;
    }
    if (!line.startsWith('-')) continue;
    final item = line.substring(1).trim();
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(item)) continue; // «-», «---»
    if (section == 'correzioni') {
      if (item.isNotEmpty) fixes.add(item);
    } else if (section == 'novita') {
      final parts = item.split('|').map((p) => p.trim()).toList();
      final lead = parts.isNotEmpty && parts.first.toLowerCase() == 'evidenza';
      if (lead) parts.removeAt(0);
      if (parts.length < 3 || parts[1].isEmpty || parts[2].isEmpty) continue;
      final icon = kReleaseNoteIcons.contains(parts[0].toLowerCase())
          ? parts[0].toLowerCase()
          : kReleaseNoteGenericIcon;
      final note = ReleaseNote(icon, parts[1], parts.sublist(2).join(' | '));
      if (lead && highlight == null) {
        highlight = note;
      } else {
        news.add(note);
      }
    }
  }
  return ReleaseNotes(highlight: highlight, news: news, fixes: fixes);
}

import 'karaoke_channels.dart';
import 'merge_results.dart';

final _isKaraoke = RegExp('karaoke', caseSensitive: false);
final _reaction = RegExp(r'\breactions?\b', caseSensitive: false);

/// «cover» / «live» only as a tag: in brackets, or as a whole segment after a
/// separator («- Live», «| Live karaoke»), so «Live Forever» and «Cover Me»
/// stay.
final _tagged = RegExp(
  r'[\(\[][^\)\]]*\b(cover|live)\b|(?:\s[-–—|]\s|\|)\s*(?:karaoke\s+)?(?:cover|live)(?:\s+karaoke)?(?:\s+version)?(?=\s*(?:$|[-–—|(\[]))',
  caseSensitive: false,
);

/// [results] that are karaoke videos: «karaoke» in the title, no reaction,
/// cover or live; known channels first, the rest in the order given.
List<SmartResult> karaokeResults(List<SmartResult> results) {
  final kept = [
    for (final r in results)
      if (_isKaraoke.hasMatch(r.primary.title) &&
          !_reaction.hasMatch(r.primary.title) &&
          !_tagged.hasMatch(r.primary.title))
        r,
  ];
  bool known(SmartResult r) {
    final c = r.primary.channel.toLowerCase();
    return kKnownKaraokeChannels.any(c.contains);
  }

  return [...kept.where(known), ...kept.where((r) => !known(r))];
}

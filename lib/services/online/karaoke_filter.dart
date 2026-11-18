import 'merge_results.dart';

/// Channels that publish real karaoke backing tracks (lowercase).
const kKnownKaraokeChannels = ['sing king', 'karafun', 'karaoke version', 'stingray'];

final _isKaraoke = RegExp('karaoke', caseSensitive: false);
final _reaction = RegExp(r'\breaction\b', caseSensitive: false);

/// «cover» / «live» only as a tag: in brackets or after a separator, so
/// «Live Forever (Karaoke Version)» stays.
final _tagged = RegExp(
  r'[\(\[][^\)\]]*\b(cover|live)\b|(?:\s[-–—|]\s).*\b(cover|live)\b',
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

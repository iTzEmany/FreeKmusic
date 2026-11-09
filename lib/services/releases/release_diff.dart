import '../online/ytm_artist.dart';
import '../../core/artist_key.dart';

/// What a release is, from how YouTube writes its subtitle.
enum ReleaseKind { album, single }

/// A release found on the artist page, read for storing.
class SeenRelease {
  const SeenRelease({
    required this.release,
    required this.kind,
    required this.year,
    required this.groupKey,
  });

  final YtmRelease release;
  final ReleaseKind kind;
  final int? year;
  final String groupKey;
}

/// A release to tell the user about; [variants] are the other versions of it
/// that came in the same round (deluxe, acoustic, track by track…).
class NewRelease extends SeenRelease {
  const NewRelease({
    required super.release,
    required super.kind,
    required super.year,
    required super.groupKey,
    this.variants = const [],
  });

  final List<YtmRelease> variants;
}

class ReleaseDiff {
  const ReleaseDiff(this.toStore, this.fresh);

  /// Every release not stored yet (variants included).
  final List<SeenRelease> toStore;

  /// The new ones, one per group of variants; most recent year first.
  final List<NewRelease> fresh;
}

/// The year in a subtitle («2025», «Single • 2025», «Singolo • 2026»): the
/// first of its numbers that is a plausible year (1900 up to next year).
int? releaseYear(String subtitle, {DateTime? now}) {
  final max = (now ?? DateTime.now()).year + 1;
  for (final m in RegExp(r'(?<!\d)(\d{4})(?!\d)').allMatches(subtitle)) {
    final y = int.parse(m.group(1)!);
    if (y >= 1900 && y <= max) return y;
  }
  return null;
}

/// Albums have just the year as subtitle; singles and EPs say so before it.
ReleaseKind releaseKind(String subtitle) =>
    subtitle.contains('•') ? ReleaseKind.single : ReleaseKind.album;

final _brackets = RegExp(r'[\(\[][^\)\]]*[\)\]]');
final _afterMark = RegExp(r'[:+].*$');
final _versionWords = RegExp(r'\b(deluxe|edition|version)\b', caseSensitive: false);

/// One key for the variants of a title: no brackets, nothing after «:» or
/// «+», no «Deluxe», «Edition», «Version». A reissue with a title of its own
/// («… 40° RPLAY Special Edition») keeps a key of its own.
String releaseGroupKey(String title) {
  final stripped = title
      .replaceAll(_brackets, ' ')
      .replaceAll(_afterMark, '')
      .replaceAll(_versionWords, ' ');
  final key = matchKey(stripped);
  return key.isEmpty ? matchKey(title) : key;
}

/// Compares what the artist page lists ([fetched]) with what is stored.
///
/// - [known]: ids already stored; [knownGroups]: `kind:groupKey` of the stored
///   ones (see [releaseGroupId]): a variant of a title that was already there
///   is not new.
/// - [firstCheck]: everything is stored, nothing is new.
/// - New = unknown id, not a variant of a known title, year >= this year - 1
///   (an old release YouTube shows only now is not news).
/// - Order is by year, then title, never by position in the carousel.
ReleaseDiff diffReleases({
  required Set<String> known,
  required List<YtmReleaseShelf> fetched,
  required bool firstCheck,
  required DateTime now,
  Set<String> knownGroups = const {},
}) {
  final seen = <String>{};
  final all = <SeenRelease>[];
  for (final shelf in fetched) {
    for (final r in shelf.releases) {
      if (!seen.add(r.browseId)) continue;
      all.add(SeenRelease(
        release: r,
        kind: releaseKind(r.subtitle),
        year: releaseYear(r.subtitle, now: now),
        groupKey: releaseGroupKey(r.title),
      ));
    }
  }
  final unknown = [for (final s in all) if (!known.contains(s.release.browseId)) s];
  if (firstCheck || unknown.isEmpty) return ReleaseDiff(unknown, const []);

  // A group already stored (or with a member already stored) is not new.
  final groupsSeenBefore = {
    ...knownGroups,
    for (final s in all)
      if (known.contains(s.release.browseId)) releaseGroupId(s.kind, s.groupKey),
  };
  final groups = <String, List<SeenRelease>>{};
  for (final s in unknown) {
    (groups[releaseGroupId(s.kind, s.groupKey)] ??= []).add(s);
  }
  final year = now.year;
  final fresh = <NewRelease>[];
  for (final e in groups.entries) {
    if (groupsSeenBefore.contains(e.key)) continue;
    // The original title (the shortest) represents the group; latest year wins ties.
    final members = [...e.value]..sort((a, b) {
        final byLen = a.release.title.length.compareTo(b.release.title.length);
        return byLen != 0 ? byLen : (b.year ?? 0).compareTo(a.year ?? 0);
      });
    final head = members.first;
    final y = head.year;
    if (y == null || y < year - 1) continue;
    fresh.add(NewRelease(
      release: head.release,
      kind: head.kind,
      year: y,
      groupKey: head.groupKey,
      variants: [for (final m in members.skip(1)) m.release],
    ));
  }
  fresh.sort((a, b) {
    final byYear = b.year!.compareTo(a.year!);
    return byYear != 0 ? byYear : a.release.title.compareTo(b.release.title);
  });
  return ReleaseDiff(unknown, fresh);
}

/// What groups releases: the kind and the title key (a single with the title
/// of an album is not a variant of it).
String releaseGroupId(ReleaseKind kind, String groupKey) => '${kind.index}:$groupKey';

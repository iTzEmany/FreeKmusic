import '../../core/audio_format.dart';
import '../import/track_matcher.dart';
import '../../core/artist_key.dart';

/// Two durations this close (ms) are the same recording.
const duplicateDurationToleranceMs = 2000;

/// What the finder needs to know about one library track: loaded in one light
/// query, plain data so it can cross an isolate.
class DupEntry {
  const DupEntry({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    required this.durationMs,
    required this.format,
    required this.sizeBytes,
    this.bitrateKbps,
    this.sampleRateHz,
    this.bitDepth,
    this.hasCover = false,
    this.userEdited = false,
    this.addedAt = 0,
    this.sha256,
  });

  final int id;
  final String path;
  final String title;
  final String? artist;
  final int durationMs;
  final String format;
  final int sizeBytes;
  final int? bitrateKbps;
  final int? sampleRateHz;
  final int? bitDepth;
  final bool hasCover;
  final bool userEdited;
  final int addedAt;

  /// Cached by an earlier search; null until the file was hashed.
  final String? sha256;
}

/// Tracks that look like the same recording. [members] are best first, so
/// `members.first` is the one proposed to keep.
class DuplicateGroup {
  const DuplicateGroup(this.members, {required this.exact});

  final List<DupEntry> members;

  /// The files are byte for byte the same (equal SHA-256).
  final bool exact;

  DupEntry get proposed => members.first;

  /// The same group of tracks whatever the order: used to remember «these are
  /// not duplicates».
  String get key => (members.map((m) => m.id).toList()..sort()).join(',');
}

/// Which of several versions to keep: lossless, then the higher bitrate, then
/// the one the user edited, then the one with a cover, then the oldest.
int compareKeeper(DupEntry a, DupEntry b) {
  final la = isLosslessFormat(a.format), lb = isLosslessFormat(b.format);
  if (la != lb) return la ? -1 : 1;
  final byRate = (b.bitrateKbps ?? 0).compareTo(a.bitrateKbps ?? 0);
  if (byRate != 0) return byRate;
  if (a.userEdited != b.userEdited) return a.userEdited ? -1 : 1;
  if (a.hasCover != b.hasCover) return a.hasCover ? -1 : 1;
  final byAge = a.addedAt.compareTo(b.addedAt);
  return byAge != 0 ? byAge : a.id.compareTo(b.id);
}

/// Tracks whose file size equals another track's and that were never hashed:
/// the only ones worth reading from disk (equal bytes mean equal size).
List<DupEntry> hashCandidates(List<DupEntry> lib) {
  final bySize = <int, int>{};
  for (final e in lib) {
    if (e.sizeBytes > 0) bySize[e.sizeBytes] = (bySize[e.sizeBytes] ?? 0) + 1;
  }
  return [
    for (final e in lib)
      if (e.sha256 == null && (bySize[e.sizeBytes] ?? 0) > 1) e,
  ];
}

/// Groups of duplicates. Two tracks are joined when their files have the same
/// hash ([hashes] adds to what the entries already carry) or when they have the
/// same title (ignoring remaster/feat. qualifiers) and main artist and lengths
/// within [duplicateDurationToleranceMs], chained. A track without title or
/// artist is never joined by name: «Track 01» of unknown artists is no match.
List<DuplicateGroup> findDuplicates(
  List<DupEntry> lib, {
  Map<int, String> hashes = const {},
}) {
  final parent = List<int>.generate(lib.length, (i) => i);
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra != rb) parent[rb] = ra;
  }

  String? hashOf(DupEntry e) => hashes[e.id] ?? e.sha256;

  final byHash = <String, int>{};
  final byName = <String, List<int>>{};
  for (var i = 0; i < lib.length; i++) {
    final e = lib[i];
    final h = hashOf(e);
    if (h != null) {
      final first = byHash.putIfAbsent(h, () => i);
      if (first != i) union(first, i);
    }
    final title = matchTitleKey(e.title);
    final artist = artistKey(e.artist);
    if (title.isNotEmpty && artist.isNotEmpty) {
      (byName['$title|$artist'] ??= []).add(i);
    }
  }
  for (final idx in byName.values) {
    if (idx.length < 2) continue;
    idx.sort((a, b) => lib[a].durationMs.compareTo(lib[b].durationMs));
    for (var k = 1; k < idx.length; k++) {
      final gap = lib[idx[k]].durationMs - lib[idx[k - 1]].durationMs;
      if (gap <= duplicateDurationToleranceMs) union(idx[k - 1], idx[k]);
    }
  }

  final groups = <int, List<DupEntry>>{};
  for (var i = 0; i < lib.length; i++) {
    (groups[find(i)] ??= []).add(lib[i]);
  }
  final out = <DuplicateGroup>[];
  for (final members in groups.values) {
    if (members.length < 2) continue;
    members.sort(compareKeeper);
    final hs = {for (final m in members) hashOf(m)};
    out.add(DuplicateGroup(members, exact: hs.length == 1 && !hs.contains(null)));
  }
  out.sort((a, b) {
    if (a.exact != b.exact) return a.exact ? -1 : 1;
    final byTitle = matchTitleKey(a.proposed.title)
        .compareTo(matchTitleKey(b.proposed.title));
    return byTitle != 0 ? byTitle : a.proposed.id.compareTo(b.proposed.id);
  });
  return out;
}

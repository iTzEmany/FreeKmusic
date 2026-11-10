import '../../core/artist_key.dart';
import '../../core/import_row.dart';
import '../online/youtube_service.dart';
import 'track_matcher.dart';

/// The three searches made for [row]: ISRC, `artist title`, `artist - title`.
List<String> searchQueries(ImportRow row) => [
  row.isrc ?? '',
  '${matchKey(row.primaryArtist)} ${matchTitleKey(row.title)}'.trim(),
  '${row.primaryArtist} - ${row.title}',
];

/// Searches YouTube for [row]: the ISRC first (a sure match ends it), then
/// [afterIsrc] if given (e.g. the album lookup), then the two text queries.
/// [thresholds] is read at every decision.
Future<MatchDecision> searchRow(
  ImportRow row,
  YoutubeService youtube, {
  required MatchThresholds Function() thresholds,
  required Duration gap,
  Future<MatchDecision?> Function()? afterIsrc,
}) async =>
    await _byIsrc(row, youtube, thresholds, gap) ??
    await afterIsrc?.call() ??
    await _find(row, youtube, thresholds, gap);

/// The ISRC identifies the recording: a sure match ends the search. Any
/// other answer is dropped, so a wrong code cannot lift a candidate's score.
Future<MatchDecision?> _byIsrc(
  ImportRow row,
  YoutubeService youtube,
  MatchThresholds Function() thresholds,
  Duration searchGap,
) async {
  final isrc = row.isrc;
  if (isrc == null || isrc.isEmpty) return null;
  final d = decide(
    row,
    await youtube.searchSongs(isrc, limit: 3),
    thresholds: thresholds(),
  );
  if (d.kind == MatchKind.sure) return d;
  await Future<void>.delayed(searchGap);
  return null;
}

Future<MatchDecision> _find(
  ImportRow row,
  YoutubeService youtube,
  MatchThresholds Function() thresholds,
  Duration searchGap,
) async {
  final queries = searchQueries(row);
  final query = queries[1];
  final songs = await youtube.searchSongs(query, limit: 5);
  var decision = decide(row, songs, thresholds: thresholds());
  if (decision.kind == MatchKind.sure) return decision;
  await Future<void>.delayed(searchGap);
  final plain = await youtube.search(queries[2]);
  final seen = {for (final s in songs) s.id};
  decision = decide(row, [
    ...songs,
    for (final p in plain.take(5))
      if (seen.add(p.id)) p,
  ], thresholds: thresholds());
  return decision;
}

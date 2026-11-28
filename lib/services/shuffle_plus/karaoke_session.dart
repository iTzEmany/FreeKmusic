import 'dart:async';

import '../../core/artist_key.dart';
import '../../core/import_row.dart';
import '../import/track_matcher.dart';
import '../online/karaoke_filter.dart';
import '../online/merge_results.dart' show SmartResult;
import '../online/query_cleaner.dart';
import '../online/smart_search.dart';
import '../online/youtube_service.dart';
import 'suggestion_pool.dart' show RadioSeed;

/// A smart search: the rows of [query] (videos alone when [videoOnly]).
typedef KaraokeSearch = Future<List<SmartResult>> Function(
  String query, {
  bool videoOnly,
});

bool _accepted(ImportRow row, YtResult c) =>
    decide(row, [c]).kind == MatchKind.sure;

/// The song a karaoke pick is a backing track of, as the seed of the radio:
/// the karaoke title cleaned, searched on YouTube Music (never a karaoke row)
/// and accepted by [decide]; null when none matches (D-766).
Future<RadioSeed?> karaokeOriginalSeed(
  YtResult karaoke,
  KaraokeSearch search,
) async {
  final q = karaokeLyricsQuery(karaoke.title, karaoke.channel);
  if (q.title.isEmpty) return null;
  final row = ImportRow(
    index: 0,
    title: q.title,
    artists: [if (q.artist.isNotEmpty) q.artist],
    durationMs: karaoke.duration?.inMilliseconds,
  );
  for (final r in await search(
    '${q.artist} ${q.title}'.trim(),
    videoOnly: false,
  )) {
    final c = r.primary;
    if (!isKaraokeTitle(c.title) && _accepted(row, c)) {
      return RadioSeed.online(c.id, c.title);
    }
  }
  return null;
}

/// The karaoke video of the song [similar]: the first karaoke result of the
/// videos search that [decide] accepts against its title and artist; null
/// when there is none.
Future<YtResult?> karaokeVideoFor(
  YtResult similar,
  KaraokeSearch search,
) async {
  final artist = similar.artists.isEmpty ? '' : similar.artists.first;
  final row = ImportRow(
    index: 0,
    title: similar.title,
    artists: [if (artist.isNotEmpty) artist],
    durationMs: similar.duration?.inMilliseconds,
  );
  final found = await search(
    '$artist ${similar.title} karaoke'.trim(),
    videoOnly: true,
  );
  for (final r in karaokeResults(found)) {
    final c = r.primary;
    final q = karaokeLyricsQuery(c.title, c.channel);
    // The karaoke title minus its tags and channel, so «(Karaoke Version)» does not weigh.
    final cleaned = YtResult(
      id: c.id,
      title: q.title.isEmpty ? c.title : q.title,
      channel: c.channel,
      duration: c.duration,
      thumbnailUrl: c.thumbnailUrl,
      artists: q.artist.isNotEmpty ? [q.artist] : c.artists,
      source: c.source,
      webpageUrl: c.webpageUrl,
    );
    // A different artist in the title is another song: the score alone can let it through.
    if (artist.isNotEmpty &&
        q.artist.isNotEmpty &&
        artistKey(q.artist) != artistKey(artist)) {
      continue;
    }
    if (_accepted(row, cleaned)) return c;
  }
  return null;
}

/// [engine] as a [KaraokeSearch]: the first state with every source answered.
/// The search is not cancelled then: it stores itself in the engine's 10-minute
/// cache only when it has run to the end.
KaraokeSearch karaokeSearchOn(SmartSearch engine, String hl) =>
    (query, {bool videoOnly = false}) {
      final done = Completer<List<SmartResult>>();
      engine
          .run(query, hl, videoOnly: videoOnly)
          .listen(
            (s) {
              if (s.loading || done.isCompleted) return;
              final e = s.error;
              if (e is YtException && e.kind == YtErrorKind.rateLimited) {
                done.completeError(e);
              } else {
                done.complete([...s.best, ...s.others]);
              }
            },
            onError: (Object e, StackTrace st) {
              if (!done.isCompleted) done.completeError(e, st);
            },
            onDone: () {
              if (!done.isCompleted) done.complete(const []);
            },
          );
      return done.future;
    };

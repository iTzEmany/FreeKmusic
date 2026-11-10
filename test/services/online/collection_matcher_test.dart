import 'package:codecore/core/import_row.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/budgeted_call.dart';
import 'package:codecore/services/online/collection_matcher.dart';
import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/query_match.dart';
import 'package:codecore/services/online/request_budget.dart';
import 'package:codecore/services/online/source_cooldown.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeYoutube implements YoutubeService {
  final songs = <String, List<YtResult>>{};
  final calls = <String>[];

  /// Called before each search; may throw.
  void Function(String query)? onSearch;

  List<YtResult> _hit(String q) {
    calls.add(q);
    onSearch?.call(q);
    return songs[q] ?? const [];
  }

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) async => _hit(query);

  @override
  Future<List<YtResult>> search(String query) async => _hit(query);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

YtResult yt(String id, String title, String artist, int seconds) => YtResult(
      id: id,
      title: title,
      channel: artist,
      duration: Duration(seconds: seconds),
      artists: [artist],
    );

Track libTrack(int id) => Track(
      coverSource: 0,
      id: id,
      path: '/m/$id.mp3',
      title: 'Time',
      artist: 'Pink Floyd',
      albumKey: 'k',
      durationMs: 413000,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false,
      kind: 0,
      addedAt: 1,
      playCount: 0,
    );

const time = ExternalTrack(
    title: 'Time', artists: ['Pink Floyd'], key: 't', durationMs: 413000);
const other = ExternalTrack(
    title: 'Money', artists: ['Pink Floyd'], key: 'm', durationMs: 382000);
// The text query searchRow builds for [time].
const timeQuery = 'pink floyd time';

void main() {
  late FakeYoutube youtube;
  late DateTime clock;
  late SourceCooldown cooldown;
  late WindowLimiter limiter;
  late List<Duration> waits;
  LibraryIndex? index;
  var thresholds = const MatchThresholds();

  CollectionMatcher build() => CollectionMatcher(
        youtube: youtube,
        cooldown: cooldown,
        limiter: limiter,
        library: () => index,
        trackById: (id) async => libTrack(id),
        thresholds: () => thresholds,
        gap: Duration.zero,
        wait: (d) async {
          waits.add(d);
          clock = clock.add(d);
        },
      );

  setUp(() {
    youtube = FakeYoutube();
    clock = DateTime(2026, 1, 1);
    cooldown = SourceCooldown(now: () => clock);
    limiter = WindowLimiter(perMinute: kLinkMatchPerMinute, now: () => clock);
    waits = [];
    index = null;
    thresholds = const MatchThresholds();
  });

  Future<List<(int, TrackMatch)>> run(CollectionMatcher m, List<ExternalTrack> t) =>
      m.match(t).toList();

  test('a song in the library is matched without any request', () async {
    index = LibraryIndex(
        const [LibraryEntryLite(id: 7, title: 'Time', artist: 'Pink Floyd', durationMs: 413000)]);
    final r = await run(build(), [time]);
    expect(((r.single.$2) as TrackReadyLibrary).track.id, 7);
    expect(youtube.calls, isEmpty);
    expect(limiter.recent, 0);
  });

  test('a sure match by ISRC ends the search', () async {
    youtube.songs['GB123'] = [yt('isrc1', 'Time', 'Pink Floyd', 413)];
    final t = ExternalTrack(
        title: 'Time', artists: const ['Pink Floyd'], key: 't', durationMs: 413000, isrc: 'GB123');
    final r = await run(build(), [t]);
    expect((r.single.$2 as TrackReadyOnline).result.id, 'isrc1');
    expect(youtube.calls, ['GB123']);
  });

  test('text match, in page order', () async {
    youtube.songs[timeQuery] = [yt('a', 'Time', 'Pink Floyd', 413)];
    youtube.songs['pink floyd money'] = [yt('b', 'Money', 'Pink Floyd', 382)];
    final r = await run(build(), [time, other]);
    expect([for (final e in r) e.$1], [0, 1]);
    expect([for (final e in r) (e.$2 as TrackReadyOnline).result.id], ['a', 'b']);
  });

  test('a review match counts as found, a stricter threshold does not', () async {
    // Same title and length but another channel: between the two cutoffs.
    youtube.songs[timeQuery] = [yt('weak', 'Time', 'Someone Else', 413)];
    final found = await run(build(), [time]);
    final kind = found.single.$2;
    if (kind is TrackReadyOnline) {
      thresholds = const MatchThresholds(sure: 0.98, review: 0.97);
      final strict = await run(build(), [time]);
      expect(strict.single.$2, isA<TrackNotFound>());
    } else {
      fail('expected a review match, got $kind');
    }
  });

  test('nothing found: TrackNotFound', () async {
    final r = await run(build(), [time]);
    expect(r.single.$2, isA<TrackNotFound>());
  });

  test('no budget: waits for a slot, then retries', () async {
    youtube.songs[timeQuery] = [yt('a', 'Time', 'Pink Floyd', 413)];
    for (var i = 0; i < kLinkMatchPerMinute; i++) {
      expect(limiter.tryAcquire(), isTrue);
    }
    final r = await run(build(), [time]);
    expect(r.single.$2, isA<TrackReadyOnline>());
    expect(waits, isNotEmpty);
    expect(waits.fold<Duration>(Duration.zero, (a, b) => a + b),
        greaterThanOrEqualTo(const Duration(seconds: 60)));
  });

  test('a 429 pauses the shared source; the matcher waits its end and goes on', () async {
    youtube.songs[timeQuery] = [yt('a', 'Time', 'Pink Floyd', 413)];
    var first = true;
    youtube.onSearch = (_) {
      if (first) {
        first = false;
        throw const YtException(YtErrorKind.rateLimited);
      }
    };
    final start = clock;
    final r = await run(build(), [time]);
    expect(r.single.$2, isA<TrackReadyOnline>());
    expect(clock.difference(start), greaterThanOrEqualTo(cooldown.pause));
    expect(cooldown.isPaused(MediaKind.ytmSong), isFalse);
  });

  test('cancel() stops the matching: no further request', () async {
    youtube.songs[timeQuery] = [yt('a', 'Time', 'Pink Floyd', 413)];
    final m = build();
    final got = <int>[];
    await for (final e in m.match([time, other, time])) {
      got.add(e.$1);
      m.cancel();
    }
    expect(got, [0]);
    expect(youtube.calls, [timeQuery]);
  });

  test('isolation: a matcher 429 leaves Cerca budget full; only the pause stops Cerca', () async {
    final cerca = WindowLimiter(perMinute: kSearchRowsPerMinute, now: () => clock);
    youtube.songs[timeQuery] = [yt('a', 'Time', 'Pink Floyd', 413)];
    var first = true;
    youtube.onSearch = (_) {
      if (first) {
        first = false;
        throw const YtException(YtErrorKind.rateLimited);
      }
    };
    final start = clock;
    var stoppedWhilePaused = 0;
    final m = CollectionMatcher(
      youtube: youtube,
      cooldown: cooldown,
      limiter: limiter,
      library: () => null,
      trackById: (id) async => libTrack(id),
      thresholds: () => thresholds,
      gap: Duration.zero,
      wait: (d) async {
        // Cerca asks while the matcher waits: the pause says no, free of charge.
        if (budgetedYtm<int>(cooldown, cerca, () async => 1) == null) stoppedWhilePaused++;
        clock = clock.add(d);
      },
    );
    await run(m, [time]);
    expect(stoppedWhilePaused, greaterThan(0));
    expect(clock.difference(start), greaterThanOrEqualTo(cooldown.pause));
    expect(limiter.granted.length, 2); // the 429 and the retry, all on the matcher's own budget
    expect(cerca.recent, 0);
    expect(await budgetedYtm<int>(cooldown, cerca, () async => 1), 1);
    expect(cerca.recent, 1);
  });
}

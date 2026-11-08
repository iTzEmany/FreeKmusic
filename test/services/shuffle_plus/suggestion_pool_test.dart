import 'dart:io';

import '../../support/suggestion_gate_fake.dart';

import 'package:codecore/core/import_row.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart';
import 'package:flutter_test/flutter_test.dart';

RadioItem item(String id,
        {String artist = 'Artist', int seconds = 200, RadioKind kind = RadioKind.song, bool seed = false}) =>
    RadioItem(
      YtResult(
        id: id,
        title: 'Title $id',
        channel: artist,
        duration: Duration(seconds: seconds),
        artists: kind == RadioKind.song ? [artist] : const [],
        album: kind == RadioKind.song ? 'Album' : null,
      ),
      kind,
      isSeed: seed,
    );

RadioPage page(List<RadioItem> items) => RadioPage(items);

void main() {
  late DateTime now;
  late SuggestionLog log;
  late SuggestionPool pool;
  var libraryIds = <String>{};
  var queued = <String>{};
  var blockedTracks = <String>[];
  var blockedArtists = <String>[];

  SuggestionCandidate? take({List<String> last = const []}) => pool.take(
    inLibrary: (r) => libraryIds.contains(r.id) || r.title == 'Owned',
    inQueue: queued.contains,
    log: log,
    filter: testGate(tracks: blockedTracks, artists: blockedArtists),
    lastArtists: last,
  );

  List<String> takeAll() {
    final out = <String>[];
    for (var c = take(); c != null; c = take()) {
      out.add(c.result.id);
    }
    return out;
  }

  setUp(() async {
    now = DateTime.utc(2026, 1, 1);
    log = SuggestionLog(
      file: () async => File('/nonexistent/none.json'),
      now: () => now,
      writeDelay: const Duration(days: 1),
    );
    await log.load();
    pool = SuggestionPool();
    libraryIds = {};
    queued = {};
    blockedTracks = [];
    blockedArtists = [];
  });

  test('skips what is in the library by id and by title', () {
    libraryIds = {'a'};
    pool.addPage('s', 'Seed', page([item('a'), item('b'), RadioItem(
        const YtResult(id: 'c', title: 'Owned', channel: 'X', duration: Duration(seconds: 200), artists: ['X'], album: 'A'),
        RadioKind.song)]));
    expect(takeAll(), ['b']);
  });

  test('skips a song suggested 10 days ago but not one suggested 40 days ago', () {
    log.add(videoId: 'old', title: 't', artist: 'a', seedTitle: 's');
    now = now.add(const Duration(days: 40));
    log.add(videoId: 'recent', title: 't', artist: 'a', seedTitle: 's');
    now = now.add(const Duration(days: 10));
    pool.addPage('s', 'Seed', page([item('old', artist: 'A'), item('recent', artist: 'B'), item('new', artist: 'C')]));
    expect(takeAll(), ['old', 'new']);
  });

  test('a blocked song needs two seeds with it in their first 10 rows', () {
    blockedTracks = ['bad'];
    pool.addPage('s1', 'One', page([item('bad'), item('ok', artist: 'B')]));
    expect(takeAll(), ['ok']);
    pool.addPage('s2', 'Two', page([item('bad')]));
    expect(takeAll(), ['bad']);
  });

  test('rows are counted across the pages of a seed: row 10 counts, row 11 does not', () {
    blockedTracks = ['bad'];
    List<RadioItem> fillers(String p) => [for (var i = 0; i < 10; i++) item('$p$i', artist: 'A$p$i')];
    // s1 has it at row 10 of its first page; s2 only at row 11 (second page).
    pool.addPage('s1', 'One', page([...fillers('x').take(9), item('bad')]));
    pool.addPage('s2', 'Two', RadioPage(fillers('y'), continuation: 'next'));
    pool.addPage('s2', 'Two', page([item('bad')]));
    expect(pool.positionsOf('bad'), [10, 11]);
    expect(takeAll(), isNot(contains('bad')));
    // a third seed with it at row 1 makes two seeds in the top 10
    pool.addPage('s3', 'Three', page([item('bad')]));
    expect(takeAll(), ['bad']);
  });

  test('a blocked artist is never taken', () {
    blockedArtists = ['b'];
    pool.addPage('s1', 'One', page([item('ok', artist: 'B')]));
    pool.addPage('s2', 'Two', page([item('ok', artist: 'B')]));
    expect(takeAll(), isEmpty);
  });

  test('skips what is already in the queue, and takes it once it is gone', () {
    queued = {'a'};
    pool.addPage('s', 'Seed', page([item('a', artist: 'A'), item('b', artist: 'B')]));
    expect(take()?.result.id, 'b');
    expect(take(), isNull);
    queued = {};
    expect(take()?.result.id, 'a');
  });

  test('skips too short, too long, uploads and the seed itself', () {
    pool.addPage('s', 'Seed', page([
      item('short', seconds: 59, artist: 'A'),
      item('long', seconds: 12 * 60 + 1, artist: 'B'),
      item('upload', kind: RadioKind.upload, artist: 'C'),
      item('seed', seed: true, artist: 'D'),
      item('edge1', seconds: 60, artist: 'E'),
      item('edge2', seconds: 12 * 60, artist: 'F'),
    ]));
    expect(takeAll(), ['edge1', 'edge2']);
  });

  test('artist videos only when the songs are finished', () {
    pool.addPage('s', 'Seed', page([
      item('clip1', kind: RadioKind.artistVideo, artist: 'A'),
      item('song1', artist: 'B'),
      item('clip2', kind: RadioKind.artistVideo, artist: 'C'),
      item('song2', artist: 'D'),
    ]));
    expect(takeAll(), ['song1', 'song2', 'clip1', 'clip2']);
  });

  test('seeds take turns', () {
    pool.addPage('s1', 'One', page([item('a1', artist: 'A1'), item('a2', artist: 'A2'), item('a3', artist: 'A3')]));
    pool.addPage('s2', 'Two', page([item('b1', artist: 'B1'), item('b2', artist: 'B2')]));
    final picked = <String>[];
    for (var c = take(); c != null; c = take()) {
      picked.add('${c.result.id}/${c.seedTitle}');
    }
    expect(picked, ['a1/One', 'b1/Two', 'a2/One', 'b2/Two', 'a3/One']);
  });

  test('the same artist does not come back within the last two', () {
    pool.addPage('s', 'Seed', page([
      item('a1', artist: 'Queen'),
      item('a2', artist: 'Queen'),
      item('b1', artist: 'Dire Straits'),
    ]));
    final first = take()!;
    expect(first.result.id, 'a1');
    final second = take(last: [suggestionArtistKey(first.result)])!;
    expect(second.result.id, 'b1');
    // Two suggestions later Queen may come back.
    final third = take(last: ['dire straits', 'other'])!;
    expect(third.result.id, 'a2');
  });

  test('a row is never offered twice, even when two seeds list it', () {
    pool.addPage('s1', 'One', page([item('x', artist: 'A')]));
    pool.addPage('s2', 'Two', page([item('x', artist: 'A')]));
    expect(takeAll(), ['x']);
  });

  test('empty pool returns null and remembers the continuation', () {
    expect(take(), isNull);
    pool.addPage('s', 'Seed', const RadioPage([], continuation: 'next'));
    expect(pool.continuationOf('s'), 'next');
    pool.clear();
    expect(pool.isEmpty, isTrue);
    expect(pool.continuationOf('s'), isNull);
  });

  group('inLibraryTest', () {
    final library = LibraryIndex(const [
      LibraryEntryLite(id: 1, title: 'Song', artist: 'Channel', durationMs: 200000),
    ]);
    bool owned(YtResult r) => inLibraryTest(hasDownload: (_) => false, library: library)(r);
    YtResult result({List<String> artists = const [], int seconds = 200}) => YtResult(
          id: 'x', title: 'Song', channel: 'Channel', duration: Duration(seconds: seconds), artists: artists);

    test('without credited artists the channel is the artist', () {
      expect(owned(result()), isTrue);
      expect(owned(result(artists: ['Other'])), isFalse);
    });

    test('the same title and artist is owned at any duration', () {
      expect(owned(result(seconds: 204)), isTrue);
      expect(owned(result(seconds: 310)), isTrue);
    });
  });

  test('clear forgets the positions', () {
    pool.addPage('s', 'Seed', page([item('a')]));
    expect(pool.positionsOf('a'), [1]);
    pool.clear();
    expect(pool.positionsOf('a'), isEmpty);
  });

  test('the same id on two pages of one seed keeps its first position', () {
    pool.addPage('s', 'Seed', RadioPage([item('a'), item('b')], continuation: 'n'));
    pool.addPage('s', 'Seed', page([item('c'), item('a')]));
    expect(pool.positionsOf('a'), [1]);
    expect(pool.positionsOf('c'), [3]);
  });
}

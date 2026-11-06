import 'dart:async';
import 'dart:io';

import 'package:codecore/services/online/query_intent.dart';
import 'package:codecore/services/online/smart_search.dart';
import 'package:codecore/services/online/query_match.dart';
import 'package:codecore/services/online/request_budget.dart';
import 'package:codecore/services/online/ytm_album_search.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'smart_cases.dart';

/// A search call the test answers when it wants.
class _Call<T> {
  final done = Completer<T>();
  CancelToken? cancel;
}

class _FakeYoutube implements YoutubeService {
  final songs = <_Call<List<YtResult>>>[];
  final videos = <_Call<List<YtResult>>>[];

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) {
    final c = _Call<List<YtResult>>();
    songs.add(c);
    return c.done.future;
  }

  @override
  Future<List<YtResult>> search(String query) {
    final c = _Call<List<YtResult>>();
    videos.add(c);
    return c.done.future;
  }

  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) async => const [];

  @override
  Future<List<YtResult>> albumTracks(String albumLink) async => const [];

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async =>
      const PlaylistListing.empty();


  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
          {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) =>
      const Stream.empty();

  @override
  Future<String?> toolVersion() async => null;

  @override
  void close() {}
}

class _FakeCatalog implements YtmCatalog {
  final cards = <_Call<TopCard?>>[];

  @override
  Future<TopCard?> topCard(String query, String hl, {CancelToken? cancel}) {
    final c = _Call<TopCard?>()..cancel = cancel;
    cards.add(c);
    return c.done.future;
  }

  /// What the «Artisti» and «Album» rows get; [rowsError] makes both fail.
  var artistRows = <YtmArtistRef>[];
  var albumRows = <YtmAlbumHit>[];
  Object? rowsError;
  Completer<void>? rowsGate;
  var rowCalls = 0;

  @override
  Future<List<YtmArtistRef>> searchArtists(String query, String hl, {CancelToken? cancel}) async {
    rowCalls++;
    await rowsGate?.future;
    if (rowsError != null) throw rowsError!;
    return artistRows;
  }

  @override
  Future<List<YtmAlbumHit>> searchAlbums(String query, String hl, {CancelToken? cancel}) async {
    rowCalls++;
    if (rowsError != null) throw rowsError!;
    return albumRows;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('$invocation');
}

void main() {
  late SmartCase sigarette;
  late _FakeYoutube youtube;
  late _FakeCatalog catalog;
  late SmartSearch engine;
  var clock = DateTime(2026, 10, 22, 12);

  setUp(() {
    sigarette = smartCase('lucio corsi sigarette');
    youtube = _FakeYoutube();
    catalog = _FakeCatalog();
    clock = DateTime(2026, 10, 22, 12);
    engine = SmartSearch(
      youtube: youtube,
      catalog: catalog,
      now: () => clock,
      cap: const Duration(milliseconds: 50),
    );
  });

  /// Runs a search and collects its states.
  ({List<SmartSearchState> states, StreamSubscription<SmartSearchState> sub}) start(
      String q, {bool refresh = false}) {
    final states = <SmartSearchState>[];
    final sub = engine.run(q, 'en', refresh: refresh).listen(states.add);
    return (states: states, sub: sub);
  }

  Future<void> answerCard() async {
    catalog.cards.last.done.complete(sigarette.card);
    await pumpEventQueue();
  }

  Future<void> answerSongs([int i = -1]) async {
    youtube.songs[i < 0 ? youtube.songs.length - 1 : i].done.complete(sigarette.songs);
    await pumpEventQueue();
  }

  Future<void> answerVideos([int i = -1]) async {
    youtube.videos[i < 0 ? youtube.videos.length - 1 : i].done.complete(sigarette.videos);
    await pumpEventQueue();
  }

  const song = 'InRdKLk1BTU'; // the same video in both lists

  test('both sources before the cap: one block with both, after the waiting state', () async {
    final run = start('lucio corsi sigarette');
    await pumpEventQueue();
    expect(run.states.single.pending, {MediaKind.ytmSong, MediaKind.ytVideo});
    expect(run.states.single.best, isEmpty);

    await answerCard();
    await answerSongs();
    expect(run.states, hasLength(1), reason: 'waits for YouTube');
    await answerVideos();

    expect(run.states, hasLength(2));
    final block = run.states.last;
    expect(block.pending, isEmpty);
    expect(block.intent, SearchIntent.song);
    expect(block.card, isA<TopSong>());
    final top = block.best.first;
    expect(top.primary.id, song);
    expect(top.sources, {MediaKind.ytmSong, MediaKind.ytVideo});
    await run.sub.cancel();
  });

  test('YouTube after the cap: the block with YouTube Music first, then the rest at the end',
      () async {
    final run = start('lucio corsi sigarette');
    await pumpEventQueue();
    await answerCard();
    await answerSongs();
    expect(run.states, hasLength(1), reason: 'still inside the cap');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(run.states, hasLength(2));
    final early = run.states.last;
    expect(early.pending, {MediaKind.ytVideo});
    expect(early.best.every((r) => r.sources.length == 1), isTrue);
    final shownBest = [for (final r in early.best) r.primary.id];
    final shownOthers = [for (final r in early.others) r.primary.id];

    await answerVideos();
    final late = run.states.last;
    expect(late.pending, isEmpty);
    // What was on screen is where it was; the new rows come after, per block.
    expect([for (final r in late.best) r.primary.id].take(shownBest.length), shownBest);
    expect([for (final r in late.others) r.primary.id].take(shownOthers.length), shownOthers);
    expect(late.best.length + late.others.length, greaterThan(shownBest.length + shownOthers.length));
    expect(late.best.first.primary.id, song);
    expect(late.best.first.sources, hasLength(2), reason: 'the same song merged into its row');
    await run.sub.cancel();
  });

  test('a 429 from YouTube gives a notice and the source is left alone for 5 minutes', () async {
    var run = start('lucio corsi sigarette');
    await pumpEventQueue();
    await answerCard();
    youtube.videos.last.done.completeError(const YtException(YtErrorKind.rateLimited));
    await answerSongs();

    var last = run.states.last;
    expect(last.notices, [const SearchNotice(MediaKind.ytVideo, NoticeKind.rateLimited)]);
    expect(last.best, isNotEmpty);
    expect(last.error, isNull);
    await run.sub.cancel();

    clock = clock.add(const Duration(minutes: 4));
    run = start('mother pink floyd');
    await pumpEventQueue();
    expect(youtube.videos, hasLength(1), reason: 'not asked while paused');
    expect(run.states.first.notices, hasLength(1));
    await run.sub.cancel();

    clock = clock.add(const Duration(minutes: 2));
    run = start('another phrase');
    await pumpEventQueue();
    expect(youtube.videos, hasLength(2), reason: 'asked again after the pause');
    await run.sub.cancel();
  });

  test('every source failing is an error', () async {
    final run = start('lucio corsi sigarette');
    await pumpEventQueue();
    catalog.cards.last.done.completeError(StateError('card'));
    youtube.songs.last.done.completeError(const YtException(YtErrorKind.network));
    youtube.videos.last.done.completeError(const YtException(YtErrorKind.network));
    await pumpEventQueue();

    final last = run.states.last;
    expect(last.error, isA<YtException>());
    expect(last.best, isEmpty);
    expect(last.pending, isEmpty);
    expect(last.notices.map((n) => n.kind), everyElement(NoticeKind.offline));
    await run.sub.cancel();
  });

  group('Artisti and Album rows', () {
    List<YtmArtistRef> artists(int n) =>
        [for (var i = 0; i < n; i++) YtmArtistRef(id: 'UC$i', name: 'Artist $i')];
    List<YtmAlbumHit> albums(int n) => [
          for (var i = 0; i < n; i++)
            (release: YtmRelease(browseId: 'MPREb_$i', title: 'Album $i', subtitle: 'Album'), artist: null),
        ];

    Future<SmartSearchState> page() async {
      final run = start('lucio corsi sigarette');
      await pumpEventQueue();
      await answerCard();
      await answerSongs();
      await answerVideos();
      await run.sub.cancel();
      return run.states.last;
    }

    test('both lists sit beside the page, at most 10 each', () async {
      catalog.artistRows = artists(15);
      catalog.albumRows = albums(12);
      final s = await page();
      expect(s.artists, hasLength(10));
      expect(s.albums, hasLength(10));
      expect(s.artists.first.id, 'UC0');
      expect(s.best, isNotEmpty);
    });

    test('rows arriving after the page are folded into it', () async {
      catalog.artistRows = artists(2);
      catalog.rowsGate = Completer<void>();
      final run = start('lucio corsi sigarette');
      await pumpEventQueue();
      await answerCard();
      await answerSongs();
      await answerVideos();
      expect(run.states.last.best, isNotEmpty);
      expect(run.states.last.artists, isEmpty);
      final before = run.states.last.best.map((r) => r.primary.id).toList();

      catalog.rowsGate!.complete();
      await pumpEventQueue();
      expect(run.states.last.artists, hasLength(2));
      expect(run.states.last.best.map((r) => r.primary.id), before);
      await run.sub.cancel();
    });

    test('a failing request leaves the page whole and the rows empty, no notice', () async {
      catalog.rowsError = const YtException(YtErrorKind.network);
      final s = await page();
      expect(s.artists, isEmpty);
      expect(s.albums, isEmpty);
      expect(s.error, isNull);
      expect(s.notices, isEmpty);
      expect(s.best.first.primary.id, song);
    });

    test('a 429 on the rows pauses YouTube Music, the page is saved all the same', () async {
      catalog.rowsError = const YtException(YtErrorKind.rateLimited);
      await page();
      expect(engine.cooldown.isPaused(MediaKind.ytmSong), isTrue);
      final again = start('lucio corsi sigarette');
      await pumpEventQueue();
      expect(youtube.songs, hasLength(1), reason: 'served from the copy, nothing asked');
      expect(again.states.single.best, isNotEmpty);
      await again.sub.cancel();
    });

    SmartSearch withBudget(int perMinute) => SmartSearch(
          youtube: youtube,
          catalog: catalog,
          now: () => clock,
          cap: const Duration(milliseconds: 50),
          rowsLimiter: WindowLimiter(perMinute: perMinute, now: () => clock),
        );

    test('budget for one request only: neither row is asked, the page is whole and saved', () async {
      engine = withBudget(1);
      catalog.artistRows = artists(3);
      catalog.albumRows = albums(3);
      final s = await page();
      expect(catalog.rowCalls, 0, reason: 'both rows or none');
      expect(s.artists, isEmpty);
      expect(s.albums, isEmpty);
      expect(s.best, isNotEmpty);

      clock = clock.add(const Duration(minutes: 1));
      final again = start('lucio corsi sigarette');
      await pumpEventQueue();
      expect(youtube.songs, hasLength(1), reason: 'the page came from the copy');
      expect(catalog.cards, hasLength(1));
      expect(again.states.single.best, isNotEmpty);
      await again.sub.cancel();
    });

    test('budget for two requests: both rows are asked together', () async {
      engine = withBudget(2);
      catalog.artistRows = artists(3);
      catalog.albumRows = albums(3);
      final s = await page();
      expect(catalog.rowCalls, 2);
      expect([s.artists.length, s.albums.length], [3, 3]);
    });

    test('the saved copy has the rows when none failed', () async {
      catalog.artistRows = artists(2);
      catalog.albumRows = albums(2);
      await page();
      final again = start('lucio corsi sigarette');
      await pumpEventQueue();
      expect(again.states.single.artists, hasLength(2));
      expect(again.states.single.albums, hasLength(2));
      await again.sub.cancel();
    });

    test('every main source failing shows the error at once, not after the rows', () async {
      catalog.rowsGate = Completer<void>();
      final run = start('lucio corsi sigarette');
      await pumpEventQueue();
      catalog.cards.last.done.complete(null);
      youtube.songs.last.done.completeError(const YtException(YtErrorKind.network));
      youtube.videos.last.done.completeError(const YtException(YtErrorKind.network));
      await pumpEventQueue();
      expect(run.states.last.error, isA<YtException>());
      expect(catalog.rowsGate!.isCompleted, isFalse, reason: 'the rows are still out');
      await run.sub.cancel();
    });

    test('a page whose rows are late is not delayed, and the stream waits for them', () async {
      catalog.rowsGate = Completer<void>();
      catalog.artistRows = artists(1);
      var closed = false;
      final states = <SmartSearchState>[];
      engine.run('lucio corsi sigarette', 'en').listen(states.add, onDone: () => closed = true);
      await pumpEventQueue();
      await answerCard();
      await answerSongs();
      await answerVideos();
      expect(states.last.best, isNotEmpty);
      expect(closed, isFalse);
      catalog.rowsGate!.complete();
      await pumpEventQueue();
      expect(closed, isTrue);
    });
  });

  group('intentKnown (D-400)', () {
    test('false while waiting and when the page comes before the card, true once it answers', () async {
      final run = start('lucio corsi sigarette');
      await pumpEventQueue();
      expect(run.states.single.intentKnown, isFalse);
      expect(run.states.single.showsLibrary, isFalse);
      await answerSongs();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(run.states.last.best, isNotEmpty);
      expect(run.states.last.intentKnown, isFalse, reason: 'the card is late');
      await answerCard();
      expect(run.states.last.intentKnown, isTrue);
      expect(run.states.last.intent, SearchIntent.song);
      expect(run.states.last.showsLibrary, isTrue);
      await run.sub.cancel();
    });

    test('an artist search never has the library, whatever the order of the answers', () async {
      final run = start('lucio corsi');
      await pumpEventQueue();
      await answerSongs();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      catalog.cards.last.done.complete(const TopArtist(YtmArtistRef(id: 'UC1', name: 'Lucio Corsi')));
      await pumpEventQueue();
      expect(run.states.every((s) => !s.showsLibrary), isTrue);
      expect(run.states.last.intent, SearchIntent.artistPage);
      await run.sub.cancel();
    });

    test('a failed card: the artists row tells, with no row the intent stays unknown', () async {
      catalog.artistRows = [const YtmArtistRef(id: 'UC1', name: 'Lucio Corsi')];
      var run = start('lucio corsi');
      await pumpEventQueue();
      catalog.cards.last.done.completeError(StateError('card'));
      await answerSongs();
      await answerVideos();
      expect(run.states.last.intentKnown, isTrue);
      expect(run.states.last.intent, SearchIntent.artistPage);
      await run.sub.cancel();

      catalog.artistRows = [];
      run = start('another phrase');
      await pumpEventQueue();
      catalog.cards.last.done.completeError(StateError('card'));
      await answerSongs();
      await answerVideos();
      expect(run.states.last.best, isNotEmpty);
      expect(run.states.last.intentKnown, isFalse);
      expect(run.states.last.showsLibrary, isFalse);
      await run.sub.cancel();
    });
  });

  test('the same phrase within 10 minutes asks nothing, a refresh or 10 minutes later does',
      () async {
    var run = start('Lucio  Corsi sigarette');
    await pumpEventQueue();
    await answerCard();
    await answerSongs();
    await answerVideos();
    final first = run.states.last;
    await run.sub.cancel();

    clock = clock.add(const Duration(minutes: 9));
    run = start('lucio corsi sigarette');
    await pumpEventQueue();
    expect(youtube.songs, hasLength(1));
    expect(run.states.single.best.first.primary.id, first.best.first.primary.id);
    await run.sub.cancel();

    run = start('lucio corsi sigarette', refresh: true);
    await pumpEventQueue();
    expect(youtube.songs, hasLength(2));
    await run.sub.cancel();

    clock = clock.add(const Duration(minutes: 11));
    run = start('lucio corsi sigarette');
    await pumpEventQueue();
    expect(youtube.songs, hasLength(3));
    await run.sub.cancel();
  });

  test('a new search drops the late answers of the old one and cancels its card', () async {
    final old = start('lucio corsi sigarette');
    await pumpEventQueue();
    final oldCard = catalog.cards.last;
    await old.sub.cancel();
    expect(oldCard.cancel!.isCancelled, isTrue);

    final fresh = start('pink floyd mother');
    await pumpEventQueue();
    // The old search finally answers.
    await answerSongs(0);
    await answerVideos(0);
    oldCard.done.complete(sigarette.card);
    await pumpEventQueue();
    expect(old.states, hasLength(1));
    expect(fresh.states.single.best, isEmpty);
    await fresh.sub.cancel();
  });

  test('a playlist address is not searched; a video address asks YouTube only', () async {
    final list = start('https://www.youtube.com/playlist?list=PLabc123');
    await pumpEventQueue();
    expect(list.states.single.queryKind, QueryKind.listing);
    expect(list.states.single.listingUrl, contains('PLabc123'));
    expect(youtube.songs, isEmpty);
    expect(youtube.videos, isEmpty);

    final video = start('https://youtu.be/InRdKLk1BTU');
    await pumpEventQueue();
    expect(youtube.songs, isEmpty);
    expect(catalog.cards, isEmpty);
    youtube.videos.single.done.complete([sigarette.videos.first]);
    await pumpEventQueue();
    expect(video.states.last.best.single.primary.id, song);
    await list.sub.cancel();
    await video.sub.cancel();
  });
}

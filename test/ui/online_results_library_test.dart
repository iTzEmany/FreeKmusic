import 'dart:async';
import 'dart:io';

import 'package:codecore/core/import_row.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_intent.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/download_queue.dart';
import 'package:codecore/services/online/smart_search.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/ui/screens/youtube/online_results.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

// «Nella tua libreria» (92.1): the library's songs on top, the ones already
// owned out of the online rows.

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

SmartResult _row(String id, String title, {String artist = 'Artist'}) =>
    SmartResult(
      primary: ytmSong(id, title, artist: artist, seconds: 200),
      sources: {MediaKind.ytmSong},
      alternatives: const [],
      confidence: 0.9,
      hasVideo: false,
    );

/// Counts the lookups, to show they run once per result and not per build.
class _CountingIndex extends LibraryIndex {
  _CountingIndex(super.tracks);

  var finds = 0;

  @override
  LibraryEntryLite? find(ImportRow r, {String? baseDir}) {
    finds++;
    return super.find(r, baseDir: baseDir);
  }
}

/// The library index the test can swap while the page is open.
class _IndexHolder extends Notifier<LibraryIndex> {
  _IndexHolder(this.first);

  final LibraryIndex first;

  @override
  LibraryIndex build() => first;

  void set(LibraryIndex i) => state = i;
}

late NotifierProvider<_IndexHolder, LibraryIndex> _holderOverride;

class _FakeDownloads extends DownloadsNotifier {
  final added = <String>[];

  @override
  List<DownloadItem> build() => const [];

  @override
  Future<bool> add(YtResult r, {String? tag}) async {
    added.add(r.id);
    return false;
  }
}

Finder _sourceFilter(String label) =>
    find.descendant(of: find.byType(SegmentedBlocks<MediaKind?>), matching: find.text(label));

void main() {
  late StreamController<SmartSearchState> engine;
  late Harness h;
  late _CountingIndex index;
  late _FakeDownloads downloads;
  late DownloadIndex downloadIndex;

  /// A library of [n] tracks "Song 0".."Song n-1" by "Artist" (the harness
  /// inserts them), found by the text and known to the library index.
  Future<void> open(
    WidgetTester tester, {
    int n = 5,
    bool textFindsThem = true,
    bool indexed = true,
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    h = await Harness.create(tester, tracks: n);
    final tracks = await h.db.select(h.db.tracks).get();
    index = _CountingIndex([
      for (final t in tracks)
        LibraryEntryLite(
          id: t.id,
          title: t.title,
          artist: t.artist,
          durationMs: t.durationMs,
        ),
    ]);
    engine = StreamController<SmartSearchState>.broadcast();
    addTearDown(engine.close);
    downloads = _FakeDownloads();
    final dir = Directory.systemTemp.createTempSync('lib92');
    addTearDown(() => dir.deleteSync(recursive: true));
    downloadIndex = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    final holder = NotifierProvider<_IndexHolder, LibraryIndex>(
        () => _IndexHolder(indexed ? index : LibraryIndex(const [])));
    _holderOverride = holder;
    await h.pump(
      tester,
      const Scaffold(body: OnlineResults(query: 'song', submitted: 1)),
      extraOverrides: [
        smartSearchProvider.overrideWith((ref, request) => engine.stream),
        searchTracksProvider.overrideWith(
          (ref, text) => AsyncData(textFindsThem ? tracks : const []),
        ),
        libraryIndexProvider.overrideWith((ref) async => ref.watch(holder)),
        downloadsProvider.overrideWith(() => downloads),
        downloadIndexProvider.overrideWith((ref) async => downloadIndex),
      ],
    );
  }

  Future<void> emit(
    WidgetTester tester, {
    List<SmartResult> best = const [],
    List<SmartResult> others = const [],
    SearchIntent intent = SearchIntent.songs,
    bool intentKnown = true,
    TopCard? card,
    Object? error,
    List<YtmArtistRef> artists = const [],
  }) async {
    engine.add(
      SmartSearchState(
        query: 'song',
        artists: artists,
        best: best,
        others: others,
        intent: intent,
        intentKnown: intentKnown,
        card: card,
        error: error,
      ),
    );
    await _settle(tester);
    // The hidden rows' tracks are read from the database after the first build.
    await _settle(tester);
  }

  testWidgets('a song search with 5 local tracks shows 3 and «Mostra tutti (5)»', (
    tester,
  ) async {
    await open(tester);
    await emit(tester, best: [_row('a', 'Mother', artist: 'Pink Floyd')]);
    expect(find.text('Nella tua libreria'), findsOneWidget);
    expect(find.byKey(const ValueKey('online-library')), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    expect(find.text('Song 2'), findsOneWidget);
    expect(find.text('Song 3'), findsNothing);
    expect(find.text('Mostra tutti (5)'), findsOneWidget);
    // Above the online results.
    expect(
      tester.getTopLeft(find.text('Nella tua libreria')).dy,
      lessThan(tester.getTopLeft(find.text('Migliori risultati')).dy),
    );
    await h.dispose(tester);
  });

  testWidgets('with 3 tracks or fewer there is no «Mostra tutti»', (tester) async {
    await open(tester, n: 2);
    await emit(tester, best: [_row('a', 'Mother', artist: 'Pink Floyd')]);
    expect(find.text('Nella tua libreria'), findsOneWidget);
    expect(find.textContaining('Mostra tutti'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('an artist or album search has no section and hides nothing', (
    tester,
  ) async {
    await open(tester);
    final owned = _row('o', 'Song 1');
    await emit(
      tester,
      best: [owned],
      intent: SearchIntent.artistPage,
      card: const TopArtist(
        YtmArtistRef(id: 'UC1', name: 'Artist', audience: ''),
      ),
    );
    expect(find.text('Nella tua libreria'), findsNothing);
    expect(find.byKey(const ValueKey('row-o')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-owned-hidden')), findsNothing);

    engine.add(
      SmartSearchState(
        query: 'song',
        best: [owned],
        intent: SearchIntent.album,
      ),
    );
    await _settle(tester);
    expect(find.text('Nella tua libreria'), findsNothing);
    expect(find.byKey(const ValueKey('row-o')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('an online song already in the library leaves the list, a line says so', (
    tester,
  ) async {
    await open(tester);
    await emit(
      tester,
      best: [_row('dup', 'Song 1'), _row('a', 'Mother', artist: 'Pink Floyd')],
    );
    expect(find.byKey(const ValueKey('row-dup')), findsNothing);
    expect(find.byKey(const ValueKey('row-a')), findsOneWidget);
    expect(find.text('1 risultato già in libreria nascosto'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('several hidden results use the plural', (tester) async {
    await open(tester);
    await emit(tester, best: [_row('d1', 'Song 1'), _row('d2', 'Song 2')]);
    expect(find.text('2 risultati già in libreria nascosti'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a tap on a library song plays the local file', (tester) async {
    await open(tester);
    await emit(tester, best: [_row('a', 'Mother', artist: 'Pink Floyd')]);
    await tester.tap(find.text('Song 1'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.backend.loaded, isNotEmpty);
    expect(h.backend.loaded.last, '/m/t1.mp3');
    await h.dispose(tester);
  });

  testWidgets('an empty library has no section and no hidden line', (tester) async {
    await open(tester, n: 0);
    await emit(tester, best: [_row('a', 'Mother', artist: 'Pink Floyd')]);
    expect(find.text('Nella tua libreria'), findsNothing);
    expect(find.byKey(const ValueKey('online-owned-hidden')), findsNothing);
    expect(find.byKey(const ValueKey('row-a')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a hidden duplicate the text search misses still shows in the library section', (
    tester,
  ) async {
    await open(tester, textFindsThem: false);
    await emit(
      tester,
      best: [_row('dup', 'Song 1'), _row('a', 'Mother', artist: 'Pink Floyd')],
    );
    expect(find.text('1 risultato già in libreria nascosto'), findsOneWidget);
    expect(find.byKey(const ValueKey('online-library')), findsOneWidget);
    expect(find.text('Song 1'), findsOneWidget);
    expect(find.textContaining('Mostra tutti'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a hidden duplicate the text search finds too is listed once, in the text search order', (
    tester,
  ) async {
    await open(tester);
    await emit(tester, best: [_row('dup', 'Song 3')]);
    // The preview is the first three of the text search, not the duplicate first.
    expect(find.text('Song 3'), findsNothing);
    expect(find.text('Song 0'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the duplicates are looked up once per result, not at every rebuild', (
    tester,
  ) async {
    await open(tester);
    await emit(
      tester,
      best: [_row('dup', 'Song 1')],
      others: [_row('b', 'Mother', artist: 'Pink Floyd')],
    );
    final once = index.finds;
    expect(once, greaterThan(0));
    await tester.tap(find.byKey(const ValueKey('others-chip')));
    await _settle(tester);
    expect(find.text('Mother'), findsOneWidget, reason: 'the page did rebuild');
    expect(index.finds, once);
    await h.dispose(tester);
  });

  testWidgets('the picks follow the results, not their place, when the library hides a row above', (
    tester,
  ) async {
    await open(tester, indexed: false);
    await emit(
      tester,
      best: [_row('dup', 'Song 1'), _row('x', 'Mother', artist: 'Pink Floyd'), _row('y', 'Time', artist: 'Pink Floyd')],
    );
    expect(find.byKey(const ValueKey('row-dup')), findsOneWidget);
    await tester.longPress(find.text('Mother'));
    await _settle(tester);
    await tester.tap(find.text('Time'));
    await _settle(tester);
    expect(find.text('2 selezionati'), findsOneWidget);

    // The index finishes loading: «Song 1» is owned and leaves the rows above.
    ProviderScope.containerOf(tester.element(find.byType(OnlineResults)))
        .read(_holderOverride.notifier)
        .set(index);
    await _settle(tester);
    await _settle(tester);
    expect(find.byKey(const ValueKey('row-dup')), findsNothing);
    expect(find.text('2 selezionati'), findsOneWidget);

    await tester.tap(find.byTooltip('Scarica').first);
    await _settle(tester);
    expect(downloads.added, ['x', 'y']);
    await h.dispose(tester);
  });

  testWidgets('the section waits for the intent: an artist search never shows it', (tester) async {
    await open(tester);
    await emit(tester, best: [_row('a', 'Mother', artist: 'Pink Floyd')], intentKnown: false);
    expect(find.byKey(const ValueKey('online-library')), findsNothing);
    expect(find.byKey(const ValueKey('row-a')), findsOneWidget);

    await emit(
      tester,
      best: [_row('a', 'Mother', artist: 'Pink Floyd')],
      intent: SearchIntent.artistPage,
      card: const TopArtist(YtmArtistRef(id: 'UC1', name: 'Artist', audience: '')),
    );
    expect(find.byKey(const ValueKey('online-library')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('the section and the duplicate filter come in together once the intent is known', (
    tester,
  ) async {
    await open(tester);
    await emit(tester, best: [_row('dup', 'Song 1')], intentKnown: false);
    expect(find.byKey(const ValueKey('row-dup')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-library')), findsNothing);
    await emit(tester, best: [_row('dup', 'Song 1')]);
    expect(find.byKey(const ValueKey('row-dup')), findsNothing);
    expect(find.byKey(const ValueKey('online-library')), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a song search with nothing online still shows the library', (tester) async {
    await open(tester);
    await emit(tester);
    expect(find.text('Nessun risultato'), findsOneWidget);
    expect(find.byKey(const ValueKey('online-library')), findsOneWidget);
    expect(find.text('Song 0'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('a song search shows the library above the Artists row and the online rows', (tester) async {
    await open(tester);
    await emit(
      tester,
      best: [_row('a', 'Mother', artist: 'Pink Floyd')],
      artists: const [YtmArtistRef(id: 'UC9', name: 'Other Artist')],
    );
    final lib = tester.getTopLeft(find.byKey(const ValueKey('online-library'))).dy;
    expect(lib, lessThan(tester.getTopLeft(find.byKey(const ValueKey('online-artists'))).dy));
    expect(lib, lessThan(tester.getTopLeft(find.byKey(const ValueKey('row-a'))).dy));
    await h.dispose(tester);
  });

  testWidgets('a song search whose online part failed shows the library above the error', (
    tester,
  ) async {
    await open(tester);
    await emit(tester, error: const YtException(YtErrorKind.network));
    expect(find.byKey(const ValueKey('online-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-library')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('online-library'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('online-retry'))).dy),
    );
    await h.dispose(tester);
  });

  testWidgets('an artist search that failed has no library section', (tester) async {
    await open(tester);
    await emit(tester, error: const YtException(YtErrorKind.network), intentKnown: false);
    expect(find.byKey(const ValueKey('online-retry')), findsOneWidget);
    expect(find.byKey(const ValueKey('online-library')), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('a video already downloaded leaves the rows too, its file in the library section', (
    tester,
  ) async {
    await open(tester);
    final file = File(p.join(Directory.systemTemp.path, 'lib92-dl.mp3'))..writeAsStringSync('x');
    addTearDown(file.deleteSync);
    await tester.runAsync(() => downloadIndex.add('dl', file.path));
    await emit(tester, best: [_row('dl', 'Another Title', artist: 'Someone'), _row('a', 'Mother', artist: 'Pink Floyd')]);
    expect(find.byKey(const ValueKey('row-dl')), findsNothing);
    expect(find.byKey(const ValueKey('row-a')), findsOneWidget);
    expect(find.text('1 risultato già in libreria nascosto'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('the hidden count follows the source filter and sits at the end', (tester) async {
    await open(tester);
    final video = SmartResult(
      primary: YtResult(id: 'vdup', title: 'Song 2', channel: 'Artist', duration: const Duration(seconds: 200)),
      sources: {MediaKind.ytVideo},
      alternatives: const [],
      confidence: 0.8,
      hasVideo: false,
    );
    await emit(
      tester,
      best: [_row('dup', 'Song 1'), video, _row('a', 'Mother', artist: 'Pink Floyd')],
    );
    expect(find.text('2 risultati già in libreria nascosti'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('online-owned-hidden'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('row-a'))).dy),
    );

    await tester.tap(_sourceFilter('YouTube'));
    await _settle(tester);
    expect(find.text('1 risultato già in libreria nascosto'), findsOneWidget);

    await tester.tap(_sourceFilter('YouTube Music'));
    await _settle(tester);
    expect(find.text('1 risultato già in libreria nascosto'), findsOneWidget);
    await h.dispose(tester);
  });
}

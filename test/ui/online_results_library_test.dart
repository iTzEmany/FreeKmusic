import 'dart:async';

import 'package:codecore/core/import_row.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_intent.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/smart_search.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/ui/screens/youtube/online_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  late StreamController<SmartSearchState> engine;
  late Harness h;
  late _CountingIndex index;

  /// A library of [n] tracks "Song 0".."Song n-1" by "Artist" (the harness
  /// inserts them), found by the text and known to the library index.
  Future<void> open(WidgetTester tester, {int n = 5, bool textFindsThem = true}) async {
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
    await h.pump(
      tester,
      const Scaffold(body: OnlineResults(query: 'song', submitted: 1)),
      extraOverrides: [
        smartSearchProvider.overrideWith((ref, request) => engine.stream),
        searchTracksProvider.overrideWith(
          (ref, text) => AsyncData(textFindsThem ? tracks : const []),
        ),
        libraryIndexProvider.overrideWith((ref) async => index),
      ],
    );
  }

  Future<void> emit(
    WidgetTester tester, {
    List<SmartResult> best = const [],
    List<SmartResult> others = const [],
    SearchIntent intent = SearchIntent.songs,
    TopCard? card,
  }) async {
    engine.add(
      SmartSearchState(
        query: 'song',
        best: best,
        others: others,
        intent: intent,
        card: card,
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

  testWidgets('a hidden duplicate the text search finds too is listed once, first', (
    tester,
  ) async {
    await open(tester);
    await emit(tester, best: [_row('dup', 'Song 3')]);
    expect(find.text('Song 3'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Song 3')).dy,
      lessThan(tester.getTopLeft(find.text('Song 0')).dy),
    );
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
}

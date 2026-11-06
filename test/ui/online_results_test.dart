import 'dart:async';

import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_intent.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/smart_search.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/ui/screens/online/album_card.dart';
import 'package:codecore/ui/screens/online/artist_card.dart';
import 'package:codecore/ui/screens/youtube/online_results.dart';
import 'package:codecore/ui/widgets/segmented_blocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 60)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

SmartResult _song(
  String id,
  String title, {
  String artistId = 'UCpf',
  bool hasVideo = false,
}) => SmartResult(
  primary: ytmSong(id, title, seconds: 200, artistId: artistId),
  sources: {MediaKind.ytmSong, if (hasVideo) MediaKind.ytVideo},
  alternatives: hasVideo
      ? [
          YtResult(
            id: '$id-v',
            title: '$title (Official Video)',
            channel: 'Pink Floyd',
            duration: null,
          ),
        ]
      : const [],
  confidence: 0.9,
  hasVideo: hasVideo,
);

SmartResult _video(String id, String title) => SmartResult(
  primary: YtResult(
    id: id,
    title: title,
    channel: 'Chan',
    duration: const Duration(minutes: 3),
  ),
  sources: {MediaKind.ytVideo},
  alternatives: const [],
  confidence: 0.7,
  hasVideo: false,
);

SmartSearchState _state({
  List<SmartResult> best = const [],
  List<SmartResult> others = const [],
  TopCard? card,
  SearchIntent intent = SearchIntent.songs,
  Set<MediaKind> pending = const {},
  List<SearchNotice> notices = const [],
  bool noneSure = false,
  Object? error,
}) => SmartSearchState(
  query: 'pink floyd',
  best: best,
  others: others,
  card: card,
  intent: intent,
  pending: pending,
  notices: notices,
  noneSure: noneSure,
  error: error,
);

class _EnqueueSpy implements PlayerController {
  final calls = <String>[];
  @override
  bool inJam = true;
  @override
  Future<void> enqueueOnline(YtResult r) async => calls.add(r.id);
  @override
  bool get jamQueueFull => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

const _pink = YtmArtistRef(
  id: 'UCpf',
  name: 'Pink Floyd',
  audience: '25.9M monthly audience',
);

void main() {
  late StreamController<SmartSearchState> engine;
  late List<SmartSearchRequest> requests;
  late List<Override> overrides;

  Future<Harness> open(
    WidgetTester tester, {
    int submitted = 1,
    Widget? page,
    List<Override> more = const [],
  }) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    engine = StreamController<SmartSearchState>.broadcast();
    addTearDown(engine.close);
    requests = [];
    overrides = [
      smartSearchProvider.overrideWith((ref, request) {
        requests.add(request);
        return engine.stream;
      }),
      ...more,
    ];
    await h.pump(
      tester,
      page ??
          Scaffold(
            body: OnlineResults(query: 'pink floyd', submitted: submitted),
          ),
      extraOverrides: overrides,
    );
    return h;
  }

  Future<void> emit(WidgetTester tester, SmartSearchState s) async {
    engine.add(s);
    await _settle(tester);
  }

  testWidgets(
    '«Altri risultati» stays closed until it is tapped, then lists its rows',
    (tester) async {
      final h = await open(tester);
      await emit(
        tester,
        _state(
          best: [_song('a', 'Mother')],
          others: [_song('b', 'Mother (Live)'), _song('c', 'Time')],
        ),
      );
      expect(find.text('Migliori risultati'), findsOneWidget);
      expect(find.text('Mother'), findsOneWidget);
      expect(find.text('Altri risultati (2)'), findsOneWidget);
      expect(find.text('Mother (Live)'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('others-chip')));
      await _settle(tester);
      expect(find.text('Mother (Live)'), findsOneWidget);
      expect(find.text('Time'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'the source filter hides the rows that are only a video, without a new request',
    (tester) async {
      final h = await open(tester);
      await emit(
        tester,
        _state(best: [_song('a', 'Mother'), _video('v', 'Mother clip')]),
      );
      expect(find.text('Mother clip'), findsOneWidget);

      await tester.tap(_filter('YouTube Music'));
      await _settle(tester);
      expect(find.text('Mother'), findsOneWidget);
      expect(find.text('Mother clip'), findsNothing);

      await tester.tap(_filter('YouTube'));
      await _settle(tester);
      expect(find.text('Mother clip'), findsOneWidget);
      expect(find.text('Mother'), findsNothing);

      await tester.tap(_filter('Tutte'));
      await _settle(tester);
      expect(find.text('Mother'), findsOneWidget);
      expect(
        requests,
        hasLength(1),
        reason: 'a filter only looks at what already arrived',
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    'a search that is just the artist: big card, then «Brani di» with their songs only',
    (tester) async {
      final h = await open(tester);
      await emit(
        tester,
        _state(
          card: const TopArtist(_pink),
          intent: SearchIntent.artistPage,
          best: [
            _song('o', 'Cover by someone else', artistId: 'UCother'),
            _song('m', 'Mother'),
          ],
        ),
      );
      expect(tester.widget<ArtistCard>(find.byType(ArtistCard)).large, isTrue);
      expect(find.text('Brani di Pink Floyd'), findsOneWidget);
      // «Mother» (his) comes before the song of another artist, which is under «Migliori risultati».
      expect(
        tester.getTopLeft(find.text('Mother')).dy,
        lessThan(tester.getTopLeft(find.text('Cover by someone else')).dy),
      );
      expect(find.text('Migliori risultati'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'an artist with more words gets the small card; an album gets its own card',
    (tester) async {
      var h = await open(tester);
      await emit(
        tester,
        _state(
          card: const TopArtist(_pink),
          intent: SearchIntent.artistAndSongs,
          best: [_song('m', 'Mother')],
        ),
      );
      expect(tester.widget<ArtistCard>(find.byType(ArtistCard)).large, isFalse);
      expect(find.text('Brani di Pink Floyd'), findsNothing);
      await h.dispose(tester);

      h = await open(tester);
      await emit(
        tester,
        _state(
          card: const TopAlbum(
            YtmRelease(
              browseId: 'MPREb_x',
              title: 'The Wall',
              subtitle: '1979',
            ),
            _pink,
          ),
          intent: SearchIntent.album,
          best: [_song('m', 'Mother')],
        ),
      );
      expect(find.byType(AlbumCard), findsOneWidget);
      expect(find.text('The Wall'), findsOneWidget);
      expect(find.text('Album, Pink Floyd, 1979'), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets(
    'a source that arrives late does not move the rows already shown',
    (tester) async {
      final h = await open(tester);
      final a = _song('a', 'Mother'), b = _song('b', 'Time');
      await emit(tester, _state(best: [a, b], pending: {MediaKind.ytVideo}));
      expect(
        find.byType(LinearProgressIndicator),
        findsOneWidget,
        reason: 'a source is still missing',
      );
      final before = [
        tester.getTopLeft(find.text('Mother')),
        tester.getTopLeft(find.text('Time')),
      ];

      await emit(tester, _state(best: [a, b, _video('c', 'Money')]));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect([
        tester.getTopLeft(find.text('Mother')),
        tester.getTopLeft(find.text('Time')),
      ], before);
      expect(
        tester.getTopLeft(find.text('Money')).dy,
        greaterThan(before[1].dy),
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    'a row says where it comes from, and «anche come video» when there is a video too',
    (tester) async {
      final h = await open(tester);
      await emit(
        tester,
        _state(
          best: [
            _song('a', 'Mother', hasVideo: true),
            _video('v', 'Time clip'),
          ],
        ),
      );
      expect(
        find.text('YouTube Music'),
        findsNWidgets(2),
        reason: 'a filter chip and the row',
      );
      expect(
        find.text('YouTube'),
        findsNWidgets(2),
        reason: 'a filter chip and the video row',
      );
      expect(find.text('anche come video'), findsOneWidget);
      expect(find.byKey(const ValueKey('listen-video-a')), findsOneWidget);
      await h.dispose(tester);
    },
  );

  testWidgets('«anche come video» with a Jam on queues the video (D-89)', (tester) async {
    final spy = _EnqueueSpy();
    final h = await open(tester, more: [
      playerControllerProvider.overrideWithValue(spy),
    ]);
    await emit(tester, _state(best: [_song('a', 'Mother', hasVideo: true)]));
    await tester.tap(find.byKey(const ValueKey('listen-video-a')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(spy.calls, ['a-v']);
    await h.dispose(tester);
  });

  testWidgets(
    'nothing sure says so; a source that gave nothing has a line above the list',
    (tester) async {
      final h = await open(tester);
      await emit(
        tester,
        _state(
          best: [_song('a', 'Mother')],
          noneSure: true,
          notices: const [
            SearchNotice(MediaKind.ytVideo, NoticeKind.rateLimited),
          ],
        ),
      );
      expect(find.text('Nessun risultato sicuro'), findsOneWidget);
      expect(find.text('Migliori risultati'), findsNothing);
      expect(
        find.text('YouTube chiede una pausa: risultati solo da YouTube Music'),
        findsOneWidget,
      );
      await h.dispose(tester);
    },
  );

  testWidgets(
    'every source failing shows the error with «Riprova», which asks again skipping the saved copy',
    (tester) async {
      final h = await open(tester);
      await emit(
        tester,
        _state(error: const YtException(YtErrorKind.network, 'offline')),
      );
      expect(find.text('Rete non disponibile'), findsOneWidget);
      expect(requests.single, (query: 'pink floyd', refresh: false, serial: 1));

      await tester.tap(find.byKey(const ValueKey('online-retry')));
      await tester.pump();
      expect(requests.last, (query: 'pink floyd', refresh: true, serial: 2));
      await h.dispose(tester);
    },
  );

  testWidgets(
    'each submit is a new request, and the filter starts over from «Tutte»',
    (tester) async {
      final h = await open(tester);
      await emit(
        tester,
        _state(best: [_song('a', 'Mother'), _video('v', 'Mother clip')]),
      );
      await tester.tap(_filter('YouTube Music'));
      await _settle(tester);
      expect(find.text('Mother clip'), findsNothing);

      await h.pump(
        tester,
        const Scaffold(body: OnlineResults(query: 'pink floyd', submitted: 2)),
        extraOverrides: overrides,
      );
      await emit(
        tester,
        _state(best: [_song('a', 'Mother'), _video('v', 'Mother clip')]),
      );
      expect(requests.map((r) => r.serial), [1, 2]);
      expect(
        find.text('Mother clip'),
        findsOneWidget,
        reason: 'not filtered any more',
      );
      await h.dispose(tester);
    },
  );
}

/// A block of the source filter (the rows carry the same words).
Finder _filter(String label) => find.descendant(
  of: find.byType(SegmentedBlocks<MediaKind?>),
  matching: find.text(label),
);

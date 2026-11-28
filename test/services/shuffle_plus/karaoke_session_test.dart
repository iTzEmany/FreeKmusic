import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/smart_search.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:codecore/services/shuffle_plus/karaoke_session.dart';
import 'package:flutter_test/flutter_test.dart';

YtResult _y(
  String id,
  String title,
  String channel, {
  List<String> artists = const [],
  int secs = 200,
}) => YtResult(
  id: id,
  title: title,
  channel: channel,
  duration: Duration(seconds: secs),
  artists: artists,
);

SmartResult _s(YtResult r) => SmartResult(
  primary: r,
  sources: {MediaKind.ytVideo},
  alternatives: const [],
  confidence: 1,
  hasVideo: true,
);

void main() {
  final karaoke = _y(
    'k1',
    'Sing King - Adele - Hello (Karaoke Version)',
    'Sing King',
  );
  final queries = <(String, bool)>[];
  KaraokeSearch searching(List<YtResult> rows) =>
      (q, {bool videoOnly = false}) async {
        queries.add((q, videoOnly));
        return [for (final r in rows) _s(r)];
      };
  setUp(queries.clear);

  test('original: the song on YouTube Music, never a karaoke row', () async {
    final seed = await karaokeOriginalSeed(
      karaoke,
      searching([
        _y('k2', 'Hello (Karaoke Version)', 'Other', artists: ['Adele']),
        _y('o1', 'Hello', 'Adele', artists: ['Adele']),
      ]),
    );
    expect(seed?.videoId, 'o1');
    expect(queries.single, ('Adele Hello', false));
  });

  test('original: nothing that matches gives null', () async {
    expect(
      await karaokeOriginalSeed(
        karaoke,
        searching([
          _y('z', 'Another thing', 'Nobody', artists: ['Nobody']),
        ]),
      ),
      isNull,
    );
    expect(await karaokeOriginalSeed(karaoke, searching(const [])), isNull);
  });

  test(
    'swap: the first karaoke video that matches the song and artist',
    () async {
      final similar = _y(
        's1',
        'Someone Like You',
        'Adele',
        artists: ['Adele'],
        secs: 285,
      );
      final found = await karaokeVideoFor(
        similar,
        searching([
          _y('v0', 'Someone Like You (Live)', 'Adele'),
          _y('v1', 'Other Song - Karaoke Version', 'Sing King', secs: 285),
          _y(
            'v2',
            'Adele - Someone Like You (Karaoke Version)',
            'Sing King',
            secs: 283,
          ),
        ]),
      );
      expect(found?.id, 'v2');
      expect(queries.single, ('Adele Someone Like You karaoke', true));
    },
  );

  test('swap: no karaoke video that matches gives null', () async {
    final similar = _y(
      's1',
      'Someone Like You',
      'Adele',
      artists: ['Adele'],
      secs: 285,
    );
    expect(
      await karaokeVideoFor(
        similar,
        searching([_y('v1', 'Other Song - Karaoke', 'Sing King')]),
      ),
      isNull,
    );
  });

  test(
    'swap: the artist of the karaoke title decides between same-title karaokes',
    () async {
      final similar = _y('s1', 'Hello', 'Adele', artists: ['Adele']);
      final found = await karaokeVideoFor(
        similar,
        searching([
          _y('v1', 'Lionel Richie - Hello (Karaoke Version)', 'Sing King'),
          _y('v2', 'Adele - Hello (Karaoke Version)', 'Sing King'),
        ]),
      );
      expect(found?.id, 'v2');
    },
  );

  test('swap: a plain video of the song is not a karaoke', () async {
    final similar = _y('s1', 'Hello', 'Adele', artists: ['Adele']);
    expect(
      await karaokeVideoFor(
        similar,
        searching([_y('v1', 'Adele - Hello', 'Adele')]),
      ),
      isNull,
    );
  });

  test('swap: a karaoke of a very different length is refused', () async {
    final similar = _y('s1', 'Hello', 'Adele', artists: ['Adele'], secs: 295);
    expect(
      await karaokeVideoFor(
        similar,
        searching([
          _y('v1', 'Adele - Hello (Karaoke Version)', 'Sing King', secs: 30),
        ]),
      ),
      isNull,
    );
  });

  test(
    'original: a title that is only «karaoke» has nothing to search',
    () async {
      expect(
        await karaokeOriginalSeed(
          _y('d', 'Karaoke', 'Drake'),
          searching([_y('o', 'Karaoke', 'Drake')]),
        ),
        isNull,
      );
      expect(queries, isEmpty);
    },
  );

  test('original: a very different length is refused', () async {
    final seed = await karaokeOriginalSeed(
      _y(
        'k1',
        'Sing King - Adele - Hello (Karaoke Version)',
        'Sing King',
        secs: 295,
      ),
      searching([
        _y('o1', 'Hello', 'Adele', artists: ['Adele'], secs: 20),
      ]),
    );
    expect(seed, isNull);
  });

  test(
    'karaokeSearchOn: a second identical search is served by the engine cache',
    () async {
      final yt = _CountingYoutube();
      final engine = SmartSearch(
        youtube: yt,
        catalog: _NoCatalog(),
        cap: const Duration(milliseconds: 20),
      );
      final search = karaokeSearchOn(engine, 'en');
      final first = await search('adele hello karaoke', videoOnly: true);
      expect(first, isNotEmpty);
      await pumpEventQueue(times: 50);
      await search('adele hello karaoke', videoOnly: true);
      expect(yt.calls, 1);
    },
  );
}

class _CountingYoutube implements YoutubeService {
  var calls = 0;

  @override
  Future<List<YtResult>> search(String query) async {
    calls++;
    return [_y('v1', 'Adele - Hello (Karaoke Version)', 'Sing King')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

class _NoCatalog implements YtmCatalog {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('$invocation');
}

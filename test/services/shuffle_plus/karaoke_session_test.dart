import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/youtube_service.dart';
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
}

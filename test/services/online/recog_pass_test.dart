import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart' show decodeRec;
import 'package:codecore/data/repositories/recog_pass_query.dart';
import 'package:codecore/services/online/enrich_completer.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/online/ytm_song_parser.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';
import '../recognition/support.dart';

const _parts = {EnrichPart.meta, EnrichPart.lyrics, EnrichPart.curio};
const _video = '/m/Whatever (Romy Wave Cover) [dQw4w9WgXcQ].mp3';
const _song = YtmSong(title: 'Song', artists: ['Band'], videoType: 'MUSIC_VIDEO_TYPE_ATV', durationMs: 200000);

void main() {
  late Rig rec;
  late EnrichRig r;
  var after = 0, done = false;
  final saved = <int>[];

  setUp(() {
    rec = Rig()
      ..acoustIdOn = false
      ..song = _song;
    r = EnrichRig(recognizer: rec.recognizer);
    after = 0;
    done = false;
    saved.clear();
  });
  tearDown(() => r.dispose());

  /// A track with every part filled and a finished enrichment.
  Future<int> full({String artist = 'Band', String path = '/a.mp3', String album = 'A'}) async {
    final id = await r.add(
        artist: artist, path: path, isrc: null, album: album, genre: 'G', year: 2020, trackNumber: 1,
        plain: 'la', curiosities: 'x', hasCover: true);
    await (r.db.update(r.db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(enrichStatus: Value(1)));
    return id;
  }

  EnrichCompleter completer() => EnrichCompleter(
        engine: r.engine,
        repo: r.credits,
        parts: () => _parts,
        waitIdle: () async {},
        recogQuery: recogPassQuery(r.db),
        loadPassAfter: () => after,
        savePassAfter: (id) {
          saved.add(id);
          after = id;
        },
        passDone: () => done,
        markPassDone: () => done = true,
      );

  test('a complete track with reliable tags is not re-passed: no calls', () async {
    await full();
    final c = completer();
    await c.run();
    expect(c.pass!.processed, 1);
    expect(rec.calls, isEmpty);
    expect(done, isTrue);
  });

  test('a track with the channel as artist is re-passed once; a second pass asks nothing', () async {
    final id = await full(artist: '7clouds Rock', path: _video);
    await completer().run();
    expect(rec.calls, ['songOf:dQw4w9WgXcQ']);
    expect(decodeRec((await r.enrichOf(id))!.details)!.v, kRecogVersion);
    done = false;
    after = 0;
    await completer().run();
    expect(rec.calls, hasLength(1));
  });

  test('filled fields stay unchanged', () async {
    final id = await full(artist: '7clouds Rock', path: _video, album: 'Mine');
    await completer().run();
    final t = (await r.repo.getById(id))!;
    expect([t.album, t.genre, t.year, t.artist], ['Mine', 'G', 2020, '7clouds Rock']);
  });

  test('the bookmark resumes after a restart and the finished pass resets it', () async {
    final a = await full(artist: '7clouds Rock', path: _video);
    final b = await full(artist: '7clouds Rock', path: '/m/Other [aaaaaaaaaaa].mp3');
    after = a; // a previous start got as far as the first track
    await completer().run();
    expect(rec.calls, ['songOf:aaaaaaaaaaa']);
    expect(saved, [b, 0]);
  });

  test('a pass done for this version is not started again', () async {
    await full(artist: '7clouds Rock', path: _video);
    done = true;
    final c = completer();
    await c.run();
    expect(c.pass, isNull);
    expect(rec.calls, isEmpty);
  });
}

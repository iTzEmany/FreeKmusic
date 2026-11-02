import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart' show decodeRec;
import 'package:codecore/data/repositories/recog_pass_query.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/backup/backup_service.dart' show kDeviceBoundKeys;
import 'package:codecore/services/online/enrich_completer.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  var yieldNow = false;

  setUp(() {
    rec = Rig()
      ..acoustIdOn = false
      ..song = _song;
    r = EnrichRig(recognizer: rec.recognizer);
    after = 0;
    done = false;
    saved.clear();
    yieldNow = false;
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
        recogNeeds: recogPassNeeds(r.db),
        yieldPass: yieldNow ? () => true : null,
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
    expect(c.pass!.processed, 0); // skipped before the runner: no gather, no wait
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

  test('50 good tracks and one dubious: only the dubious one is gathered', () async {
    for (var n = 0; n < 50; n++) {
      await full(path: '/g$n.mp3');
    }
    await full(artist: '7clouds Rock', path: _video);
    final c = completer();
    await c.run();
    expect(c.pass!.processed, 1);
    expect(rec.calls, ['songOf:dQw4w9WgXcQ']);
  });

  test('a pass asked to yield stops with its bookmark kept and is not done', () async {
    await full(artist: '7clouds Rock', path: _video);
    yieldNow = true;
    final c = completer();
    await c.run();
    expect([c.passInterrupted, c.pass!.processed, done, saved], [true, 0, false, isEmpty]);
    expect(rec.calls, isEmpty);
  });

  test('tracks lost offline are not passed: the pass is not done and they come back', () async {
    await full(artist: '7clouds Rock', path: _video);
    await full(artist: '7clouds Rock', path: '/m/Other [aaaaaaaaaaa].mp3');
    rec.song = null;
    rec.ytmError = StateError('offline');
    await completer().run();
    expect([done, after], [false, 0]);
    rec.ytmError = null;
    rec.song = _song;
    await completer().run();
    expect([done, rec.calls.where((c) => c.startsWith('songOf')).length], [true, 4]);
  });

  test('the bookmark holds only for its version, and neither key travels in a backup', () async {
    SharedPreferences.setMockInitialValues({recogPassAfterKey: '${kRecogVersion - 1}:9'});
    final old = SettingsStore(await SharedPreferences.getInstance());
    expect(old.recogPassAfter, 0);
    await old.writeRecogPassAfter(9);
    expect(old.recogPassAfter, 9);
    expect(kDeviceBoundKeys, containsAll([recogPassAfterKey, recogPassDoneKey]));
  });

  test('a track that stays due after the normal round does not stop the pass', () async {
    await full(artist: '7clouds Rock', path: _video);
    await r.add(path: '/due.mp3', plain: null); // lyrics stay due: LRCLIB rests
    r.chain
      ..resting = true
      ..limited = true;
    final c = completer();
    await c.run();
    expect([c.passInterrupted, done], [false, true]);
    expect(await r.credits.dueTrackIds(_parts, DateTime.now(), limit: 1), isNotEmpty);
  });
}

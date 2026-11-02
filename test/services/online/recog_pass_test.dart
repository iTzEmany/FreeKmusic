import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart' show decodeRec, mergeDetails;
import 'package:codecore/data/repositories/recog_pass_query.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/backup/backup_service.dart' show kDeviceBoundKeys;
import 'package:codecore/services/online/enrich_completer.dart';
import 'package:codecore/services/online/enrich_runner.dart' show RecogPassIds;
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

  test('a track still unsaved is held when the round was unhealthy, passed over when it was healthy', () async {
    Future<(bool, List<int>)> go({required bool healthy}) async {
      final marks = <int>[];
      final ids = RecogPassIds((a, n) async => [for (final i in [1, 2, 3]) if (i > a) i], (_) async => true, save: marks.add);
      await ids.chunk(_parts, AskMode.due, DateTime.now(), 20);
      return (await ids.complete(healthy: healthy), marks);
    }

    final held = await go(healthy: false);
    expect([held.$1, held.$2], [false, <int>[]]);
    final over = await go(healthy: true); // passed over, but the ids have not run out yet
    expect([over.$1, over.$2], [false, <int>[3]]);
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

  Future<void> threeStablyLost() async {
    for (var n = 0; n < 3; n++) {
      await full(artist: '7clouds Rock', path: '/m/s$n.mp3');
    }
  }

  test('tracks no source recognises are passed over: the second run asks nothing and the pass is done', () async {
    await threeStablyLost();
    rec.song = null;
    await completer().run();
    final first = rec.calls.length;
    expect([done, first], [true, 3]);
    await completer().run();
    expect(rec.calls, hasLength(first));
  });

  test('an unreadable file does not hold the pass', () async {
    await threeStablyLost();
    rec.song = null;
    rec.acoustIdOn = true;
    rec.fingerprintError = StateError('unreadable');
    await completer().run();
    expect(done, isTrue);
  });

  test('the query takes tracks without a rec or with an older one, never one of this version', () async {
    Future<int> withRec(int v) async {
      final id = await full(path: '/v$v.mp3');
      await r.credits.saveEnrich(TrackEnrichCompanion(
          trackId: Value(id), details: Value(mergeDetails(null, rec: Recognition(at: 1, v: v)))));
      return id;
    }

    final none = await full(path: '/none.mp3');
    final old = await withRec(kRecogVersion - 1);
    await withRec(kRecogVersion);
    expect(await recogPassQuery(r.db)(0, 100), [none, old]);
  });
}

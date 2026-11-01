import 'package:codecore/core/text_utils.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/services/online/enrich_engine.dart' show GatherSignal, needsRecognition;
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/online/musicbrainz_client.dart';
import 'package:codecore/services/online/ytm_song_parser.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor, Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';
import '../recognition/support.dart';

class _Reads extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(QueryExecutor e, String sql, List<Object?> args) {
    selects++;
    return super.runSelect(e, sql, args);
  }
}

const _studio = YtmSong(
  title: 'Song',
  artists: ['Band'],
  videoType: 'MUSIC_VIDEO_TYPE_ATV',
  durationMs: 200000,
);
const _video = '/m/Whatever (Romy Wave Cover) [dQw4w9WgXcQ].mp3';
const _parts = {EnrichPart.meta, EnrichPart.lyrics, EnrichPart.curio};

/// A recognizer that answers [out] without asking anyone.
class _Fixed implements TrackRecognizer {
  _Fixed(this.out);
  final RecogOutcome out;

  @override
  Future<RecogOutcome> recognize(Track t, {required TextProbe? textProbe, CancelToken? cancel}) async => out;

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

void main() {
  late Rig rec;
  late EnrichRig r;
  _Reads? reads;

  /// [r] with the recognizer of [rec]; the track says «Whatever» by a channel,
  /// the video it came from says «Song» by «Band».
  Future<int> setUp3({String path = _video, String title = 'Whatever (Romy Wave Cover)', String artist = '7clouds Rock', String? isrc}) {
    r = EnrichRig(interceptor: reads, recognizer: rec.recognizer);
    return r.add(title: title, artist: artist, isrc: isrc, path: path);
  }

  Recognition? recOf(TrackEnrichData? e) => decodeRec(e?.details);

  setUp(() {
    rec = Rig()..acoustIdOn = false;
    reads = null;
  });
  tearDown(() => r.dispose());

  test('the identity gives meta, lyrics and curiosity its title and artist; the row keeps its own', () async {
    rec.song = _studio;
    final id = await setUp3();
    await r.engine.completeOne(id, _parts);
    expect(r.web.queries.where((q) => q.contains('itunes')), everyElement(isNot(anyOf(contains('Whatever'), contains('7clouds')))));
    expect(r.web.queries.any((q) => q.contains('Band Song')), isTrue);
    expect(r.chain.askedWith, ['Song|Band']);
    expect(r.finder.askedFor, ['Song|Band|null|200000']);
    final t = (await r.repo.getById(id))!;
    expect([t.title, t.artist], ['Whatever (Romy Wave Cover)', '7clouds Rock']); // 69d never renames
    // Album, key and cover go to the real row, as today.
    expect(t.album, 'New Album');
    expect(t.albumKey, computeAlbumKey(albumArtist: null, artist: '7clouds Rock', album: 'New Album', directory: '/m'));
    expect(t.hasCover, isTrue);
    final saved = recOf(await r.enrichOf(id))!;
    expect([saved.src, saved.sure, saved.identity!.title, saved.identity!.artist], [RecogSource.ytid, true, 'Song', 'Band']);

    // Next time the saved answer is used, not asked again.
    await r.engine.completeOne(id, _parts, force: true);
    expect(rec.calls.where((c) => c.startsWith('songOf')), hasLength(1));
    expect(r.finder.askedFor.last, 'Song|Band|null|200000');
  });

  test('an identity found by the text search costs no second metadata search', () async {
    final base = EnrichRig();
    final baseId = await base.add();
    await base.engine.completeOne(baseId, {EnrichPart.meta});
    final searches = base.web.count('itunes');
    await base.dispose();

    final id = await setUp3(path: '/a.mp3', title: 'Song', artist: 'Band');
    await r.engine.completeOne(id, {EnrichPart.meta});
    expect(r.web.count('itunes'), searches);
    expect(recOf(await r.enrichOf(id))!.src, RecogSource.text);
    expect((await r.repo.getById(id))!.album, 'New Album');
  });

  test('without a recognizer nothing new is asked and no rec is written', () async {
    r = EnrichRig();
    final id = await r.add(path: _video);
    await r.engine.completeOne(id, _parts);
    expect(rec.calls, isEmpty);
    expect((await r.enrichOf(id))?.details, isNull);
  });

  test('credits written after rec keep it, and rec keeps the details', () async {
    rec.song = _studio;
    final id = await setUp3(isrc: 'ITABC2400001'); // Deezer details come by ISRC
    await r.engine.completeOne(id, {EnrichPart.meta, EnrichPart.credits});
    final e = (await r.enrichOf(id))!;
    expect(recOf(e)!.src, RecogSource.ytid);
    expect(decodeDetails(id, e.details)?.bpm, 120);
    expect(await r.credits.creditsOf(id), isNotEmpty);
  });

  group('needsRecognition', () {
    setUp(() => r = EnrichRig()); // the shared tearDown disposes one
    Track full({String? artist = 'Band', bool userEdited = false}) => track('Song', artist).copyWith(
        album: const Value('Alb'),
        year: const Value(2020),
        genre: const Value('Rock'),
        trackNumber: const Value(1),
        hasCover: true,
        curiosities: const Value('x'),
        userEdited: userEdited);
    String stored(int v) => mergeDetails(null, rec: Recognition(at: 1, v: v));
    TrackEnrichData row(String details) => TrackEnrichData(trackId: 1, details: details, lyricsByUser: false);

    test('a complete track with reliable tags is left alone', () => expect(needsRecognition(full(), null, null), isFalse));
    test('a channel as artist asks', () => expect(needsRecognition(full(artist: '7clouds Rock'), null, null), isTrue));
    test('an empty meta field asks', () => expect(needsRecognition(full().copyWith(year: const Value(null)), null, null), isTrue));
    test('no curiosities asks', () => expect(needsRecognition(full().copyWith(curiosities: const Value(null)), null, null), isTrue));
    test('a saved rec of this version does not ask again',
        () => expect(needsRecognition(full(artist: '7clouds Rock'), row(stored(kRecogVersion)), decodeRec(stored(kRecogVersion))), isFalse));
    test('a saved rec of another version asks',
        () => expect(needsRecognition(full(artist: '7clouds Rock'), row(stored(kRecogVersion + 1)), decodeRec(stored(kRecogVersion + 1))), isTrue));
    test('a hand-edited track never asks', () => expect(needsRecognition(full(artist: '7clouds Rock', userEdited: true), null, null), isFalse));
  });

  test('a track with no part due but dubious tags is recognized', () async {
    rec.song = _studio;
    r = EnrichRig(recognizer: rec.recognizer);
    final id = await r.add(
        title: 'Whatever (Romy Wave Cover)',
        artist: '7clouds Rock',
        path: _video,
        album: 'A',
        genre: 'G',
        year: 2020,
        trackNumber: 1,
        plain: 'la',
        curiosities: 'c',
        hasCover: true);
    final g = await r.engine.gather(id, _parts);
    await r.engine.commit([g]);
    expect(rec.calls.where((c) => c.startsWith('songOf')), hasLength(1));
    expect(recOf(await r.enrichOf(id))!.src, RecogSource.ytid);
  });

  group('the saved rec is merged', () {
    const old = RecogSource.ytid;
    Future<int> withStale(String title, String artist, {String? prop}) async {
      rec.song = _studio;
      final id = await setUp3();
      final stale = Recognition(
          v: kRecogVersion + 1,
          at: 1,
          src: old,
          identity: TrackIdentity(title: title, artist: artist),
          prop: prop,
          was: const {'title': 'T0', 'artist': 'A0'},
          original: const {'title': 'Orig'});
      await r.credits.saveEnrich(TrackEnrichCompanion(trackId: Value(id), details: Value(mergeDetails(null, rec: stale))));
      return id;
    }

    test('a discarded proposal stays discarded for the same identity, and was is kept', () async {
      final id = await withStale('Song', 'Band', prop: 'discarded');
      await r.engine.completeOne(id, _parts);
      final saved = recOf(await r.enrichOf(id))!;
      expect([saved.v, saved.prop, saved.was, saved.original],
          [kRecogVersion, 'discarded', {'title': 'T0', 'artist': 'A0'}, {'title': 'Orig'}]);
    });

    test('an accepted proposal stays accepted for the same identity', () async {
      final id = await withStale('Song', 'Band', prop: 'accepted');
      await r.engine.completeOne(id, _parts);
      expect(recOf(await r.enrichOf(id))!.prop, 'accepted');
    });

    test('a discarded proposal is dropped for another identity', () async {
      final id = await withStale('Old', 'Name', prop: 'discarded');
      await r.engine.completeOne(id, _parts);
      expect(recOf(await r.enrichOf(id))!.prop, isNull);
    });

    test('a row edited by hand meanwhile gets no open proposal', () async {
      r = EnrichRig(
          recognizer: _Fixed(RecogOutcome(
              rec: Recognition(at: 1, src: old, identity: const TrackIdentity(title: 'X', artist: 'Y'), prop: 'open'),
              asked: true)));
      final id = await r.add();
      final g = await r.engine.gather(id, {EnrichPart.meta});
      await (r.db.update(r.db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(userEdited: Value(true)));
      await r.engine.commit([g]);
      expect(recOf(await r.enrichOf(id))!.prop, isNull);
    });
  });

  test('credits use the recognised MusicBrainz id and skip the ISRC lookup', () async {
    const mbid = '6190f4cf-2396-4827-a9cc-c05a0ff3a5b4';
    rec.ids = (isrc: null, mbid: mbid);
    rec.mbById = const MbRecordingDetail(id: mbid, title: 'Song', artist: 'Band', length: 200000);
    final id = await setUp3(path: '/a.mp3', title: 'Song', artist: 'Band', isrc: 'ITABC2400001');
    await r.engine.completeOne(id, {EnrichPart.credits});
    expect(r.web.count('musicbrainz.org/ws/2/isrc/'), 0);
    expect(r.web.count('musicbrainz.org/ws/2/recording/$mbid'), 1);
    expect((await r.enrichOf(id))!.mbid, mbid);
  });

  test('the mbid of a proposal (not sure) does not drive the credits', () async {
    const mbid = '6190f4cf-2396-4827-a9cc-c05a0ff3a5b4';
    r = EnrichRig(
        recognizer: _Fixed(RecogOutcome(
            rec: Recognition(
                at: 1,
                src: RecogSource.ytm,
                identity: const TrackIdentity(title: 'Song', artist: 'Band', mbid: mbid)),
            asked: true)));
    final id = await r.add();
    await r.engine.completeOne(id, {EnrichPart.credits});
    expect(r.web.count('musicbrainz.org/ws/2/isrc/'), 1);
  });

  group('track_enrich.mbid', () {
    const mbid = '6190f4cf-2396-4827-a9cc-c05a0ff3a5b4';
    setUp(() {
      rec.ids = (isrc: null, mbid: mbid);
      rec.mbById = const MbRecordingDetail(id: mbid, title: 'Song', artist: 'Band', length: 200000);
    });

    test('is the identity\'s when the row has none', () async {
      final id = await setUp3(path: '/a.mp3', title: 'Song', artist: 'Band');
      await r.engine.completeOne(id, {EnrichPart.meta});
      expect((await r.enrichOf(id))!.mbid, mbid);
    });

    test('is kept when the row has one', () async {
      final id = await setUp3(path: '/a.mp3', title: 'Song', artist: 'Band');
      await r.credits.saveEnrich(TrackEnrichCompanion(trackId: Value(id), mbid: const Value('old')));
      await r.engine.completeOne(id, {EnrichPart.meta});
      final e = (await r.enrichOf(id))!;
      expect([e.mbid, recOf(e)!.identity!.mbid], ['old', mbid]);
    });
  });

  group('when rec is saved', () {
    test('lost and no identity: no rec, and it asks again next time', () async {
      final id = await setUp3(path: '/a.mp3', title: 'Song', artist: 'Foo - Topic');
      await r.engine.completeOne(id, {EnrichPart.meta});
      expect((await r.enrichOf(id))?.details, isNull);
      expect(rec.calls, ['ytm']);
      await r.engine.completeOne(id, {EnrichPart.meta}, force: true);
      expect(rec.calls, ['ytm', 'ytm']);
    });

    test('every source said «nothing»: rec without src, one metadata search, not asked again', () async {
      final base = EnrichRig()..web.itunes = ItunesMode.empty;
      await base.engine.completeOne(await base.add(isrc: null), {EnrichPart.meta});
      final searches = base.web.count('itunes');
      await base.dispose();

      r = EnrichRig(recognizer: (rec..acoustIdOn = true).recognizer)..web.itunes = ItunesMode.empty;
      final id = await r.add(isrc: null);
      await r.engine.completeOne(id, {EnrichPart.meta});
      expect(r.web.count('itunes'), searches); // the recognizer's text search is the metadata search
      final saved = recOf(await r.enrichOf(id))!;
      expect([saved.src, saved.identity, saved.v], [null, null, kRecogVersion]);
      final asked = rec.calls.length;
      await r.engine.completeOne(id, {EnrichPart.meta}, force: true);
      expect(rec.calls, hasLength(asked));
    });
  });

  test('a new identity asks the parts a recent «nothing» had closed', () async {
    rec.song = _studio;
    final id = await setUp3();
    final now = DateTime.now().millisecondsSinceEpoch;
    await r.credits.saveEnrich(TrackEnrichCompanion(trackId: Value(id), metaNoneAt: Value(now)));
    await r.engine.completeOne(id, {EnrichPart.meta, EnrichPart.lyrics});
    expect(r.web.count('itunes'), greaterThan(0));
    expect((await r.repo.getById(id))!.album, 'New Album');
  });

  test('a manual round counts the sources of the identities it found (the Registro line)', () async {
    rec.song = _studio;
    final id = await setUp3();
    final round = await r.runManual([id], parts: {EnrichPart.meta});
    expect(round.sources, {'ytid': 1});
  });

  test('the commit still reads <= 3 times with a rec to write', () async {
    reads = _Reads();
    rec.song = _studio;
    final id = await setUp3(isrc: 'ITABC2400001');
    final g = await r.engine.gather(id, {...EnrichPart.values});
    expect([g.rec?.src, g.credits != null], [RecogSource.ytid, true]);
    reads!.selects = 0;
    await r.engine.commit([g]);
    expect(reads!.selects, lessThanOrEqualTo(3));
    expect(recOf(await r.enrichOf(id)), isNotNull);
  });

  test('a userEdited track is not recognized and a saved identity is not used', () async {
    rec.song = _studio;
    r = EnrichRig(recognizer: rec.recognizer);
    final id = await r.add(userEdited: true, title: 'Mine', artist: 'Me', path: _video);
    const saved = Recognition(
        at: 1, src: RecogSource.ytid, sure: true, identity: TrackIdentity(title: 'Song', artist: 'Band'));
    await r.credits.saveEnrich(
        TrackEnrichCompanion(trackId: Value(id), details: Value(mergeDetails(null, rec: saved))));
    await r.engine.completeOne(id, _parts);
    expect([rec.calls, r.chain.askedWith], [<String>[], ['Mine|Me']]);
  });

  test('an identity that confirms the tags does not reopen the «nothing» marks', () async {
    rec.song = _studio;
    final id = await setUp3(path: '/m/Song [dQw4w9WgXcQ].mp3', title: 'Song', artist: 'Band');
    final now = DateTime.now().millisecondsSinceEpoch;
    await r.credits.saveEnrich(TrackEnrichCompanion(trackId: Value(id), metaNoneAt: Value(now)));
    await r.engine.completeOne(id, {EnrichPart.meta, EnrichPart.lyrics});
    expect([recOf(await r.enrichOf(id))!.src, r.web.count('itunes')], [RecogSource.ytid, 0]);
  });

  test('a saved rec of another version is not used: the track is recognized again', () async {
    rec.song = _studio;
    final id = await setUp3();
    const stale = Recognition(
        v: kRecogVersion + 1,
        at: 1,
        src: RecogSource.ytid,
        sure: true,
        identity: TrackIdentity(title: 'Old', artist: 'Name'));
    await r.credits.saveEnrich(
        TrackEnrichCompanion(trackId: Value(id), details: Value(mergeDetails(null, rec: stale))));
    await r.engine.completeOne(id, _parts);
    expect(rec.calls.where((c) => c.startsWith('songOf')), hasLength(1));
    expect(r.chain.askedWith, ['Song|Band']);
    final saved = recOf(await r.enrichOf(id))!;
    expect([saved.v, saved.identity!.title], [kRecogVersion, 'Song']);
  });

  test('an identity with the same title and another artist reopens the «nothing» marks', () async {
    rec.song = _studio;
    final id = await setUp3(path: '/m/Song [dQw4w9WgXcQ].mp3', title: 'Song', artist: 'Other Band');
    final now = DateTime.now().millisecondsSinceEpoch;
    await r.credits.saveEnrich(TrackEnrichCompanion(trackId: Value(id), metaNoneAt: Value(now)));
    await r.engine.completeOne(id, {EnrichPart.meta, EnrichPart.lyrics});
    expect(r.web.count('itunes'), greaterThan(0));
    expect((await r.repo.getById(id))!.album, 'New Album');
  });

  test('a rec is written even when no part leaves a mark (meta and lyrics lost)', () async {
    rec.song = _studio;
    final id = await setUp3();
    r.web.itunes = ItunesMode.down;
    r.chain.failed = true;
    await r.engine.completeOne(id, {EnrichPart.meta, EnrichPart.lyrics});
    final e = (await r.enrichOf(id))!;
    expect([e.metaNoneAt, e.lyricsNoneAt], [null, null]);
    expect(recOf(e)!.src, RecogSource.ytid);
  });

  test('D-304: an unsure identity guides the searches, and the row keeps its tags', () async {
    rec.song = const YtmSong(
      title: 'Song',
      artists: ['Band'],
      videoType: 'MUSIC_VIDEO_TYPE_UGC',
      durationMs: 200000,
    );
    final id = await setUp3();
    await r.engine.completeOne(id, _parts);
    expect(recOf(await r.enrichOf(id))!.sure, isFalse);
    expect(r.chain.askedWith, ['Song|Band']);
    expect(r.web.queries.any((q) => q.contains('itunes') && q.contains('Band Song')), isTrue);
    final t = (await r.repo.getById(id))!;
    expect([t.title, t.artist], ['Whatever (Romy Wave Cover)', '7clouds Rock']);
  });

  group('the runner\'s offline count', () {
    Future<GatherSignal> signalOf(RecogOutcome out) async {
      r = EnrichRig(recognizer: _Fixed(out))..web.itunes = ItunesMode.down;
      final g = await r.engine.gather(await r.add(), {EnrichPart.meta});
      await r.engine.commit([g]);
      return g.signal;
    }

    test('a «nothing» that asked no one proves nothing; one that was answered or refused is a sign of life', () async {
      expect(await signalOf(RecogOutcome(rec: const Recognition(at: 1))), GatherSignal.silent);
      expect(await signalOf(RecogOutcome(rec: const Recognition(at: 1), asked: true)), GatherSignal.answered);
      expect(await signalOf(const RecogOutcome(lost: true)), GatherSignal.silent);
      expect(await signalOf(const RecogOutcome(lost: true, limited: true)), GatherSignal.answered);
    });
  });

  test('a track gone between gather and commit is not counted in the sources', () async {
    rec.song = _studio;
    final id = await setUp3();
    final g = await r.engine.gather(id, {EnrichPart.meta});
    expect(g.rec?.src, RecogSource.ytid);
    await r.db.delete(r.db.tracks).go();
    await r.engine.commit([g]);
    expect(g.rec, isNull);
  });
}

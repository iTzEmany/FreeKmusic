import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/activity_log_repository.dart';
import 'package:codecore/data/repositories/credits_repository.dart';
import 'package:codecore/services/library/track_corrections.dart';
import 'package:codecore/services/library/track_editor.dart';
import 'package:codecore/services/library/track_file_sync.dart';
import 'package:codecore/services/online/enrich_parts.dart';
import 'package:codecore/services/recognition/track_identity.dart';
import 'package:codecore/services/recognition/track_recognizer.dart';
import 'package:codecore/services/tags/safe_tag_writer.dart';
import 'package:codecore/services/tags/tag_backups.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:codecore/services/tags/tag_writer.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../../support/enrich_fakes.dart';

const _mbid = '6190f4cf-2396-4827-a9cc-c05a0ff3a5b4';

class _Reader implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async {
    final l = File(path).readAsLinesSync();
    return TagInfo(title: l.length > 1 ? l[1] : '', artist: l.length > 2 ? l[2] : null, durationMs: 1000);
  }
}

/// Records what it is asked to write.
class _FakeWriter implements TagWriter {
  final writes = <TagChanges>[];

  @override
  bool supports(String format) => format == 'mp3';

  @override
  Future<void> write(String path, TagChanges c) async {
    writes.add(c);
    File(path).writeAsStringSync('AUDIO\n${c.title}\n${c.artist}');
  }
}

class _Fixed implements TrackRecognizer {
  _Fixed(this.rec);
  Recognition rec;

  @override
  Future<RecogOutcome> recognize(Track t, {required TextProbe? textProbe, CancelToken? cancel}) async =>
      RecogOutcome(rec: rec, asked: true);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

/// Fails the status write of a commit while [on].
class _FailStatus extends QueryInterceptor {
  bool on = false;
  bool failLog = false;

  @override
  Future<int> runInsert(QueryExecutor e, String sql, List<Object?> args) {
    if (failLog && sql.contains('activity_log')) throw StateError('log broken');
    return super.runInsert(e, sql, args);
  }

  @override
  Future<int> runUpdate(QueryExecutor e, String sql, List<Object?> args) {
    if (on && sql.contains('enrich_status')) throw StateError('disk full');
    return super.runUpdate(e, sql, args);
  }
}

Recognition _rec({bool sure = true, bool cover = false}) => Recognition(
  at: 1,
  cover: cover,
  src: RecogSource.tags,
  sure: sure,
  identity: const TrackIdentity(title: 'Real Title', artist: 'Real Artist', isrc: 'ITABC2400001', mbid: _mbid),
);

void main() {
  late Directory root;
  late EnrichRig r;
  late _FakeWriter writer;
  late _Fixed recognizer;
  late TrackCorrections corrections;
  late bool fileWrites;
  String? playing;
  late String path;
  late _FailStatus failStatus;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('corr');
    path = p.join(root.path, 'a.mp3');
    File(path).writeAsStringSync('AUDIO\nJunk');
    writer = _FakeWriter();
    recognizer = _Fixed(_rec());
    fileWrites = false;
    failStatus = _FailStatus();
    r = EnrichRig(
      interceptor: failStatus,
      recognizer: recognizer,
      onSure: (t, rec) => corrections.apply(t, rec, byUser: false).then((_) {}),
    );
    corrections = TrackCorrections(
      r.db,
      TrackEditor(
        r.db,
        _Reader(),
        files: TrackFileSync(
          r.db,
          () async => SafeTagWriter(
            writer: writer,
            reader: _Reader(),
            workDir: Directory(p.join(root.path, 'work')),
            backups: TagBackupStore(Directory(p.join(root.path, 'bk'))),
          ),
        ),
        fileWritesEnabled: () => fileWrites,
      ),
      r.credits,
      playingPath: () => playing,
    );
    playing = null;
  });
  tearDown(() async {
    await r.dispose();
    root.deleteSync(recursive: true);
  });

  Future<int> track({bool userEdited = false}) => r.add(title: 'Junk', artist: 'Channel', path: path, userEdited: userEdited);
  Future<void> enrich(int id) => r.engine.completeOne(id, {EnrichPart.meta}, force: true);
  Future<Track> row(int id) async => (await r.repo.getById(id))!;
  Future<Recognition?> recOf(int id) async => decodeRec((await r.enrichOf(id))?.details);
  Future<List<ActivityLogRow>> log() => ActivityLogRepository(r.db).page(limit: 10);

  test('a sure recognition corrects the track by itself and the Registro keeps the old values', () async {
    final id = await track();
    await enrich(id);
    final t = await row(id);
    expect([t.title, t.artist, t.userEdited], ['Real Title', 'Real Artist', false]);
    final rows = await log();
    expect(rows.single.kind, 'correction');
    final d = jsonDecode(rows.single.detail!) as Map;
    expect([d['trackId'], d['old'], d['new']], [
      id,
      {'title': 'Junk', 'artist': 'Channel'}, // the file is not written: its ids are not read
      {'title': 'Real Title', 'artist': 'Real Artist'},
    ]);
    final rec = (await recOf(id))!;
    expect([rec.prop, rec.was], ['auto', {'title': 'Junk', 'artist': 'Channel'}]);
  });

  Future<int> enriched({String title = 'Junk', String artist = 'Channel', int status = 1}) async {
    final id = await r.add(title: title, artist: artist, path: path);
    await (r.db.update(r.db.tracks)..where((t) => t.id.equals(id))).write(TracksCompanion(enrichStatus: Value(status)));
    return id;
  }

  Recognition sameTitle() => const Recognition(
    at: 1,
    src: RecogSource.tags,
    sure: true,
    identity: TrackIdentity(title: 'real title', artist: 'Real Artist'),
  );

  test('D-333: on an enriched track a sure identity with another title is only a proposal', () async {
    final id = await enriched();
    await enrich(id);
    final t = await row(id);
    expect([t.title, t.artist, (await recOf(id))!.prop], ['Junk', 'Channel', 'open']);
    expect(await log(), isEmpty);
  });

  test('D-333: on an enriched track an empty artist is filled and the title is kept', () async {
    final id = await enriched(title: 'Real Title', artist: '');
    recognizer.rec = sameTitle();
    await enrich(id);
    final t = await row(id);
    final rec = (await recOf(id))!;
    expect([t.title, t.artist, rec.prop, rec.was], ['Real Title', 'Real Artist', 'auto', {'title': 'Real Title', 'artist': ''}]);
    expect((await log()).single.kind, 'correction');
  });

  test('D-333: a generic artist counts as missing', () async {
    final id = await enriched(title: 'Real Title', artist: 'Unknown Artist');
    recognizer.rec = sameTitle();
    await enrich(id);
    expect((await row(id)).artist, 'Real Artist');
  });

  test('a track enriched with «nothing» still gets the sure correction', () async {
    final id = await enriched(status: 2);
    await enrich(id);
    expect((await row(id)).title, 'Real Title');
  });

  test('a proposal the user accepts marks the track as edited', () async {
    recognizer.rec = _rec(sure: false);
    final id = await track();
    await enrich(id);
    expect((await row(id)).title, 'Junk');
    expect((await recOf(id))!.prop, 'open');
    await corrections.apply(await row(id), (await recOf(id))!, byUser: true);
    final t = await row(id);
    expect([t.title, t.userEdited, (await recOf(id))!.prop], ['Real Title', true, 'accepted']);
  });

  test('accepting and discarding keep the cover mark', () async {
    recognizer.rec = _rec(sure: false, cover: true);
    final id = await track();
    await enrich(id);
    await corrections.apply(await row(id), (await recOf(id))!, byUser: true);
    expect([(await recOf(id))!.prop, (await recOf(id))!.cover], ['accepted', true]);
    await corrections.discard(id);
    expect([(await recOf(id))!.prop, (await recOf(id))!.cover], ['discarded', true]);
  });

  test('a discarded proposal does not come back when the track is enriched again', () async {
    recognizer.rec = _rec(sure: false);
    final id = await track();
    await enrich(id);
    await corrections.discard(id);
    await enrich(id);
    expect((await recOf(id))!.prop, 'discarded');
    expect(await r.credits.watchProposals().first, isEmpty);
    expect((await row(id)).title, 'Junk');
  });

  test('a track edited by hand is never changed nor proposed', () async {
    final id = await track(userEdited: true);
    await enrich(id);
    expect((await row(id)).title, 'Junk');
    expect(await log(), isEmpty);
    expect((await recOf(id))?.prop, isNull);
    expect(await corrections.apply(await row(id), _rec(), byUser: true), isFalse);
  });

  test('the file gets title, artist, ISRC and MBID when a hand edit would write it', () async {
    fileWrites = true;
    await enrich(await track());
    final c = writer.writes.single;
    expect([c.title, c.artist, c.isrc, c.mbid], ['Real Title', 'Real Artist', 'ITABC2400001', _mbid]);
  });

  test('the file is left alone when a hand edit would not write it', () async {
    await enrich(await track());
    expect(writer.writes, isEmpty);
  });

  test('revert puts the old title and artist back and the proposal does not return', () async {
    final id = await track();
    await enrich(id);
    expect(await corrections.revert((await log()).single), isTrue);
    final t = await row(id);
    expect([t.title, t.artist, t.userEdited], ['Junk', 'Channel', false]);
    expect((await recOf(id))!.prop, 'discarded');
  });

  test('a commit that fails applies no correction, and leaves none for the next commit', () async {
    final a = await track();
    final b = await r.add(title: 'Other', artist: 'Channel', path: '/b.mp3');
    failStatus.on = true;
    await enrich(a);
    failStatus.on = false;
    expect((await row(a)).title, 'Junk');
    await enrich(b);
    expect([(await row(a)).title, (await row(b)).title], ['Junk', 'Real Title']);
    expect(await log(), hasLength(1));
  });

  test('revert removes the ids the file did not have', () async {
    fileWrites = true;
    final id = await track();
    await enrich(id);
    writer.writes.clear();
    await corrections.revert((await log()).single);
    final c = writer.writes.single;
    expect([c.title, c.isrc, c.mbid], ['Junk', '', '']);
  });

  test('an error in the Registro rolls the whole correction back', () async {
    final id = await track();
    failStatus.failLog = true;
    await expectLater(corrections.apply(await row(id), _rec(), byUser: true), throwsStateError);
    expect(((await row(id)).title, (await row(id)).userEdited), ('Junk', false));
    expect(await recOf(id), isNull);
  });

  test('an automatic correction that fails stays open for the user', () async {
    final id = await track();
    failStatus.failLog = true;
    await enrich(id);
    failStatus.failLog = false;
    expect((await row(id)).title, 'Junk');
    expect((await recOf(id))!.prop, 'open');
    expect((await r.credits.watchProposals().first).map((p) => p.track.id), [id]);
  });

  test('revert does nothing when the track was edited after the correction', () async {
    final id = await track();
    await enrich(id);
    await r.repo.getById(id);
    await (r.db.update(r.db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(title: Value('Mine')));
    expect(await corrections.revert((await log()).single), isFalse);
    expect((await row(id)).title, 'Mine');
  });

  test('an automatic correction leaves the playing file alone, the DB is corrected', () async {
    fileWrites = true;
    playing = path;
    await enrich(await track());
    expect(writer.writes, isEmpty);
    expect((await r.db.select(r.db.tracks).get()).single.title, 'Real Title');
  });

  test('an automatic correction makes no backup of the file', () async {
    fileWrites = true;
    final id = await track();
    await enrich(id);
    expect(writer.writes, hasLength(1));
    expect(Directory(p.join(root.path, 'bk')).existsSync() && Directory(p.join(root.path, 'bk')).listSync().isNotEmpty, isFalse);
  });

  group('proposals', () {
    Future<void> put(int id, String? details) =>
        r.credits.saveEnrich(TrackEnrichCompanion(trackId: Value(id), details: Value(details)));
    String withProp(String prop) => mergeDetails(null, rec: Recognition(at: 1, identity: _rec().identity, prop: prop));

    test('lists the open ones only and skips a broken JSON', () async {
      final open = await track();
      await put(open, withProp('open'));
      await put(await r.add(path: '/b.mp3'), withProp('discarded'));
      await put(await r.add(path: '/c.mp3'), '{broken');
      await put(await r.add(path: '/d.mp3', userEdited: true), withProp('open'));
      expect((await r.credits.watchProposals().first).map((e) => e.track.id), [open]);
    });

    test('a recognition with a blank title is not a proposal', () async {
      await put(await track(), '{"rec":{"v":2,"at":1,"src":"tags","sure":false,"title":"   ","artist":"A","prop":"open"}}');
      expect(await r.credits.watchProposals().first, isEmpty);
    });

    test('accept all applies them one by one and empties the list', () async {
      await put(await track(), withProp('open'));
      await put(await r.add(path: '/b.mp3', title: 'Other'), withProp('open'));
      expect(await corrections.acceptAll(), 2);
      expect(await r.credits.watchProposals().first, isEmpty);
      expect((await r.db.select(r.db.tracks).get()).map((t) => t.title), everyElement('Real Title'));
    });
  });
}

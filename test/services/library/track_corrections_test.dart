import 'dart:async';
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
import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor, TransactionExecutor, Value;
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

  /// Holds back the next write (only that one) until completed.
  Completer<void>? gate;

  @override
  bool supports(String format) => format == 'mp3';

  @override
  Future<void> write(String path, TagChanges c) async {
    writes.add(c);
    final g = gate;
    gate = null;
    await g?.future;
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

/// Lets a test act while the corrections read the ids of a file (before their transaction).
class _HookEditor extends TrackEditor {
  _HookEditor(super.db, super.tags, {super.files, super.fileWritesEnabled});

  Future<void> Function(Track)? onFileIds;

  @override
  Future<({String? isrc, String? mbid})?> fileIds(Track t) async {
    await onFileIds?.call(t);
    return super.fileIds(t);
  }
}

/// Fails the status write of a commit while [on].
class _FailStatus extends QueryInterceptor {
  bool on = false;
  bool failLog = false;
  int transactions = 0; // top-level ones only (a nested one has a transaction as parent)

  @override
  TransactionExecutor beginTransaction(QueryExecutor parent) {
    if (parent is! TransactionExecutor) transactions++;
    return super.beginTransaction(parent);
  }

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
  late _HookEditor editor;
  TagWriteReason? blocked;
  Object? blockError;
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
    blocked = null;
    blockError = null;
    failStatus = _FailStatus();
    r = EnrichRig(
      interceptor: failStatus,
      recognizer: recognizer,
      onSure: (t, rec) => corrections.apply(t, rec, byUser: false).then((_) {}),
    );
    editor = _HookEditor(
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
    );
    corrections = TrackCorrections(
      r.db,
      editor,
      r.credits,
      fileBlock: (_) async {
        if (blockError != null) throw blockError!;
        return blocked;
      },
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

  test('a correction by the user whose file stays as it was is told in the Registro, the DB row stands', () async {
    fileWrites = true;
    blocked = TagWriteReason.readOnly;
    final id = await track();
    expect(await corrections.apply(await row(id), _rec(), byUser: true), isTrue);
    expect((await row(id)).title, 'Real Title');
    final failed = (await log()).where((e) => e.failed != 0).single;
    expect([failed.kind, (jsonDecode(failed.detail!) as Map)['file']], ['correction', 'readOnly']);
  });

  test('an automatic correction whose file stays as it was leaves no line in the Registro, only the correction', () async {
    fileWrites = true;
    blockError = StateError('no storage');
    final id = await track();
    await enrich(id);
    expect((await row(id)).title, 'Real Title');
    expect((await log()).map((e) => e.failed), [0]);
  });

  test('with the file writes off a blocked file is not asked about and nothing is told', () async {
    blocked = TagWriteReason.readOnly;
    final id = await track();
    expect(await corrections.apply(await row(id), _rec(), byUser: true), isTrue);
    expect((await log()).map((e) => e.failed), [0]);
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

    Future<int> second({String file = 'b.mp3'}) async {
      final path = p.join(root.path, file);
      if (file == 'b.mp3') File(path).writeAsStringSync('AUDIO\nJunk');
      final id = await r.add(path: path, title: 'Other');
      await put(id, withProp('open'));
      return id;
    }

    test('accept all is one transaction and one change of the list, and returns how many', () async {
      await put(await track(), withProp('open'));
      await second();
      final emissions = <int>[];
      final sub = r.credits.watchProposals().listen((l) => emissions.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      emissions.clear();
      failStatus.transactions = 0;
      final done = await corrections.acceptAll();
      await done.files;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(done.count, 2);
      expect(failStatus.transactions, 1);
      expect(emissions, [0]);
      expect((await r.db.select(r.db.tracks).get()).map((t) => t.title), everyElement('Real Title'));
      expect((await log()).map((e) => e.kind), everyElement('correction'));
    });

    test('accept all counts only what changed, and takes the decision for the rest', () async {
      final same = await r.add(path: '/s.mp3', title: 'Real Title', artist: 'Real Artist');
      await put(same, withProp('open'));
      await put(await track(), withProp('open'));
      expect((await corrections.acceptAll()).count, 1);
      expect((await recOf(same))!.prop, 'accepted');
    });

    test('accept all: a file that cannot be written goes in the Registro, the DB rows stay', () async {
      fileWrites = true;
      await put(await track(), withProp('open'));
      final bad = await second(file: 'missing.mp3');
      final done = await corrections.acceptAll();
      expect(done.count, 2);
      await done.files;
      expect(writer.writes, hasLength(1));
      expect((await row(bad)).title, 'Real Title');
      expect((await recOf(bad))!.prop, 'accepted');
      final failed = (await log()).where((e) => e.failed != 0).single;
      expect([failed.kind, failed.name, (jsonDecode(failed.detail!) as Map)['trackId']], ['correction', 'Real Title', bad]);
      expect((await log()).where((e) => e.failed == 0), hasLength(2));
    });

    test('accept all: a file blocked for writing is told in the Registro, the DB rows stay', () async {
      fileWrites = true;
      blocked = TagWriteReason.readOnly;
      final id = await track();
      await put(id, withProp('open'));
      final done = await corrections.acceptAll();
      await done.files;
      expect(writer.writes, isEmpty);
      expect((await row(id)).title, 'Real Title');
      final failed = (await log()).where((e) => e.failed != 0).single;
      expect((jsonDecode(failed.detail!) as Map)['file'], 'readOnly');
    });

    test('accept all leaves out a proposal refused after the list was read', () async {
      fileWrites = true;
      final kept = await track();
      await put(kept, withProp('open'));
      final refused = await second();
      editor.onFileIds = (t) async {
        if (t.id == refused) await corrections.discard(refused);
      };
      final done = await corrections.acceptAll();
      await done.files;
      expect(done.count, 1);
      expect([(await row(kept)).title, (await row(refused)).title], ['Real Title', 'Other']);
      expect((await recOf(refused))!.prop, 'discarded');
    });

    test('reverting with reopen puts the values back and the proposals in the list again', () async {
      final id = await track();
      await put(id, withProp('open'));
      final other = await second();
      final done = await corrections.acceptAll();
      expect(await r.credits.watchProposals().first, isEmpty);
      for (final e in done.log) {
        expect(await corrections.revert(e, reopen: true), isTrue);
      }
      expect((await r.credits.watchProposals().first).map((e) => e.track.id).toSet(), {id, other});
      expect([(await row(id)).title, (await row(id)).userEdited], ['Junk', false]);
    });

    test('revertAll puts every title back and every proposal open in ONE transaction, the files after', () async {
      fileWrites = true;
      final id = await track();
      await put(id, withProp('open'));
      final other = await second();
      final done = await corrections.acceptAll();
      await done.files;
      final emissions = <int>[];
      final sub = r.credits.watchProposals().listen((l) => emissions.add(l.length));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      emissions.clear();
      failStatus.transactions = 0;
      final back = await corrections.revertAll(done);
      await back.files;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(back.count, 2);
      expect(failStatus.transactions, 1);
      expect(emissions, isNotEmpty);
      expect(emissions, everyElement(2), reason: 'the list goes from none to both, never through one');
      expect([(await row(id)).title, (await row(other)).title, (await row(id)).userEdited], ['Junk', 'Other', false]);
      expect(File(path).readAsStringSync(), contains('Junk'));
    });

    test('revertAll writes the old tags only after the new ones are in the file', () async {
      fileWrites = true;
      await put(await track(), withProp('open'));
      final gate = Completer<void>();
      writer.gate = gate;
      final done = await corrections.acceptAll(); // its file write waits at the gate
      final back = await corrections.revertAll(done);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(writer.writes, hasLength(1), reason: 'the old tags wait for the new ones');
      gate.complete();
      await back.files;
      expect(writer.writes.map((c) => c.title), ['Real Title', 'Junk']);
      expect(File(path).readAsStringSync(), contains('Junk'));
    });

    test('revertAll does not write the file of a correction that accepting did not write', () async {
      await put(await track(), withProp('open'));
      final done = await corrections.acceptAll(); // file writes off
      fileWrites = true;
      final back = await corrections.revertAll(done);
      await back.files;
      expect(back.count, 1);
      expect(writer.writes, isEmpty);
    });

    test('revertAll leaves a track edited since and counts only what went back', () async {
      await put(await track(), withProp('open'));
      final other = await second();
      final done = await corrections.acceptAll();
      await (r.db.update(r.db.tracks)..where((t) => t.id.equals(other))).write(const TracksCompanion(title: Value('Mine')));
      final back = await corrections.revertAll(done);
      await back.files;
      expect(back.count, 1);
      expect((await row(other)).title, 'Mine');
    });

    Future<int> third({String file = 'c.mp3'}) async {
      final path = p.join(root.path, file);
      File(path).writeAsStringSync('AUDIO\nJunk');
      final id = await r.add(path: path, title: 'Third');
      await put(id, withProp('open'));
      return id;
    }

    Future<List<ActivityLogRow>> accepted() async {
      fileWrites = true;
      await put(await track(), withProp('open'));
      final done = await corrections.acceptAll();
      await done.files;
      return done.log;
    }

    test('revert with the file blocked: the DB is back and the Registro tells the file was not updated', () async {
      final rows = await accepted();
      blocked = TagWriteReason.readOnly;
      expect(await corrections.revert(rows.single), isTrue);
      expect((await row(rows.map((e) => (jsonDecode(e.detail!) as Map)['trackId'] as int).single)).title, 'Junk');
      final failed = (await log()).where((e) => e.failed != 0).single;
      expect([failed.name, (jsonDecode(failed.detail!) as Map)['file']], ['Junk', 'readOnly']);
    });

    test('revert whose file check throws: the DB is back and the Registro tells it', () async {
      final rows = await accepted();
      blockError = StateError('no storage');
      expect(await corrections.revert(rows.single), isTrue);
      final failed = (await log()).where((e) => e.failed != 0).single;
      expect((jsonDecode(failed.detail!) as Map)['file'], 'ioError');
    });

    test('accept all reads its Registro rows back in chunks', () async {
      await put(await track(), withProp('open'));
      await second();
      await third();
      final done = await corrections.acceptAll(logChunk: 1);
      expect(done.log.map((e) => e.id).toSet(), hasLength(3));
    });

    test('accept all leaves alone a track edited by hand, or whose proposal was renewed, after the list was read', () async {
      fileWrites = true;
      final kept = await track();
      await put(kept, withProp('open'));
      final edited = await second();
      final renewed = await third();
      final renewedArtist = await third(file: 'd.mp3');
      editor.onFileIds = (t) async {
        if (t.id == edited) {
          await (r.db.update(r.db.tracks)..where((x) => x.id.equals(edited))).write(const TracksCompanion(userEdited: Value(true)));
        }
        if (t.id == renewed || t.id == renewedArtist) {
          final byTitle = t.id == renewed; // one differs by title only, the other by artist only
          final title = byTitle ? 'Newer' : 'Real Title';
          await put(
            t.id,
            mergeDetails(null, rec: Recognition(at: 2, identity: TrackIdentity(title: title, artist: byTitle ? 'Real Artist' : 'Other'), prop: 'open')),
          );
        }
      };
      final done = await corrections.acceptAll();
      expect(done.count, 1);
      expect([(await row(kept)).title, (await row(edited)).title, (await row(renewed)).title, (await row(renewedArtist)).title],
          ['Real Title', 'Other', 'Third', 'Third']);
      expect((await recOf(renewed))!.prop, 'open');
    });

    test('revert and revertAll with the file writes off since: a blocked file is not asked about and nothing is told', () async {
      final id = await track();
      await put(id, withProp('open'));
      final done = await corrections.acceptAll();
      await done.files;
      fileWrites = false;
      blocked = TagWriteReason.readOnly;
      expect(await corrections.revert(done.log.single, reopen: true), isTrue);
      expect((await log()).where((e) => e.failed != 0), isEmpty);
      await put(id, withProp('open'));
      final again = await corrections.acceptAll();
      fileWrites = true;
      blocked = null;
      await again.files;
      fileWrites = false;
      blocked = TagWriteReason.readOnly;
      final back = await corrections.revertAll(again);
      await back.files;
      expect(back.count, 1);
      expect((await log()).where((e) => e.failed != 0), isEmpty);
    });

    test('a recognition that changes only the artist still reads the file ids to put back', () async {
      fileWrites = true;
      final id = await r.add(title: 'Real Title', artist: 'Channel', path: path);
      await put(id, withProp('open'));
      final done = await corrections.acceptAll();
      final old = (jsonDecode(done.log.single.detail!) as Map)['old'] as Map;
      expect([old['title'], old['artist'], old['isrc'], old['mbid']], ['Real Title', 'Channel', '', '']);
    });

    test('a blank artist in the identity keeps the track artist, in the DB and in the Registro', () async {
      final id = await track();
      await put(
        id,
        mergeDetails(null, rec: const Recognition(at: 1, identity: TrackIdentity(title: 'Real Title', artist: ''), prop: 'open')),
      );
      final done = await corrections.acceptAll();
      expect([(await row(id)).title, (await row(id)).artist], ['Real Title', 'Channel']);
      expect(((jsonDecode(done.log.single.detail!) as Map)['new'] as Map)['artist'], 'Channel');
    });

    test('revert does nothing when only the artist was edited after the correction', () async {
      final id = await track();
      await put(id, withProp('open'));
      final done = await corrections.acceptAll();
      await (r.db.update(r.db.tracks)..where((t) => t.id.equals(id))).write(const TracksCompanion(artist: Value('Hand')));
      expect(await corrections.revert(done.log.single), isFalse);
      expect([(await row(id)).title, (await row(id)).artist], ['Real Title', 'Hand']);
    });

    test('accept all, apply by the user and revert keep a backup of the file', () async {
      final bk = Directory(p.join(root.path, 'bk'));
      int backups() => bk.existsSync() ? bk.listSync(recursive: true).whereType<File>().length : 0;
      void clear() {
        if (bk.existsSync()) bk.deleteSync(recursive: true);
      }

      final rows = await accepted();
      expect(backups(), greaterThan(0));
      clear();
      expect(await corrections.revert(rows.single), isTrue);
      expect(backups(), greaterThan(0));
      clear();
      final other = await second();
      await corrections.apply(await row(other), (await recOf(other))!, byUser: true);
      expect(backups(), greaterThan(0));
    });

    test('reverting what accept all logged puts every title back, files included', () async {
      fileWrites = true;
      final id = await track();
      await put(id, withProp('open'));
      final other = await second();
      final done = await corrections.acceptAll();
      await done.files;
      expect(File(path).readAsStringSync(), contains('Real Title'));
      for (final e in done.log) {
        expect(await corrections.revert(e), isTrue);
      }
      expect([(await row(id)).title, (await row(other)).title], ['Junk', 'Other']);
      expect(File(path).readAsStringSync(), contains('Junk'));
      expect((await recOf(id))!.prop, 'discarded');
    });
  });
}

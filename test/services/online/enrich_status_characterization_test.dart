import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_genre_repository.dart';
import 'package:codecore/services/online/enrichment_service.dart';
import 'package:codecore/services/online/itunes_client.dart' show ItunesMatch;
import 'package:drift/drift.dart' show QueryExecutor, QueryInterceptor, Value;
import 'package:flutter_test/flutter_test.dart';

import '../../support/enrich_fakes.dart';

/// Fixes what `tracks.enrich_status` and the job counts are.
class _Reads extends QueryInterceptor {
  int selects = 0;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    selects++;
    return super.runSelect(executor, statement, args);
  }
}

void main() {
  late EnrichRig r;
  late _Reads reads;

  setUp(() {
    reads = _Reads();
    r = EnrichRig(interceptor: reads);
  });
  tearDown(() => r.dispose());

  Future<void> setStatus(int id, int s) => (r.db.update(
    r.db.tracks,
  )..where((t) => t.id.equals(id))).write(TracksCompanion(enrichStatus: Value(s)));

  Future<int> statusOf(int id) async => (await r.repo.getById(id))!.enrichStatus;

  Future<int> viaMany(int id, {bool lyrics = false}) async {
    await r.runManual([id], parts: {EnrichPart.meta, if (lyrics) EnrichPart.lyrics});
    return statusOf(id);
  }

  group('manual job', () {
    test('found: status 1', () async {
      expect(await viaMany(await r.add()), 1);
    });

    test('iTunes empty: status 2', () async {
      r.web.itunes = ItunesMode.empty;
      expect(await viaMany(await r.add()), 2);
    });

    test('offline: status unchanged (0)', () async {
      r.web.itunes = ItunesMode.down;
      expect(await viaMany(await r.add()), 0);
    });

    test('lyrics failed + meta none: status unchanged (0)', () async {
      r.web.itunes = ItunesMode.empty;
      r.chain.failed = true;
      expect(await viaMany(await r.add(), lyrics: true), 0);
    });

    test('a track at 1, then nothing: status stays 1 (D-285)', () async {
      final id = await r.add();
      await setStatus(id, 1);
      r.web.itunes = ItunesMode.empty;
      expect(await viaMany(id), 1);
    });

    test('a match that writes nothing is «nothing», not found: status 2, not counted as updated', () async {
      r.web.itunesGenre = false;
      final id = await r.add(album: 'A', year: 2000, trackNumber: 1, hasCover: true);
      final round = await r.runManual([id]);
      expect(await statusOf(id), 2);
      expect((round.updatedTracks, round.notFoundTracks), (0, 1));
    });

    test('a failed cover download leaves the status as it was', () async {
      r.web.coverDown = true;
      final id = await r.add(album: 'A', year: 2000, genre: 'G', trackNumber: 1);
      final round = await r.runManual([id]);
      expect(await statusOf(id), 0);
      expect((round.updatedTracks, round.notFoundTracks), (0, 0), reason: 'no answer: neither found nor «nothing»');
    });

    test('job counts on 3 tracks: filled, no match, already complete', () async {
      final a = await r.add(path: '/a.mp3');
      final b = await r.add(path: '/b.mp3');
      final c = await r.add(
        path: '/c.mp3',
        album: 'A',
        genre: 'G',
        year: 2000,
        trackNumber: 1,
        hasCover: true,
      );
      await setStatus(c, 1);
      // The second iTunes question gets an empty answer.
      r.web.onUrl = (u) {
        if (u.contains('itunes')) {
          r.web.itunes = r.web.count('itunes') >= 2 ? ItunesMode.empty : ItunesMode.match;
        }
      };
      final seen = <(int, int)>[];
      final round = await r.runManual([a, b, c], onProgress: (d, t) => seen.add((d, t)));
      expect((round.updatedTracks, round.notFoundTracks), (1, 1));
      expect(seen.last, (3, 3));
    });
  });

  group('commit', () {
    Future<int> viaCommit(int id, Set<EnrichPart> parts) async {
      await r.engine.completeOne(id, parts);
      return statusOf(id);
    }

    test('offline: status unchanged (0)', () async {
      r.web.itunes = ItunesMode.down;
      expect(await viaCommit(await r.add(), {EnrichPart.meta}), 0);
    });

    test('only the curiosity found: status 1', () async {
      r.web.itunes = ItunesMode.empty;
      final id = await r.add();
      expect(await viaCommit(id, {EnrichPart.meta, EnrichPart.curio}), 1);
    });

    test('lyrics failed + meta none: status unchanged (0)', () async {
      r.web.itunes = ItunesMode.empty;
      r.chain.failed = true;
      final id = await r.add();
      expect(await viaCommit(id, {EnrichPart.meta, EnrichPart.lyrics}), 0);
    });

    test('meta none, lyrics found: status 1', () async {
      r.web.itunes = ItunesMode.empty;
      final id = await r.add();
      expect(await viaCommit(id, {EnrichPart.meta, EnrichPart.lyrics}), 1);
    });

    test('only lyrics asked and none: status unchanged (0), metadata was not asked', () async {
      r.chain.result = null;
      final id = await r.add();
      expect(await viaCommit(id, {EnrichPart.lyrics}), 0);
    });

    test('a track at 1, then nothing: status stays 1 (D-285)', () async {
      r.web.itunes = ItunesMode.empty;
      final id = await r.add();
      await setStatus(id, 1);
      expect(await viaCommit(id, {EnrichPart.meta}), 1);
    });

    test('selects in one commit of one track: <= 3 (row, track_enrich, credits)', () async {
      final id = await r.add();
      final g = await r.engine.gather(id, {
        EnrichPart.meta,
        EnrichPart.lyrics,
        EnrichPart.synced,
        EnrichPart.curio,
        EnrichPart.credits,
      });
      expect(g.credits, isNotNull); // credits really gathered: 3 reads, not 2
      reads.selects = 0;
      await r.engine.commit([g]);
      // A hand-picked cover with a changed album key (settleMovedCover) reads more, as before.
      expect(reads.selects, lessThanOrEqualTo(3));
    });
  });

  test('apply that writes the genre keeps track_genres in step (D-390)', () async {
    final id = await r.add();
    final t = (await r.repo.getById(id))!;
    final proposal = EnrichmentProposal(
      track: t,
      meta: const ItunesMatch(title: 'Song', artist: 'Band', genre: 'Rock; Pop'),
    );
    expect(await r.svc.apply(proposal, {EnrichField.genre}), isTrue);
    expect(await TrackGenreRepository(r.db).of(id), ['Rock', 'Pop']);
  });

  test('apply that writes no field leaves the status as it was', () async {
    final id = await r.add();
    final t = (await r.repo.getById(id))!;
    final proposal = EnrichmentProposal(
      track: t,
      meta: const ItunesMatch(title: 'Song', artist: 'Band', album: 'New Album'),
    );
    expect(await r.svc.apply(proposal, <EnrichField>{}), isTrue);
    expect(await statusOf(id), 0);
  });
}

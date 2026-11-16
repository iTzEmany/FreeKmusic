import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PlayHistoryRepository repo;
  late int trackId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = PlayHistoryRepository(db);
    await db.into(db.tracks).insert(TracksCompanion.insert(
        path: '/a.mp3', title: 'A', albumKey: 'k', format: 'mp3',
        sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    trackId = (await db.select(db.tracks).getSingle()).id;
  });
  tearDown(() => db.close());

  test('start opens a row with the time and the context', () async {
    final id = await repo.start(trackId, 1000, context: 2, contextName: 'Mix', msPlayed: 30000);
    final row = (await db.select(db.plays).get()).single;
    expect(row.id, id);
    expect(row.trackId, trackId);
    expect(row.playedAt, 1000);
    expect(row.msPlayed, 30000);
    expect(row.context, 2);
    expect(row.contextName, 'Mix');
  });

  test('finish sets the time played; the last call wins', () async {
    final id = await repo.start(trackId, 1000);
    expect((await db.select(db.plays).getSingle()).msPlayed, 0);
    await repo.finish(id, 31000);
    await repo.finish(id, 42000);
    expect((await db.select(db.plays).getSingle()).msPlayed, 42000);
  });

  test('count counts the rows', () async {
    expect(await repo.count(), 0);
    await repo.start(trackId, 1);
    await repo.start(trackId, 2);
    expect(await repo.count(), 2);
  });

  group('reading and clearing', () {
    late List<int> ids;
    setUp(() async {
      for (final n in ['b', 'c']) {
        await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/$n.mp3', title: n, albumKey: 'k', format: 'mp3',
            sizeBytes: 1, mtimeMs: 1, addedAt: 1));
      }
      ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    });

    test('the newest first, with the track, and the same track can appear twice', () async {
      await repo.start(ids[0], 1000);
      await repo.start(ids[1], 3000);
      await repo.start(ids[0], 2000);
      final list = await repo.watchHistory().first;
      expect(list.map((e) => e.play.playedAt), [3000, 2000, 1000]);
      expect(list.map((e) => e.track.title), ['b', 'A', 'A']);
    });

    test('a block at a time: limit, then «before» the last one seen', () async {
      for (var i = 1; i <= 5; i++) {
        await repo.start(ids[0], i * 1000);
      }
      final first = await repo.watchHistory(limit: 2).first;
      expect(first.map((e) => e.play.playedAt), [5000, 4000]);
      final next = await repo.watchHistory(limit: 2, beforePlayedAt: 4000).first;
      expect(next.map((e) => e.play.playedAt), [3000, 2000]);
    });

    test('listens of a track whose file is gone are left out', () async {
      await repo.start(ids[0], 1000);
      await repo.start(ids[1], 2000);
      await (db.update(db.tracks)..where((t) => t.id.equals(ids[1])))
          .write(const TracksCompanion(missing: Value(true)));
      expect((await repo.watchHistory().first).map((e) => e.track.id), [ids[0]]);
    });

    test('listens of a shadow row (a streamed track) are in the history', () async {
      final shadow = await TrackRepository(db).upsertStreamRow(
          'youtube:abc',
          const YtResult(id: 'abc', title: 'S', channel: 'C', duration: null),
          File('pubspec.yaml'));
      await repo.start(shadow, 1000);
      await repo.start(shadow, 2000);
      expect((await repo.watchHistory().first).map((e) => e.track.id), [shadow, shadow]);
    });

    test('the stream follows new listens', () async {
      // Each list is awaited before the next change: no sleeping, no timing.
      final lengths = StreamIterator(repo.watchHistory().map((l) => l.length));
      addTearDown(lengths.cancel);
      expect(await lengths.moveNext(), isTrue);
      expect(lengths.current, 0);
      await repo.start(ids[0], 1000);
      expect(await lengths.moveNext(), isTrue);
      expect(lengths.current, 1);
    });

    test('clear forgets the listens but not the play counts', () async {
      await repo.start(ids[0], 1000);
      await TrackRepository(db).registerPlay(ids[0]);
      expect(await repo.clear(), 1);
      expect(await repo.count(), 0);
      expect((await TrackRepository(db).getById(ids[0]))!.playCount, 1);
    });
  });

  group('groupHistoryByDay', () {
    HistoryEntry e(DateTime at) => HistoryEntry(
        Play(id: 1, trackId: 1, playedAt: at.millisecondsSinceEpoch, msPlayed: 0),
        Track(saved: false, coverSource: 0, id: 1, path: '/a', title: 'A', albumKey: 'k', format: 'mp3',
            sizeBytes: 1, mtimeMs: 1, isFavorite: false, enrichStatus: 0,
            userEdited: false, missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
            hasCover: false, durationMs: 0));

    test('one header per day, entries in the order given', () {
      final a = e(DateTime(2026, 10, 16, 22, 5));
      final b = e(DateTime(2026, 10, 16, 9, 30));
      final c = e(DateTime(2026, 10, 15, 23, 59));
      final items = groupHistoryByDay([a, b, c]);
      expect(items, [DateTime(2026, 10, 16), a, b, DateTime(2026, 10, 15), c]);
    });

    test('nothing, no header', () {
      expect(groupHistoryByDay(const []), isEmpty);
    });
  });
}


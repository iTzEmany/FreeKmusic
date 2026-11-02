import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/tags/mp3_length_fix.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TracksCompanion _row(
  String path, {
  String format = 'mp3',
  int ms = 274000,
  int kind = 0,
  int kbps = 56,
  bool missing = false,
}) => TracksCompanion.insert(
  path: path,
  title: 'Fixed Title',
  albumKey: 'k',
  format: format,
  sizeBytes: 1,
  mtimeMs: 1,
  addedAt: 1,
  artist: const Value('Fixed Artist'),
  durationMs: Value(ms),
  bitrateKbps: Value(kbps),
  kind: Value(kind),
  missing: Value(missing),
);

void main() {
  late AppDatabase db;
  late TrackRepository tracks;
  late SharedPreferences prefs;
  var calls = 0;

  Future<List<Mp3Measure>> measure(List<String> paths) async {
    calls += paths.length;
    return [
      for (final p in paths)
        switch (p) {
          '/a/ok.mp3' => (ms: 240000, bps: 64000, failed: false),
          '/a/gone.mp3' => (ms: 0, bps: 0, failed: true),
          '/a/unknown.mp3' => null,
          '/a/xing.mp3' => (ms: 274000, bps: 128000, failed: false), // length right, bitrate off
          _ => (ms: 274500, bps: 56000, failed: false),
        },
    ];
  }

  setUp(() async {
    calls = 0;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
  });
  tearDown(() => db.close());

  Future<void> insert(List<TracksCompanion> rows) async {
    for (final r in rows) {
      await db.into(db.tracks).insert(r);
    }
  }

  test('the repository lists local mp3 music only: no shadow rows, episodes or missing files', () async {
    await insert([
      _row('/a/ok.mp3'),
      _row('/a/song.flac', format: 'flac'),
      _row('stream:abc'), // a shadow row by its path, kind 0
      _row('/a/shadow.mp3', kind: 2), // a shadow row by its kind, normal path
      _row('/a/episode.mp3', kind: 1),
      _row('/a/lost.mp3', missing: true),
    ]);
    final rows = await tracks.mp3LengthRows();
    expect(rows.map((r) => r.path), ['/a/ok.mp3']);
    await tracks.setLengths([(id: rows.first.id, durationMs: 1234, bitrateKbps: 99)]);
    final t = await (db.select(db.tracks)..where((x) => x.id.equals(rows.first.id))).getSingle();
    expect((t.durationMs, t.bitrateKbps, t.title, t.artist), (1234, 99, 'Fixed Title', 'Fixed Artist'));
  });

  test('runs once: a wrong length or bitrate is fixed, the rest stays, the flag stops a second run', () async {
    await insert([
      _row('/a/ok.mp3'),
      _row('/a/same.mp3'), // within 1 s and 2 kbps of its measure
      _row('/a/xing.mp3', ms: 274000, kbps: 56), // same length, bitrate far off
      _row('/a/unknown.mp3'),
    ]);
    expect(await Mp3LengthFix(tracks, prefs, measure: measure).runOnce(), 2);
    final all = {for (final t in await db.select(db.tracks).get()) t.path: t};
    expect((all['/a/ok.mp3']!.durationMs, all['/a/ok.mp3']!.bitrateKbps, all['/a/ok.mp3']!.title), (240000, 64, 'Fixed Title'));
    expect((all['/a/xing.mp3']!.durationMs, all['/a/xing.mp3']!.bitrateKbps), (274000, 128));
    expect(all['/a/same.mp3']!.durationMs, 274000);
    expect(all['/a/unknown.mp3']!.durationMs, 274000);
    expect(prefs.getBool(Mp3LengthFix.flag), true);
    expect(await Mp3LengthFix(tracks, prefs, measure: measure).runOnce(), 0);
    expect(calls, 4);
  });

  test('a file that cannot be read leaves the flag unset so the next start tries again', () async {
    await insert([_row('/a/ok.mp3'), _row('/a/gone.mp3')]);
    expect(await Mp3LengthFix(tracks, prefs, measure: measure).runOnce(), 1);
    expect(prefs.getBool(Mp3LengthFix.flag), isNull);
  });

  test('two runs at once make a single pass', () async {
    await insert([_row('/a/ok.mp3')]);
    final gate = Completer<void>();
    Future<List<Mp3Measure>> slow(List<String> p) async {
      await gate.future;
      return measure(p);
    }

    final a = Mp3LengthFix(tracks, prefs, measure: slow).runOnce();
    final b = Mp3LengthFix(tracks, prefs, measure: slow).runOnce();
    gate.complete();
    expect(await Future.wait([a, b]), [1, 0]);
    expect(calls, 1);
  });
}

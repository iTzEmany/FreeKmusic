import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/tags/mp3_length_fix.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

TracksCompanion _row(String path, {String format = 'mp3', int ms = 274000, int kind = 0}) =>
    TracksCompanion.insert(
      path: path,
      title: 'Fixed Title',
      albumKey: 'k',
      format: format,
      sizeBytes: 1,
      mtimeMs: 1,
      addedAt: 1,
      artist: const Value('Fixed Artist'),
      durationMs: Value(ms),
      bitrateKbps: const Value(56),
      kind: Value(kind),
    );

void main() {
  late AppDatabase db;
  late TrackRepository tracks;
  late SharedPreferences prefs;
  var calls = 0;

  Future<List<({int ms, int bps})?>> measure(List<String> paths) async {
    calls += paths.length;
    return [for (final p in paths) p == '/a/ok.mp3' ? (ms: 240000, bps: 64000) : (ms: 274500, bps: 56000)];
  }

  setUp(() async {
    calls = 0;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    await db.into(db.tracks).insert(_row('/a/ok.mp3'));
    await db.into(db.tracks).insert(_row('/a/same.mp3'));
    await db.into(db.tracks).insert(_row('/a/song.flac', format: 'flac'));
    await db.into(db.tracks).insert(_row('stream:abc', kind: 2));
  });
  tearDown(() => db.close());

  test('the repository changes only the length and bitrate of local mp3 rows', () async {
    final rows = await tracks.mp3LengthRows();
    expect(rows.map((r) => r.path), unorderedEquals(['/a/ok.mp3', '/a/same.mp3']));
    await tracks.setLengths([(id: rows.first.id, durationMs: 1234, bitrateKbps: 99)]);
    final t = await (db.select(db.tracks)..where((x) => x.id.equals(rows.first.id))).getSingle();
    expect((t.durationMs, t.bitrateKbps, t.title, t.artist), (1234, 99, 'Fixed Title', 'Fixed Artist'));
  });

  test('runs once: rows off by more than 1 s are fixed, the flag stops a second run', () async {
    final fix = Mp3LengthFix(tracks, prefs, measure: measure);
    expect(await fix.runOnce(), 1); // same.mp3 is within 1 s of its measure (274500 vs 274000)
    final all = await db.select(db.tracks).get();
    final ok = all.firstWhere((t) => t.path == '/a/ok.mp3');
    expect((ok.durationMs, ok.bitrateKbps, ok.title), (240000, 64, 'Fixed Title'));
    expect(all.firstWhere((t) => t.path == '/a/same.mp3').durationMs, 274000);
    expect(all.firstWhere((t) => t.path == '/a/song.flac').durationMs, 274000);
    expect(all.firstWhere((t) => t.path == 'stream:abc').durationMs, 274000);
    expect(prefs.getBool(Mp3LengthFix.flag), true);
    expect(await Mp3LengthFix(tracks, prefs, measure: measure).runOnce(), 0);
    expect(calls, 2);
  });
}

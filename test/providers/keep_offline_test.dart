import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/keep_offline_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only stream rows without a file are queued: saved and unsaved alike', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> add(int n, String path, int kind, {bool saved = true}) => db.into(db.tracks).insert(
          TracksCompanion.insert(
            path: path, title: 'T$n', albumKey: 'k', format: '', sizeBytes: 0, mtimeMs: 0, addedAt: 1,
            kind: Value(kind), saved: Value(saved),
          ),
        );
    await add(1, 'stream:youtube:a', 2); // saved stream, no file
    await add(2, 'stream:youtube:b', 2, saved: false); // shadow row, no file
    await add(3, 'stream:youtube:c', 2); // already downloaded
    await add(4, '/m/d.mp3', 0); // a device file
    await add(5, 'stream:youtube:e', 1); // an episode
    final queued = <YtResult>[];
    final n = keepOffline(
      await db.select(db.tracks).get(),
      pathForKey: (k) => k == 'youtube:c' ? '/m/c.m4a' : null,
      download: queued.add,
    );
    expect(n, 2);
    expect(queued.map((r) => r.indexKey), ['youtube:a', 'youtube:b']);
    expect(queued.first.title, 'T1');
  });
}

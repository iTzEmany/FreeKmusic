import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/providers/keep_offline_providers.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/providers/library_add_providers.dart';
import 'package:codecore/providers/youtube_providers.dart' show downloadsProvider, DownloadsNotifier;
import 'package:codecore/providers/youtube_providers.dart' show downloadIndexProvider;
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/download_queue.dart' show DownloadItem;
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoDownloads extends DownloadsNotifier {
  @override
  List<DownloadItem> build() => const [];
}

class _Adder extends LibraryAdder {
  _Adder(super.ref);
  final got = <String>[];
  @override
  Future<bool?> download(YtResult r, {String? tag}) async {
    got.add(r.indexKey);
    return true;
  }
}

void main() {
  test('the bulk action downloads through the library adder (D-695), skipping files and local rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    Future<void> add(String path, int kind) => db.into(db.tracks).insert(TracksCompanion.insert(
          path: path, title: 't', albumKey: 'k', format: '', sizeBytes: 0, mtimeMs: 0, addedAt: 1, kind: Value(kind)));
    await add('stream:youtube:a', 2);
    await add('stream:youtube:b', 2);
    await add('/m/d.mp3', 0);
    final idx = DownloadIndex(File('/nonexistent/idx.json'));
    late _Adder adder;
    final c = ProviderContainer(overrides: [
      downloadIndexProvider.overrideWith((ref) async => idx),
      downloadsProvider.overrideWith(_NoDownloads.new),
      libraryAdderProvider.overrideWith((ref) => adder = _Adder(ref)),
    ]);
    addTearDown(c.dispose);
    final n = await c.read(keepOfflineProvider)(await db.select(db.tracks).get());
    expect(n, 2);
    expect(adder.got, ['youtube:a', 'youtube:b']);
  });

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
    await add(6, 'stream:youtube:q', 2); // already queued
    final queued = <YtResult>[];
    final n = keepOffline(
      await db.select(db.tracks).get(),
      pathForKey: (k) => k == 'youtube:c' ? '/m/c.m4a' : null,
      inQueue: {'youtube:q'},
      download: queued.add,
    );
    expect(n, 2);
    expect(queued.map((r) => r.indexKey), ['youtube:a', 'youtube:b']);
    expect(queued.first.title, 'T1');
  });
}

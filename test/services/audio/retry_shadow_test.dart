import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_stream_preparer.dart';

void main() {
  late AppDatabase db;
  late FakeStreamPreparer preparer;
  late OnlineEntries online;
  late CodecoreAudioHandler handler;
  late Directory dir;
  late int id;
  late Completer<void> gate;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('retry_shadow');
    preparer = FakeStreamPreparer(TrackRepository(db), dir);
    online = OnlineEntries();
    handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {}, online: online, preparer: preparer);
    // Plays from an address: the file (and so the row) is not there yet.
    preparer.urls['youtube:v1'] = (Uri.parse('https://rr1.googlevideo.com/first'), const {});
    id = online.register(const YtResult(id: 'v1', title: 'Song', channel: 'C', artists: ['A'], duration: Duration(minutes: 3)));
    await db.into(db.tracks).insert(TracksCompanion.insert(
      path: '/m/t.mp3', title: 'Lib', albumKey: 'a|b', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1, artist: const Value('A')));
    final lib = (await db.select(db.tracks).get()).single.id;
    // The background download is held back: no row yet.
    gate = preparer.gates['youtube:v1'] = Completer<void>();
    await handler.playQueue([id, lib], 0);
    await pumpEventQueue();
    expect(online.entryOf(id)!.trackId, isNull);
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('after a failed download, retry asks the preparer again and binds the row', () async {
    preparer.failing.add('youtube:v1');
    gate.complete(); // the background download fails
    await pumpEventQueue();
    final queues = preparer.queues.length;
    await handler.retryShadow();
    expect(online.entryOf(id)!.trackId, isNull);
    expect(preparer.queues.length, greaterThan(queues)); // resynced before asking

    preparer.failing.clear();
    await handler.retryShadow();
    expect(online.entryOf(id)!.trackId, isNotNull);
  });

  test('a failed retry does not look for the row', () async {
    // The row exists, but the preparer fails: the retry must stop before binding it.
    final f = File('${dir.path}/row.m4a')..writeAsStringSync('x');
    await TrackRepository(db).upsertStreamRow('youtube:v1', online.entryOf(id)!.result, f);
    preparer.gates.remove('youtube:v1');
    preparer.failing.add('youtube:v1');
    await handler.retryShadow();
    expect(online.entryOf(id)!.trackId, isNull);
  });

  test('a skip while the retry waits: the row is not bound to the new track', () async {
    final retry = handler.retryShadow();
    await pumpEventQueue();
    await handler.skipToNext();
    gate.complete();
    await retry;
    expect(online.entryOf(id)!.trackId, isNull);
  });

  test('shadowWaitOf stops listening to the phases once the subscription is cancelled', () async {
    int listening() => preparer.phases.listeners;
    final before = listening();
    final sub = handler.shadowWaitOf(id).listen((_) {});
    await pumpEventQueue();
    expect(listening(), before + 1);
    await sub.cancel();
    expect(listening(), before);
  });
}

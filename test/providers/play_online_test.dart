import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_backend.dart';
import '../support/fake_stream_preparer.dart';

YtResult _r(String id) => YtResult(id: id, title: 'T$id', channel: 'C', duration: null);

void main() {
  late AppDatabase db;
  late OnlineEntries online;
  late CodecoreAudioHandler handler;
  late PlayerController player;
  late List<int> ids;
  late bool plus;
  int? downloaded;
  var lookupFails = false;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    online = OnlineEntries();
    final repo = TrackRepository(db);
    handler = CodecoreAudioHandler(
      FakeBackend(),
      PlayQueue(),
      repo,
      onError: (_) {},
      online: online,
      preparer: FakeStreamPreparer(repo, Directory.systemTemp.createTempSync('play_online')),
    );
    ids = [
      for (final n in ['a', 'b'])
        await db.into(db.tracks).insert(TracksCompanion.insert(
              path: '/m/$n.mp3',
              title: 'Song $n',
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
            )),
    ];
    plus = true;
    downloaded = null;
    lookupFails = false;
    player = PlayerController(
      handler,
      null,
      shufflePlus: () => plus,
      setShufflePlus: (on) => plus = on,
      libraryIdOf: (_) async {
        if (lookupFails) throw StateError('index unreadable');
        return downloaded;
      },
    );
    await handler.playQueue(ids, 0);
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  test('playOnline inserts after the current track and jumps to it', () async {
    await player.playOnline(_r('x'));
    final q = handler.queueIds;
    expect(q.length, 3);
    expect([q[0], q[2]], ids);
    expect(isOnlineId(q[1]), isTrue);
    expect(handler.currentIndex, 1);
  });

  test('a result already downloaded plays the library track, no online entry', () async {
    downloaded = ids[1];
    await player.playOnline(_r('x'));
    expect(handler.queueIds, [ids[0], ids[1], ids[1]]);
    expect(handler.currentIndex, 1);
    expect(online.idsOf(_r('x')), isEmpty);
  });

  test('enqueueOnline appends, playOnlineNext goes after the current one', () async {
    await player.enqueueOnline(_r('e'));
    expect(isOnlineId(handler.queueIds.last), isTrue);
    await player.playOnlineNext(_r('n'));
    final q = handler.queueIds;
    expect(isOnlineId(q[1]), isTrue);
    expect(q.length, 4);
    expect(handler.currentIndex, 0);
    expect(q[0], ids[0]);
  });

  test('playOnlineList replaces the queue in order; shuffle never turns Shuffle+ on', () async {
    final list = [for (var i = 0; i < 5; i++) _r('v$i')];
    await player.playOnlineList(list);
    expect([for (final i in handler.queueIds) online.entryOf(i)?.result.id],
        ['v0', 'v1', 'v2', 'v3', 'v4']);
    await player.playOnlineList(list, shuffle: true);
    expect(handler.shuffleEnabled, isTrue);
    expect(plus, isFalse);
  });

  test('playMixed queues library and online songs in the given order; shuffle keeps the same items', () async {
    final tracks = [
      for (final id in ids)
        (await db.select(db.tracks).get()).firstWhere((t) => t.id == id),
    ];
    final mix = <MixItem>[
      (track: tracks[0], online: null),
      (track: tracks[1], online: null),
      (track: null, online: _r('s0')),
    ];
    await player.playMixed(mix);
    expect(handler.queueIds.take(2), ids);
    expect(online.entryOf(handler.queueIds[2])?.result.id, 's0');
    expect(handler.queueIds, hasLength(3));
    await player.setShuffle(true);
    await player.playMixed(mix);
    expect(handler.queueIds.toSet(), hasLength(3));
    expect(handler.queueIds.where((i) => isOnlineId(i)), hasLength(1));
    expect(handler.queueIds.where(ids.contains), hasLength(2));
  });

  test('playOnlineList with shuffle starts at a random track, not always the first', () async {
    player = PlayerController(handler, null, random: _FixedRandom(3), libraryIdOf: (_) async => null);
    await player.playOnlineList([for (var i = 0; i < 5; i++) _r('v$i')], shuffle: true);
    expect(online.entryOf(handler.queueIds[handler.currentIndex])?.result.id, 'v3');
  });

  test('playOnlineList sets the shuffle modes without waiting for the first track to load', () async {
    await player.setShuffle(true);
    plus = true;
    final dir = Directory.systemTemp.createTempSync('play_online_gate');
    addTearDown(() => dir.deleteSync(recursive: true));
    final preparer = FakeStreamPreparer(TrackRepository(db), dir)..gates['youtube:v0'] = Completer<void>();
    handler.preparer = preparer;
    final playing = player.playOnlineList([_r('v0'), _r('v1')]);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(handler.shuffleEnabled, isFalse);
    expect(plus, isFalse);
    preparer.gates['youtube:v0']!.complete();
    await playing;
  });

  test('playOnlineList without shuffle un-shuffles a queue that was shuffled', () async {
    await player.setShuffle(true);
    final list = [for (var i = 0; i < 5; i++) _r('v$i')];
    await player.playOnlineList(list);
    expect([for (final i in handler.queueIds) online.entryOf(i)?.result.id],
        ['v0', 'v1', 'v2', 'v3', 'v4']);
    expect(handler.shuffleEnabled, isFalse);
  });

  test('during radio an online result replaces the stations', () async {
    await handler.playStations(
        [const RadioStation(id: 's', name: 'S', streamUrl: 'http://x')], 0);
    await player.enqueueOnline(_r('x'));
    expect(handler.queueIds.length, 1);
    expect(online.entryOf(handler.queueIds.single)?.result.id, 'x');
    expect(handler.isRadio, isFalse);
  });

  test('playOnline, enqueueOnline and playOnlineNext survive an unreadable download index', () async {
    lookupFails = true;
    await player.playOnline(_r('x'));
    await player.enqueueOnline(_r('x'));
    await player.playOnlineNext(_r('x'));
    expect(handler.queueIds, ids);
  });

  test('playOnline during radio plays the result alone', () async {
    await handler.playStations(
        [const RadioStation(id: 's', name: 'S', streamUrl: 'http://x')], 0);
    await player.playOnline(_r('x'));
    expect(handler.queueIds.length, 1);
    expect(online.entryOf(handler.queueIds.single)?.result.id, 'x');
    expect(handler.isRadio, isFalse);
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);
  final int value;
  @override
  int nextInt(int max) => value;
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

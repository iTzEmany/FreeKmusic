import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:audio_service/audio_service.dart' show AudioProcessingState;
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show DebugPrintCallback, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_stream_preparer.dart';

Future<void> settle() => pumpEventQueue();

YtResult result(String id, {String? thumb}) => YtResult(
      id: id,
      title: 'Song $id',
      channel: 'Chan',
      artists: const ['Ann', 'Bob'],
      album: 'Alb',
      duration: const Duration(minutes: 3),
      thumbnailUrl: thumb,
    );

void main() {
  late AppDatabase db;
  late FakeBackend backend;
  late OnlineEntries online;
  late CodecoreAudioHandler handler;
  late FakeStreamPreparer preparer;
  late Directory dir;
  late List<int> ids;
  late List<PlaybackFailure> failures;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    backend = FakeBackend();
    online = OnlineEntries();
    failures = [];
    dir = Directory.systemTemp.createTempSync('online_playback');
    for (final n in ['a', 'b']) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$n.mp3', title: n, albumKey: 'k', format: 'mp3',
          sizeBytes: 1, mtimeMs: 1, addedAt: 1, durationMs: const Value(200000)));
    }
    ids = (await db.select(db.tracks).get()).map((t) => t.id).toList();
    preparer = FakeStreamPreparer(TrackRepository(db), dir);
    handler = CodecoreAudioHandler(backend, PlayQueue(), TrackRepository(db),
        onError: failures.add,
        history: PlayHistoryRepository(db),
        online: online,
        preparer: preparer);
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> listenTo(int seconds) async {
    for (var s = 0; s <= seconds; s += 5) {
      backend.posC.add(Duration(seconds: s));
      await Future<void>.delayed(Duration.zero);
    }
  }

  // AppLog echoes to debugPrint in debug builds.
  Future<List<String>> timingLines(Future<void> Function() body) async {
    final lines = <String>[];
    final DebugPrintCallback old = debugPrint;
    debugPrint = (m, {wrapWidth}) => lines.add(m ?? '');
    try {
      await body();
    } finally {
      debugPrint = old;
    }
    return lines.where((l) => l.contains('stream timing')).toList();
  }

  test('the first sound of a streamed track logs play= from the cache', () async {
    final id = online.register(result('v1'));
    final lines = await timingLines(() async {
      await handler.playQueue([id], 0);
      backend.stateC.add(BackendState.playing);
      backend.posC.add(const Duration(seconds: 1));
      backend.posC.add(const Duration(seconds: 2));
      await settle();
    });
    expect(lines, hasLength(1));
    expect(lines.single, matches(RegExp(r'key=youtube:v1 play=\d+ from=cache$')));
  });

  test('a streamed track from the address logs from=url; after a natural end it also logs gap=', () async {
    final id = online.register(result('v1'));
    preparer.urls['youtube:v1'] = (Uri.parse('https://rr1.googlevideo.com/v1'), const {});
    final lines = await timingLines(() async {
      await handler.playQueue([ids.first, id], 0);
      backend.stateC.add(BackendState.completed);
      await settle();
      backend.stateC.add(BackendState.playing);
      backend.posC.add(const Duration(seconds: 1));
      await settle();
    });
    expect(lines.single, matches(RegExp(r'key=youtube:v1 play=\d+ from=url gap=\d+$')));
  });

  test('the first sound of a library track logs from=file', () async {
    final lines = await timingLines(() async {
      await handler.playQueue([ids.first], 0);
      backend.stateC.add(BackendState.playing);
      backend.posC.add(const Duration(seconds: 1));
      await settle();
    });
    expect(lines.single, matches(RegExp(r'key=track:\d+ play=\d+ from=file$')));
  });

  test('an online entry loads the cached file, not an address', () async {
    final id = online.register(result('v1'));
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await settle();
    expect(handler.playbackState.value.processingState, AudioProcessingState.loading);
    expect(backend.loaded, isEmpty);
    gate.complete();
    await started;
    expect(backend.loaded.single, endsWith('youtube_v1.m4a'));
    expect(backend.loadedUris, isEmpty);
    expect(preparer.queues.first, ['youtube:v1']); // told before the file was asked for
    expect(handler.currentTrack?.id, id);
  });

  final addr = Uri.parse('https://rr1.googlevideo.com/v1');

  test('an address that arrives first is opened with loadUri and its headers, no file', () async {
    final id = online.register(result('v1'));
    preparer.urls['youtube:v1'] = (addr, {'User-Agent': 'x'});
    final lines = await timingLines(() async {
      await handler.playQueue([id], 0);
      backend.stateC.add(BackendState.playing);
      backend.posC.add(const Duration(seconds: 1));
      backend.posC.add(const Duration(seconds: 2));
      await settle();
    });
    expect(backend.loadedUris.single.uri, addr);
    expect(backend.loadedUris.single.headers, {'User-Agent': 'x'});
    expect(backend.loaded, isEmpty);
    expect(lines.single, matches(RegExp(r'play=\d+ from=url$')));
  });

  test('an address that fails to open falls back to the file, with no error for the user', () async {
    final id = online.register(result('v1'));
    preparer.urls['youtube:v1'] = (addr, const {});
    backend.failing.add(addr.toString());
    await handler.playQueue([id], 0);
    await settle();
    expect(backend.loaded.single, endsWith('youtube_v1.m4a'));
    expect(failures, isEmpty);
  });

  test('from the address, the plays count on the shadow row once the file is there', () async {
    final id = online.register(result('v1'));
    preparer.urls['youtube:v1'] = (addr, const {});
    await handler.playQueue([id], 0);
    await listenTo(100);
    backend.stateC.add(BackendState.completed);
    await settle();
    final row = await TrackRepository(db).streamRow('youtube:v1');
    expect(row!.playCount, 1);
    expect(backend.loaded, isEmpty);
  });

  test('a stream that reports no length keeps the known one while it plays from the address', () async {
    final id = online.register(result('v1'));
    preparer.urls['youtube:v1'] = (addr, const {});
    await handler.playQueue([id], 0);
    final seen = <Duration?>[];
    final sub = handler.durationStream.listen(seen.add);
    backend.durC.add(null);
    backend.durC.add(const Duration(minutes: 4));
    await settle();
    await sub.cancel();
    expect(seen, [const Duration(minutes: 4)]);
  });

  test('a Shuffle+ suggestion starts from its address too', () async {
    final id = online.register(result('v2'), suggested: true);
    preparer.urls['youtube:v2'] = (addr, const {});
    await handler.playQueue([id], 0);
    await settle();
    expect(backend.loadedUris.single.uri, addr);
    expect(backend.loaded, isEmpty);
  });

  test('a downloaded online entry is not prepared nor streamed; the other still is', () async {
    handler.libraryIdOf = (r) async => r.id == 'v1' ? ids[1] : null;
    final e = [online.register(result('v1')), online.register(result('v2'))];
    await handler.playQueue(e, 0);
    await settle();
    expect(handler.currentTrack?.id, ids[1]);
    expect(backend.loaded.single, '/m/b.mp3');
    expect(preparer.asked, isEmpty);
    expect(preparer.queues.last, ['youtube:v2']);
    expect(handler.loadingStream, isFalse);
  });

  test('plays and the resume point of a downloaded online entry land on the library id', () async {
    await (db.update(db.tracks)..where((t) => t.id.equals(ids[1]))).write(const TracksCompanion(
        durationMs: Value(30 * 60 * 1000), resumePositionMs: Value(600000)));
    handler.libraryIdOf = (_) async => ids[1];
    await handler.playQueue([online.register(result('v1'))], 0);
    expect(backend.seeks, [const Duration(milliseconds: 595000)]);
    await listenTo(100);
    backend.stateC.add(BackendState.completed);
    await settle();
    final plays = await db.select(db.plays).get();
    expect(plays.map((p) => p.trackId), [ids[1]]);
  });

  test('deleting the library file of a playing online entry takes the entry out too', () async {
    handler.libraryIdOf = (_) async => ids[1];
    final id = online.register(result('v1'));
    await handler.playQueue([id, ids[0]], 0);
    expect(handler.currentTrack?.id, ids[1]);
    await handler.removeTracks({ids[1]});
    expect(handler.queueIds, [ids[0]]);
    expect(handler.currentTrack?.id, ids[0]);
  });

  test('resyncPreparer drops an entry downloaded after it was queued', () async {
    final e = [online.register(result('v1')), online.register(result('v2'))];
    await handler.playQueue([ids[0], ...e], 0);
    await settle();
    expect(preparer.queues.last, ['youtube:v1', 'youtube:v2']);
    handler.libraryIdOf = (r) async => r.id == 'v2' ? ids[1] : null;
    await handler.resyncPreparer();
    expect(preparer.queues.last, ['youtube:v1']);
  });

  test('a download lookup that fails leaves the entry streaming', () async {
    handler.libraryIdOf = (_) async => throw StateError('index unreadable');
    final id = online.register(result('v1'));
    await handler.playQueue([id], 0);
    expect(preparer.asked, ['youtube:v1']);
    expect(backend.loaded.single, endsWith('youtube_v1.m4a'));
  });

  test('a seek while the stream loads never reaches the backend', () async {
    final id = online.register(result('v1'));
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await settle();
    expect(handler.loadingStream, isTrue);
    await handler.seek(const Duration(seconds: 30));
    expect(backend.seeks, isEmpty);
    gate.complete();
    await started;
  });

  test('a row of kind 2 plays through the preparer with the key of its path', () async {
    final file = File('${dir.path}/x.m4a')..writeAsStringSync('x');
    final rowId = await TrackRepository(db).upsertStreamRow('youtube:v9', result('v9'), file);
    await handler.playQueue([rowId], 0);
    expect(preparer.asked, ['youtube:v9']);
    expect(backend.loaded.single, endsWith('youtube_v9.m4a'));
  });

  test('a preparer that fails skips the entry; too many failures end in idle', () async {
    final bad = [for (final n in ['1', '2', '3', '4', '5']) online.register(result(n))];
    preparer.failing.addAll([for (final n in ['1', '2', '3', '4', '5']) 'youtube:$n']);
    await handler.playQueue([...bad, ids[0]], 0);
    await settle();
    expect(failures.length, CodecoreAudioHandler.maxConsecutiveErrors + 1);
    expect(failures.first.reason, PlaybackFailureReason.onlineUnavailable);
    expect(handler.playbackState.value.processingState, AudioProcessingState.idle);
    expect(backend.loaded, isEmpty);
  });

  test('an offline preparer failure is reported as a network failure', () async {
    final id = online.register(result('v1'));
    preparer.failing.add('youtube:v1');
    preparer.failure = const YtException(YtErrorKind.network);
    await handler.playQueue([id, ids[0]], 0);
    await settle();
    expect(failures.single.reason, PlaybackFailureReason.networkUnavailable);
  });

  test('an age-restricted video with no substitute is reported as ageRestricted', () async {
    final id = online.register(result('v1'));
    preparer.failing.add('youtube:v1');
    preparer.failure = const YtException(YtErrorKind.unavailable, 'ERROR: Sign in to confirm your age');
    await handler.playQueue([id, ids[0]], 0);
    await settle();
    expect(failures.single.reason, PlaybackFailureReason.ageRestricted);
  });

  test('a non-network YtException is reported as onlineUnavailable', () async {
    final id = online.register(result('v1'));
    preparer.failing.add('youtube:v1');
    preparer.failure = const YtException(YtErrorKind.unavailable);
    await handler.playQueue([id, ids[0]], 0);
    await settle();
    expect(failures.single.reason, PlaybackFailureReason.onlineUnavailable);
  });

  test('one failure skips to the next track', () async {
    final id = online.register(result('v1'));
    preparer.failing.add('youtube:v1');
    await handler.playQueue([id, ids[0]], 0);
    await settle();
    expect(failures.single.reason, PlaybackFailureReason.onlineUnavailable);
    expect(handler.currentTrack?.id, ids[0]);
  });

  test('the next track still downloading at the end stays loading, then plays by itself', () async {
    final id = online.register(result('v2'));
    final gate = preparer.gates['youtube:v2'] = Completer<void>();
    await handler.playQueue([ids[0], id], 0);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(handler.currentTrack?.id, id);
    expect(handler.playbackState.value.processingState, AudioProcessingState.loading);
    expect(backend.loaded, ['/m/a.mp3']);
    gate.complete();
    await settle();
    expect(backend.loaded.last, endsWith('youtube_v2.m4a'));
    expect(backend.playing, isTrue);
  });

  test('the player never sets a streamed track as the backend next track', () async {
    final id = online.register(result('v2'));
    await handler.playQueue([ids[0], id], 0);
    await settle();
    expect(backend.nextCalls.whereType<String>(), isEmpty);
  });

  Future<int> shadowRow(String v) async {
    final file = File('${dir.path}/$v.m4a')..writeAsStringSync('x');
    final id = await TrackRepository(db).upsertStreamRow('youtube:$v', result(v), file);
    await (db.update(db.tracks)..where((t) => t.id.equals(id))).write(
        const TracksCompanion(replayGainDb: Value(-6), resumePositionMs: Value(5000), durationMs: Value(200000)));
    return id;
  }

  Future<int?> resumeOf(int id) async => (await TrackRepository(db).getById(id))!.resumePositionMs;

  test('a shadow row is a stream: no ReplayGain, no bookmark on leaving', () async {
    final row = await shadowRow('s1');
    await handler.setNormalize(true);
    await handler.setTransition(TransitionMode.gapless);
    await handler.playQueue([row, ids[1]], 0);
    await settle();
    expect(backend.volumes.last, 1.0);
    expect(backend.seeks, isEmpty);
    await listenTo(100);
    await handler.skipToNext();
    expect(await resumeOf(row), 5000);
  });

  test('a shadow row played to its end keeps its bookmark untouched', () async {
    final row = await shadowRow('s2');
    await handler.playQueue([row, ids[1]], 0);
    await listenTo(100);
    backend.stateC.add(BackendState.completed);
    await settle();
    expect(await resumeOf(row), 5000);
  });

  test('the preparer gets the queue from the current entry on', () async {
    final e = [for (final n in ['q0', 'q1', 'q2']) online.register(result(n))];
    await handler.playQueue(e, 1);
    await settle();
    expect(preparer.queues.last, ['youtube:q1', 'youtube:q2']);
  });

  test('two full listens of a streamed track count on its shadow row', () async {
    final id = online.register(result('v1'));
    for (var i = 0; i < 2; i++) {
      await handler.playQueue([id], 0);
      await listenTo(100);
      backend.stateC.add(BackendState.completed);
      await settle();
    }
    final row = await TrackRepository(db).streamRow('youtube:v1');
    final plays = await db.select(db.plays).get();
    expect(plays.length, 2);
    expect(plays.every((p) => p.trackId == row!.id), isTrue);
    expect(row!.playCount, 2);
  });

  test('liveCurrentTrackProvider shows the shadow row once the enrichment wrote the lyrics', () async {
    final id = online.register(result('v1'));
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      audioHandlerProvider.overrideWithValue(handler),
    ]);
    addTearDown(container.dispose);
    container.listen(liveCurrentTrackProvider, (_, _) {});
    await handler.playQueue([id], 0);
    await settle();
    final row = (await TrackRepository(db).streamRow('youtube:v1'))!;
    await (db.update(db.tracks)..where((t) => t.id.equals(row.id)))
        .write(const TracksCompanion(lyricsPlain: Value('la la')));
    await settle();
    final live = container.read(liveCurrentTrackProvider).value;
    expect(live?.id, id);
    expect(live?.lyricsPlain, 'la la');
  });

  test('enrichment: a new uncached track does not re-enrich the previous row, then enriches its own once', () async {
    final rows = <int>[];
    Future<void> later() => Future<void>.delayed(const Duration(milliseconds: 200));
    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      audioHandlerProvider.overrideWithValue(handler),
      streamEnrichRowProvider.overrideWithValue((r) async => rows.add(r)),
    ]);
    addTearDown(container.dispose);
    container.listen(currentTrackProvider, (_, _) {});
    container.listen(streamEnrichTriggerProvider, (_, _) {});
    await later(); // the providers subscribe to the handler
    final a = online.register(result('va'));
    await handler.playQueue([a], 0);
    await later();
    final rowA = (await TrackRepository(db).streamRow('youtube:va'))!.id;
    expect(rows, [rowA]);
    final b = online.register(result('vb'));
    final gate = preparer.gates['youtube:vb'] = Completer<void>();
    final started = handler.playQueue([b], 0);
    await later();
    expect(rows, [rowA]);
    gate.complete();
    await started;
    await later();
    final rowB = (await TrackRepository(db).streamRow('youtube:vb'))!.id;
    expect(rows, [rowA, rowB]);
  });

  test('the old track pauses while the file comes; A ending meanwhile does not skip B', () async {
    final id = online.register(result('v2'));
    final gate = preparer.gates['youtube:v2'] = Completer<void>();
    await handler.playQueue([ids[0], id], 0);
    backend.playing = true;
    backend.stateC.add(BackendState.playing);
    await settle();
    final started = handler.skipToNext();
    await settle();
    backend.stateC.add(BackendState.completed); // A ends while B is fetched
    await settle();
    expect(handler.currentTrack?.id, id);
    expect(handler.playbackState.value.processingState, AudioProcessingState.loading);
    gate.complete();
    await started;
    await settle();
    expect(backend.loaded.last, endsWith('youtube_v2.m4a'));
    expect(backend.playing, isTrue);
    expect(handler.queueIds.length, 2);
  });

  test('pause while the file comes: it loads paused', () async {
    final id = online.register(result('v2'));
    final gate = preparer.gates['youtube:v2'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await settle();
    await handler.pause();
    gate.complete();
    await started;
    expect(backend.loaded.single, endsWith('youtube_v2.m4a'));
    expect(backend.playing, isFalse);
  });

  test('pause then play while the file comes: playback starts when it is ready', () async {
    final id = online.register(result('v2'));
    final gate = preparer.gates['youtube:v2'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await settle();
    await handler.pause();
    await handler.play();
    gate.complete();
    await started;
    expect(backend.loaded.single, endsWith('youtube_v2.m4a'));
    expect(backend.playing, isTrue);
  });

  test('a pause before the entry is even known as a stream still sticks', () async {
    final lookup = Completer<void>();
    handler.libraryIdOf = (_) async {
      await lookup.future;
      return null;
    };
    final id = online.register(result('v2'));
    final started = handler.playQueue([id], 0);
    await settle();
    await handler.pause();
    lookup.complete();
    await started;
    expect(backend.loaded.single, endsWith('youtube_v2.m4a'));
    expect(backend.playing, isFalse);
  });

  test('toggle while the file comes pauses it instead of playing', () async {
    final id = online.register(result('v2'));
    final gate = preparer.gates['youtube:v2'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await settle();
    await handler.togglePlayPause();
    gate.complete();
    await started;
    expect(backend.playing, isFalse);
  });

  test('while a stream loads the position is 0 and the length the result\'s, not the old track\'s', () async {
    final id = online.register(result('v2'));
    final gate = preparer.gates['youtube:v2'] = Completer<void>();
    await handler.playQueue([ids[0]], 0);
    final pos = <Duration>[], dur = <Duration?>[];
    final subs = [handler.positionStream.listen(pos.add), handler.durationStream.listen(dur.add)];
    final started = handler.playQueue([id], 0);
    await settle();
    backend.posC.add(const Duration(seconds: 137)); // the old track still reports
    backend.durC.add(const Duration(seconds: 200));
    await settle();
    expect(pos, everyElement(Duration.zero));
    expect(dur.last, const Duration(minutes: 3));
    gate.complete();
    await started;
    for (final s in subs) {
      await s.cancel();
    }
  });

  test('no listen is counted for B before its file loads', () async {
    final id = online.register(result('v2'));
    final gate = preparer.gates['youtube:v2'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await settle();
    await listenTo(100); // positions of the old track
    expect(await db.select(db.plays).get(), isEmpty);
    gate.complete();
    await started;
  });

  test('a failed restore while paused does not start the next track', () async {
    final bad = online.register(result('v1'));
    preparer.failing.add('youtube:v1');
    await handler.restore([bad, ids[0]], 0, Duration.zero);
    await settle();
    expect(handler.currentTrack?.id, ids[0]);
    expect(backend.playing, isFalse);
  });

  test('replaceQueueId swaps a stream entry for a library track in place', () async {
    final s1 = online.register(result('v1'));
    final s2 = online.register(result('v2'));
    await handler.playQueue([ids[0], s1, s2], 0);
    expect(handler.replaceQueueId(s1, ids[1]), isTrue);
    expect(handler.queueIds, [ids[0], ids[1], s2]);
    // The entry now playing keeps streaming.
    await handler.skipToQueueItem(2);
    await settle();
    expect(handler.replaceQueueId(s2, ids[1]), isFalse);
    expect(handler.replaceQueueId(-99, ids[1]), isFalse);
  });

  test('an entry missing from the registry is skipped as not in library', () async {
    await handler.playQueue([-99, ids[0]], 0);
    await settle();
    expect(failures.single.reason, PlaybackFailureReason.notInLibrary);
    expect(handler.currentTrack?.id, ids[0]);
  });

  test('the notification item comes from the synthetic track', () async {
    final id = online.register(result('v1',
        thumb: 'https://lh3.googleusercontent.com/x=w60-h60-l90-rj'));
    await handler.playQueue([id], 0);
    final item = handler.mediaItem.value!;
    expect(item.id, 'online:v1');
    expect(item.title, 'Song v1');
    expect(item.artist, 'Ann, Bob');
    expect(item.album, 'Alb');
    expect(item.artUri.toString(), 'https://lh3.googleusercontent.com/x=w544-h544-l90-rj');
    expect(item.extras, {'online': true});
  });

  test('while a stream loads the notification says «Caricamento…» instead of the artist', () async {
    final id = online.register(result('v1'));
    final gate = preparer.gates['youtube:v1'] = Completer<void>();
    final started = handler.playQueue([id], 0);
    await settle();
    expect(handler.loadingStream, isTrue);
    expect(handler.mediaItem.value!.title, 'Song v1');
    expect(handler.mediaItem.value!.artist, 'Caricamento…');
    gate.complete();
    await started;
    await settle();
    expect(handler.loadingStream, isFalse);
    expect(handler.mediaItem.value!.artist, 'Ann, Bob');
  });

  test('a seek or backend buffering on a ready stream does not raise the loading flag', () async {
    final id = online.register(result('v1'));
    await handler.playQueue([id], 0);
    await settle();
    expect(handler.loadingStream, isFalse);
    backend.stateC.add(BackendState.loading);
    await handler.seek(const Duration(seconds: 30));
    await settle();
    expect(handler.loadingStream, isFalse);
    expect(handler.mediaItem.value!.artist, 'Ann, Bob');
  });

  test('skipping from a loading stream to a local track clears the flag', () async {
    final id = online.register(result('v1'));
    preparer.gates['youtube:v1'] = Completer<void>();
    unawaited(handler.playQueue([id, ids[0]], 0));
    await settle();
    expect(handler.loadingStream, isTrue);
    await handler.skipToNext();
    await settle();
    expect(handler.loadingStream, isFalse);
    expect(handler.mediaItem.value!.title, 'a');
    expect(handler.mediaItem.value!.artist, isNot('Caricamento…'));
  });

  test('a radio never raises the loading flag', () async {
    final states = <bool>[];
    final sub = handler.playbackState.listen((_) => states.add(handler.loadingStream));
    await handler.playStations(const [
      RadioStation(id: 'r', name: 'Radio r', streamUrl: 'http://radio.test/r', faviconUrl: '')
    ], 0);
    await settle();
    await sub.cancel();
    expect(states, isNot(contains(true)));
  });

  test('insertAt and removeQueueId change the queue and tell the listeners', () async {
    final id = online.register(result('v2'));
    await handler.playQueue([ids[0], ids[1]], 0);
    var changes = 0;
    final sub = handler.queueChanges.listen((_) => changes++);
    handler.insertAt(1, id);
    await settle();
    expect(handler.queueIds, [ids[0], id, ids[1]]);
    await handler.removeQueueId(id);
    await settle();
    expect(handler.queueIds, [ids[0], ids[1]]);
    expect(changes, 2);
    expect(handler.sourceIds, [ids[0], ids[1]]);
    await sub.cancel();
  });
}

import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart' show trackRepositoryProvider;
import 'package:codecore/providers/jam_local_queue.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/library_providers.dart' show libraryQueriesProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/services/audio/audio_backend.dart' show BackendState;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/playback_persistence.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

class _Jam extends JamController {
  @override
  JamUiState build() {
    super.build();
    return const JamUiState();
  }
}

/// Counts the writes of the copy kept aside (D-341).
class _CountingPersistence extends PlaybackPersistence {
  _CountingPersistence(super.handler, super.store);
  int keeps = 0;

  @override
  Future<void> keepAside(SavedPlayback q, {required bool plus}) {
    keeps++;
    return super.keepAside(q, plus: plus);
  }
}

final _refProvider = Provider<Ref>((ref) => ref);

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
}

/// What the user finds after the Jam (D-341, D-342): the queue, the shuffle mode, the disk.
void main() {
  late FakeBackend backend;
  late CodecoreAudioHandler handler;
  late AppDatabase db;
  late SettingsStore store;
  late ProviderContainer c;
  late List<int> ids;
  late List<int> before;
  late _CountingPersistence persistence;

  CodecoreAudioHandler newHandler() => CodecoreAudioHandler(
      backend, PlayQueue(), TrackRepository(db), onError: (_) {});

  ShuffleMode mode() => c.read(shuffleModeProvider);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SettingsStore(await SharedPreferences.getInstance());
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    backend = FakeBackend();
    handler = newHandler();
    addTearDown(handler.dispose);
    ids = [
      for (var i = 0; i < 4; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
              path: '/m/t$i.mp3',
              title: 'Song $i',
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: i,
              durationMs: const Value(190000),
            )),
    ];
    persistence = _CountingPersistence(handler, store);
    c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      shareHubProvider.overrideWith(_Hub.new),
      jamProvider.overrideWith(_Jam.new),
      libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      audioHandlerProvider.overrideWithValue(handler),
      playbackPersistenceProvider.overrideWithValue(persistence),
      jamCacheDirProvider.overrideWith((ref) => Directory.systemTemp.createTemp('jam_exit')),
      jamBackendFactoryProvider.overrideWithValue(FakeBackend.new),
    ]);
    addTearDown(c.dispose);
    c.read(jamProvider);
    c.read(shufflePlusConfigProvider); // the listener that drops «+» when shuffle goes off
    c.listen(shuffleModeProvider, (_, _) {}); // as the shell does
  });

  /// The player in [m], paused on track 1 of 3 at 1:00, as the app leaves it.
  Future<void> startIn(ShuffleMode m) async {
    handler.setShuffleAndRepeat(shuffle: m != ShuffleMode.off, repeat: PlayRepeat.off);
    c.read(settingsProvider.notifier).update((s) => s.copyWith(shufflePlus: m == ShuffleMode.plus));
    await handler.restore(ids.take(3).toList(), 1, const Duration(minutes: 1));
    await c.read(playbackPersistenceProvider)!.flush();
    await pumpEventQueue();
    before = List.of(handler.queueIds);
    expect(mode(), m);
  }

  const jamState = JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h');

  JamState together(List<JamItem> items, int cur) => JamState(
      version: 2,
      hostDeviceId: 'h',
      outputDeviceId: 'h',
      mode: JamMode.together,
      items: items,
      currentIndex: cur);

  JamItem mine(int id) => JamItem(
      id: id, ownerDeviceId: '', title: 't$id', ext: 'mp3', ref: '${ids[id]}', partKey: '${ids[id]}');

  const other = JamItem(id: 9, ownerDeviceId: 'h', title: 'cur', ext: 'mp3');

  for (final m in ShuffleMode.values) {
    test('${m.name} before the Jam is ${m.name} after «Esci»', () async {
      await startIn(m);
      final jam = c.read(jamProvider.notifier);
      await jam.debugBegin(JamRole.guest, jamState);
      await handler.playQueue([ids[3]], 0);
      await pumpEventQueue();
      await jam.end();
      await pumpEventQueue();
      expect(mode(), m);
      expect(handler.queueIds, before);
      expect(handler.currentIndex, 1);
    });

    test('${m.name} before the Jam is ${m.name} after «Termina»', () async {
      await startIn(m);
      final jam = c.read(jamProvider.notifier);
      await jam.debugBegin(JamRole.host, jamState);
      await pumpEventQueue();
      await jam.debugFinish();
      await pumpEventQueue();
      expect(mode(), m);
    });
  }

  test('a guest who leaves finds the block\'s tracks in the same order, as normal entries', () async {
    await startIn(ShuffleMode.off);
    handler.addToQueue(ids[3]);
    handler.addToQueue(ids[0]);
    await c.read(playbackPersistenceProvider)!.flush();
    before = List.of(handler.queueIds);
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, jamState);
    await handler.playQueue([ids[2]], 0);
    await pumpEventQueue();
    await jam.end();
    await pumpEventQueue();
    expect(handler.queueIds, before);
    expect(handler.userAhead, 0);
  });

  Future<CodecoreAudioHandler> reopen() async {
    backend = FakeBackend();
    handler = newHandler();
    addTearDown(handler.dispose);
    return handler;
  }

  test('the app closed in «Coda dell\'host» reopens on the queue and mode «Esci» would give', () async {
    await startIn(ShuffleMode.plus);
    await c.read(jamProvider.notifier).debugBegin(JamRole.guest, jamState);
    await handler.playQueue([ids[3]], 0);
    await pumpEventQueue(); // the Jam's own player state drops «+» from the settings
    final h = await reopen();
    bool? plus;
    await PlaybackPersistence(h, store).restore(applyPlus: (on) => plus = on);
    expect(h.queueIds, before);
    expect(h.currentIndex, 1);
    expect(h.shuffleEnabled, true);
    expect(plus, true);
    expect(backend.seeks.last, const Duration(minutes: 1));
  });

  test('the app closed in «Coda insieme» reopens on the part not yet played', () async {
    await startIn(ShuffleMode.plus);
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, together([other, mine(1)], 0));
    await handler.playQueue([ids[3]], 0);
    await pumpEventQueue();
    // The part changes meanwhile: our track 1 was played, the Jam moves on.
    jam.debugState(together([other, mine(1)], 1));
    final h = await reopen();
    bool? plus;
    await PlaybackPersistence(h, store).restore(applyPlus: (on) => plus = on);
    expect(h.queueIds, [ids[2], ids[0]]);
    expect(h.currentIndex, 0);
    expect(h.shuffleEnabled, true);
    expect(plus, true);
    expect(store.readPlayback().queueIds, [ids[2], ids[0]]);
  });

  test('no saved copy is left after the exit, or after the reopening', () async {
    await startIn(ShuffleMode.shuffle);
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, jamState);
    expect(store.readJamAside(), isNotNull);
    await jam.end();
    expect(store.readJamAside(), isNull);

    await jam.debugBegin(JamRole.guest, jamState);
    final h = await reopen();
    var seenInside = false;
    await PlaybackPersistence(h, store).restore(applyPlus: (_) {
      // Queue back and flushed, copy still there: a kill now finds it again.
      seenInside = store.readJamAside() != null && store.readPlayback().queueIds.isNotEmpty;
    });
    expect(seenInside, true);
    expect(store.readJamAside(), isNull);
  });

  test('a copy is dropped even when applying it fails: no loop on a bad copy', () async {
    await store.writeJamAside(SavedPlayback(queueIds: ids.take(2).toList()), plus: true);
    final h = await reopen();
    await expectLater(
        PlaybackPersistence(h, store).restore(applyPlus: (_) => throw StateError('boom')),
        throwsStateError);
    expect(store.readJamAside(), isNull);
  });

  test('a host copy (no queue) keeps the saved queue and brings back its mode', () async {
    await store.writePlayback(SavedPlayback(
        queueIds: ids.take(3).toList(), index: 1, positionMs: 5000));
    await store.writeJamAside(const SavedPlayback(shuffle: true), plus: true);
    final h = await reopen();
    bool? plus;
    await PlaybackPersistence(h, store).restore(applyPlus: (on) => plus = on);
    expect(h.queueIds, ids.take(3));
    expect(h.currentIndex, 1);
    expect(h.shuffleEnabled, true);
    expect(plus, true);
  });

  test('a position exactly at the end of the track is not saved either', () async {
    await startIn(ShuffleMode.off);
    backend.posC.add(const Duration(milliseconds: 190000));
    backend.stateC.add(BackendState.paused);
    await pumpEventQueue();
    expect(handler.playbackState.value.position, const Duration(milliseconds: 190000));
    await c.read(jamProvider.notifier).debugBegin(JamRole.guest, jamState);
    expect(store.readPlayback().positionMs, 0);
  });

  test('a position exactly at the end of the track is not restored', () async {
    await handler.restore([ids[0]], 0, const Duration(milliseconds: 190000));
    expect(backend.seeks, isEmpty);
  });

  test('a position past the end of the track is not saved either', () async {
    await startIn(ShuffleMode.off);
    backend.posC.add(const Duration(minutes: 4, seconds: 7)); // a stale, extrapolated position
    backend.stateC.add(BackendState.paused);
    await pumpEventQueue();
    expect(handler.playbackState.value.position, const Duration(minutes: 4, seconds: 7));
    await c.read(jamProvider.notifier).debugBegin(JamRole.guest, jamState);
    expect(store.readPlayback().positionMs, 0);
    expect(store.readJamAside()!.queue.positionMs, 0);
  });

  test('a position past the end of the track is not restored', () async {
    await handler.restore([ids[0]], 0, const Duration(minutes: 4, seconds: 7));
    expect(backend.seeks.where((d) => d > const Duration(milliseconds: 190000)), isEmpty);
    expect(handler.playbackState.value.position, Duration.zero);
  });

  test('after a guest Jam, a host Jam gives back the host\'s own queue, not the guest\'s old one', () async {
    await startIn(ShuffleMode.off);
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, jamState);
    await jam.end();
    await pumpEventQueue();
    expect(handler.queueIds, before);
    jam.reset();
    await handler.playQueue([ids[3]], 0); // what the user plays between the two Jams
    await pumpEventQueue();
    await jam.debugBegin(JamRole.host, jamState);
    await pumpEventQueue();
    await jam.debugFinish();
    await pumpEventQueue();
    expect(handler.queueIds, [ids[3]]);
  });

  test('restoring twice puts the queue back only once', () async {
    await startIn(ShuffleMode.shuffle);
    final local = JamLocalQueue(() => c.read(_refProvider), () => const []);
    await local.save();
    await local.restore();
    handler.setShuffleAndRepeat(shuffle: false, repeat: PlayRepeat.off); // the user changes it
    await local.restore();
    expect(handler.shuffleEnabled, false, reason: 'the second restore must do nothing');
  });

  test('the same part of ours seen twice is written aside once (D-341)', () async {
    await startIn(ShuffleMode.off);
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, together([other, mine(1)], 0));
    await pumpEventQueue();
    jam.debugState(together([other, mine(1)], 1)); // our part moved: one write
    await pumpEventQueue();
    final after = persistence.keeps;
    jam.debugState(JamState(
        version: 3,
        hostDeviceId: 'h',
        outputDeviceId: 'h',
        mode: JamMode.together,
        items: [other, mine(1)],
        currentIndex: 1)); // same part, new version: no write
    await pumpEventQueue();
    expect(persistence.keeps, after);
  });

  test('a late state after «Esci» does not overwrite the Jam', () async {
    await startIn(ShuffleMode.off);
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, together([other, mine(1)], 0));
    jam.debugState(together([other, mine(1)], 0));
    final shown = c.read(jamProvider).jam;
    final ending = jam.end(); // the exit part is worked out before its first await
    jam.debugState(together([other], 0)); // late, without our tracks
    expect(identical(c.read(jamProvider).jam, shown), isTrue);
    await ending;
  });
}

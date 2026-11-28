import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart' show ShuffleMode, libraryListKey, listKeyOf, listShuffleProvider;
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/plus_allowed.dart' show ShufflePlusBlock;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/playback_persistence.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

/// Always picks the last candidate, so the start track is predictable.
class _LastPick implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

final _refProvider = Provider<Ref>((ref) => ref);

class _ThrowingRepo extends TrackRepository {
  _ThrowingRepo(super.db);
  @override
  Future<List<Track>> getByIdsLight(List<int> ids) => throw StateError('db down');
}

void main() {
  late AppDatabase db;
  late CodecoreAudioHandler handler;
  late List<Track> tracks;
  late bool plus;
  late PlayerController ctrl;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    for (final n in ['a', 'b', 'c']) {
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/m/$n.mp3',
              title: n,
              albumKey: 'k',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              durationMs: const Value(100000),
            ),
          );
    }
    tracks = await db.select(db.tracks).get();
    handler = CodecoreAudioHandler(
      FakeBackend(),
      PlayQueue(),
      TrackRepository(db),
      onError: (_) {},
    );
    plus = true;
    ctrl = PlayerController(
      handler,
      null,
      shufflePlus: () => plus,
      setShufflePlus: (on) => plus = on,
      random: _LastPick(),
    );
  });
  tearDown(() async {
    await handler.dispose();
    await db.close();
  });

  test('the list shuffle button only toggles shuffle: no playback, Shuffle+ cleared on off', () async {
    await ctrl.toggleShuffle();
    expect(handler.shuffleEnabled, isTrue);
    expect(handler.isPlaying, isFalse);
    expect(handler.currentTrack, isNull);

    await ctrl.toggleShuffle();
    expect(handler.shuffleEnabled, isFalse);
    expect(handler.isPlaying, isFalse);
    expect(plus, isFalse);
  });

  test('playAll starts from a random track with shuffle on, from the first with it off', () async {
    await ctrl.playAll(tracks);
    await pumpEventQueue();
    expect(handler.currentTrack!.id, tracks.first.id);

    await ctrl.toggleShuffle();
    await ctrl.playAll(tracks);
    await pumpEventQueue();
    expect(handler.currentTrack!.id, tracks.last.id);
  });

  test('two fast shuffle taps run one after the other: shuffle, then Shuffle+, then off', () async {
    final gate = Completer<ShufflePlusBlock?>();
    final c = PlayerController(handler, null,
        shufflePlus: () => plus,
        setShufflePlus: (on) => plus = on,
        plusBlock: (_) => gate.future);
    plus = false;
    await c.toggleShuffle(); // shuffle on, Shuffle+ off
    final first = c.cycleShuffle();
    final second = c.cycleShuffle();
    gate.complete(null);
    await Future.wait([first, second]);
    expect(handler.shuffleEnabled, isFalse);
    expect(plus, isFalse);
  });

  test('a failing allowed-lookup still lets the cycle turn shuffle off', () async {
    final c = ProviderContainer(overrides: [
      audioHandlerProvider.overrideWithValue(handler),
      trackRepositoryProvider.overrideWithValue(_ThrowingRepo(db)),
    ]);
    addTearDown(c.dispose);
    final ctl = PlayerController(handler, null,
        shufflePlus: () => plus,
        setShufflePlus: (on) => plus = on,
        plusBlock: (ids) => plusAllowedNow(c.read(_refProvider), ids: ids));
    plus = false;
    await ctl.toggleShuffle(); // shuffle on
    await ctl.cycleShuffle(); // lookup throws -> treated as allowed: Shuffle+
    expect(plus, isTrue);
    await ctl.cycleShuffle();
    expect(handler.shuffleEnabled, isFalse);
  });

  test('the radio context blocks the radio queue, not a list of its own', () async {
    final c = ProviderContainer(overrides: [
      audioHandlerProvider.overrideWithValue(handler),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
    ]);
    addTearDown(c.dispose);
    handler.setPlayContext(PlayContextKind.radio.index, null);
    final ref = c.read(_refProvider);
    expect(await plusAllowedNow(ref), ShufflePlusBlock.radio);
    expect(await plusAllowedNow(ref, ids: const []), isNull);
  });

  test('saved stream rows count as library songs for Shuffle+', () async {
    final repo = TrackRepository(db);
    final ids = <int>[];
    for (var i = 0; i < 5; i++) {
      const r = YtResult(id: 'x', title: 'S', channel: 'C', duration: Duration(seconds: 9));
      final id = await repo.upsertStreamRow('youtube:s$i', r, File('/nowhere'));
      ids.add(id);
    }
    final c = ProviderContainer(overrides: [
      audioHandlerProvider.overrideWithValue(handler),
      trackRepositoryProvider.overrideWithValue(repo),
    ]);
    addTearDown(c.dispose);
    final ref = c.read(_refProvider);
    expect(await plusAllowedNow(ref, ids: ids), ShufflePlusBlock.shortList);
    for (var i = 0; i < 5; i++) {
      await repo.setSaved('youtube:s$i', true);
    }
    expect(await plusAllowedNow(ref, ids: ids), isNull);
  });

  group('a list page\'s «Casuale» (D-534)', () {
    late Map<Object, ShuffleMode> modes;
    late PlayerController lists;
    setUp(() {
      modes = {};
      lists = PlayerController(
        handler,
        null,
        shufflePlus: () => plus,
        setShufflePlus: (on) => plus = on,
        listMode: (k) => modes[k] ?? ShuffleMode.off,
        setListMode: (k, m) => modes[k] = m,
        random: _LastPick(),
      );
    });

    test('on a list that is not playing it only changes the list\'s mode', () async {
      await lists.playAll(tracks); // another list plays, shuffle off
      await pumpEventQueue();
      expect(await lists.cycleListShuffle('k'), isNull);
      expect(modes['k'], ShuffleMode.shuffle);
      await lists.cycleListShuffle('k');
      expect(modes['k'], ShuffleMode.plus);
      await lists.cycleListShuffle('k');
      expect(modes['k'], ShuffleMode.off);
      expect(handler.shuffleEnabled, isFalse);
      expect(plus, isTrue, reason: 'the stored Shuffle+ of the queue is untouched');
      expect(handler.queueIds, [for (final t in tracks) t.id]);
    });

    test('on the list that is playing it changes the real queue', () async {
      await lists.playAll(tracks, listKey: 'k');
      await pumpEventQueue();
      expect(lists.isPlayingList('k'), isTrue);
      await lists.cycleListShuffle('k');
      expect(handler.shuffleEnabled, isTrue);
      expect(modes['k'], ShuffleMode.shuffle, reason: 'stored = what is applied');
    });

    test('toggling the playing list, then Play on it, keeps the mode (no stale restart)', () async {
      await lists.playAll(tracks, listKey: 'k'); // in order
      await pumpEventQueue();
      await lists.cycleListShuffle('k'); // real shuffle on
      await lists.playAll(tracks, listKey: 'k');
      await pumpEventQueue();
      expect(handler.shuffleEnabled, isTrue);
      expect(handler.currentTrack!.id, tracks.last.id, reason: 'random start, not in order');
    });

    test('after another list starts, the first list\'s stored mode is what was really applied', () async {
      await lists.playAll(tracks, listKey: 'a');
      await pumpEventQueue();
      await lists.cycleListShuffle('a'); // shuffle on
      await lists.cycleListShuffle('a'); // Shuffle+
      await lists.playAll(tracks.take(2).toList(), listKey: 'b'); // b: off
      await pumpEventQueue();
      expect(handler.shuffleEnabled, isFalse);
      expect(modes['a'], ShuffleMode.plus);
    });

    test('two quick taps on a non-playing list read one after the other', () async {
      final a = lists.cycleListShuffle('k');
      final b = lists.cycleListShuffle('k');
      await Future.wait([a, b]);
      expect(modes['k'], ShuffleMode.plus);
    });

    test('a row tap on a list also makes it the playing one (ids as key)', () async {
      final ids = [for (final t in tracks) t.id];
      await lists.playFromList(tracks, 1);
      await pumpEventQueue();
      expect(lists.isPlayingList(listKeyOf(ids)), isTrue);
      expect(lists.isPlayingList(listKeyOf(ids.reversed.toList())), isFalse);
    });

    test('Play applies the list\'s mode: in order, shuffle, Shuffle+', () async {
      await lists.playAll(tracks, listKey: 'k');
      await pumpEventQueue();
      expect(handler.currentTrack!.id, tracks.first.id);
      expect(handler.shuffleEnabled, isFalse);

      modes['k'] = ShuffleMode.shuffle;
      plus = true;
      await lists.playAll(tracks.take(2).toList(), listKey: 'other');
      await lists.playAll(tracks, listKey: 'k');
      await pumpEventQueue();
      expect(handler.currentTrack!.id, tracks.last.id, reason: 'random start');
      expect(handler.shuffleEnabled, isTrue);
      expect(plus, isFalse);

      modes['k'] = ShuffleMode.plus;
      await lists.playAll(tracks.take(2).toList(), listKey: 'other');
      await lists.playAll(tracks, listKey: 'k');
      expect(handler.shuffleEnabled, isTrue);
      expect(plus, isTrue);

      modes['k'] = ShuffleMode.off;
      await lists.playAll(tracks.take(2).toList(), listKey: 'other');
      await lists.playAll(tracks, listKey: 'k');
      expect(handler.shuffleEnabled, isFalse);
    });

    // The «Casuale» of any list (not the library, not a playlist): the cycle of today.
    Future<List<ShuffleMode>> table(PlayerController c, Object key, int taps, {List<int>? ids}) async {
      final out = <ShuffleMode>[];
      for (var i = 0; i < taps; i++) {
        await c.cycleListShuffle(key, ids: ids);
        out.add(modes[key]!);
      }
      return out;
    }

    test('table, list playing: off → Casuale → Casuale+ → off, the real queue follows each step', () async {
      plus = false;
      await lists.playAll(tracks, listKey: 'k');
      await pumpEventQueue();
      final seen = <(ShuffleMode, bool, bool)>[];
      for (var i = 0; i < 3; i++) {
        await lists.cycleListShuffle('k');
        seen.add((modes['k']!, handler.shuffleEnabled, plus));
      }
      expect(seen, [
        (ShuffleMode.shuffle, true, false),
        (ShuffleMode.plus, true, true),
        (ShuffleMode.off, false, false),
      ]);
    });

    test('table, Shuffle+ blocked: off → Casuale → off with the reason, playing or not', () async {
      final blocked = PlayerController(
        handler,
        null,
        shufflePlus: () => plus,
        setShufflePlus: (on) => plus = on,
        listMode: (k) => modes[k] ?? ShuffleMode.off,
        setListMode: (k, m) => modes[k] = m,
        plusBlock: (_) async => ShufflePlusBlock.shortList,
        random: _LastPick(),
      );
      plus = false;
      // Not playing: only the stored mode moves, the reason comes with the step to off.
      expect(await blocked.cycleListShuffle('n'), isNull);
      expect(modes['n'], ShuffleMode.shuffle);
      expect(await blocked.cycleListShuffle('n'), ShufflePlusBlock.shortList);
      expect(modes['n'], ShuffleMode.off);
      expect(await blocked.cycleListShuffle('n'), isNull);
      expect(modes['n'], ShuffleMode.shuffle);
      // Playing: the real queue goes the same way.
      await blocked.playAll(tracks, listKey: 'p');
      await pumpEventQueue();
      expect(await blocked.cycleListShuffle('p'), isNull);
      expect((modes['p'], handler.shuffleEnabled), (ShuffleMode.shuffle, true));
      expect(await blocked.cycleListShuffle('p'), ShufflePlusBlock.shortList);
      expect((modes['p'], handler.shuffleEnabled, plus), (ShuffleMode.off, false, false));
    });

    test('table, not playing and allowed: off → Casuale → Casuale+ → off, in a row', () async {
      expect(await table(lists, 'z', 4), [ShuffleMode.shuffle, ShuffleMode.plus, ShuffleMode.off, ShuffleMode.shuffle]);
    });

    test('an online list (no Casuale+): off → Casuale → off, on the playing queue too', () async {
      plus = false;
      expect(await lists.cycleListShuffle('o', plus: false), isNull);
      expect(modes['o'], ShuffleMode.shuffle);
      expect(await lists.cycleListShuffle('o', plus: false), isNull);
      expect(modes['o'], ShuffleMode.off);
      await lists.playAll(tracks, listKey: 'o');
      await pumpEventQueue();
      await lists.cycleListShuffle('o', plus: false);
      expect((modes['o'], handler.shuffleEnabled), (ShuffleMode.shuffle, true));
      await lists.cycleListShuffle('o', plus: false);
      expect((modes['o'], handler.shuffleEnabled), (ShuffleMode.off, false));
    });
  });

  test('a replayed suggestion is logged once', () async {
    final log = SuggestionLog(file: () async => File('${Directory.systemTemp.path}/sl_unused.json'));
    final r = YtResult(id: 'v', title: 'T', channel: 'C', duration: null);
    log.addSuggestion(r, 'Seed');
    log.addSuggestion(r, 'Seed');
    expect(log.length, 1);
  });

  test('a list\'s «Casuale» lives in memory by listKeyOf and writes nothing to the settings', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
    ]);
    addTearDown(c.dispose);
    final key = listKeyOf([1, 2, 3]);
    expect(listKeyOf([1, 2, 3]), key);
    expect(listKeyOf([3, 2, 1]), isNot(key));
    expect(c.read(listShuffleProvider(key)), ShuffleMode.off);
    c.read(listShuffleProvider(key).notifier).set(ShuffleMode.plus);
    expect(c.read(listShuffleProvider(listKeyOf([1, 2, 3]))), ShuffleMode.plus);
    expect(c.read(listShuffleProvider(listKeyOf([3, 2, 1]))), ShuffleMode.off);
    await pumpEventQueue();
    expect(prefs.getKeys(), isEmpty);
    final other = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(SettingsStore(prefs)),
    ]);
    addTearDown(other.dispose);
    expect(other.read(listShuffleProvider(key)), ShuffleMode.off, reason: 'not saved');
  });

  group('the Home\'s list is never off (D-767)', () {
    late PlayerController home;
    ShufflePlusBlock? block;
    setUp(() {
      block = null;
      plus = false;
      home = PlayerController(
        handler,
        null,
        shufflePlus: () => plus,
        setShufflePlus: (on) => plus = on,
        // The provider's default: the Home's list starts on shuffle.
        listMode: (k) => k == libraryListKey ? ShuffleMode.shuffle : ShuffleMode.off,
        setListMode: (k, m) {},
        plusBlock: (_) async => block,
        random: _LastPick(),
      );
    });

    test('Play starts on shuffle; the player button goes Casuale <-> Casuale+', () async {
      await home.playAll(tracks, listKey: libraryListKey);
      await pumpEventQueue();
      expect(handler.shuffleEnabled, isTrue);
      expect(await home.cycleShuffle(), isNull);
      expect((handler.shuffleEnabled, plus), (true, true));
      expect(await home.cycleShuffle(), isNull);
      expect((handler.shuffleEnabled, plus), (true, false));
    });

    test('Shuffle+ blocked: stays on Casuale and the reason comes at every tap', () async {
      await home.playAll(tracks, listKey: libraryListKey);
      await pumpEventQueue();
      block = ShufflePlusBlock.jam;
      for (var i = 0; i < 2; i++) {
        expect(await home.cycleShuffle(), ShufflePlusBlock.jam);
        expect((handler.shuffleEnabled, plus), (true, false));
        expect(await home.cycleListShuffle(libraryListKey), ShufflePlusBlock.jam);
        expect(handler.shuffleEnabled, isTrue);
      }
    });

    test('not playing: the list cycles Casuale <-> Casuale+ and never off', () async {
      final modes = <ShuffleMode>[];
      final c = PlayerController(
        handler,
        null,
        shufflePlus: () => plus,
        setShufflePlus: (on) => plus = on,
        listMode: (k) => modes.isEmpty ? ShuffleMode.shuffle : modes.last,
        setListMode: (k, m) => modes.add(m),
      );
      await c.cycleListShuffle(libraryListKey);
      await c.cycleListShuffle(libraryListKey);
      expect(modes, [ShuffleMode.plus, ShuffleMode.shuffle]);
    });

    test('MPRIS Shuffle=false is refused on the Home queue, works on another one', () async {
      await home.playAll(tracks, listKey: libraryListKey);
      await pumpEventQueue();
      await home.setShuffleFromSystem(false);
      expect(handler.shuffleEnabled, isTrue);
      await home.setShuffleFromSystem(true);
      expect(handler.shuffleEnabled, isTrue);

      await home.playAll(tracks, listKey: 'k'); // a new queue removes the lock
      await pumpEventQueue();
      await home.setShuffleFromSystem(true);
      plus = true;
      await home.setShuffleFromSystem(false);
      expect((handler.shuffleEnabled, plus), (false, false));
      await home.setShuffleFromSystem(true);
      expect(handler.shuffleEnabled, isTrue);
    });

    test('the lock follows the restored key, not another restored queue', () async {
      handler.setShuffleAndRepeat(shuffle: true, repeat: PlayRepeat.off);
      await handler.restore([for (final t in tracks) t.id], 0, Duration.zero);
      expect(home.isPlayingList(libraryListKey), isFalse);
      await home.setShuffleFromSystem(false);
      expect(handler.shuffleEnabled, isFalse, reason: 'another list restored: not locked');

      handler.setShuffleAndRepeat(shuffle: true, repeat: PlayRepeat.off);
      home.restoreListKey(libraryListKey, handler.sourceIds!);
      expect(home.isPlayingList(libraryListKey), isTrue);
      await home.setShuffleFromSystem(false);
      expect(handler.shuffleEnabled, isTrue);
    });

    test('the Home lock survives resumeLastQueue, track removal and handler.restore', () async {
      await home.playAll(tracks, listKey: libraryListKey);
      await pumpEventQueue();
      Future<void> refused(String route) async {
        expect(home.isPlayingList(libraryListKey), isTrue, reason: route);
        await home.setShuffleFromSystem(false);
        expect(handler.shuffleEnabled, isTrue, reason: route);
      }

      await home.resumeLastQueue();
      await pumpEventQueue();
      await refused('resumeLastQueue');
      await handler.restore(handler.queueIds, 0, Duration.zero); // a Jam guest ends
      await refused('handler.restore');
      await handler.removeTracks({tracks.first.id});
      await refused('removeTracks');
    });

    test('a queue of other songs is not the Home\'s even with the key left over', () async {
      await home.playAll(tracks, listKey: libraryListKey);
      await pumpEventQueue();
      await handler.restore([-5, -6], 0, Duration.zero);
      expect(home.isPlayingList(libraryListKey), isFalse);
    });

    test('restoreListKey takes only the Home key for the queue that is really there', () async {
      final ids = [for (final t in tracks) t.id];
      await handler.restore(ids, 0, Duration.zero);
      home.restoreListKey('k', ids);
      expect(home.isPlayingList('k'), isFalse);
      home.restoreListKey(libraryListKey, [ids.first]); // the user started another meanwhile
      expect(home.isPlayingList(libraryListKey), isFalse);
      home.restoreListKey(libraryListKey, ids);
      expect(home.isPlayingList(libraryListKey), isTrue);
    });

    test('locked with Shuffle+ on, a turn-off request leaves Casuale', () async {
      await home.playAll(tracks, listKey: libraryListKey);
      await pumpEventQueue();
      await home.cycleShuffle(); // Casuale+
      expect((handler.shuffleEnabled, plus), (true, true));
      await home.setShuffleFromSystem(false);
      expect((handler.shuffleEnabled, plus), (true, false));
    });

    test('the saved list key follows the queue: written for the Home, cleared for another', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final saver = PlaybackPersistence(handler, SettingsStore(prefs));
      final c = PlayerController(
        handler,
        saver,
        shufflePlus: () => plus,
        setShufflePlus: (on) => plus = on,
        random: _LastPick(),
      );
      await c.playAll(tracks, listKey: libraryListKey);
      await pumpEventQueue();
      await saver.flush();
      expect(prefs.getString('lastListKey'), libraryListKey);
      await c.playAll(tracks, listKey: 'k');
      await pumpEventQueue();
      await saver.flush();
      expect(prefs.containsKey('lastListKey'), isFalse);
    });

    test('the Home\'s mode in ListShuffle: Casuale by default, off reads as Casuale', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(listShuffleProvider(libraryListKey)), ShuffleMode.shuffle);
      c.read(listShuffleProvider(libraryListKey).notifier).set(ShuffleMode.off);
      expect(c.read(listShuffleProvider(libraryListKey)), ShuffleMode.shuffle);
      expect(c.read(listShuffleProvider(listKeyOf([1]))), ShuffleMode.off);
    });
  });
}

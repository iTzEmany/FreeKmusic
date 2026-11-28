import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

void main() {
  late SharedPreferences prefs;
  ProviderContainer open() {
    final c = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(SettingsStore(prefs))],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  const normal = PlaylistShuffleKey(5);
  const smart = PlaylistShuffleKey(5, smart: true);

  test('a playlist mode survives a new container; a smart one is apart', () async {
    final c = open();
    expect(c.read(listShuffleProvider(normal)), ShuffleMode.off);
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.plus);
    c.read(listShuffleProvider(smart).notifier).set(ShuffleMode.shuffle);
    c.read(settingsProvider.notifier).flush(); // the save is debounced
    await Future<void>.delayed(const Duration(milliseconds: 50)); // the store writes key by key
    final c2 = open();
    expect(c2.read(listShuffleProvider(normal)), ShuffleMode.plus);
    expect(c2.read(listShuffleProvider(smart)), ShuffleMode.shuffle);
    expect(c2.read(settingsProvider).playlistShuffles, {'5': 'plus', 'smart:5': 'shuffle'});
  });

  test('the mode is by id: a sort change keeps it, off drops the entry, a new key equals the old', () {
    final c = open();
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.shuffle);
    c.read(settingsProvider.notifier).update((s) => s.copyWith(playlistSorts: {'5': 'title:asc'}));
    expect(c.read(listShuffleProvider(const PlaylistShuffleKey(5))), ShuffleMode.shuffle);
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.off);
    expect(c.read(settingsProvider).playlistShuffles, isEmpty);
  });

  test('a removed entry (playlist deleted) reads as off', () {
    final c = open();
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.plus);
    c.read(settingsProvider.notifier).update((s) => s.copyWith(playlistShuffles: {}));
    expect(c.read(listShuffleProvider(normal)), ShuffleMode.off);
  });

  test('other keys stay in memory and write nothing', () {
    final c = open();
    c.read(listShuffleProvider(listKeyOf(const [1, 2])).notifier).set(ShuffleMode.plus);
    expect(c.read(listShuffleProvider(listKeyOf(const [1, 2]))), ShuffleMode.plus);
    expect(c.read(settingsProvider).playlistShuffles, isEmpty);
  });

  test('the mode stays for the id when the track list changes (the key has no tracks in it)', () {
    final c = open();
    c.read(listShuffleProvider(normal).notifier).set(ShuffleMode.plus);
    // Add, remove or reorder only change the tracks; a sort change is covered above.
    expect(const PlaylistShuffleKey(5), normal);
    expect(c.read(listShuffleProvider(const PlaylistShuffleKey(5))), ShuffleMode.plus);
  });

  group('with a player', () {
    late AppDatabase db;
    late CodecoreAudioHandler handler;
    late List<Track> tracks;
    late ProviderContainer c;
    late PlayerController ctrl;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      for (final n in ['a', 'b', 'c']) {
        await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$n.mp3', title: n, albumKey: 'k', format: 'mp3',
          sizeBytes: 1, mtimeMs: 1, addedAt: 1, durationMs: const Value(100000),
        ));
      }
      tracks = await db.select(db.tracks).get();
      handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
      c = open();
      ctrl = PlayerController(
        handler, null,
        shufflePlus: () => false,
        setShufflePlus: (_) {},
        listMode: (k) => c.read(listShuffleProvider(k)),
        setListMode: (k, m) => c.read(listShuffleProvider(k).notifier).set(m),
      );
    });
    tearDown(() async {
      await handler.dispose();
      await db.close();
    });

    test('Play with the key, then the pill: it acts on the player and saves', () async {
      await ctrl.playAll(tracks, listKey: normal);
      await pumpEventQueue();
      expect(ctrl.isPlayingList(normal), isTrue);
      expect(ctrl.isPlayingList(smart), isFalse);
      await ctrl.cycleListShuffle(normal, ids: [for (final t in tracks) t.id], plus: false);
      expect(handler.shuffleEnabled, isTrue);
      expect(c.read(settingsProvider).playlistShuffles, {'5': 'shuffle'});
    });

    test('a row tap with the key makes the playlist the playing one too', () async {
      await ctrl.playFromList(tracks, 1, listKey: smart);
      await pumpEventQueue();
      expect(ctrl.isPlayingList(smart), isTrue);
      await ctrl.cycleListShuffle(smart, ids: [for (final t in tracks) t.id], plus: false);
      expect(handler.shuffleEnabled, isTrue);
      expect(c.read(settingsProvider).playlistShuffles, {'smart:5': 'shuffle'});
    });
  });
}

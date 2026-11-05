import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/plus_allowed.dart' show ShufflePlusBlock;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    c.read(playContextProvider.notifier).set(const PlayContext(PlayContextKind.radio));
    final ref = c.read(_refProvider);
    expect(await plusAllowedNow(ref), ShufflePlusBlock.radio);
    expect(await plusAllowedNow(ref, ids: const []), isNull);
  });

  test('a replayed suggestion is logged once', () async {
    final log = SuggestionLog(file: () async => File('${Directory.systemTemp.path}/sl_unused.json'));
    final r = YtResult(id: 'v', title: 'T', channel: 'C', duration: null);
    log.addSuggestion(r, 'Seed');
    log.addSuggestion(r, 'Seed');
    expect(log.length, 1);
  });
}

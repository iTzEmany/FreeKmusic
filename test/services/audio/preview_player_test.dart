import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/audio/audio_backend.dart';
import 'package:codecore/services/audio/preview_player.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';

Track track(int id, {int durationMs = 90000}) => Track(saved: false, coverSource: 0, 
      id: id,
      path: '/m/$id.mp3',
      title: 'T$id',
      albumKey: 'k',
      durationMs: durationMs,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false, kind: 0,
      addedAt: 1,
      playCount: 0,
    );

Future<void> pause(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late List<FakeBackend> made;
  late PreviewPlayer player;
  late List<PreviewState> seen;

  setUp(() {
    made = [];
    player = PreviewPlayer(
      () {
        final b = FakeBackend();
        made.add(b);
        return b;
      },
      length: const Duration(milliseconds: 160),
      fade: const Duration(milliseconds: 20),
      step: const Duration(milliseconds: 10),
    );
    seen = [];
    player.changes.listen(seen.add);
  });
  tearDown(() => player.dispose());

  test('starts a third of the way in, fading the sound up', () async {
    await player.start(track(7));
    await pause(5);
    final b = made.single;
    expect(b.loaded, ['/m/7.mp3']);
    expect(b.seeks.single, const Duration(seconds: 30));
    expect(b.playing, isTrue);
    expect(player.state.trackId, 7);
    expect(player.state.active, isTrue);
    expect(b.volumes.first, 0, reason: 'silent before the fade-in');
    await pause(40);
    expect(b.volumes, contains(1.0));
    expect(b.volumes.every((v) => v >= 0 && v <= 1), isTrue);
  });

  test('ends by itself after the length, fading out and releasing the player',
      () async {
    await player.start(track(1));
    await pause(300);
    final b = made.single;
    expect(player.state.active, isFalse);
    expect(seen.map((s) => s.active), [true, false]);
    expect(b.volumes.last, 0, reason: 'faded out');
    expect(b.stopCalls, greaterThan(0));
    expect(b.disposed, isTrue);
  });

  test('a new preview replaces the old one without announcing an ending',
      () async {
    await player.start(track(1));
    await player.start(track(2));
    await pause(5);
    expect(made, hasLength(2));
    expect(made.first.disposed, isTrue);
    expect(player.state.trackId, 2);
    expect(seen.map((s) => s.trackId), [1, 2],
        reason: 'never inactive in between');
  });

  test('stop() silences and ends it at once', () async {
    await player.start(track(3));
    await pause(5);
    await player.stop();
    expect(player.state.active, isFalse);
    expect(made.single.volumes.last, 0);
    expect(made.single.disposed, isTrue);
    await pause(250);
    expect(seen.where((s) => !s.active), hasLength(1),
        reason: 'the timer of the stopped preview does not fire again');
  });

  test('the track ending first ends the preview too', () async {
    await player.start(track(4, durationMs: 1000));
    made.single.stateC.add(BackendState.completed);
    await pause(20);
    expect(player.state.active, isFalse);
  });

  test('an unplayable file ends quietly', () async {
    final failing = PreviewPlayer(() {
      final b = FakeBackend()..failing.add('/m/9.mp3');
      return b;
    });
    addTearDown(failing.dispose);
    await failing.start(track(9));
    expect(failing.state.active, isFalse);
  });

  test('a track of unknown length starts from the beginning', () async {
    await player.start(track(5, durationMs: 0));
    expect(made.single.seeks, isEmpty);
  });
}

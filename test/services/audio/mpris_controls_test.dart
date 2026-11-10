import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/mpris_controls.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:dbus/dbus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_backend.dart';

/// Needs a session bus (a desktop session); skipped without one.
final _hasBus = Platform.isLinux && (Platform.environment['DBUS_SESSION_BUS_ADDRESS'] ?? '').isNotEmpty;

const _busName = 'org.mpris.MediaPlayer2.freekmusic';

/// Reads [read] until it gives [want] (the bus answers asynchronously), for at
/// most two seconds; the caller then checks the value.
Future<void> _until<T>(Future<T> Function() read, T want) async {
  final deadline = DateTime.now().add(const Duration(seconds: 2));
  while (await read() != want && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  test('on the real session bus: metadata, status and commands round-trip', () async {
    final client = DBusClient.session();
    addTearDown(client.close);
    if (await client.nameHasOwner(_busName)) {
      // A running FreeKmusic owns the name: the calls below would reach it (and
      // pause or skip its music) instead of the player under test.
      markTestSkipped('another FreeKmusic owns $_busName on this session bus');
      return;
    }

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TrackRepository(db);
    for (var i = 0; i < 2; i++) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/$i.mp3', title: 'Song $i', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1,
          artist: const Value('Band'), album: const Value('Alb'), durationMs: const Value(120000)));
    }
    final handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), repo, onError: (_) {});
    addTearDown(handler.dispose);
    final controls = MprisControls();
    await controls.attach(handler);
    addTearDown(controls.dispose);

    final player = DBusRemoteObject(client, name: _busName, path: DBusObjectPath('/org/mpris/MediaPlayer2'));
    Future<DBusValue> prop(String n) => player.getProperty('org.mpris.MediaPlayer2.Player', n);
    Future<String> status() async => (await prop('PlaybackStatus') as DBusString).value;

    expect(await status(), 'Stopped');
    await handler.playQueue([1, 2], 0);
    await _until(status, 'Playing');
    expect(await status(), 'Playing');
    final meta = (await prop('Metadata') as DBusDict).children;
    final byKey = {for (final e in meta.entries) (e.key as DBusString).value: (e.value as DBusVariant).value};
    expect((byKey['xesam:title'] as DBusString).value, 'Song 0');
    expect((byKey['mpris:length'] as DBusInt64).value, 120000000);

    await player.callMethod('org.mpris.MediaPlayer2.Player', 'Pause', [], replySignature: DBusSignature(''));
    await _until(status, 'Paused');
    expect(await status(), 'Paused');
    await player.callMethod('org.mpris.MediaPlayer2.Player', 'Next', [], replySignature: DBusSignature(''));
    await _until(() async => handler.currentTrack?.title, 'Song 1');
    expect(handler.currentTrack!.title, 'Song 1');
    // Volume, Shuffle and LoopStatus are read/write.
    const pl = 'org.mpris.MediaPlayer2.Player';
    await player.setProperty(pl, 'Volume', DBusDouble(0.4));
    await _until(() async => handler.volume, 0.4);
    expect(handler.volume, 0.4);
    expect((await prop('Volume') as DBusDouble).value, 0.4);
    await player.setProperty(pl, 'Shuffle', const DBusBoolean(true));
    await _until(() async => handler.shuffleEnabled, true);
    expect((await prop('Shuffle') as DBusBoolean).value, isTrue);
    await player.setProperty(pl, 'LoopStatus', const DBusString('Track'));
    await _until(() async => handler.repeatMode, PlayRepeat.one);
    expect((await prop('LoopStatus') as DBusString).value, 'Track');
    expect((await player.getProperty('org.mpris.MediaPlayer2', 'Identity') as DBusString).value, 'FreeKmusic');
  }, skip: _hasBus ? false : 'no D-Bus session bus');
}

import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart' show trackRepositoryProvider;
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/library_providers.dart' show libraryQueriesProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/share_providers.dart' show deviceNameProvider;
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/playback_persistence.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_guest.dart' show JamGuest, JamJoinOutcome;
import 'package:codecore/services/jam/speaker_jam.dart';
import 'package:codecore/services/share/discovery.dart' show Peer;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

final _host = JamHost(deviceId: 'me', deviceName: 'PC');

var _noHost = false;

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
  void setActive(bool v) => state = ShareHubState(active: v);
  @override
  JamHost? get jamHost => _noHost ? null : _host;
  @override
  String? get deviceId => 'me';
  @override
  int? get port => 4000;
  @override
  Future<void> holdJam({bool remote = false}) async {}
  @override
  Future<void> releaseJam({bool remote = false}) async {}
}

void main() {
  late ProviderContainer c;
  late CodecoreAudioHandler handler;
  late FakeBackend backend;
  late List<int> ids;
  late AppDatabase db;

  setUp(() async {
    _host.clearSession();
    _noHost = false;
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    backend = FakeBackend();
    handler = CodecoreAudioHandler(
        backend, PlayQueue(), TrackRepository(db), onError: (_) {});
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
            )),
    ];
    c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      deviceNameProvider.overrideWithValue('Salotto'),
      shareHubProvider.overrideWith(_Hub.new),
      libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      audioHandlerProvider.overrideWithValue(handler),
      playbackPersistenceProvider.overrideWithValue(PlaybackPersistence(handler, store)),
      jamCacheDirProvider.overrideWith((ref) async => Directory.systemTemp.createTemp('jam_spk')),
      jamBackendFactoryProvider.overrideWithValue(FakeBackend.new),
    ]);
    addTearDown(c.dispose);
  });

  test('from idle it only waits: name announced, nothing else changes', () async {
    final jam = c.read(jamProvider.notifier);
    await jam.openSpeakerJam();
    expect(c.read(jamProvider).phase, JamPhase.idle);
    expect(_host.state, isNull);
    expect(c.read(shareHubProvider.notifier).speakerJamName, 'Salotto');
    final v = jam.speakerPort.view;
    expect((v.role, v.guests), (SpeakerRole.host, 0));

    await jam.closeSpeakerJamSilently();
    expect(c.read(shareHubProvider.notifier).speakerJamName, isNull);
    expect(jam.speakerPort.view.role, SpeakerRole.none);
  });

  test('openSpeakerJam is false with no hub Jam and true with one', () async {
    final jam = c.read(jamProvider.notifier);
    _noHost = true;
    expect(await jam.openSpeakerJam(), isFalse);
    _noHost = false;
    expect(await jam.openSpeakerJam(), isTrue);
  });

  test('the hub becoming active tells the speaker Jam to try opening again', () async {
    final jam = c.read(jamProvider.notifier);
    var n = 0;
    final sub = jam.speakerPort.changes.listen((_) => n++);
    addTearDown(sub.cancel);
    (c.read(shareHubProvider.notifier) as _Hub).setActive(true);
    await Future<void>.delayed(Duration.zero);
    expect(n, 1);
  });

  test('a request accepted while waiting starts the speaker Jam', () async {
    final jam = c.read(jamProvider.notifier);
    await jam.openSpeakerJam();
    final r = _host.requests.putIfAbsent(
        'r1', () => JamRequest(id: 'r1', fromId: 'g', fromName: 'Phone', fromHost: '192.168.1.5', fromPort: 4000, token: 't', receivedAt: DateTime.now()));
    await jam.acceptRequest(r);
    final s = c.read(jamProvider).jam!;
    expect(c.read(jamProvider).isHost, isTrue);
    expect(s.speaker, isTrue);
    expect(s.outputs, ['me']);
  });

  test('a running host Jam becomes the speaker one', () async {
    final jam = c.read(jamProvider.notifier);
    _host.open();
    await jam.debugBegin(JamRole.host, _host.state!);
    await jam.openSpeakerJam();
    expect(_host.state!.speaker, isTrue);
    expect(c.read(shareHubProvider.notifier).speakerJamName, 'Salotto');
  });

  test('«Continua sul telefono»: the speaker coming back does not turn the Jam into the speaker one', () async {
    final jam = c.read(jamProvider.notifier);
    _host.open();
    await jam.debugBegin(JamRole.host, _host.state!);
    await jam.openSpeakerJam();
    await jam.send(const JamCommand.speakerAway());
    expect(await jam.continueOnPhone(), isNull);
    expect(c.read(shareHubProvider.notifier).speakerJamName, isNull);
    expect(_host.state!.speaker, isFalse);
    await jam.openSpeakerJam();
    expect(_host.state!.speaker, isFalse);
  });

  test('joining another Jam gives up the waiting speaker Jam', () async {
    final jam = c.read(jamProvider.notifier);
    await jam.openSpeakerJam();
    await jam.request(const Peer(id: 'x', name: 'X', host: '10.0.0.9', port: 1, platform: 'linux'));
    expect(c.read(shareHubProvider.notifier).speakerJamName, isNull);
    expect(jam.speakerPort.view.role, isNot(SpeakerRole.host));
  });

  test('the speaker port throws when the command is refused', () async {
    final jam = c.read(jamProvider.notifier);
    await expectLater(jam.speakerPort.send(const JamCommand.speakerAway()), throwsStateError);
  });

  test('a guest does nothing', () async {
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, const JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h'));
    await jam.openSpeakerJam();
    expect(_host.state, isNull);
  });

  JamRequest req() => _host.requests.putIfAbsent(
      'r2',
      () => JamRequest(
          id: 'r2',
          fromId: 'g',
          fromName: 'Phone',
          fromHost: '192.168.1.5',
          fromPort: 4000,
          token: 't',
          receivedAt: DateTime.now()));

  test('waiting and closing leave the playing queue untouched', () async {
    await handler.playQueue(ids, 1);
    final seeks = backend.seeks.length;
    final jam = c.read(jamProvider.notifier);
    void expectUntouched() {
      expect(handler.queueIds, ids);
      expect(handler.currentIndex, 1);
      expect(handler.isPlaying, isTrue);
      expect(backend.seeks.length, seeks);
    }

    await jam.openSpeakerJam();
    expectUntouched();
    await jam.closeSpeakerJamSilently();
    expectUntouched();
  });

  test('the Jam is seeded with the queue at the moment of the request', () async {
    await handler.playQueue(ids.take(2).toList(), 0);
    final jam = c.read(jamProvider.notifier);
    await jam.openSpeakerJam();
    await handler.playQueue(ids, 2);
    await jam.acceptRequest(req());
    final titles = [for (final i in c.read(jamProvider).jam!.items) i.title];
    expect(titles, ['Song 2', 'Song 3', 'Song 0', 'Song 1']);
  });

  Future<List<int>> manyTracks(int n) async => [
        for (var i = 0; i < n; i++)
          await db.into(db.tracks).insert(TracksCompanion.insert(
                path: '/m/many$i.mp3',
                title: 'Many $i',
                albumKey: 'k',
                format: 'mp3',
                sizeBytes: 1,
                mtimeMs: 1,
                addedAt: 100 + i,
              )),
      ];

  test('«Continua sul telefono», the end, a new Jam: the speaker opens it again', () async {
    final jam = c.read(jamProvider.notifier);
    _host.open();
    await jam.debugBegin(JamRole.host, _host.state!);
    await jam.openSpeakerJam();
    await jam.send(const JamCommand.speakerAway());
    await jam.continueOnPhone();
    await jam.end();
    jam.reset();
    _host.open();
    await jam.debugBegin(JamRole.host, _host.state!);
    await jam.openSpeakerJam();
    expect(_host.state!.speaker, isTrue);
  });

  test('a full «Coda insieme» with the first track playing refuses and says so', () async {
    final jam = c.read(jamProvider.notifier);
    _host.open();
    await jam.debugBegin(JamRole.host, _host.state!);
    await jam.send(const JamCommand.setMode(JamMode.together));
    for (var i = 0; i < maxJamItems; i++) {
      await jam.send(JamCommand.add(JamItem(id: 0, ownerDeviceId: 'me', title: 't$i', ext: 'mp3')));
    }
    await Future<void>.delayed(Duration.zero);
    expect(jam.queueFull, isTrue);
    final tracks = await c.read(trackRepositoryProvider).getByIds(ids);
    expect(await jam.addTracks(tracks), (added: 0, full: true));
  });

  test('a guest that leaves is marked as left; a host that ends is not', () async {
    final jam = c.read(jamProvider.notifier);
    await jam.debugBegin(JamRole.guest, const JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h'));
    await jam.end();
    expect(c.read(jamProvider).left, isTrue);
    jam.reset();
    _host.open();
    await jam.debugBegin(JamRole.host, _host.state!);
    await jam.end();
    expect(c.read(jamProvider).phase, JamPhase.ended);
    expect(c.read(jamProvider).left, isFalse);
  });

  test('a guest whose link reports lost while leaving still reads «left», not «lost»', () async {
    final jam = c.read(jamProvider.notifier);
    jam.guestFactory = _LeavingGuest.new;
    const peer = Peer(id: 'x', name: 'X', host: '10.0.0.9', port: 1, platform: 'linux');
    await jam.request(peer);
    expect(c.read(jamProvider).phase, JamPhase.active);
    await jam.end();
    final s = c.read(jamProvider);
    expect((s.phase, s.left, s.lost), (JamPhase.ended, true, false));
  });

  test('a host that really disappears is «lost»', () async {
    final jam = c.read(jamProvider.notifier);
    jam.guestFactory = _LeavingGuest.new;
    const peer = Peer(id: 'x', name: 'X', host: '10.0.0.9', port: 1, platform: 'linux');
    await jam.request(peer);
    _LeavingGuest.last.emitLost();
    await Future<void>.delayed(Duration.zero);
    final s = c.read(jamProvider);
    expect((s.phase, s.left, s.lost), (JamPhase.ended, false, true));
  });

  test('a 300-track seed in «Coda insieme» puts 180 in the Jam, the rest stays in the part', () async {
    final many = await manyTracks(300);
    await handler.playQueue(many, 0);
    _host.open();
    _host.apply(const JamCommand.setMode(JamMode.together));
    final jam = c.read(jamProvider.notifier);
    await jam.openSpeakerJam();
    _host.requests['r3'] = JamRequest(
        id: 'r3', fromId: 'g3', fromName: 'Phone', fromHost: '192.168.1.6', fromPort: 4000, token: 't', receivedAt: DateTime.now());
    await jam.acceptRequest(_host.requests['r3']!);
    expect(_host.state!.items.length, maxJamItems - jamManualSeats);
    await jam.end(); // stops the feeder before the container goes
  });

  test('the third request within a minute is not sent; unreachable ones do not count', () async {
    final jam = c.read(jamProvider.notifier);
    var t = DateTime(2026, 1, 1, 12);
    jam.now = () => t;
    jam.guestFactory = _DecliningGuest.new;
    const peer = Peer(id: 'x', name: 'X', host: '10.0.0.9', port: 1, platform: 'linux');
    await jam.request(peer);
    await jam.request(peer);
    expect(c.read(jamProvider).outcome, JamJoinOutcome.declined);
    await jam.request(peer);
    expect(c.read(jamProvider).outcome, JamJoinOutcome.tooSoon);
    // another peer is not affected
    await jam.request(const Peer(id: 'y', name: 'Y', host: '10.0.0.8', port: 1, platform: 'linux'));
    expect(c.read(jamProvider).outcome, JamJoinOutcome.declined);
    t = t.add(const Duration(seconds: 61));
    await jam.request(peer);
    expect(c.read(jamProvider).outcome, JamJoinOutcome.declined);
  });

  test('requests to an unreachable device are not counted', () async {
    final jam = c.read(jamProvider.notifier);
    const peer = Peer(id: 'x', name: 'X', host: '10.0.0.9', port: 1, platform: 'linux');
    for (var i = 0; i < 4; i++) {
      await jam.request(peer);
      expect(c.read(jamProvider).outcome, JamJoinOutcome.unreachable);
    }
  });
}

class _DecliningGuest extends JamGuest {
  _DecliningGuest(JamHost h) : super(local: h);
  @override
  Future<JamJoinOutcome> join({
    required String host,
    required int port,
    required String ownDeviceId,
    required String ownName,
    required int ownPort,
    Duration timeout = const Duration(seconds: 1),
  }) async =>
      JamJoinOutcome.declined;
}

/// Joins at once; the host drops it during leave(), so the poll reports lost.
class _LeavingGuest extends JamGuest {
  _LeavingGuest(JamHost h) : super(local: h) {
    last = this;
  }
  static late _LeavingGuest last;
  final _lostC = StreamController<void>.broadcast();
  void emitLost() => _lostC.add(null);
  @override
  JamState? get state => const JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h');
  @override
  Stream<JamState> get states => const Stream.empty();
  @override
  Stream<void> get lost => _lostC.stream;
  @override
  Future<JamJoinOutcome> join({
    required String host,
    required int port,
    required String ownDeviceId,
    required String ownName,
    required int ownPort,
    Duration timeout = const Duration(seconds: 1),
  }) async =>
      JamJoinOutcome.accepted;
  @override
  Future<void> leave() async {
    emitLost();
    await Future<void>.delayed(Duration.zero);
  }
  @override
  Future<void> dispose() async {}
}

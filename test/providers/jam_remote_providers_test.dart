import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart' show trackRepositoryProvider;
import 'package:codecore/providers/jam_broker_providers.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/jam_remote_providers.dart';
import 'package:codecore/providers/library_providers.dart' show libraryQueriesProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/share_providers.dart' show deviceNameProvider;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/playback_persistence.dart';
import 'package:codecore/services/jam/jam_clock.dart';
import 'package:codecore/services/jam/jam_guest.dart' show JamJoinOutcome;
import 'package:codecore/services/jam/jam_guest_link.dart';
import 'package:codecore/services/jam/jam_host.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/remote/broker_entry.dart';
import 'package:codecore/services/jam/remote/jam_crypto.dart';
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/services/jam/remote/remote_jam_guest.dart';
import 'package:codecore/services/share/share_notifier.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../jam/remote/fakes.dart';
import '../support/fake_backend.dart';

final _host = JamHost(deviceId: 'me', deviceName: 'PC');

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
  @override
  JamHost? get jamHost => _host;
  @override
  String? get deviceId => 'me';
  @override
  int? get port => 4000;
  int held = 0, remoteHeld = 0;
  @override
  Future<void> holdJam({bool remote = false}) async {
    held++;
    if (remote) remoteHeld++;
  }

  @override
  Future<void> releaseJam({bool remote = false}) async {
    held--;
    if (remote) remoteHeld--;
  }
}

/// A remote guest that answers [outcome] without any network.
class _FakeGuest implements RemoteJamGuest {
  _FakeGuest(this.outcome);
  final JamJoinOutcome outcome;
  JamState _cur = const JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h');

  /// Pushes a newer state as soon as the controller listens, i.e. while it is still starting.
  late final StreamController<JamState> _ctl = StreamController<JamState>.broadcast(onListen: () => scheduleMicrotask(() {
        _cur = _cur.copyWith(version: 2);
        _ctl.add(_cur);
      }));
  @override
  JamState? get state => _cur;
  @override
  Stream<JamState> get states => _ctl.stream;
  @override
  Stream<void> get lost => const Stream.empty();
  @override
  Stream<JamLinkState> get links => const Stream.empty();
  @override
  JamLinkState get link => JamLinkState.ok;
  @override
  JamHostFiles? get files => null;
  @override
  Future<JamJoinOutcome> join(JamInvite invite, {required String ownDeviceId, required String ownName}) async =>
      outcome;
  @override
  Future<JamTimeSample?> probeHostTime(int Function() localNow) async => null;
  @override
  Future<void> dispose() async {}
  @override
  Future<void> leave() async {}
  @override
  void cancelJoin() {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Lets a test flip the remote-guest flag on a real controller.
class _MarkableJam extends JamController {
  void markRemote(bool v) => state = state.copyWith(remote: v);
}

class _ServiceHub extends ShareHubNotifier {
  Completer<void>? slowEnter;
  @override
  Future<void> enter() async => slowEnter?.future;
  @override
  Future<void> leave() async {}
}

class _Service extends NoopShareNotifier {
  final calls = <String>[];
  @override
  Future<void> startService({required String title, required String text, required String disable}) async =>
      calls.add('start:$title');
  @override
  Future<void> stopService() async => calls.add('stop');
}

void main() {
  late ProviderContainer c;
  late CodecoreAudioHandler handler;
  late AppDatabase db;
  late FakeNet net;
  late List<FakeMqttLink> links;
  late JamJoinOutcome guestOutcome;
  late SodiumJamCrypto crypto;
  late List<Uint8List> randoms;
  late Future<JamCrypto> Function() cryptoFor;

  setUp(() async {
    _host.clearSession();
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
    addTearDown(handler.dispose);
    // Keeps every random buffer: JamKey.dispose zeroes the one it adopted.
    randoms = [];
    final rng = Random();
    crypto = await SodiumJamCrypto.create(random: (n) {
      final b = Uint8List.fromList([for (var i = 0; i < n; i++) 1 + rng.nextInt(255)]);
      randoms.add(b);
      return b;
    });
    cryptoFor = () async => crypto;
    net = FakeNet(kDefaultJamBrokers);
    links = [];
    guestOutcome = JamJoinOutcome.declined;
    c = ProviderContainer(overrides: [
      jamProvider.overrideWith(_MarkableJam.new),
      settingsStoreProvider.overrideWithValue(store),
      deviceNameProvider.overrideWithValue('PC'),
      shareHubProvider.overrideWith(_Hub.new),
      libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      audioHandlerProvider.overrideWithValue(handler),
      playbackPersistenceProvider.overrideWithValue(PlaybackPersistence(handler, store)),
      jamCacheDirProvider.overrideWith((ref) async => Directory.systemTemp.createTemp('jam_rem')),
      jamBackendFactoryProvider.overrideWithValue(FakeBackend.new),
      jamStopGraceProvider.overrideWithValue(const Duration(milliseconds: 10)),
      jamCryptoProvider.overrideWith((_) => cryptoFor()),
      mqttLinkFactoryProvider.overrideWithValue(() => FakeMqttLink(net)..let(links.add)),
      remoteJamGuestFactoryProvider.overrideWithValue((_) => _FakeGuest(guestOutcome)),
    ]);
    addTearDown(c.dispose);
    c.read(jamBridgeProvider); // the shell does this through speakerJamProvider
  });

  /// The bridge says goodbye, then disconnects after its short grace.
  Future<void> graceOver() => Future<void>.delayed(const Duration(milliseconds: 60));

  bool connected() => links.any((l) => l.connectAttempts.isNotEmpty);

  test('a remote guest never asks an owner for a cover (no HTTP), a LAN device does', () async {
    final server = await HttpServer.bind('127.0.0.1', 0);
    addTearDown(() => server.close(force: true));
    var hits = 0;
    server.listen((r) {
      // The jam also fetches the item's meta on its own; count covers only.
      if (r.uri.pathSegments.contains('cover')) hits++;
      r.response.add([1, 2, 3]);
      r.response.close();
    });
    _host.open();
    final jam = c.read(jamProvider.notifier) as _MarkableJam;
    await jam.debugBegin(JamRole.host, _host.state!);
    const item = JamItem(id: 3, ownerDeviceId: 'x', title: 'T', ext: 'mp3', ref: '12');
    jam.debugState(_host.state!.copyWith(
      items: [item],
      participants: [
        const JamParticipant(id: 'me', name: 'PC'),
        JamParticipant(id: 'x', name: 'X', host: '127.0.0.1', port: server.port),
      ],
    ));
    jam.markRemote(true);
    expect(await jam.fetchCover(item), isNull);
    expect(hits, 0);
    jam.markRemote(false);
    expect(await jam.fetchCover(item), isNotNull);
    expect(hits, 1);
  });

  group('bridge', () {
    test('a normal LAN Jam opens no connection', () async {
      _host.open();
      await c.read(jamProvider.notifier).debugBegin(JamRole.host, _host.state!);
      await pumpEventQueue();
      expect(links, isEmpty);
      expect(c.read(jamBridgeProvider).on, isFalse);
    });

    test('«Invita chi è vicino» connects, and the end turns it off and drops the keys', () async {
      final jam = c.read(jamProvider.notifier);
      _host.open();
      await jam.debugBegin(JamRole.host, _host.state!);
      await jam.invite();
      await pumpEventQueue();
      final b = c.read(jamBridgeProvider.notifier);
      expect(connected(), isTrue);
      expect(c.read(jamBridgeProvider).on, isTrue);
      expect(b.currentQr(), isNotNull);
      expect(randoms.firstWhere((b) => b.length == 32).any((x) => x != 0), isTrue);

      await jam.end();
      await graceOver();
      expect(c.read(jamBridgeProvider).on, isFalse);
      expect(b.currentQr(), isNull);
      expect(links.single.connected, isFalse);
      expect(c.read(jamProvider).inviting, isFalse);
      // The host secret (the first 32 random bytes) was zeroed with the bridge.
      expect(randoms.firstWhere((b) => b.length == 32).every((x) => x == 0), isTrue);
    });

    test('the speaker Jam, also waiting, turns it on by itself and closing turns it off', () async {
      final jam = c.read(jamProvider.notifier);
      await jam.openSpeakerJam();
      await pumpEventQueue();
      expect(c.read(jamBridgeProvider).on, isTrue);
      expect(connected(), isTrue);

      await jam.closeSpeakerJamSilently();
      await graceOver();
      expect(c.read(jamBridgeProvider).on, isFalse);
      expect(links.single.connected, isFalse);
    });
  });


  group('bridge lifetime', () {
    _Hub hub() => c.read(shareHubProvider.notifier) as _Hub;
    JamRequest req() => _host.requests.putIfAbsent(
        'r1',
        () => JamRequest(
            id: 'r1', fromId: 'g', fromName: 'Phone', fromHost: '10.0.0.5', fromPort: 4000, token: 't', receivedAt: DateTime.now()));

    test('«Termina» with the speaker Jam waiting closes it, the bridge and the holds', () async {
      final jam = c.read(jamProvider.notifier);
      await jam.openSpeakerJam();
      await jam.invite();
      await pumpEventQueue();
      expect(c.read(jamBridgeProvider).on, isTrue);
      await jam.end();
      await graceOver();
      expect(c.read(jamBridgeProvider).on, isFalse);
      expect(c.read(jamProvider).inviting, isFalse);
      expect(jam.speakerJam, isFalse);
      expect(hub().held, 0);
    });

    test('accepting the first guest of the waiting speaker Jam keeps the bridge on', () async {
      final jam = c.read(jamProvider.notifier);
      await jam.openSpeakerJam();
      await pumpEventQueue();
      await jam.acceptRequest(req());
      await pumpEventQueue();
      expect(c.read(jamProvider).active, isTrue);
      expect(c.read(jamBridgeProvider).on, isTrue);
      expect(links.single.connected, isTrue);
    });

    test('«Continua sul telefono» does not switch the bridge off mid-Jam', () async {
      final jam = c.read(jamProvider.notifier);
      _host.open();
      await jam.debugBegin(JamRole.host, _host.state!);
      await jam.openSpeakerJam();
      jam.debugState(_host.state!); // what the host's change stream does
      await pumpEventQueue();
      expect(c.read(jamBridgeProvider).on, isTrue);
      await jam.send(const JamCommand.speakerAway());
      expect(await jam.continueOnPhone(), isNull);
      await graceOver();
      expect(c.read(jamBridgeProvider).on, isTrue);
      expect(links.single.connected, isTrue);
    });

    test('an invitation opened and closed while the speaker waits leaves no hold behind', () async {
      final jam = c.read(jamProvider.notifier);
      await jam.openSpeakerJam();
      await jam.invite();
      await jam.stopInviting();
      await jam.closeSpeakerJamSilently();
      await graceOver();
      expect(hub().held, 0);
    });

    test('the bridge failing to start is logged, not thrown', () async {
      cryptoFor = () async => throw StateError('no sodium');
      final jam = c.read(jamProvider.notifier);
      await jam.invite();
      await pumpEventQueue();
      expect(c.read(jamBridgeProvider).on, isFalse);
      expect(links, isEmpty);
    });
  });

  group('requestRemote', () {
    final invite = JamInvite.fromCode('ABCD-EFGH');

    test('a malformed code is refused without touching the network', () async {
      await c.read(jamProvider.notifier).requestRemote(JamInvite.fromCode('x'));
      expect(c.read(jamProvider).outcome, JamJoinOutcome.codeInvalid);
      expect(links, isEmpty);
    });

    test('the third request within a minute is too soon', () async {
      final jam = c.read(jamProvider.notifier);
      for (var i = 0; i < 2; i++) {
        await jam.requestRemote(invite);
        expect(c.read(jamProvider).outcome, JamJoinOutcome.declined);
      }
      await jam.requestRemote(invite);
      expect(c.read(jamProvider).outcome, JamJoinOutcome.tooSoon);
    });

    test('a crypto failure ends the request as unreachable and releases the hold', () async {
      cryptoFor = () async => throw StateError('no sodium');
      await c.read(jamProvider.notifier).requestRemote(invite);
      final s = c.read(jamProvider);
      expect((s.phase, s.outcome, s.remote), (JamPhase.idle, JamJoinOutcome.unreachable, false));
      expect((c.read(shareHubProvider.notifier) as _Hub).held, 0);
    });

    test('cancelling while the crypto loads stops the request', () async {
      final gate = Completer<JamCrypto>();
      cryptoFor = () => gate.future;
      guestOutcome = JamJoinOutcome.accepted;
      final jam = c.read(jamProvider.notifier);
      final done = jam.requestRemote(invite);
      await pumpEventQueue();
      jam.cancelRequest();
      gate.complete(crypto);
      await done;
      expect(c.read(jamProvider).phase, JamPhase.idle);
      expect((c.read(shareHubProvider.notifier) as _Hub).held, 0);
    });

    test('a request after an open invitation takes the remote hold', () async {
      guestOutcome = JamJoinOutcome.accepted;
      final jam = c.read(jamProvider.notifier);
      await jam.invite();
      await jam.requestRemote(invite);
      await graceOver();
      final hub = c.read(shareHubProvider.notifier) as _Hub;
      expect((hub.held, hub.remoteHeld), (1, 1));
    });

    test('a state that arrives while the Jam is starting is not lost', () async {
      guestOutcome = JamJoinOutcome.accepted;
      await c.read(jamProvider.notifier).requestRemote(invite);
      expect(c.read(jamProvider).jam!.version, 2);
    });

    test('accepted: the Jam is active and this device is a remote guest', () async {
      guestOutcome = JamJoinOutcome.accepted;
      final jam = c.read(jamProvider.notifier);
      await jam.requestRemote(invite);
      final s = c.read(jamProvider);
      expect((s.phase, s.role, s.remote), (JamPhase.active, JamRole.guest, true));
      expect(jam.debugFeeder, isNotNull); // a remote guest feeds its part as video ids (R-153)
      final hub = c.read(shareHubProvider.notifier) as _Hub;
      expect((hub.held, hub.remoteHeld), (1, 1));
      await jam.end();
      expect((hub.held, hub.remoteHeld), (0, 0));
    });
  });

  test('the service says «Jam a distanza» while a remote hold lasts and stops with the last release', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = _Service();
    final d = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(SettingsStore(await SharedPreferences.getInstance())),
      shareNotifierProvider.overrideWithValue(svc),
      shareHubProvider.overrideWith(_ServiceHub.new),
    ]);
    addTearDown(d.dispose);
    final hub = d.read(shareHubProvider.notifier);
    await hub.holdJam();
    await hub.holdJam(remote: true);
    await hub.releaseJam(remote: true);
    await hub.releaseJam();
    expect(svc.calls.last, 'stop');
    expect(svc.calls.where((x) => x == 'stop'), hasLength(1));
  });

  test('a release during a slow endpoint start does not bring the service back', () async {
    SharedPreferences.setMockInitialValues({});
    final svc = _Service();
    final d = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(SettingsStore(await SharedPreferences.getInstance())),
      shareNotifierProvider.overrideWithValue(svc),
      shareHubProvider.overrideWith(_ServiceHub.new),
    ]);
    addTearDown(d.dispose);
    final hub = d.read(shareHubProvider.notifier) as _ServiceHub;
    hub.slowEnter = Completer<void>();
    final held = hub.holdJam();
    await hub.releaseJam();
    hub.slowEnter!.complete();
    await held;
    expect(svc.calls, ['stop']);
  });
}

extension on FakeMqttLink {
  void let(void Function(FakeMqttLink) f) => f(this);
}

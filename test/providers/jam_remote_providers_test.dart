import 'dart:async';
import 'dart:io';

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
  final holds = <bool>[];
  @override
  Future<void> holdJam({bool remote = false}) async => holds.add(remote);
  @override
  Future<void> releaseJam({bool remote = false}) async => holds.add(!remote);
}

/// A remote guest that answers [outcome] without any network.
class _FakeGuest implements RemoteJamGuest {
  _FakeGuest(this.outcome);
  final JamJoinOutcome outcome;
  @override
  JamState? get state => const JamState(version: 1, hostDeviceId: 'h', outputDeviceId: 'h');
  @override
  Stream<JamState> get states => const Stream.empty();
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

class _ServiceHub extends ShareHubNotifier {
  @override
  Future<void> enter() async {}
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

  setUpAll(() async => crypto = await SodiumJamCrypto.create());

  setUp(() async {
    _host.clearSession();
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
    addTearDown(handler.dispose);
    net = FakeNet(kDefaultJamBrokers);
    links = [];
    guestOutcome = JamJoinOutcome.declined;
    c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      deviceNameProvider.overrideWithValue('PC'),
      shareHubProvider.overrideWith(_Hub.new),
      libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      audioHandlerProvider.overrideWithValue(handler),
      playbackPersistenceProvider.overrideWithValue(PlaybackPersistence(handler, store)),
      jamCacheDirProvider.overrideWith((ref) async => Directory.systemTemp.createTemp('jam_rem')),
      jamBackendFactoryProvider.overrideWithValue(FakeBackend.new),
      jamCryptoProvider.overrideWith((_) => crypto),
      mqttLinkFactoryProvider.overrideWithValue(() => FakeMqttLink(net)..let(links.add)),
      remoteJamGuestFactoryProvider.overrideWithValue((_) => _FakeGuest(guestOutcome)),
    ]);
    addTearDown(c.dispose);
    c.read(jamBridgeProvider); // the shell does this through speakerJamProvider
  });

  /// The bridge says goodbye, then disconnects after its short grace.
  Future<void> graceOver() => Future<void>.delayed(const Duration(milliseconds: 700));

  bool connected() => links.any((l) => l.connectAttempts.isNotEmpty);

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

      await jam.end();
      await graceOver();
      expect(c.read(jamBridgeProvider).on, isFalse);
      expect(b.currentQr(), isNull);
      expect(links.single.connected, isFalse);
      expect(c.read(jamProvider).inviting, isFalse);
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

    test('accepted: the Jam is active and this device is a remote guest', () async {
      guestOutcome = JamJoinOutcome.accepted;
      final jam = c.read(jamProvider.notifier);
      await jam.requestRemote(invite);
      final s = c.read(jamProvider);
      expect((s.phase, s.role, s.remote), (JamPhase.active, JamRole.guest, true));
      expect((c.read(shareHubProvider.notifier) as _Hub).holds, [true]); // held as remote
      await jam.end();
      expect((c.read(shareHubProvider.notifier) as _Hub).holds, [true, false]); // released as remote
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
    expect(svc.calls, ['start:La Jam è attiva', 'start:Jam a distanza attiva', 'start:La Jam è attiva', 'stop']);
  });
}

extension on FakeMqttLink {
  void let(void Function(FakeMqttLink) f) => f(this);
}

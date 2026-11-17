import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart' show trackRepositoryProvider;
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/library_providers.dart' show libraryQueriesProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/karaoke/karaoke_send_throttle.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_backend.dart';
import '../../support/fake_voice_filter.dart';

class _Jam extends JamController {
  @override
  JamUiState build() {
    super.build();
    return const JamUiState();
  }

  void markRemote() => state = state.copyWith(remote: true);
  void markInviting() => state = state.copyWith(inviting: true);
}

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
  @override
  String? get deviceId => 'me';
}

void main() {
  late ProviderContainer c;
  late _Jam jam;
  late FakeVoiceFilter filter;

  JamState state({double? karaoke, bool guests = false, String output = 'me', bool remoteGuest = false}) => JamState(
    version: 1,
    hostDeviceId: 'h',
    outputDeviceId: output,
    karaoke: karaoke,
    karaokeGuests: guests,
    participants: [
      const JamParticipant(id: 'h', name: 'Marco'),
      const JamParticipant(id: 'me', name: 'Io'),
      if (remoteGuest) const JamParticipant(id: 'r', name: 'Lontano', remote: true),
    ],
  );

  Future<void> setUpJam({bool withFilter = true}) async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final handler = CodecoreAudioHandler(FakeBackend(), PlayQueue(), TrackRepository(db), onError: (_) {});
    addTearDown(handler.dispose);
    filter = FakeVoiceFilter();
    c = ProviderContainer(overrides: [
      settingsStoreProvider.overrideWithValue(store),
      shareHubProvider.overrideWith(_Hub.new),
      jamProvider.overrideWith(_Jam.new),
      libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
      trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
      audioHandlerProvider.overrideWithValue(handler),
      jamCacheDirProvider.overrideWith((ref) => Directory.systemTemp.createTemp('jam_karaoke')),
      jamBackendFactoryProvider.overrideWithValue(() => FakeBackend()..voiceFilter = withFilter ? filter : null),
    ]);
    addTearDown(c.dispose);
    jam = c.read(jamProvider.notifier) as _Jam;
  }

  void setIgnore(bool v) =>
      c.read(settingsProvider.notifier).update((s) => s.copyWith(karaokeJamIgnore: v));

  test('in a Jam the level comes from the Jam state, not from the local setting', () async {
    await setUpJam();
    // The local karaoke is on at 90 %: the Jam does not read it.
    c.read(settingsProvider.notifier).update((s) => s.copyWith(karaokeOn: true, karaokeLevel: 0.9));
    await jam.debugBegin(JamRole.host, state(karaoke: 0.3));
    jam.debugState(state(karaoke: 0.55));
    jam.debugState(state());
    expect(filter.calls, [0.3, 0.55, null]);
    final k = c.read(settingsProvider);
    expect((k.karaokeOn, k.karaokeLevel), (true, 0.9));
  });

  test('«Ignora per me» in a remote Jam: no filter here, the Jam and the local karaoke stay', () async {
    await setUpJam();
    jam.markRemote();
    setIgnore(true);
    await jam.debugBegin(JamRole.guest, state(karaoke: 0.3));
    jam.debugState(state(karaoke: 0.4));
    expect(filter.calls, [null]);
    expect(c.read(jamProvider).jam?.karaoke, 0.4);
    expect(c.read(karaokeProvider).on, isFalse);
    // Back to listening with the filter, then out again.
    setIgnore(false);
    expect(filter.calls.last, 0.4);
    setIgnore(true);
    expect(filter.calls.last, isNull);
    expect(c.read(jamProvider).jam?.karaoke, 0.4);
  });

  test('the preference does not touch a local Jam: the karaoke is for everyone', () async {
    await setUpJam();
    setIgnore(true);
    await jam.debugBegin(JamRole.host, state(karaoke: 0.3));
    expect(filter.calls, [0.3]);
  });

  test('a device without a voice filter just plays', () async {
    await setUpJam(withFilter: false);
    await jam.debugBegin(JamRole.host, state(karaoke: 0.3));
    jam.debugState(state());
    expect(c.read(jamProvider).jam?.karaoke, isNull);
  });

  test('jamKaraokeProvider: guest rights, host name, who plays, and nothing outside a Jam', () async {
    await setUpJam();
    expect(c.read(jamKaraokeProvider), isNull);
    jam.markRemote();
    await jam.debugBegin(JamRole.guest, state(karaoke: 0.1));
    var k = c.read(jamKaraokeProvider)!;
    expect((k.level, k.hostName, k.canCommand, k.playsHere, k.canIgnore), (0.1, 'Marco', false, true, true));
    jam.debugState(state(karaoke: 0.1, guests: true));
    expect(c.read(jamKaraokeProvider)!.canCommand, isTrue);
    k = c.read(jamKaraokeProvider)!;
    expect(k.guestsAllowed, isTrue);
  });

  test('a remote guest is never an output: it still sees the Jam karaoke, but cannot ignore it', () async {
    await setUpJam();
    jam.markRemote();
    await jam.debugBegin(JamRole.guest, state(karaoke: 0.1, output: 'h'));
    final k = c.read(jamKaraokeProvider)!;
    expect((k.level, k.remote, k.playsHere, k.canIgnore), (0.1, true, false, false));
  });

  test('the inviting host and a LAN output of a Jam with remote guests are in a remote Jam', () async {
    await setUpJam();
    jam.markInviting();
    await jam.debugBegin(JamRole.host, state(karaoke: 0.1, output: 'h'));
    expect(c.read(jamKaraokeProvider)!.remote, isTrue);
    // Without a filter the host still has the mic: it commands the Jam.
    expect(c.read(karaokeButtonVisibleProvider), isTrue);
  });

  test('a LAN output in a Jam with remote guests can ignore the Jam karaoke', () async {
    await setUpJam();
    setIgnore(true);
    await jam.debugBegin(JamRole.guest, state(karaoke: 0.3, remoteGuest: true));
    final k = c.read(jamKaraokeProvider)!;
    expect((k.remote, k.playsHere, k.canIgnore), (true, true, true));
    expect(filter.calls, [null]);
  });

  test('a host without a filter in a Jam with no remote guests has no mic', () async {
    await setUpJam();
    await jam.debugBegin(JamRole.host, state(karaoke: 0.1));
    expect(c.read(karaokeButtonVisibleProvider), isFalse);
  });

  test('the drag sends the first level at once and then the last one every 250 ms', () async {
    final sent = <double?>[];
    final t = KaraokeSendThrottle(sent.add);
    t.add(0.1);
    t.add(0.2);
    t.add(0.3);
    expect(sent, [0.1]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(sent, [0.1, 0.3]);
    t.add(null); // inside the new window: waits, and flush sends it
    t.add(0.5);
    t.flush();
    expect(sent, [0.1, 0.3, 0.5]);
    t.flush(); // nothing left
    expect(sent.length, 3);
  });
}

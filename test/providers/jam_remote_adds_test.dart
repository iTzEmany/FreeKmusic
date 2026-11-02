import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart'
    show trackRepositoryProvider;
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/jam_remote_providers.dart';
import 'package:codecore/providers/library_providers.dart'
    show libraryQueriesProvider;
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/seed_resolver_provider.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/share_hub.dart';
import 'package:codecore/providers/share_providers.dart'
    show deviceNameProvider;
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/audio/playback_persistence.dart';
import 'package:codecore/services/jam/jam_clock.dart';
import 'package:codecore/services/jam/jam_guest.dart' show JamJoinOutcome;
import 'package:codecore/services/jam/jam_guest_link.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/jam/jam_state.dart';
import 'package:codecore/services/jam/remote/jam_invite.dart';
import 'package:codecore/services/jam/remote/remote_jam_guest.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

/// A remote guest whose host is the reducer: every command is applied and recorded.
class _HostedGuest implements RemoteJamGuest {
  final sent = <JamCommand>[];
  JamState _cur = const JamState(
    version: 1,
    hostDeviceId: 'h',
    outputDeviceId: 'h',
  );
  final _ctl = StreamController<JamState>.broadcast();
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
  Future<JamJoinOutcome> join(
    JamInvite invite, {
    required String ownDeviceId,
    required String ownName,
  }) async {
    _cur = _cur.copyWith(
      participants: [
        JamParticipant(id: ownDeviceId, name: ownName, remote: true),
      ],
    );
    return JamJoinOutcome.accepted;
  }

  @override
  Future<JamResult> send(JamCommand cmd) async {
    sent.add(cmd);
    final r = applyCommand(_cur, cmd, from: cmd.item!.ownerDeviceId, nowMs: 1);
    if (r.isOk) _cur = r.state!;
    return r;
  }

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

class _Hub extends ShareHubNotifier {
  @override
  ShareHubState build() => const ShareHubState();
  @override
  String? get deviceId => 'me';
  @override
  Future<void> holdJam({bool remote = false}) async {}
  @override
  Future<void> releaseJam({bool remote = false}) async {}
}

Track _track(String title) => Track(
  coverSource: 0,
  id: 1,
  path: '/m/1.mp3',
  title: title,
  artist: 'Nobody',
  albumKey: 'k',
  durationMs: 200000,
  format: 'mp3',
  sizeBytes: 1,
  mtimeMs: 1,
  hasCover: false,
  isFavorite: false,
  enrichStatus: 0,
  userEdited: false,
  missing: false,
  ignored: false,
  kind: 0,
  addedAt: 1,
  playCount: 0,
);

void main() {
  late ProviderContainer c;
  late _HostedGuest guest;
  late JamController jam;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final store = SettingsStore(await SharedPreferences.getInstance());
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final handler = CodecoreAudioHandler(
      FakeBackend(),
      PlayQueue(),
      TrackRepository(db),
      onError: (_) {},
    );
    addTearDown(handler.dispose);
    guest = _HostedGuest();
    c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        deviceNameProvider.overrideWithValue('PC'),
        shareHubProvider.overrideWith(_Hub.new),
        libraryQueriesProvider.overrideWithValue(LibraryQueries(db)),
        trackRepositoryProvider.overrideWithValue(TrackRepository(db)),
        audioHandlerProvider.overrideWithValue(handler),
        playbackPersistenceProvider.overrideWithValue(
          PlaybackPersistence(handler, store),
        ),
        jamCacheDirProvider.overrideWith(
          (ref) async => Directory.systemTemp.createTemp('jam_adds'),
        ),
        jamBackendFactoryProvider.overrideWithValue(FakeBackend.new),
        jamStopGraceProvider.overrideWithValue(Duration.zero),
        remoteJamGuestFactoryProvider.overrideWithValue((_) => guest),
        seedResolverProvider.overrideWith(
          (ref) async => SeedResolver(
            downloads: DownloadIndex(File('/nonexistent/dl.json')),
            index: SeedIndex(
              file: () async =>
                  File('${Directory.systemTemp.path}/seed_adds.json'),
            ),
            searchSongs: (q) async => q.contains('Time')
                ? const [
                    YtResult(
                        id: 'dQw4w9WgXcQ',
                        title: 'Time',
                        channel: 'Nobody',
                        artists: ['Nobody'],
                        duration: Duration(seconds: 200))
                  ]
                : const [],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    jam = c.read(jamProvider.notifier);
    await jam.requestRemote(JamInvite.fromCode('ABCD-EFGH'));
    expect(c.read(jamProvider).remote, true);
  });

  test(
    'a Ricerca online result reaches the host queue as a yt: item',
    () async {
      expect(
        jam.addOnline(
          const YtResult(
            id: 'dQw4w9WgXcQ',
            title: 'Time',
            channel: 'PF',
            duration: Duration(minutes: 3),
          ),
        ),
        true,
      );
      await pumpEventQueue();
      final i = guest.state!.items.single;
      expect(
        (i.ref, i.videoId, i.selfFetchable, i.sizeBytes),
        ('yt:youtube:dQw4w9WgXcQ', 'dQw4w9WgXcQ', true, 0),
      );
    },
  );

  test('a SoundCloud result is refused and not sent', () async {
    const sc = YtResult(
      id: '1',
      title: 'x',
      channel: 'c',
      duration: Duration.zero,
      source: MediaSource.soundcloud,
    );
    expect(jam.addOnline(sc), false);
    await pumpEventQueue();
    expect(guest.sent, isEmpty);
  });

  test(
    'a library track not found online sends no command and adds 0',
    () async {
      expect(await jam.addTracks([_track('Unknown')]), (added: 0, full: false));
      expect(guest.sent, isEmpty);
    },
  );

  test('a library track found online reaches the host as a yt: item', () async {
    expect(await jam.addTracks([_track('Time')]), (added: 1, full: false));
    expect(guest.state!.items.single.ref, 'yt:youtube:dQw4w9WgXcQ');
  });
}

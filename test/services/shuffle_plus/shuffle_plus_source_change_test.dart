import 'dart:async';

import '../../support/suggestion_gate_fake.dart';

import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_service.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/shuffle_host.dart';
import 'package:codecore/services/shuffle_plus/shuffle_plus_controller.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _Host implements ShuffleHost {
  _Host(this.queueIds, this.sourceIds);

  @override
  List<int> queueIds;
  @override
  List<int>? sourceIds;
  @override
  int currentIndex = 0;
  @override
  bool shuffleEnabled = true;
  @override
  bool isPlaying = true;
  @override
  int userAhead = 0;
  @override
  bool currentFromUser = false;
  final changesC = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get changes => changesC.stream;
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Stream<PlaybackFailure> get failures => const Stream.empty();
  @override
  void insertAt(int index, int id) => queueIds.insert(index, id);
  @override
  Future<void> removeQueueId(int id) async => queueIds.remove(id);
}

/// Radio answers wait on [gate] (once); every request is recorded.
class _Adapter implements HttpClientAdapter {
  Completer<void>? gate;

  /// Runs on the next request (once), before it answers; [clipJson] answers it.
  void Function()? onFetch;
  String? clipJson;
  final bodies = <String>[];
  final String json = File('test/fixtures/innertube/ytm_radio.json')
      .readAsStringSync();

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async {
    bodies.add(o.data.toString());
    final g = gate;
    gate = null;
    onFetch?.call();
    onFetch = null;
    if (g != null) await g.future;
    final answer = clipJson ?? json;
    clipJson = null;
    return ResponseBody.fromString(
      answer,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _NoMix implements YoutubeService {
  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async =>
      const PlaylistListing.empty();
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Track _track(int id) => Track(
  coverSource: 0,
  id: id,
  path: '/m/$id.mp3',
  title: 'Song $id',
  artist: 'Rock Band',
  genre: 'Rock',
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
  final oldList = [for (var i = 1; i <= 12; i++) i];
  final newList = [for (var i = 101; i <= 112; i++) i];
  late _Host host;
  late _Adapter adapter;
  late ShufflePlusController controller;
  var now = DateTime.utc(2026, 1, 1, 12);
  Future<void> Function() libraryHook = () async {};
  Future<void> Function() prepareHook = () async {};

  setUp(() async {
    final dir = Directory.systemTemp.createTempSync('shuffle_plus_src');
    addTearDown(() => dir.deleteSync(recursive: true));
    now = DateTime.utc(2026, 1, 1, 12);
    libraryHook = () async {};
    prepareHook = () async {};
    host = _Host([...oldList], [...oldList]);
    adapter = _Adapter();
    final downloads = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    for (final id in [...oldList, ...newList]) {
      await downloads.add('dl$id', '/m/$id.mp3');
    }
    final client = InnerTubeClient(
      Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = adapter,
    );
    controller = ShufflePlusController(
      host: host,
      online: OnlineEntries(),
      log: SuggestionLog(
        file: () async => File(p.join(dir.path, 'suggestions.json')),
        now: () => now,
        writeDelay: const Duration(days: 1),
      ),
      filter: testGate(),
      resolver: SeedResolver(
        downloads: downloads,
        index: SeedIndex(
          file: () async => File(p.join(dir.path, 'seeds.json')),
        ),
        searchSongs: (q) async => const [],
      ),
      radio: YtmRadioService(client, _NoMix(), now: () => now),
      config: () => const ShufflePlusConfig(enabled: true),
      jamActive: () => false,
      isMetered: () async => false,
      toolAvailable: () async => true,
      loadTracks: (ids) async => [for (final id in ids) _track(id)],
      loadLibrary: () async {
        await libraryHook();
        return LibraryIndex(const []);
      },
      hasDownload: (_) => false,
      prepare: (r) => prepareHook(),
      now: () => now,
    );
    addTearDown(controller.dispose);
  });

  Future<void> until(bool Function() done) async {
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (!done() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect(done(), isTrue);
  }

  Future<void> pause() =>
      Future<void>.delayed(const Duration(milliseconds: 200));

  /// A new list starts. [quiet]: no event reaches the controller.
  void newSource({bool quiet = false}) {
    host
      ..queueIds = [...newList]
      ..sourceIds = [...newList];
    if (!quiet) host.changesC.add(null);
  }

  /// The id after «dl» in the radio request [i]: 1-2 digits old, 3 new.
  String seed(int i) =>
      RegExp(r'dl(\d+)').firstMatch(adapter.bodies[i])!.group(1)!;

  test('a radio answer for the old source is dropped; new seeds are used afterwards', () async {
    final gate = Completer<void>();
    adapter.gate = gate;
    controller.start();
    await until(
      () => adapter.bodies.length == 1,
    ); // radio of an old seed, stuck
    newSource();
    gate.complete();
    await pause();
    expect(
      host.queueIds.where(isOnlineId),
      isEmpty,
      reason: 'nothing of the old list',
    );
    expect(
      adapter.bodies,
      hasLength(1),
      reason: 'the radio gap holds the next request',
    );

    now = now.add(const Duration(minutes: 2));
    controller.poke();
    await until(() => adapter.bodies.length == 2);
    expect(seed(0), hasLength(lessThan(3)), reason: 'first request: old seed');
    expect(
      seed(1),
      hasLength(3),
      reason: 'second request: seed of the new list',
    );
  });

  test('a slow radio request that outlasts the gap: the next seed is asked at once, no failed step', () async {
    adapter
      ..clipJson = File('test/fixtures/innertube/ytm_radio_video_seed.json')
          .readAsStringSync()
      ..onFetch = () => now = now.add(const Duration(minutes: 2));
    controller.start();
    await until(() => adapter.bodies.length == 2);
    expect(controller.stoppedForSession, isFalse);
    await pause();
    expect(
      adapter.bodies,
      hasLength(2),
      reason: 'the gap (from the new clock) holds a third one',
    );
    expect(
      seed(1),
      isNot(seed(0)),
      reason: 'the next seed, not the same one again',
    );
  });

  test(
    'a source change nobody announces is noticed by the interrupted work',
    () async {
      final gate = Completer<void>();
      adapter.gate = gate;
      controller.start();
      await until(() => adapter.bodies.length == 1);
      newSource(quiet: true);
      now = now.add(const Duration(minutes: 2));
      gate.complete();
      await until(() => adapter.bodies.length == 2); // no poke from outside
      expect(seed(1), hasLength(3));
    },
  );

  test(
    'a source change while the library loads: no radio for the old seed',
    () async {
      final gate = Completer<void>();
      libraryHook = () => gate.future;
      controller.start();
      await pause();
      newSource(quiet: true);
      gate.complete();
      await until(() => adapter.bodies.isNotEmpty);
      expect(
        seed(0),
        hasLength(3),
        reason: 'the first radio asked is the new list\'s',
      );
    },
  );

  test(
    'a source change while an address is prepared inserts nothing',
    () async {
      final gate = Completer<void>();
      var preparing = false;
      prepareHook = () {
        preparing = true;
        return gate.future;
      };
      controller.start();
      await until(() => preparing);
      newSource(quiet: true);
      gate.complete();
      await pause();
      expect(host.queueIds.where(isOnlineId), isEmpty);
    },
  );
}

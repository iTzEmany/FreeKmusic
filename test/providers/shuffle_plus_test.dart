import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../support/suggestion_gate_fake.dart';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/online_entries.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:codecore/services/import/track_matcher.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_service.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:codecore/services/shuffle_plus/radio_gate.dart';
import 'package:codecore/services/shuffle_plus/seed_index.dart';
import 'package:codecore/services/shuffle_plus/seed_resolver.dart';
import 'package:codecore/services/shuffle_plus/shuffle_host.dart';
import 'package:codecore/services/shuffle_plus/shuffle_plus_controller.dart';
import 'package:codecore/services/shuffle_plus/suggestion_log.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart'
    show suggestionArtistKey;
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart';
import 'package:codecore/providers/stream_providers.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import '../support/fake_backend.dart';
import '../support/fake_stream_preparer.dart';

final radioJson = File('test/fixtures/innertube/ytm_radio.json')
    .readAsStringSync();

class _Adapter implements HttpClientAdapter {
  int status = 200;
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<List<int>>? s,
    Future<void>? c,
  ) async {
    sent.add(o);
    return ResponseBody.fromString(
      status == 200 ? radioJson : '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Host implements ShuffleHost {
  _Host(this._ids, this.sourceIds);

  /// When set, the real queue (its shuffle order) backs this host.
  PlayQueue? real;
  final List<int> _ids;
  int _index = 0;
  bool _shuffle = true;

  @override
  List<int> get queueIds => real?.items ?? _ids;
  @override
  List<int>? sourceIds;
  @override
  int get currentIndex => real?.currentIndex ?? _index;
  set currentIndex(int v) => _index = v;
  @override
  bool get shuffleEnabled => real?.shuffle ?? _shuffle;
  set shuffleEnabled(bool v) => _shuffle = v;
  @override
  bool isPlaying = true;
  @override
  int get userAhead => real?.userAhead ?? 0;
  @override
  bool get currentFromUser => real?.currentFromUser ?? false;
  int inserts = 0;
  bool insertFails = false;

  final _changes = StreamController<void>.broadcast(sync: true);
  final _pos = StreamController<Duration>.broadcast(sync: true);
  final _dur = StreamController<Duration?>.broadcast(sync: true);
  final _fail = StreamController<PlaybackFailure>.broadcast(sync: true);

  @override
  Stream<void> get changes => _changes.stream;
  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<Duration?> get durationStream => _dur.stream;
  @override
  Stream<PlaybackFailure> get failures => _fail.stream;

  @override
  void insertAt(int index, int id) {
    if (insertFails) throw StateError('queue unavailable');
    inserts++;
    real != null ? real!.insertAt(index, id) : _ids.insert(index, id);
    _changes.add(null);
  }

  @override
  Future<void> removeQueueId(int id) async {
    if (real != null) {
      real!.removeId(id);
      _changes.add(null);
      return;
    }
    final i = _ids.indexOf(id);
    if (i < 0) return;
    _ids.removeAt(i);
    if (i < _index) _index--;
    _changes.add(null);
  }

  /// The current song plays to its end and the next one starts.
  void finishAndAdvance({bool toTheEnd = true}) {
    _dur.add(const Duration(minutes: 3));
    _pos.add(
      toTheEnd ? const Duration(minutes: 3) : const Duration(seconds: 5),
    );
    real != null ? real!.next(auto: true) : _index++;
    _changes.add(null);
  }

  void change() => _changes.add(null);
  void fail() => _fail.add(
    const PlaybackFailure('x', PlaybackFailureReason.onlineUnavailable),
  );
}

Track track(int id) => Track(
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
  late Directory dir;
  late DateTime now;
  late _Adapter adapter;
  late _Host host;
  late OnlineEntries online;
  late SuggestionLog log;
  late ShufflePlusController controller;
  late ShufflePlusConfig cfg;
  var jam = false;
  var metered = false;
  var searches = 0;
  var filterOverride = testGate();
  Future<void> Function(YtResult) prepareHook = (_) async {};
  Future<void> Function(List<int>) enrichHook = (_) async {};
  final withins = <Duration>[];
  final prepared = <String>[];
  final enriched = <List<int>>[];
  late ShufflePlusController Function({
    Duration? enrichTimeout,
    RadioGate? gate,
  })
  make;
  const library = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await pumpEventQueue();
    }
  }

  /// Waits (in real time, generously) until [done]: the controller's work
  /// goes through file and isolate I/O, so a fixed number of event-loop
  /// turns is not enough on a loaded machine.
  Future<void> until(bool Function() done) async {
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (!done() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (!done()) {
      print('DBG until failed queue=${host.queueIds} cur=${host.currentIndex} enriched=$enriched cfg=${cfg.enabled} pending=${controller.pending.value} log=${log.length}');
    }
    expect(done(), isTrue, reason: 'the condition was never reached');
    await settle();
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('shuffle_plus');
    addTearDown(() => dir.deleteSync(recursive: true));
    now = DateTime.utc(2026, 1, 1, 12);
    adapter = _Adapter();
    jam = false;
    metered = false;
    searches = 0;
    filterOverride = testGate();
    prepared.clear();
    prepareHook = (r) async => prepared.add(r.id);
    enriched.clear();
    withins.clear();
    enrichHook = (ids) async => enriched.add(ids);
    cfg = const ShufflePlusConfig(enabled: true);
    host = _Host([...library], [...library]);
    online = OnlineEntries();
    log = SuggestionLog(
      file: () async => File(p.join(dir.path, 'suggestions.json')),
      now: () => now,
      writeDelay: const Duration(days: 1),
    );
    final downloads = DownloadIndex(File(p.join(dir.path, 'downloads.json')));
    for (final id in library) {
      await downloads.add('dl$id', '/m/$id.mp3');
    }
    final client = InnerTubeClient(
      Dio(BaseOptions(validateStatus: (_) => true))
        ..httpClientAdapter = adapter,
    );
    make = ({Duration? enrichTimeout, RadioGate? gate}) =>
        ShufflePlusController(
          host: host,
          online: online,
          log: log,
          filter: filterOverride,
          resolver: SeedResolver(
            downloads: downloads,
            index: SeedIndex(
              file: () async => File(p.join(dir.path, 'seeds.json')),
            ),
            searchSongs: (q) async {
              searches++;
              return const [];
            },
          ),
          radio: YtmRadioService(client, _NoMix(), now: () => now),
          config: () => cfg,
          jamActive: () => jam,
          isMetered: () async => metered,
          toolAvailable: () async => true,
          loadTracks: (ids) async => [for (final id in ids) track(id)],
          loadLibrary: () async => LibraryIndex(const []),
          hasDownload: (_) => false,
          prepare: (r) => prepareHook(r),
          enrichSuggested: (ids, within) {
            withins.add(within);
            return enrichHook(ids);
          },
          enrichTimeout:
              enrichTimeout ?? ShufflePlusController.blockEnrichTimeout,
          gate: gate,
          now: () => now,
        );
    controller = make();
    addTearDown(controller.dispose);
  });

  /// What plays, in order, for [songs] steps: true = a suggestion.
  Future<List<bool>> play(int songs) async {
    final seen = <bool>[];
    for (var i = 0; i < songs; i++) {
      seen.add(isOnlineId(host.queueIds[host.currentIndex]));
      host.finishAndAdvance();
      await settle();
    }
    return seen;
  }

  /// Plays with [play], then replaces the one suggestion with a fresh plan;
  /// returns where the new suggestion lands.
  Future<int> replanAfter(FutureOr<void> Function() play) async {
    cfg = const ShufflePlusConfig(enabled: true, every: 10);
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 11; i++) i]);
    controller.start();
    await until(() => host.queueIds.any(isOnlineId));
    await play();
    await settle();
    await host.removeQueueId(host.queueIds.firstWhere(isOnlineId));
    host.queueIds.addAll([for (var i = 12; i <= 40; i++) i]);
    host.change();
    await until(() => host.queueIds.any(isOnlineId));
    return host.queueIds.indexWhere(isOnlineId);
  }

  test('a library song skipped before its last 3 s does not bring the '
      'suggestion closer', () async {
    final at = await replanAfter(() async {
      for (var i = 0; i < 5; i++) {
        host.finishAndAdvance(toTheEnd: false);
        await settle();
      }
    });
    expect(at, 14);
  });

  /// A real queue [1..11] in this order with shuffle on; [block] is enqueued
  /// first. Returns once Shuffle+ has put its first suggestion in.
  Future<void> startReal({List<int> block = const []}) async {
    cfg = const ShufflePlusConfig(enabled: true, every: 10);
    host.real = PlayQueue()
      ..shuffle = true
      ..setItems([for (var i = 1; i <= 11; i++) i], alreadyShuffled: true);
    for (final id in block) {
      host.real!.enqueue(id);
    }
    controller.start();
    await until(() => host.queueIds.any(isOnlineId));
  }

  /// Takes the suggestion out, lengthens the queue and returns how far from
  /// the current song the new suggestion lands (it tells the songs counted).
  Future<int> replanDistance() async {
    await host.removeQueueId(host.queueIds.firstWhere(isOnlineId));
    for (var i = 12; i <= 40; i++) {
      host.real!.insertAt(host.queueIds.length, i);
    }
    host.change();
    await until(() => host.queueIds.any(isOnlineId));
    return host.queueIds.indexWhere(isOnlineId) - host.currentIndex;
  }

  test('a song of the queue block does not count as a listen, even if '
      'another one is enqueued before the controller looks', () async {
    await startReal(block: [50, 51]);
    host.real!.next(auto: true); // 50 becomes current, controller not told yet
    host.real!.enqueue(52); // the block is 2 long again
    host.change();
    await settle();
    expect(host.real!.currentFromUser, isTrue);
    expect(await replanDistance(), 12);
  });

  test('the suggestion is planned after the queue block', () async {
    await startReal(block: [50, 51]);
    expect(host.queueIds.indexWhere(isOnlineId), 11);
  });

  test('a block entry skipped early gives no refund', () async {
    await startReal(block: [50]);
    host.finishAndAdvance(); // 50 from the block, not counted
    await settle();
    host.finishAndAdvance(toTheEnd: false); // 50 left early: no refund
    await settle();
    expect(await replanDistance(), 8);
  });

  test('a library song skipped before the backend gave its duration still '
      'gives its count back', () async {
    await startReal();
    for (var i = 0; i < 3; i++) {
      host.real!.next(auto: true); // no duration, no position reported
      host.change();
      await settle();
    }
    expect(await replanDistance(), 9);
  });

  test(
    'with the option off nothing is asked and nothing is inserted',
    () async {
      cfg = const ShufflePlusConfig();
      controller.start();
      await settle();
      expect(adapter.sent, isEmpty);
      expect(searches, 0);
      expect(host.queueIds, library);
    },
  );

  test(
    'no request in a Jam, on a metered network, without shuffle, in pause',
    () async {
      jam = true;
      controller.start();
      await settle();
      jam = false;
      metered = true;
      controller.poke();
      await settle();
      metered = false;
      host.shuffleEnabled = false;
      controller.poke();
      await settle();
      host.shuffleEnabled = true;
      host.isPlaying = false;
      controller.poke();
      await settle();
      expect(adapter.sent, isEmpty);
      expect(host.queueIds, library);
      host.isPlaying = true;
      controller.poke();
      await settle();
      expect(adapter.sent, hasLength(1), reason: 'all conditions met');
    },
  );

  test('metered network is fine when «Solo su Wi-Fi» is off', () async {
    metered = true;
    cfg = const ShufflePlusConfig(enabled: true, unmeteredOnly: false);
    controller.start();
    await settle();
    expect(adapter.sent, hasLength(1));
  });

  test('a list shorter than 5 songs gets plain shuffle', () async {
    host.sourceIds = [1, 2, 3, 4];
    controller.start();
    await settle();
    expect(adapter.sent, isEmpty);
  });

  test('with the queue running, the free slots fill at once and a passed one leaves', () async {
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => host.queueIds.where(isOnlineId).length == 3);
    final at = [
      for (var i = 0; i < host.queueIds.length; i++)
        if (isOnlineId(host.queueIds[i])) i,
    ];
    expect(at, [8, 12, 16], reason: 'no track change needed');
    expect(host.currentIndex, 5);
    expect(
      adapter.sent,
      hasLength(1),
      reason: 'one radio feeds many suggestions',
    );
    host.finishAndAdvance();
    await settle();
    host.finishAndAdvance();
    await settle();
    host.finishAndAdvance();
    await settle();
    host.finishAndAdvance(); // the first suggestion plays
    await settle();
    host.finishAndAdvance();
    await settle();
    expect(
      host.queueIds.take(host.currentIndex).where(isOnlineId),
      isEmpty,
      reason: 'passed suggestions are taken out',
    );
  });

  test('a blocked artist is never inserted', () async {
    void fresh() => host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    fresh();
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => host.queueIds.where(isOnlineId).length == 3);
    final keys = [
      for (final id in host.queueIds.where(isOnlineId))
        suggestionArtistKey(online[id]!.result),
    ];
    controller.dispose();

    filterOverride = testGate(artists: keys);
    fresh();
    controller = make()..start();
    await settle();
    await settle();
    final now = [
      for (final id in host.queueIds.where(isOnlineId))
        suggestionArtistKey(online[id]!.result),
    ];
    expect(now.where(keys.contains), isEmpty);
  });

  test(
    'a block that arrives between the pick and the insertion inserts nothing',
    () async {
      prepareHook = (r) async {
        prepared.add(r.id);
        filterOverride.store.blockArtist(
          DislikedArtist(key: suggestionArtistKey(r), name: 'x'),
        );
      };
      host.queueIds
        ..clear()
        ..addAll([for (var i = 1; i <= 20; i++) i]);
      host.sourceIds = [...library];
      host.currentIndex = 5;
      controller.start();
      await until(() => prepared.isNotEmpty);
      await settle();
      await settle();
      expect(host.queueIds.where(isOnlineId), isEmpty);
    },
  );

  test(
    'an online entry the user picked stays in the queue once passed',
    () async {
      cfg = const ShufflePlusConfig();
      final stations = [-101, -102, -103];
      host.queueIds
        ..clear()
        ..addAll(stations);
      controller.start();
      await settle();
      host.finishAndAdvance();
      await settle();
      host.finishAndAdvance();
      await settle();
      expect(host.queueIds, stations);
    },
  );

  test(
    'the engine prepares a suggestion through the stream preparer',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final fake = FakeStreamPreparer(TrackRepository(db), dir);
      final c = ProviderContainer(
        overrides: [streamPreparerProvider.overrideWithValue(fake)],
      );
      addTearDown(c.dispose);
      const r = YtResult(id: 'v9', title: 'T', channel: 'C', duration: null);
      await c.read(shufflePlusPrepareProvider)(r);
      expect(fake.asked, [r.indexKey]);
      expect(await TrackRepository(db).streamRow(r.indexKey), isNotNull);
    },
  );

  test('prepare asks for the address only: it returns while the file is still downloading', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final fake = FakeStreamPreparer(TrackRepository(db), dir);
    const r = YtResult(id: 'v9', title: 'T', channel: 'C', duration: null);
    fake.urls[r.indexKey] = (Uri.parse('https://x/a'), const {});
    fake.gates[r.indexKey] = Completer<void>(); // the file never arrives
    final c = ProviderContainer(
      overrides: [streamPreparerProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    var done = false;
    unawaited(c.read(shufflePlusPrepareProvider)(r).then((_) => done = true));
    await pumpEventQueue();
    expect(done, isTrue);
    expect(fake.asked, isEmpty, reason: 'no wait for the whole file');
    expect(fake.keeps, [
      false,
    ], reason: 'the job goes back to being a prefetch');
  });

  test('with the file never arriving, every free slot still fills from the addresses', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final fake = FakeStreamPreparer(TrackRepository(db), dir);
    final c = ProviderContainer(
      overrides: [streamPreparerProvider.overrideWithValue(fake)],
    );
    addTearDown(c.dispose);
    prepareHook = (r) {
      fake.urls[r.indexKey] = (Uri.parse('https://x/${r.id}'), const {});
      fake.gates[r.indexKey] = Completer<void>();
      return c.read(shufflePlusPrepareProvider)(r);
    };
    controller.start();
    await until(() => host.queueIds.where(isOnlineId).length == 3);
    expect(fake.asked, isEmpty);
  });

  test('after 3 suggestions their ids go to the enrichment and the next waits for it', () async {
    final gate = Completer<void>();
    enrichHook = (ids) async {
      enriched.add(ids);
      await gate.future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => enriched.isNotEmpty);
    final first = host.queueIds.where(isOnlineId).toList();
    expect(enriched.single, first);
    expect(first, hasLength(3));
    for (var i = 0; i < 5; i++) {
      host.finishAndAdvance(); // a slot frees up
      await settle();
    }
    expect(host.inserts, 3, reason: 'blocked while the block is enriched');
    gate.complete();
    await until(() => host.inserts > 3);
  });

  test('while a block is being enriched, turning Shuffle+ off takes the suggestions out at once', () async {
    enrichHook = (ids) {
      enriched.add(ids);
      return Completer<void>().future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => enriched.isNotEmpty);
    expect(host.queueIds.where(isOnlineId), hasLength(3));
    cfg = const ShufflePlusConfig();
    controller.poke();
    await until(() => host.queueIds.where(isOnlineId).isEmpty);
  });

  test('off then on during an enrichment: suggestions resume at once, the next block is new', () async {
    enrichHook = (ids) {
      enriched.add(ids);
      return Completer<void>().future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => enriched.isNotEmpty);
    cfg = const ShufflePlusConfig();
    controller.poke();
    await until(() => host.queueIds.where(isOnlineId).isEmpty);
    cfg = const ShufflePlusConfig(enabled: true);
    controller.poke();
    await until(() => enriched.length == 2);
    expect(enriched[1], hasLength(3));
    expect(enriched[1].toSet().intersection(enriched[0].toSet()), isEmpty);
  });

  test('pending: 3 coming at the start, fewer as they enter, then the block being enriched, then none', () async {
    final prepare = Completer<void>();
    final enrich = Completer<void>();
    prepareHook = (r) async {
      prepared.add(r.id);
      await prepare.future;
    };
    enrichHook = (ids) async {
      enriched.add(ids);
      await enrich.future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    final seen = <ShufflePlusPending>[];
    controller.pending.addListener(() => seen.add(controller.pending.value));
    controller.start();
    await until(() => prepared.isNotEmpty);
    expect(controller.pending.value, const ShufflePlusPending(incoming: 3));
    prepare.complete();
    await until(() => enriched.isNotEmpty);
    expect(seen.map((v) => v.incoming).toSet(), containsAll([3, 2, 1, 0]));
    expect(
      [for (final v in seen) v.incoming],
      orderedEquals(
        [...seen.map((v) => v.incoming)]..sort((a, b) => b.compareTo(a)),
      ),
      reason: 'it only goes down',
    );
    final block = host.queueIds.where(isOnlineId).toSet();
    expect(controller.pending.value, ShufflePlusPending(enriching: block));
    enrich.complete();
    await until(() => controller.pending.value.enriching.isEmpty);
    expect(controller.pending.value, ShufflePlusPending.none);
    final n = seen.length;
    controller.poke();
    await settle();
    expect(seen, hasLength(n), reason: 'no emission when nothing changed');
  });

  test('pending: while a block is enriched, incoming follows the free slots; it goes on after', () async {
    final gate = Completer<void>();
    enrichHook = (ids) async {
      enriched.add(ids);
      await gate.future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => enriched.isNotEmpty);
    expect(controller.pending.value.incoming, 0, reason: 'no free slot yet');
    for (var i = 0; i < 5; i++) {
      host.finishAndAdvance();
      await settle();
    }
    final free = controller.pending.value.incoming;
    expect(free, greaterThan(0), reason: 'slots freed, held by the enrichment');
    expect(controller.pending.value.enriching, isNotEmpty);
    gate.complete();
    await until(() => host.inserts > 3);
    await until(() => controller.pending.value.incoming < free);
  });

  test('pending: an error in the engine leaves nothing incoming', () async {
    final prepare = Completer<void>();
    prepareHook = (r) async {
      prepared.add(r.id);
      await prepare.future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => prepared.isNotEmpty);
    expect(controller.pending.value.incoming, 3);
    host.insertFails = true;
    prepare.complete();
    await until(() => controller.pending.value == ShufflePlusPending.none);
  });

  test('pending: back to none with Shuffle+ off, in a Jam, and when the controller stops', () async {
    enrichHook = (ids) {
      enriched.add(ids);
      return Completer<void>().future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => enriched.isNotEmpty);
    expect(controller.pending.value.enriching, hasLength(3));
    cfg = const ShufflePlusConfig();
    controller.poke();
    await until(() => controller.pending.value == ShufflePlusPending.none);
    cfg = const ShufflePlusConfig(enabled: true);
    controller.poke();
    await until(() => controller.pending.value.enriching.isNotEmpty);
    jam = true;
    controller.poke();
    await until(() => controller.pending.value == ShufflePlusPending.none);
    jam = false;
    controller.poke();
    await until(() => controller.pending.value.enriching.isNotEmpty);
    controller.dispose();
    expect(controller.pending.value, ShufflePlusPending.none);
  });

  test('an enrichment that throws does not stop Shuffle+', () async {
    var calls = 0;
    enrichHook = (ids) async {
      calls++;
      throw StateError('enrichment broke');
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => calls == 1);
    for (var i = 0; i < 5; i++) {
      host.finishAndAdvance();
      await settle();
    }
    await until(() => host.inserts > 3);
  });

  test('an enrichment that never ends holds the next suggestion only for the time limit', () async {
    controller = make(enrichTimeout: const Duration(milliseconds: 30));
    addTearDown(controller.dispose);
    enrichHook = (ids) {
      enriched.add(ids);
      return Completer<void>().future;
    };
    host.queueIds
      ..clear()
      ..addAll([for (var i = 1; i <= 20; i++) i]);
    host.sourceIds = [...library];
    host.currentIndex = 5;
    controller.start();
    await until(() => enriched.isNotEmpty);
    for (var i = 0; i < 5; i++) {
      host.finishAndAdvance();
      await settle();
    }
    await until(() => host.inserts > 3);
    expect(enriched, hasLength(1));
    expect(
      withins.single,
      ShufflePlusController.entryEnrichLimit,
      reason:
          'entries keep waiting in the background after the block is released',
    );
  });

  test(
    'a suggestion enters the queue only after its address is ready',
    () async {
      final gate = Completer<void>();
      prepareHook = (r) async {
        prepared.add(r.id);
        await gate.future;
      };
      controller.start();
      await until(() => prepared.isNotEmpty);
      expect(prepared, hasLength(1));
      expect(
        host.queueIds,
        library,
        reason: 'address not ready: nothing queued',
      );
      expect(log.recent, isEmpty);
      gate.complete();
      await until(() => host.queueIds.where(isOnlineId).length == 3);
    },
  );

  test(
    'a failed address tries the next candidate, no entry for the failed one',
    () async {
      var calls = 0;
      prepareHook = (r) async {
        prepared.add(r.id);
        if (calls++ == 0) throw TimeoutException('slow');
      };
      controller.start();
      await until(() => host.queueIds.any(isOnlineId));
      await until(() => host.queueIds.where(isOnlineId).length == 3);
      expect(prepared, hasLength(4));
      final queued = host.queueIds
          .where(isOnlineId)
          .map((id) => online[id]!.result.id);
      expect(queued, prepared.skip(1));
    },
  );

  test('when every candidate fails nothing is queued', () async {
    prepareHook = (r) async {
      prepared.add(r.id);
      throw TimeoutException('slow');
    };
    controller.start();
    await until(() => prepared.length >= ShufflePlusController.prepareAttempts);
    await settle();
    expect(prepared, hasLength(ShufflePlusController.prepareAttempts));
    expect(host.queueIds, library);
    expect(log.recent, isEmpty);
  });

  test('outcomes: heard to the end, skipped otherwise', () async {
    controller.start();
    await settle();
    await play(3);
    host.finishAndAdvance(toTheEnd: true); // the suggestion is current: heard
    await settle();
    await play(3);
    host.finishAndAdvance(toTheEnd: false);
    await settle();
    final outcomes = log.recent.map((r) => r.outcome).toList();
    expect(
      outcomes.first,
      SuggestionOutcome.queued,
      reason: 'the next one is waiting',
    );
    expect(outcomes.last, SuggestionOutcome.heard);
    expect(log.recent.last.seedTitle, startsWith('Song'));
  });

  test(
    'turning shuffle off takes every suggestion after the current out',
    () async {
      host.queueIds
        ..clear()
        ..addAll([for (var i = 1; i <= 20; i++) i]);
      host.currentIndex = 5;
      controller.start();
      await until(() => host.queueIds.where(isOnlineId).length == 3);
      host.shuffleEnabled = false;
      host.change();
      await until(() => host.queueIds.every((id) => !isOnlineId(id)));
      expect(host.queueIds, [for (var i = 1; i <= 20; i++) i]);
      expect(host.queueIds[host.currentIndex], 6, reason: 'the current stays');
    },
  );

  for (final seed in [5, 6, 8]) {
    test(
      'shuffle off removes suggestions even behind the current song (seed $seed)',
      () async {
        host.real = PlayQueue(random: Random(seed))
          ..setItems([for (var i = 1; i <= 20; i++) i])
          ..shuffle = true;
        controller.start();
        await until(() => host.queueIds.where(isOnlineId).length == 3);
        for (var i = 0; i < 6; i++) {
          host.finishAndAdvance();
          await settle();
        }
        await until(() => host.queueIds.where(isOnlineId).isNotEmpty);
        host.real!.shuffle = false;
        host.change();
        await until(() => host.queueIds.where(isOnlineId).isEmpty);
      },
    );
  }

  test(
    'a Jam that starts while a suggestion is being prepared inserts nothing',
    () async {
      final gate = Completer<void>();
      prepareHook = (r) async {
        prepared.add(r.id);
        await gate.future;
      };
      controller.start();
      await until(() => prepared.isNotEmpty);
      jam = true;
      gate.complete();
      await settle();
      expect(host.inserts, 0);
      expect(host.queueIds.where(isOnlineId), isEmpty);
    },
  );

  test('Shuffle+ turned off while a suggestion is being prepared inserts nothing more', () async {
    final gate = Completer<void>();
    var calls = 0;
    prepareHook = (r) async {
      if (++calls == 2) await gate.future;
    };
    controller.start();
    await until(() => calls == 2);
    expect(host.queueIds.where(isOnlineId), hasLength(1));
    host.shuffleEnabled = false;
    gate.complete();
    await settle();
    expect(host.queueIds.where(isOnlineId), isEmpty);
  });

  test(
    'a new list drops the pool: the next suggestion asks for a new radio',
    () async {
      controller.start();
      await settle();
      expect(adapter.sent, hasLength(1));
      host.sourceIds = [for (var i = 1; i <= 8; i++) i];
      now = now.add(const Duration(minutes: 2));
      // The suggestions are used up: the free slots need new rows.
      for (final id in host.queueIds.where(isOnlineId).toList()) {
        await host.removeQueueId(id);
      }
      await until(() => adapter.sent.length >= 2);
      expect(
        adapter.sent,
        hasLength(2),
        reason: 'rows of the old list are not reused',
      );
    },
  );

  test(
    'a 429 pauses every request for 15 minutes, with a single notice',
    () async {
      adapter.status = 429;
      final notices = <ShufflePlusNotice>[];
      controller.notices.listen(notices.add);
      controller.start();
      await settle();
      expect(adapter.sent, hasLength(1));
      expect(notices, [ShufflePlusNotice.rateLimited]);
      expect(controller.rateLimited, isTrue);

      now = now.add(const Duration(minutes: 14));
      controller.poke();
      await settle();
      expect(adapter.sent, hasLength(1), reason: 'still paused');
      expect(controller.rateLimited, isTrue);

      now = now.add(const Duration(minutes: 2));
      expect(controller.rateLimited, isFalse);
      controller.poke();
      await settle();
      expect(adapter.sent, hasLength(2));
      expect(notices, hasLength(1), reason: 'told once');
    },
  );

  test('radio requests are at least a minute apart', () async {
    adapter.status = 500; // unreadable: falls to the (empty) yt-dlp mix
    controller.start();
    await settle();
    final first = adapter.sent.length;
    controller.poke();
    await settle();
    expect(adapter.sent.length, first);
  });

  test('a radio request made elsewhere (the genre mix) holds Shuffle+ back for the gap', () async {
    final gate = RadioGate(now: () => now)..asked();
    controller.dispose();
    controller = make(gate: gate);
    addTearDown(controller.dispose);
    controller.start();
    await settle();
    expect(adapter.sent, isEmpty);

    now = now.add(const Duration(minutes: 2));
    controller.poke();
    await settle();
    expect(adapter.sent, hasLength(1));
  });

  test('a 429 trips the shared gate', () async {
    adapter.status = 429;
    final gate = RadioGate(now: () => now);
    controller.dispose();
    controller = make(gate: gate);
    addTearDown(controller.dispose);
    controller.start();
    await settle();
    expect(gate.rateLimited, isTrue);
    expect(controller.rateLimited, isTrue);
  });

  test(
    'three playback failures in a row stop Shuffle+ for the session',
    () async {
      final notices = <ShufflePlusNotice>[];
      controller.notices.listen(notices.add);
      controller.start();
      await settle();
      host
        ..fail()
        ..fail()
        ..fail();
      await settle();
      expect(notices, [ShufflePlusNotice.tooManyErrors]);
      expect(controller.stoppedForSession, isTrue);
      expect(host.queueIds, library, reason: 'the waiting suggestion is gone');
      expect(
        controller.pending.value,
        ShufflePlusPending.none,
        reason: 'no placeholder rows once the engine is off',
      );
    },
  );

  /// Distance of the replanned suggestion after the original is skipped early
  /// and the block copy (id [copyOf], or 50) plays to the end.
  Future<int> copyScenario(int? copyOf) async {
    cfg = const ShufflePlusConfig(enabled: true, every: 10);
    host.real = PlayQueue()
      ..shuffle = true
      ..setItems([for (var i = 1; i <= 11; i++) i], alreadyShuffled: true);
    host.real!.enqueue(copyOf ?? 50);
    controller.start();
    await until(() => host.queueIds.any(isOnlineId));
    host.finishAndAdvance(toTheEnd: false);
    await settle();
    host.finishAndAdvance();
    await settle();
    return replanDistance();
  }

  test('a block copy of the playing song counts like any other block entry', () async {
    final control = await copyScenario(null);
    host = _Host([...library], [...library]);
    controller.dispose();
    controller = make();
    expect(await copyScenario(1), control);
  });

  test('HandlerShuffleHost reads the block from the real handler', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = TrackRepository(db);
    final h = CodecoreAudioHandler(FakeBackend(), PlayQueue(), repo,
        onError: (_) {},
        online: OnlineEntries(),
        preparer: FakeStreamPreparer(repo, Directory.systemTemp.createTempSync('hsh')));
    addTearDown(h.dispose);
    final ids = [
      for (var i = 0; i < 3; i++)
        await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/m/$i.mp3', title: 'S$i', albumKey: 'k', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: i)),
    ];
    final plusHost = HandlerShuffleHost(h);
    await h.playQueue([ids[0], ids[1]], 0);
    expect(plusHost.userAhead, 0);
    h.addToQueue(ids[2]);
    expect(plusHost.userAhead, 1);
    expect(plusHost.currentFromUser, isFalse);
    await h.skipToNext();
    expect(plusHost.currentFromUser, isTrue);
    expect(plusHost.userAhead, 0);
  });
}

class _NoMix implements YoutubeService {
  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) async =>
      const PlaylistListing.empty();

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

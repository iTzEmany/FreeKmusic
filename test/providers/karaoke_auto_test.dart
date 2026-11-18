import 'dart:async';
import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/providers/karaoke_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart'
    show networkProbeProvider;
import 'package:codecore/providers/stream_providers.dart'
    show streamCacheProvider;
import 'package:codecore/services/karaoke/separation_service.dart';
import 'package:codecore/services/stream/stream_cache.dart';
import 'package:drift/drift.dart' show Value;
import 'package:codecore/data/db/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/services/audio/codecore_audio_handler.dart';
import 'package:codecore/services/audio/play_queue.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_backend.dart';

/// Plain `test`s: the providers' streams need the real zone (not a widget test's fake time).
class _T {
  Future<R?> runAsync<R>(Future<R> Function() f) => f();
}

class _H {
  _H(this.db, this.handler, this.store);
  final AppDatabase db;
  final CodecoreAudioHandler handler;
  final SettingsStore store;

  List<Override> get overrides => [
    databaseProvider.overrideWithValue(db),
    audioHandlerProvider.overrideWithValue(handler),
    settingsStoreProvider.overrideWithValue(store),
  ];

  Future<void> dispose(_T _) async {
    await handler.dispose();
    await db.close();
  }

  static Future<_H> create(_T _, {required int tracks}) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    for (var i = 0; i < tracks; i++) {
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/m/t$i.mp3',
              title: 'Song $i',
              albumKey: 'a|b',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: i,
            ),
          );
    }
    final handler = CodecoreAudioHandler(
      FakeBackend(),
      PlayQueue(),
      TrackRepository(db),
      onError: (_) {},
    );
    return _H(db, handler, await SettingsStore.open());
  }
}

/// Writes the two outputs, then waits for [release]; records every input.
class _Separator implements Separator {
  final inputs = <String>[];
  final _gates = <Completer<void>>[];
  bool hold = false;
  int cancels = 0;

  void release() {
    for (final g in _gates) {
      if (!g.isCompleted) g.complete();
    }
  }

  @override
  Future<void> separate({
    required String input,
    required String output,
    required String voiceOutput,
    required String vocals,
    required String accompaniment,
    void Function(double fraction)? onProgress,
  }) async {
    inputs.add(input);
    await File(output).writeAsBytes([1]);
    await File(voiceOutput).writeAsBytes([1]);
    if (!hold) return;
    final g = Completer<void>();
    _gates.add(g);
    await g.future;
  }

  @override
  Future<void> mix({
    required String base,
    required String voice,
    required double level,
    required String output,
  }) async {}

  /// Like the engine: the running job ends with [SeparationCancelled].
  @override
  Future<void> cancel() async {
    cancels++;
    for (final g in _gates) {
      if (!g.isCompleted) g.completeError(const SeparationCancelled());
    }
  }
}

class _Service extends SeparationService {
  _Service(
    StreamCache cache,
    Separator sep,
    this.modelMissing,
    Directory root, {
    super.clock,
  }) : super(
         cache: cache,
         separator: sep,
         modelsRoot: () async => root,
         models: const {},
       );
  final bool modelMissing;

  @override
  Future<bool> modelsMissing() async => modelMissing;
}

class _Net extends NetworkProbe {
  _Net(this.m) : super(android: false);
  final bool m;

  @override
  Future<NetworkKind> current() async => NetworkKind(metered: m);
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('karaoke_auto'));
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<void> until(bool Function() ok) async {
    for (var i = 0; i < 60 && !ok(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Five tracks: t0..t4, the files of [missing] do not exist.
  Future<
    ({
      _H h,
      ProviderContainer c,
      _Separator sep,
      StreamCache cache,
      _Service svc,
      List<int> ids,
      List<String> keys,
    })
  >
  setup(
    _T t, {
    bool metered = false,
    bool modelMissing = false,
    bool hold = false,
    DateTime Function()? clock,
    Set<int> missing = const {},
    bool on = false,
  }) async {
    final h = await _H.create(t, tracks: 5);
    final sep = _Separator()..hold = hold;
    final cache = StreamCache(Directory('${tmp.path}/cache'));
    final svc = _Service(cache, sep, modelMissing, tmp, clock: clock);
    final rows = (await t.runAsync(() => h.db.select(h.db.tracks).get()))!;
    final keys = <String>[];
    await t.runAsync(() async {
      for (var i = 0; i < rows.length; i++) {
        final f = File('${tmp.path}/t$i.mp3');
        if (!missing.contains(i)) f.writeAsBytesSync([i]);
        await (h.db.update(h.db.tracks)..where((r) => r.id.equals(rows[i].id)))
            .write(TracksCompanion(path: Value(f.path)));
        keys.add(
          missing.contains(i)
              ? ''
              : karaokeKeyOfLocal(
                  rows[i].id,
                  f.statSync().modified.millisecondsSinceEpoch,
                ),
        );
      }
    });
    final c = ProviderContainer(
      overrides: [
        ...h.overrides,
        separationServiceProvider.overrideWithValue(svc),
        streamCacheProvider.overrideWithValue(cache),
        networkProbeProvider.overrideWithValue(_Net(metered)),
      ],
    );
    addTearDown(() {
      sep.release();
      c.dispose();
    });
    c.listen(karaokeAutoProvider, (_, _) {});
    if (on) setKaraoke(c, true);
    // The providers subscribe to the player's streams a moment after they are first read.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return (
      h: h,
      c: c,
      sep: sep,
      cache: cache,
      svc: svc,
      ids: [for (final r in rows) r.id],
      keys: keys,
    );
  }

  test('switching karaoke on separates the playing track by itself', () async {
    final t = _T();
    final s = await setup(t);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(s.sep.inputs, isEmpty);
      setKaraoke(s.c, true);
      await until(() => s.sep.inputs.isNotEmpty);
    });
    expect(s.sep.inputs, ['${tmp.path}/t0.mp3']);
    await s.h.dispose(t);
  });

  test('a track change separates the new track', () async {
    final t = _T();
    final s = await setup(t, on: true);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      await until(() => s.sep.inputs.length == 1);
      await s.h.handler.playQueue([s.ids[1]], 0);
      await until(() => s.sep.inputs.length == 2);
    });
    expect(s.sep.inputs.last, '${tmp.path}/t1.mp3');
    await s.h.dispose(t);
  });

  test('metered with the model missing: waits for «Avvia»', () async {
    final t = _T();
    final s = await setup(t, metered: true, modelMissing: true, on: true);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(s.sep.inputs, isEmpty);
      s.c.read(karaokeConfirmedProvider.notifier).add(s.keys[0]);
      await until(() => s.sep.inputs.isNotEmpty);
    });
    expect(s.sep.inputs, ['${tmp.path}/t0.mp3']);
    await s.h.dispose(t);
  });

  test('queued by hand: separated in queue order after the current, skipping what has no file', () async {
    final t = _T();
    final s = await setup(t, on: true, missing: {1});
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0], s.ids[4]], 0);
      s.h.handler
        ..addToQueue(s.ids[1])
        ..addToQueue(s.ids[2])
        ..addToQueue(s.ids[3]);
      await until(() => s.sep.inputs.length >= 3);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    // t4 is in the automatic queue and t1 has no file: neither is separated.
    expect(s.sep.inputs, [
      for (final i in [0, 2, 3]) '${tmp.path}/t$i.mp3',
    ]);
    await s.h.dispose(t);
  });

  test('queued tracks are not prefetched when the model is missing on a metered network', () async {
    final t = _T();
    final s = await setup(t, metered: true, modelMissing: true, on: true);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      s.h.handler.addToQueue(s.ids[1]);
      s.c.read(karaokeConfirmedProvider.notifier).add(s.keys[0]);
      await until(() => s.sep.inputs.isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    expect(s.sep.inputs, ['${tmp.path}/t0.mp3']);
    await s.h.dispose(t);
  });

  test(
    'stems of queued tracks stay pinned until they leave the queue',
    () async {
      final t = _T();
      final s = await setup(t, on: true);
      await t.runAsync(() async {
        await s.h.handler.playQueue([s.ids[0]], 0);
        s.h.handler.addToQueue(s.ids[1]);
        await until(() => s.sep.inputs.length == 2);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      final base = karaokeFileKey('base', s.keys[1]);
      final voice = karaokeFileKey('voice', s.keys[1]);
      expect(s.cache.isPinned(base) && s.cache.isPinned(voice), isTrue);
      await t.runAsync(() async {
        await s.h.handler.removeFromQueue(1);
        await until(() => !s.cache.isPinned(base));
      });
      expect(s.cache.isPinned(base) || s.cache.isPinned(voice), isFalse);
      await s.h.dispose(t);
    },
  );

  test('karaoke off cancels a running prefetch', () async {
    final t = _T();
    final s = await setup(t, on: true);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      await until(() => s.sep.inputs.length == 1);
      s.sep.hold = true;
      s.h.handler.addToQueue(s.ids[1]);
      await until(() => s.sep.inputs.length == 2);
      setKaraoke(s.c, false);
      await until(() => s.sep.cancels == 1);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    expect(s.sep.cancels, 1);
    expect(s.sep.inputs, hasLength(2)); // nothing restarted
    expect(s.cache.isPinned(karaokeFileKey('base', s.keys[1])), isFalse);
    await s.h.dispose(t);
  });

  test('karaoke off leaves the current track\'s job running', () async {
    final t = _T();
    final s = await setup(t, on: true, hold: true);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      s.h.handler.addToQueue(s.ids[1]);
      await until(() => s.sep.inputs.length == 1);
      setKaraoke(s.c, false);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      s.sep.hold = false;
      s.sep.release();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    expect(s.sep.cancels, 0);
    expect(s.sep.inputs, ['${tmp.path}/t0.mp3']);
    await s.h.dispose(t);
  });

  test(
    'playback of a ready track does not wait for a running prefetch',
    () async {
      final t = _T();
      final s = await setup(t, on: true);
      await t.runAsync(() async {
        await s.h.handler.playQueue([s.ids[0]], 0);
        await until(() => s.sep.inputs.length == 1);
        s.sep.hold = true;
        s.h.handler.addToQueue(s.ids[1]);
        await until(() => s.sep.inputs.length == 2);
        final r = await s.svc
            .mixFor(s.keys[0], 0)
            .timeout(const Duration(seconds: 2));
        expect(r.status, MixStatus.file);
        expect(s.sep.cancels, 1);
        // The prefetch starts again afterwards.
        await until(() => s.sep.inputs.length == 3);
      });
      expect(s.sep.inputs.last, '${tmp.path}/t1.mp3');
      await s.h.dispose(t);
    },
  );

  test('a track change during a held prefetch: the current wins, the prefetch resumes', () async {
    final t = _T();
    final s = await setup(t, on: true);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      await until(() => s.sep.inputs.length == 1);
      s.sep.hold = true;
      s.h.handler.addToQueue(s.ids[1]);
      await until(() => s.sep.inputs.length == 2);
      await s.h.handler.playQueue([s.ids[2]], 0);
      s.h.handler.addToQueue(s.ids[1]);
      await until(() => s.sep.inputs.length == 3);
      s.sep.hold = false;
      s.sep.release();
      await until(() => s.sep.inputs.length == 4);
    });
    expect(s.sep.inputs.skip(1), [
      for (final i in [1, 2, 1]) '${tmp.path}/t$i.mp3',
    ]);
    await s.h.dispose(t);
  });

  test('expiry while the track plays at 100 %: no new separation', () async {
    final t = _T();
    final s = await setup(
      t,
      on: true,
      clock: () => DateTime.now().add(const Duration(hours: 1)),
    );
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      await until(() => s.sep.inputs.length == 1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await s.svc.expire();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    expect(s.sep.inputs, hasLength(1));
    expect(await s.cache.fileFor(karaokeFileKey('base', s.keys[0])), isNotNull);
    await s.h.dispose(t);
  });

  test('disposing the provider releases the pins', () async {
    final t = _T();
    final s = await setup(t, on: true);
    await t.runAsync(() async {
      await s.h.handler.playQueue([s.ids[0]], 0);
      s.h.handler.addToQueue(s.ids[1]);
      await until(() => s.sep.inputs.length == 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    final queued = karaokeFileKey('base', s.keys[1]);
    final current = karaokeFileKey('base', s.keys[0]);
    expect(s.cache.isPinned(queued) && s.cache.isPinned(current), isTrue);
    s.c.dispose();
    expect(s.cache.isPinned(queued) || s.cache.isPinned(current), isFalse);
    await s.h.dispose(t);
  });
}

void setKaraoke(ProviderContainer c, bool on) =>
    c.read(settingsProvider.notifier).update((s) => s.copyWith(karaokeOn: on));

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/chinese_dictionary_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/online_providers.dart';
import 'package:codecore/providers/romanization_ops.dart';
import 'package:codecore/providers/romanization_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/lyrics/romanization_cache.dart';
import 'package:codecore/services/lyrics/romanization_resolver.dart';
import 'package:codecore/services/online/netease_lyrics_client.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _Netease implements NeteaseLyricsClient {
  String? answer;
  var calls = 0;

  @override
  Future<String?> romanized({
    required String title,
    required String artist,
    required int? durationSec,
    CancelToken? cancel,
  }) async {
    calls++;
    return answer;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late Directory dir;
  late AppDatabase db;
  late _Netease netease;
  late RomanizationCache cache;
  late ProviderContainer c;

  Future<void> boot([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues({'autoLyrics': true, ...prefs});
    c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(await SettingsStore.open()),
        databaseProvider.overrideWithValue(db),
        neteaseLyricsClientProvider.overrideWithValue(netease),
        romanizationCacheProvider.overrideWithValue(cache),
        cedictPathProvider.overrideWith((_) => p.join(dir.path, 'cedict.gz')),
      ],
    );
    addTearDown(c.dispose);
  }

  Future<int> addTrack({
    String? plain,
    String? synced,
    bool byUser = false,
  }) async {
    final id = await db
        .into(db.tracks)
        .insert(
          TracksCompanion.insert(
            path: '/m/${plain ?? synced}.mp3',
            title: 'T',
            albumKey: 'k',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            artist: const Value('A'),
            durationMs: const Value(200000),
            lyricsPlain: Value(plain),
            lyricsSynced: Value(synced),
          ),
        );
    if (byUser) {
      await db
          .into(db.trackEnrich)
          .insert(
            TrackEnrichCompanion(
              trackId: Value(id),
              lyricsByUser: const Value(true),
            ),
          );
    }
    return id;
  }

  /// The first state that is neither loading nor downloading.
  Future<RomanizationState> settled(int id) {
    final done = Completer<RomanizationState>();
    c.listen(romanizationProvider(id), (_, n) {
      final v = n.value;
      if (v != null &&
          v.status != RomanizationStatus.loading &&
          v.status != RomanizationStatus.downloading &&
          !done.isCompleted) {
        done.complete(v);
      }
    }, fireImmediately: true);
    return done.future.timeout(const Duration(seconds: 5));
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('romprov');
    db = AppDatabase(NativeDatabase.memory());
    netease = _Netease();
    cache = RomanizationCache(
      file: () async => File(p.join(dir.path, 'cache.json')),
    );
  });
  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('Korean is computed from the track\'s lyrics, no lookup', () async {
    await boot();
    final id = await addTrack(plain: '안녕하세요');
    final s = await settled(id);
    expect(s.lines, ['annyeonghaseyo']);
    expect(netease.calls, 0);
  });

  test('Japanese: the lookup answer is saved in the cache', () async {
    netease.answer = '[00:01.00]konnichiwa';
    await boot();
    final id = await addTrack(synced: '[00:01.00]こんにちは');
    final s = await settled(id);
    expect(s.source, RomanizationSource.found);
    expect(s.lines, ['konnichiwa']);
    expect((await cache.get(id))!.lrc, '[00:01.00]konnichiwa');
  });

  test('the setting off: off, and no lookup', () async {
    await boot({'romanization': false});
    final id = await addTrack(plain: '안녕하세요');
    expect((await settled(id)).status, RomanizationStatus.off);
  });

  test('the automatic lyrics search off: no lookup', () async {
    netease.answer = '[00:01.00]konnichiwa';
    await boot({'autoLyrics': false});
    final id = await addTrack(synced: '[00:01.00]こんにちは');
    expect((await settled(id)).status, RomanizationStatus.unavailable);
    expect(netease.calls, 0);
  });

  test(
    'lyrics of the user (typed or chosen): no lookup, Korean still computed',
    () async {
      netease.answer = '[00:01.00]konnichiwa';
      await boot();
      final ja = await addTrack(synced: '[00:01.00]こんにちは', byUser: true);
      expect((await settled(ja)).status, RomanizationStatus.unavailable);
      final ko = await addTrack(plain: '좋아', byUser: true);
      expect((await settled(ko)).lines, ['joa']);
      expect(netease.calls, 0);
    },
  );

  test('the sync switch off: the plain text of the synced lyrics is aligned by index', () async {
    netease.answer = '[00:01.00]konnichiwa';
    await boot();
    final id = await addTrack(synced: '[00:01.00]こんにちは');
    await c.read(unsyncedLyricsProvider.notifier).setSynced(id, false);
    final s = await settled(id);
    expect(s.lines, ['konnichiwa']);
  });

  test(
    'a typed transliteration wins over the lookup and follows save/delete/undo',
    () async {
      netease.answer = '[00:01.00]konnichiwa';
      await boot();
      final id = await addTrack(synced: '[00:01.00]こんにちは');
      final ops = c.read(romanizationOpsProvider);
      expect(await ops.save(id, '  '), isNull);
      final undoSave = await ops.save(id, 'mine');
      expect(c.read(manualRomanizationProvider), {id: 'mine'});
      expect((await settled(id)).lines, ['mine']);
      expect((await SettingsStore.open()).readManualRomanizations(), {
        id: 'mine',
      }, reason: 'saved in the settings, which the backup carries');

      final undoDelete = await ops.delete(id);
      expect(c.read(manualRomanizationProvider), isEmpty);
      await undoDelete!();
      expect(c.read(manualRomanizationProvider), {id: 'mine'});
      await undoSave!();
      expect(c.read(manualRomanizationProvider), isEmpty);
      expect(await ops.delete(id), isNull);
    },
  );

  test(
    'Chinese with no romalrc: the dictionary on disk gives the pinyin',
    () async {
      await boot();
      File(p.join(dir.path, 'cedict.gz')).writeAsBytesSync(
        gzip.encode(utf8.encode('銀行 银行 [yin2 hang2] /bank/\n')),
      );
      final id = await addTrack(plain: '银行');
      final s = await settled(id);
      expect(s.source, RomanizationSource.dictionary);
      expect(s.lines, ['yínháng']);
      final dict = c.read(chineseDictionaryProvider);
      expect(dict.status, ChineseDictionaryStatus.ready);
      expect(dict.sizeBytes, greaterThan(0));
    },
  );
}

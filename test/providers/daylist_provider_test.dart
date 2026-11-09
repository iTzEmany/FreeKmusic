import 'dart:async';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/daylist_providers.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/dislike_store_provider.dart';
import 'package:codecore/services/shuffle_plus/dislike_store.dart';
import 'package:codecore/providers/player_providers.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/services/daylist/daylist_builder.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_radio_parser.dart';
import 'package:codecore/services/shuffle_plus/suggestion_pool.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _Player implements PlayerController {
  List<MixItem>? items;
  bool? shuffle;
  int? index;

  @override
  Future<void> playMixed(List<MixItem> items, {int? index, PlayContext? context, bool? shuffle}) async {
    this.items = items;
    this.shuffle = shuffle;
    this.index = index;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('${i.memberName}');
}

// Default slots: 4 is 19-22 (funk, soul, indie), 5 is 22-24 (lo-fi, jazz, soul), 6 is 0-3 and off.
final evening = DateTime(2026, 11, 9, 20, 30);
final lateEvening = DateTime(2026, 11, 9, 22, 30);
final smallHours = DateTime(2026, 11, 9, 1);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory dir;
  late SettingsStore store;
  late DateTime Function() clock;
  late int suggestAsked;
  late bool offline;
  late _Player player;
  late DislikeStore dislikes;
  late List<bool> forced;
  Completer<void>? holdFirst;
  var settle = Duration.zero;

  Future<void> addTracks(int n, {String genre = 'Soul'}) async {
    for (var i = 1; i <= n; i++) {
      await db
          .into(db.tracks)
          .insert(
            TracksCompanion.insert(
              path: '/m/$i.mp3',
              title: 'Song $i',
              albumKey: 'k$i',
              format: 'mp3',
              sizeBytes: 1,
              mtimeMs: 1,
              addedAt: 1,
              artist: Value('Band $i'),
              genre: Value(genre),
            ),
          );
    }
  }

  /// A container on the same database, settings and `daylist.json`: a new one is an app restart.
  ProviderContainer open() {
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(db),
        daylistClockProvider.overrideWithValue(() => clock()),
        daylistFileProvider.overrideWithValue(() async => File(p.join(dir.path, 'daylist.json'))),
        playerControllerProvider.overrideWithValue(player),
        daylistSettleProvider.overrideWithValue(settle),
        dislikeStoreProvider.overrideWithValue(dislikes),
        daylistSuggestProvider.overrideWithValue((cancelled, {force = false}) async {
          final n = ++suggestAsked;
          forced.add(force);
          if (n == 1) await holdFirst?.future;
          if (offline) return null;
          return (seeds, want, accept, inQueue) => Stream.fromIterable([
            for (var i = 0; i < want; i++)
              SuggestionCandidate(
                YtResult(
                  id: 's${n}_$i',
                  title: 'Online $i',
                  channel: 'Ch',
                  artists: ['Band ${i + 1}'],
                  duration: const Duration(seconds: 200),
                ),
                seeds.first.title,
                RadioKind.song,
              ),
          ]).where(accept);
        }),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  List<Object?> ids(DaylistState s) => [for (final i in s.result.items) i.track?.id ?? i.suggestion!.result.id];

  Future<DaylistState?> daylist(ProviderContainer c) => c.read(daylistProvider.future);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await SettingsStore.open();
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    dir = Directory.systemTemp.createTempSync('daylist_provider');
    addTearDown(() => dir.deleteSync(recursive: true));
    clock = () => lateEvening;
    suggestAsked = 0;
    offline = false;
    player = _Player();
    dislikes = DislikeStore(file: () async => File(p.join(dir.path, 'dislikes.json')), writeDelay: Duration.zero);
    forced = [];
    holdFirst = null;
    settle = Duration.zero;
  });

  test('a switched-off slot has no daylist', () async {
    await addTracks(40);
    clock = () => smallHours;
    expect(await daylist(open()), isNull);
    expect(suggestAsked, 0);
  });

  test('the daylist of the slot: own songs and suggested ones, the end of the slot', () async {
    await addTracks(40);
    final s = (await daylist(open()))!;
    expect(s.slotIndex, 5);
    expect(s.nextChange, DateTime(2026, 11, 10, 0));
    expect(s.result.tooFew, isFalse);
    expect(s.result.items.where((i) => i.suggestion != null), hasLength(15)); // 30 % of 50
    expect(s.result.items, hasLength(DaylistBuilder.size));
  });

  test('without a network only the own songs', () async {
    await addTracks(20);
    offline = true;
    final s = (await daylist(open()))!;
    expect(s.result.tooFew, isFalse);
    expect(s.result.items.where((i) => i.suggestion != null), isEmpty);
    expect(s.result.items, hasLength(20));
  });

  test('too few songs: no daylist, and nothing is saved', () async {
    await addTracks(5);
    offline = true;
    final s = (await daylist(open()))!;
    expect(s.result.tooFew, isTrue);
    expect(File(p.join(dir.path, 'daylist.json')).existsSync(), isFalse);
  });

  test('the same slot after a restart: the saved daylist, no new work', () async {
    await addTracks(40);
    final first = (await daylist(open()))!;
    expect(suggestAsked, 1);
    final again = (await daylist(open()))!;
    expect(suggestAsked, 1, reason: 'no suggestions asked again');
    expect(ids(again), ids(first));
    expect(again.result.genres, first.result.genres);
  });

  test('a restart after the slot changed: a new daylist', () async {
    await addTracks(40);
    clock = () => evening;
    expect((await daylist(open()))!.slotIndex, 4);
    clock = () => lateEvening;
    final s = (await daylist(open()))!;
    expect(s.slotIndex, 5);
    expect(suggestAsked, 2);
  });

  test('the slot changes while the app runs: the daylist is made again at the change', () async {
    await addTracks(40);
    final sw = Stopwatch()..start();
    clock = () => DateTime(2026, 11, 9, 21, 59, 59).add(sw.elapsed);
    final c = open();
    expect((await daylist(c))!.slotIndex, 4);
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (c.read(daylistProvider).value?.slotIndex != 5 && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(c.read(daylistProvider).value?.slotIndex, 5);
  });

  test('changing a slot makes the daylist again; so does regenerate()', () async {
    await addTracks(40);
    final c = open();
    await daylist(c);
    expect(suggestAsked, 1);
    final slot = c.read(daylistConfigProvider).slots[5];
    await c.read(daylistConfigProvider.notifier).setSlot(5, slot.copyWith(sharePercent: 10));
    final s = (await daylist(c))!;
    expect(suggestAsked, 2);
    expect(s.result.items.where((i) => i.suggestion != null), hasLength(5));
    expect(store.readDaylistConfig().slots[5].sharePercent, 10);
    await c.read(daylistActionsProvider).regenerate();
    await daylist(c);
    expect(suggestAsked, 3);
  });

  test('play: own songs and suggested ones as «suggerito» entries', () async {
    await addTracks(40);
    final c = open();
    await daylist(c);
    await c.read(daylistActionsProvider).play(shuffle: true);
    expect(player.items, hasLength(DaylistBuilder.size));
    expect(player.shuffle, isTrue);
    final online = player.items!.where((i) => i.online != null);
    expect(online, hasLength(15));
    expect(online.every((i) => i.track == null && i.seedTitle != null), isTrue);
  });

  test('regenerate() while a build is under way: the old build neither saves nor wins', () async {
    await addTracks(40);
    holdFirst = Completer<void>();
    final c = open();
    unawaited(c.read(daylistProvider.future).then((_) {}, onError: (Object _) {}));
    while (suggestAsked == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await c.read(daylistActionsProvider).regenerate();
    final fresh = (await daylist(c))!;
    expect(forced, [false, true], reason: 'the user asked for the second one');
    holdFirst!.complete();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(ids(fresh).whereType<String>().every((id) => id.startsWith('s2_')), isTrue);
    expect(File(p.join(dir.path, 'daylist.json')).readAsStringSync(), contains('s2_'));
    expect(File(p.join(dir.path, 'daylist.json')).readAsStringSync(), isNot(contains('s1_')));
    expect(ids((await daylist(c))!), ids(fresh));
  });

  test('back from a suspend after the slot ended (the timer did not run): a new daylist', () async {
    await addTracks(40);
    clock = () => evening;
    final c = open();
    expect((await daylist(c))!.slotIndex, 4);
    clock = () => lateEvening;
    final b = TestWidgetsFlutterBinding.instance;
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      b.handleAppLifecycleStateChanged(st);
    }
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (c.read(daylistProvider).value?.slotIndex != 5 && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(c.read(daylistProvider).value?.slotIndex, 5);
  });

  test('play() after the slot ended waits for the new daylist', () async {
    await addTracks(40);
    clock = () => evening;
    final c = open();
    await daylist(c);
    clock = () => lateEvening;
    await c.read(daylistActionsProvider).play();
    expect(suggestAsked, 2);
    expect(player.items!.where((i) => i.online != null).every((i) => i.online!.id.startsWith('s2_')), isTrue);
  });

  test('play() leaves out suggested songs blocked since the daylist was saved; startIndex counts the rest', () async {
    await addTracks(40);
    final c = open();
    final s = (await daylist(c))!;
    final firstSuggested = s.result.items.indexWhere((i) => i.suggestion != null);
    final blocked = s.result.items[firstSuggested].suggestion!.result;
    dislikes.blockTrack(DislikedTrack(videoId: blocked.id, title: blocked.title, artist: 'x'));
    // The row after the removed one, counted in the list the user sees.
    await c.read(daylistActionsProvider).play(startIndex: firstSuggested);
    expect(player.items, hasLength(DaylistBuilder.size - 1));
    expect(player.items!.any((i) => i.online?.id == blocked.id), isFalse);
    expect(player.index, firstSuggested, reason: 'the row after the removed one');
  });

  test('the visible daylist drops suggested songs of a blocked song or artist at once, saved one untouched', () async {
    await addTracks(40);
    final c = open();
    final s = (await daylist(c))!;
    c.listen(daylistVisibleProvider, (_, _) {});
    await c.read(daylistProvider.future);
    await dislikes.load();
    await Future<void>.delayed(const Duration(milliseconds: 50)); // the store listener is up
    expect(c.read(daylistVisibleProvider)!.result.items, hasLength(s.result.items.length));
    final sug = [
      for (final i in s.result.items)
        if (i.suggestion != null) i.suggestion!.result,
    ];
    dislikes.blockTrack(DislikedTrack(videoId: sug[0].id, title: sug[0].title, artist: 'x'));
    await Future<void>.delayed(Duration.zero);
    expect(c.read(daylistVisibleProvider)!.result.items, hasLength(s.result.items.length - 1));
    final key = suggestionArtistKey(sug[1]);
    dislikes.blockArtist(DislikedArtist(key: key, name: sug[1].artists.first));
    await Future<void>.delayed(Duration.zero);
    final left = c.read(daylistVisibleProvider)!.result.items;
    expect(left.where((i) => i.suggestion != null && suggestionArtistKey(i.suggestion!.result) == key), isEmpty);
    expect(left.length, lessThan(s.result.items.length - 1));
    expect((await daylist(c))!.result.items, hasLength(s.result.items.length));
  });

  test('without the network and with suggestions wanted, nothing is saved: the next start tries again', () async {
    await addTracks(20);
    offline = true;
    await daylist(open());
    expect(File(p.join(dir.path, 'daylist.json')).existsSync(), isFalse);
  });

  test('a suggestion source that throws: own songs only, no error', () async {
    await addTracks(20);
    final c = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        databaseProvider.overrideWithValue(db),
        daylistClockProvider.overrideWithValue(() => clock()),
        daylistFileProvider.overrideWithValue(() async => File(p.join(dir.path, 'daylist.json'))),
        daylistSuggestProvider.overrideWithValue(
          (cancelled, {force = false}) async => throw StateError('log unreadable'),
        ),
      ],
    );
    addTearDown(c.dispose);
    final s = (await daylist(c))!;
    expect(s.result.items, hasLength(20));
  });

  test('a change of the settings waits and makes one build for a few taps', () async {
    await addTracks(40);
    settle = const Duration(milliseconds: 500);
    final c = open();
    c.listen(daylistProvider, (_, _) {}); // listened: every change rebuilds at once
    await daylist(c);
    expect(suggestAsked, 1);
    final n = c.read(daylistConfigProvider.notifier);
    for (final share in [10, 20, 40]) {
      await n.setSlot(5, c.read(daylistConfigProvider).slots[5].copyWith(sharePercent: share));
    }
    await daylist(c);
    expect(suggestAsked, 2);
  });

  test('touching another slot (even a switched-off one) leaves the daylist alone', () async {
    await addTracks(40);
    final c = open();
    c.listen(daylistProvider, (_, _) {});
    final first = (await daylist(c))!;
    final other = c.read(daylistConfigProvider).slots[2];
    await c.read(daylistConfigProvider.notifier).setSlot(2, other.copyWith(sharePercent: 5, enabled: false));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(suggestAsked, 1);
    expect(ids((await daylist(c))!), ids(first));
    // And a restart finds the saved one still good.
    await daylist(open());
    expect(suggestAsked, 1);
  });

  test('reset() takes the keys out of the preferences instead of writing the defaults', () async {
    final c = open();
    final cfg = c.read(daylistConfigProvider.notifier);
    await cfg.setSlot(5, c.read(daylistConfigProvider).slots[5].copyWith(sharePercent: 7));
    await c.read(moodTableProvider.notifier).setMoods('rock', {});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(daylistSlotsKey), isTrue);
    expect(prefs.containsKey(moodTableKey), isTrue);
    await cfg.reset();
    expect(prefs.containsKey(daylistSlotsKey), isFalse);
    expect(prefs.containsKey(moodTableKey), isTrue, reason: 'the other one is not touched');
    expect(c.read(daylistConfigProvider).slots[5].sharePercent, 30);
    await c.read(moodTableProvider.notifier).reset();
    expect(prefs.containsKey(moodTableKey), isFalse);
    expect(c.read(moodTableProvider).moodsOf('rock'), isNotEmpty);
  });

  test('daylist.json emptied (Memoria, «Svuota cache»): the daylist is made again, no error', () async {
    await addTracks(40);
    await daylist(open());
    File(p.join(dir.path, 'daylist.json')).deleteSync();
    final s = (await daylist(open()))!;
    expect(s.result.tooFew, isFalse);
    expect(suggestAsked, 2);
  });
}

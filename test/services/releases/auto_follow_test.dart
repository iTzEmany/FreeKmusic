import 'package:codecore/data/repositories/artist_alias_repository.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/follow_repository.dart';
import 'package:codecore/data/repositories/play_history_repository.dart';
import 'package:codecore/data/repositories/stats_queries.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/releases/auto_follow.dart';
import 'package:codecore/services/releases/auto_follow_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

YtmArtistRef ref(String id, String name) => YtmArtistRef(id: id, name: name);
({String key, String name}) top(String name) => (key: name.toLowerCase(), name: name);

void main() {
  group('planAutoFollow', () {
    test('adds a resolved artist, resolves the unknown names, asks about the unclear', () {
      final plan = planAutoFollow(
        top: [top('A'), top('B'), top('C'), top('D')],
        followedIds: {},
        autoIds: {},
        excludedIds: {},
        resolved: {'a': ResolvedArtist(ref('UCa', 'A')), 'c': const Ambiguous(), 'd': const NoMatch()},
      );
      expect(plan.toAdd.map((a) => a.id), ['UCa']);
      expect(plan.toResolve, ['b']);
      expect(plan.toConfirm.map((c) => (c.name, c.nobody)), [('C', false), ('D', true)]);
      expect(plan.toRemove, isEmpty);
    });

    test('never touches artists followed by hand and never re-adds an excluded one', () {
      final plan = planAutoFollow(
        top: [top('A'), top('B')],
        followedIds: {'UCa', 'UCold'},
        autoIds: {},
        excludedIds: {'UCb'},
        resolved: {'a': ResolvedArtist(ref('UCa', 'A')), 'b': ResolvedArtist(ref('UCb', 'B'))},
      );
      expect(plan.toAdd, isEmpty);
      expect(plan.toRemove, isEmpty); // UCold is by hand
    });

    test('an automatic artist that left the top is removed, once every lookup is done', () {
      final resolved = {'a': ResolvedArtist(ref('UCa', 'A'))};
      final plan = planAutoFollow(
          top: [top('A')], followedIds: {'UCa', 'UCx'}, autoIds: {'UCa', 'UCx'}, excludedIds: {}, resolved: resolved);
      expect(plan.toRemove, ['UCx']);
      final pending = planAutoFollow(
          top: [top('A'), top('B')], followedIds: {'UCx'}, autoIds: {'UCx'}, excludedIds: {}, resolved: resolved);
      expect(pending.toRemove, isEmpty);
    });

    test('the top is capped at 15', () {
      final names = [for (var i = 0; i < 20; i++) top('N$i')];
      final plan = planAutoFollow(
          top: names, followedIds: {}, autoIds: {}, excludedIds: {}, resolved: const {});
      expect(plan.toResolve.length, 15);
    });
  });

  group('AutoFollowService', () {
    late AppDatabase db;
    late FollowRepository follows;
    late List<String> searched, waits;
    late Map<String, List<YtmArtistRef>> catalog;

    Future<void> listened(String artist, int ms) async {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/$artist.mp3', title: artist, albumKey: 'k', format: 'mp3',
          sizeBytes: 1, mtimeMs: 1, addedAt: 1, artist: Value(artist)));
      final id = (await (db.select(db.tracks)..where((t) => t.path.equals('/$artist.mp3'))).getSingle()).id;
      await PlayHistoryRepository(db).start(id, DateTime(2026, 10, 1).millisecondsSinceEpoch, msPlayed: ms);
    }

    AutoFollowService service({int max = 5}) => AutoFollowService(
          stats: StatsQueries(db),
          follows: follows,
          now: () => DateTime(2026, 10, 22),
          maxLookups: max,
          aliases: ArtistAliasRepository(db),
          wait: (d) async => waits.add('${d.inMilliseconds}'),
          search: (name) async {
            searched.add(name);
            return catalog[name] ?? const [];
          },
        );

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      follows = FollowRepository(db, now: () => DateTime(2026, 10, 22).millisecondsSinceEpoch);
      searched = [];
      waits = [];
      catalog = {};
    });
    tearDown(() => db.close());

    test('follows the unique same name, leaves two namesakes to confirm, and remembers answers', () async {
      await listened('Solo', 400);
      await listened('Twin', 300);
      await listened('Nobody', 200);
      catalog = {
        'Solo': [ref('UC1', 'Solo'), ref('UC9', 'Solo Band')],
        'Twin': [ref('UC2', 'Twin'), ref('UC3', 'Twin')],
      };
      final plan = await service().run();
      expect((await follows.all()).map((a) => (a.ytmId, a.isAuto)), [('UC1', true)]);
      expect(plan.toConfirm.map((c) => c.name), ['Twin', 'Nobody']);
      expect(searched, ['Solo', 'Twin', 'Nobody']);
      expect(waits, ['1500', '1500']);
      // Second round: nothing is asked again.
      await service().run();
      expect(searched.length, 3);
    });

    test('asks at most 5 names a round and removes nobody while some are pending', () async {
      await follows.followAuto(ref('UCold', 'Old'));
      for (var i = 0; i < 7; i++) {
        await listened('Artist$i', 1000 - i);
        catalog['Artist$i'] = [ref('UC$i', 'Artist$i')];
      }
      await service().run();
      expect(searched.length, 5);
      expect((await follows.all()).map((a) => a.ytmId), containsAll(['UCold', 'UC0', 'UC4']));
      await service().run();
      expect(searched.length, 7);
      final ids = (await follows.all()).map((a) => a.ytmId).toSet();
      expect(ids.contains('UCold'), isFalse);
      expect(ids.length, 7);
    });

    test('two namesakes that are one merged artist are followed, not left to confirm', () async {
      await listened('Twin', 300);
      await ArtistAliasRepository(db).merge('UC2', 'UC3');
      catalog = {'Twin': [ref('UC2', 'Twin'), ref('UC3', 'Twin')]};
      final plan = await service().run();
      expect((await follows.all()).map((a) => a.ytmId), ['UC2']);
      expect(plan.toConfirm, isEmpty);
    });

    test('a stopped search leaves the rest for the next round', () async {
      await listened('Solo', 400);
      final s = AutoFollowService(
        stats: StatsQueries(db),
        follows: follows,
        now: () => DateTime(2026, 10, 22),
        search: (_) => throw const YtException(YtErrorKind.rateLimited),
      );
      await s.run();
      expect(await follows.all(), isEmpty);
      expect(await follows.lookups(), isEmpty);
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:codecore/core/clock.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/favorite_collections_repository.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:codecore/services/share/settings_sync.dart';
import 'package:codecore/services/share/tables_sync.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// Two devices, two in-memory DBs, the plan and the apply of the app (no network): the sync in both directions, with
// changes and deletions on both sides, must converge in two rounds, do nothing in the third and never touch a file
// or a library row (D-668, D-709).

int _clock = 0;
int _current = 0;
List<int> _skew = [0, 0];

YtResult _yt(String id) =>
    YtResult(id: id, title: 'T$id', channel: 'Ch', duration: null);
const _s1 = 'aaaaaaaaaaa', _s2 = 'bbbbbbbbbbb', _s3 = 'ccccccccccc';

class _Dev {
  _Dev(this.i, this.dir) : db = AppDatabase(NativeDatabase.memory()) {
    playlists = PlaylistRepository(db);
    sync = PlaylistSyncRepository(db);
    tracks = TrackRepository(db);
    favorites = FavoriteCollectionsRepository(db);
  }

  final int i;
  final Directory dir;
  final AppDatabase db;
  late final PlaylistRepository playlists;
  late final PlaylistSyncRepository sync;
  late final TrackRepository tracks;
  late final FavoriteCollectionsRepository favorites;
  AppSettings settings = const AppSettings();

  String get root => p.join(dir.path, 'dev$i');

  /// Three tracks with a real (fake) file each, the same names on both devices under another root.
  Future<void> seed() async {
    Directory(root).createSync(recursive: true);
    final folder = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(path: root, addedAt: 1));
    for (final n in ['a', 'b', 'c']) {
      File(p.join(root, '$n.mp3')).writeAsStringSync('audio $i $n');
    }
    await tracks.upsertBatch([
      for (final n in ['a', 'b', 'c'])
        TracksCompanion.insert(
          path: p.join(root, '$n.mp3'),
          title: n,
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          artist: const Value('Art'),
          durationMs: const Value(180000),
          folderId: Value(folder),
        ),
    ]);
  }

  Future<int> id(String n) async =>
      (await tracks.idForPath(p.join(root, '$n.mp3')))!;

  Future<void> at(Future<void> Function() op) async {
    _current = i;
    _clock += 1000;
    await op();
  }

  Future<String> playlistId(String name) async =>
      (await sync.local()).firstWhere((l) => l.name == name).uuid;

  Future<int> playlistRow(String name) async =>
      (await sync.local()).firstWhere((l) => l.name == name).id;

  Future<void> setLyrics(String n, String text) =>
      (db.update(db.tracks)
            ..where((t) => t.path.equals(p.join(root, '$n.mp3'))))
          .write(TracksCompanion(lyricsPlain: Value(text)));

  Future<void> play(String n, int at) async => db
      .into(db.plays)
      .insert(
        PlaysCompanion.insert(
          trackId: await id(n),
          playedAt: at,
          msPlayed: const Value(1000),
        ),
      );

  Future<void> tag(String name, List<String> on) async {
    final tagId = await db
        .into(db.userTags)
        .insert(UserTagsCompanion.insert(name: name));
    for (final n in on) {
      await db
          .into(db.trackTags)
          .insert(
            TrackTagsCompanion.insert(trackId: await id(n), tagId: tagId),
          );
    }
  }

  Future<void> save(String k) => tracks.saveStream(_yt(k));

  Future<void> unsave(String k) => tracks.setSaved('youtube:$k', false);

  Future<void> heart(String k, bool on) async =>
      tracks.setFavoriteMany([await tracks.ensureStreamRow(_yt(k))], on);

  /// Everything a sync is meant to make equal, with playlists by uuid so a rename shows.
  Future<String> state() async {
    final pl = <String>[];
    for (final l in await sync.local()) {
      final titles = [
        for (final t in l.trackIds) (await tracks.getById(t))!.title,
      ];
      pl.add('${l.uuid}:${l.name}:${titles.join(",")}');
    }
    pl.sort();
    final fav = [for (final f in await sync.favorites()) '${f.kind}/${f.key}']
      ..sort();
    final st = await sync.streams();
    final saved = [
      for (final s in st)
        if (s.saved) s.key,
    ]..sort();
    final hearts = [
      for (final s in st)
        if (s.favorite) s.key,
    ]..sort();
    final tx = [
      for (final t in (await sync.texts(0)).texts) '${t.ref.title}:${t.plain}',
    ]..sort();
    final plays = [
      for (final r in await db.select(db.plays).get())
        '${(await tracks.getById(r.trackId))!.title}@${r.playedAt}',
    ]..sort();
    final tg =
        (await sync.tags()).tagged
            .map((t) => '${t.ref.title}:${(t.tags.toList()..sort()).join("+")}')
            .toList()
          ..sort();
    final tags = [for (final t in await db.select(db.userTags).get()) t.name]
      ..sort();
    return 'PL=$pl FAV=$fav SAVED=$saved HEART=$hearts TEXT=$tx PLAYS=$plays TAGGED=$tg TAGS=$tags SET=${syncedSettings(settings)}';
  }

  /// The library rows (kind 0) without the lyrics, which a sync may legitimately fill.
  Future<String> library() async =>
      (await db
              .customSelect(
                'SELECT id,path,title,artist,is_favorite,sha256 FROM tracks WHERE kind = 0 ORDER BY id',
              )
              .get())
          .map((r) => r.data.toString())
          .join('|');

  Future<Set<String>> tombstoneKeys() async => {
    for (final t in await sync.tombstones())
      '${t.kind}/${t.key}@${t.deletedAt}',
  };
}

Future<SyncPlan> _plan(_Dev me, _Dev other, {required bool mine}) async {
  _current = me.i;
  final resolver = await me.sync.resolver();
  // The other device's data as the routes send it: through JSON.
  Object? wire(Object? j) => jsonDecode(jsonEncode(j));
  final tags = await other.sync.tags();
  final theirs = TablesBundle(
    texts: [
      for (final t in (await other.sync.texts(0)).texts)
        ?TextEntry.tryParse(wire(t.toJson())),
    ],
    plays: [
      for (final x in await other.sync.plays())
        ?PlayEntry.tryParse(wire(x.toJson())),
    ],
    tags: [for (final t in tags.tags) ?TagEntry.tryParse(wire(t.toJson()))],
    tagged: [
      for (final t in tags.tagged) ?TaggedTrack.tryParse(wire(t.toJson())),
    ],
  );
  return planSync(
    await me.sync.local(),
    await other.sync.export(),
    resolver.resolve,
    localSide: await me.sync.side(settings: syncedSettings(me.settings)),
    // As the client does for a device that is not «mine»: nothing but the playlists is read.
    remoteSide: !mine
        ? const SyncSide()
        : SyncSide(
            favorites: await other.sync.favorites(),
            streams: await other.sync.streams(),
            tombstones: mine ? await other.sync.tombstones() : const [],
            settings: syncedSettings(other.settings),
            tables: mine
                ? await me.sync.newTables(theirs, resolver)
                : const TablesBundle(),
          ),
    mine: mine,
  );
}

/// One sync of [me] from [other], as the user would confirm it everything (settings included). False: nothing to do.
Future<bool> _pull(_Dev me, _Dev other, {bool mine = true}) async {
  _clock += 1000;
  final plan = await _plan(me, other, mine: mine);
  if (plan.isEmpty) return false;
  _current = me.i;
  await me.sync.apply(
    plan,
    applyCollections: true,
    resolver: await me.sync.resolver(),
  );
  me.settings = applySettings(me.settings, plan.collections.settings);
  return true;
}

/// A round: each pulls from the other, in [order].
Future<bool> _round(_Dev a, _Dev b, {bool aFirst = true}) async {
  final x = aFirst ? await _pull(a, b) : await _pull(b, a);
  final y = aFirst ? await _pull(b, a) : await _pull(a, b);
  return x || y;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late _Dev a, b;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('sync-two');
    _clock = DateTime.now().millisecondsSinceEpoch - 5 * 86400000;
    _skew = [0, 0];
    nowMsOverride = () => _clock + _skew[_current];
    a = _Dev(0, dir);
    b = _Dev(1, dir);
    await a.seed();
    await b.seed();
  });
  tearDown(() async {
    nowMsOverride = null;
    await a.db.close();
    await b.db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> expectConverged(String why) async {
    expect(await b.state(), await a.state(), reason: why);
  }

  /// Two rounds make both sides equal, the third has an empty plan both ways and changes nothing.
  Future<void> twoRoundsThenQuiet(String phase, {bool aFirst = true}) async {
    await _round(a, b, aFirst: aFirst);
    await _round(a, b, aFirst: !aFirst);
    await expectConverged('$phase: not equal after 2 rounds');
    final before = [await a.state(), await b.state()];
    expect(
      (await _plan(a, b, mine: true)).isEmpty,
      isTrue,
      reason: '$phase: a<-b plan not empty in round 3',
    );
    expect(
      (await _plan(b, a, mine: true)).isEmpty,
      isTrue,
      reason: '$phase: b<-a plan not empty in round 3',
    );
    expect(
      await _round(a, b),
      isFalse,
      reason: '$phase: round 3 changed something',
    );
    expect(
      [await a.state(), await b.state()],
      before,
      reason: '$phase: round 3 changed the state',
    );
  }

  /// [strict]: the clocks agree, so the later action wins and the deletions below must show; with skewed clocks only
  /// the convergence is checked (a deletion stamped earlier than a creation loses, as it should).
  Future<void> scenario({bool strict = true}) async {
    final libraryBefore = [await a.library(), await b.library()];

    // Phase 1: both sides create things, in different order; settings differ on one allowed key.
    await a.at(() async {
      final pa = await a.playlists.create('PA');
      await a.playlists.addTracks(pa, [await a.id('a'), await a.id('b')]);
      await a.playlists.create('PX');
    });
    await b.at(() async {
      final pb = await b.playlists.create('PB');
      await b.playlists.addTracks(pb, [await b.id('b'), await b.id('c')]);
    });
    await a.at(() async {
      await a.favorites.toggle('album', 'art|alb0');
      await a.save(_s1);
      await a.save(_s2);
      await a.heart(_s1, true);
      await a.setLyrics('a', 'lyrics of a');
      await a.play('a', 1000);
      await a.tag('rock', ['a']);
    });
    await b.at(() async {
      await b.favorites.toggle('album', 'art|alb1');
      await b.save(_s3);
      await b.heart(_s2, true);
      await b.setLyrics('b', 'lyrics of b');
      await b.play('b', 2000);
      await b.tag('sera', ['b', 'c']);
    });
    b.settings = b.settings.copyWith(theme: 'oled');
    await twoRoundsThenQuiet('phase 1');
    expect(a.settings.theme, 'oled', reason: 'the chosen setting is applied');
    expect((await a.state()).contains('PX'), isTrue);

    // Phase 2: deletions and edits on both sides, the other way round.
    await b.at(() async {
      await b.playlists.delete(await b.playlistRow('PX'));
      await b.playlists.rename(await b.playlistRow('PA'), 'PA2');
      await b.heart(_s1, false);
      await b.unsave(_s2);
    });
    await a.at(() async {
      await a.playlists.delete(await a.playlistRow('PB'));
      await a.favorites.toggle(
        'album',
        'art|alb1',
      ); // un-favourite what b added
      await a.unsave(_s3);
      await a.favorites.toggle('playlist', await a.playlistId('PA'));
      await a.play('c', 3000);
      await a.setLyrics('c', 'lyrics of c');
    });
    await twoRoundsThenQuiet('phase 2', aFirst: false);
    final s = await a.state();
    if (strict) {
      expect(s.contains('PX'), isFalse, reason: 'PX deleted on b');
      expect(s.contains(':PB:'), isFalse, reason: 'PB deleted on a');
      expect(s.contains('PA2'), isTrue, reason: 'rename travelled');
      expect(s.contains('youtube:$_s3'), isFalse, reason: 'unsaved on a');
    }

    // Phase 3: same-item edits, a heart and a favourite put back after the deletion, a new playlist.
    await a.at(() async {
      await a.favorites.toggle('album', 'art|alb1');
      await a.heart(_s1, true);
    });
    await b.at(() async {
      await b.playlists.create('PN');
      await b.save(_s3);
    });
    await twoRoundsThenQuiet('phase 3');

    // Nothing but data changed: no file and no library row.
    for (final d in [a, b]) {
      for (final n in ['a', 'b', 'c']) {
        expect(
          File(p.join(d.root, '$n.mp3')).existsSync(),
          isTrue,
          reason: 'file $n of dev${d.i} is gone',
        );
        expect(
          File(p.join(d.root, '$n.mp3')).readAsStringSync(),
          'audio ${d.i} $n',
        );
      }
    }
    expect(
      [await a.library(), await b.library()],
      libraryBefore,
      reason: 'kind 0 rows changed',
    );
  }

  test(
    'two own devices converge in two rounds, the third changes nothing, no file or library row is touched',
    () => scenario(),
  );

  test('the same scenario with clocks a few minutes apart still converges and stays quiet', () async {
    _skew = [0, 4 * 60 * 1000];
    await scenario(strict: false);
    _skew = [0, -7 * 60 * 1000];
    await a.at(() async => a.playlists.create('PLate'));
    await b.at(() async => b.playlists.create('PEarly'));
    await twoRoundsThenQuiet('skewed clocks');
  });

  test('a device that is not «mine» gets no tombstone and no deletion, only playlists are added', () async {
    // Both sides have history with deletions, as in the scenario.
    await a.at(() async {
      final pa = await a.playlists.create('PA');
      await a.playlists.addTracks(pa, [await a.id('a')]);
      await a.playlists.create('PX');
      await a.favorites.toggle('album', 'art|alb0');
      await a.save(_s1);
      await a.setLyrics('a', 'lyrics of a');
      await a.play('a', 1000);
    });
    await b.at(() async {
      await b.playlists.create('PB');
      await b.favorites.toggle('album', 'art|alb1');
      await b.favorites.toggle('album', 'art|alb2');
      await b.favorites.toggle('album', 'art|alb2'); // a tombstone here
      await b.save(_s3);
      await b.save(_s2);
      await b.unsave(_s2); // and a deleted saved stream
      await b.setLyrics('b', 'lyrics of b');
      await b.play('b', 2000);
    });
    await b.at(() async => b.playlists.delete(await b.playlistRow('PB')));
    await b.at(() async => b.playlists.create('PB2'));
    b.settings = b.settings.copyWith(theme: 'oled');

    final libraryBefore = [await a.library(), await b.library()];
    final tombsBefore = [await a.tombstoneKeys(), await b.tombstoneKeys()];
    final stateBefore = [await a.state(), await b.state()];
    expect(
      tombsBefore[1],
      isNotEmpty,
      reason: 'the scenario must offer tombstones to refuse',
    );

    final plan = await _plan(a, b, mine: false);
    expect(plan.collections.deletes, isEmpty);
    expect(plan.collections.learned, isEmpty);
    expect(plan.collections.tables.isEmpty, isTrue);
    expect(plan.collections.settings, isEmpty);

    for (var r = 0; r < 3; r++) {
      await _pull(a, b, mine: false);
      await _pull(b, a, mine: false);
    }
    expect(
      await a.tombstoneKeys(),
      tombsBefore[0],
      reason: 'a tombstone crossed to a',
    );
    expect(
      await b.tombstoneKeys(),
      tombsBefore[1],
      reason: 'a tombstone crossed to b',
    );
    final after = [await a.state(), await b.state()];
    // Playlists are added both ways, and nothing is lost on either side; no collection, text, listen or setting moves.
    expect(after[0].contains('PB2'), isTrue);
    expect(after[1].contains('PA'), isTrue);
    String section(String s, String name) =>
        RegExp('$name=(\\[.*?\\]|\\{.*?\\})').firstMatch(s)!.group(1)!;
    for (final k in [
      'FAV',
      'SAVED',
      'HEART',
      'TEXT',
      'PLAYS',
      'TAGGED',
      'TAGS',
      'SET',
    ]) {
      for (var i = 0; i < 2; i++) {
        expect(
          section(after[i], k),
          section(stateBefore[i], k),
          reason: '$k moved on dev$i with a non-mine device',
        );
      }
    }
    for (var i = 0; i < 2; i++) {
      final lost = RegExp(r'\w{8}-\w{4}-\w{4}-\w{4}-\w{12}')
          .allMatches(stateBefore[i])
          .map((m) => m.group(0))
          .toSet()
          .difference(
            RegExp(r'\w{8}-\w{4}-\w{4}-\w{4}-\w{12}')
                .allMatches(after[i])
                .map((m) => m.group(0))
                .toSet(),
          );
      expect(lost, isEmpty, reason: 'a playlist disappeared from dev$i');
    }
    expect([await a.library(), await b.library()], libraryBefore);
    for (final d in [a, b]) {
      for (final n in ['a', 'b', 'c']) {
        expect(File(p.join(d.root, '$n.mp3')).existsSync(), isTrue);
      }
    }
  });
}

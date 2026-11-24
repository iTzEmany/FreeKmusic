import 'dart:convert';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/play_context_kind.dart';
import 'package:codecore/data/repositories/playlist_sync_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/share/collection_sync.dart';
import 'package:codecore/services/share/playlist_sync.dart';
import 'package:codecore/services/share/tables_sync.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A device: its own DB, its music folder at [root] and the files in [names].
class _Device {
  _Device(this.root, this.names) : db = AppDatabase(NativeDatabase.memory()) {
    sync = PlaylistSyncRepository(db);
  }

  final String root;
  final List<String> names;
  final AppDatabase db;
  late final PlaylistSyncRepository sync;

  Future<void> seed() async {
    final folder = await db
        .into(db.folders)
        .insert(FoldersCompanion.insert(path: root, addedAt: 1));
    await TrackRepository(db).upsertBatch([
      for (final n in names)
        TracksCompanion.insert(
          path: '$root/$n.mp3',
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

  Future<int> id(String name) async =>
      (await TrackRepository(db).idForPath('$root/$name.mp3'))!;

  Future<void> lyrics(
    String name, {
    String? plain,
    String? synced,
    String? curiosities,
  }) async {
    final trackId = await id(name);
    await (db.update(db.tracks)..where((t) => t.id.equals(trackId))).write(
      TracksCompanion(
        lyricsPlain: Value(plain),
        lyricsSynced: Value(synced),
        curiosities: Value(curiosities),
      ),
    );
  }

  Future<void> play(
    String name,
    int at, {
    int? context,
    String? contextName,
    int ms = 1000,
  }) async => db
      .into(db.plays)
      .insert(
        PlaysCompanion.insert(
          trackId: await id(name),
          playedAt: at,
          msPlayed: Value(ms),
          context: Value(context),
          contextName: Value(contextName),
        ),
      );

  Future<void> tag(String tag, {int? color, List<String> on = const []}) async {
    final tagId = await db
        .into(db.userTags)
        .insert(UserTagsCompanion.insert(name: tag, color: Value(color)));
    for (final n in on) {
      await db
          .into(db.trackTags)
          .insert(
            TrackTagsCompanion.insert(trackId: await id(n), tagId: tagId),
          );
    }
  }

  /// This device's data as the routes send it and a client reads it back (through JSON).
  Future<TablesBundle> sent() async {
    Object? wire(Object? j) => jsonDecode(jsonEncode(j));
    final tags = await sync.tags();
    return TablesBundle(
      texts: [
        for (final t in (await sync.texts(0)).texts)
          ?TextEntry.tryParse(wire(t.toJson())),
      ],
      plays: [
        for (final p in await sync.plays())
          ?PlayEntry.tryParse(wire(p.toJson())),
      ],
      tags: [for (final t in tags.tags) ?TagEntry.tryParse(wire(t.toJson()))],
      tagged: [
        for (final t in tags.tagged) ?TaggedTrack.tryParse(wire(t.toJson())),
      ],
    );
  }

  /// What a sync from [other] does here. [mine] is what the client thinks; the tables go through the same cut
  /// as in the app, whatever [mine] says (the plan must still refuse them for a device that is not «mine»).
  Future<SyncPlan> planFrom(
    _Device other, {
    bool mine = true,
    Map<String, Object> mySettings = const {},
    Map<String, Object> theirSettings = const {},
  }) async {
    final resolver = await sync.resolver();
    return planSync(
      await sync.local(),
      await other.sync.export(),
      resolver.resolve,
      localSide: await sync.side(settings: mySettings),
      remoteSide: SyncSide(
        settings: theirSettings,
        tables: await sync.newTables(await other.sent(), resolver),
      ),
      mine: mine,
    );
  }

  Future<void> apply(SyncPlan plan) => sync.apply(plan, applyCollections: true);

  Future<Set<(String, int)>> plays() async {
    final rows = await db.select(db.plays).get();
    final titles = {
      for (final t in await db.select(db.tracks).get()) t.id: t.title,
    };
    return {for (final r in rows) (titles[r.trackId]!, r.playedAt)};
  }

  Future<Set<(String, String)>> tagged() async {
    final names = {
      for (final t in await db.select(db.userTags).get()) t.id: t.name,
    };
    final titles = {
      for (final t in await db.select(db.tracks).get()) t.id: t.title,
    };
    return {
      for (final r in await db.select(db.trackTags).get())
        (titles[r.trackId]!, names[r.tagId]!),
    };
  }

  Future<Track> track(String name) async =>
      (await TrackRepository(db).getById(await id(name)))!;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late _Device phone, pc;

  setUp(() async {
    phone = _Device('/storage/music', ['a', 'b', 'c']);
    pc = _Device('/home/me/Music', ['a', 'b']); // no «c», another root
    await phone.seed();
    await pc.seed();
    await phone.lyrics(
      'a',
      plain: 'La la',
      synced: '[00:01]La',
      curiosities: 'Fun',
    );
    await phone.lyrics('b', plain: 'Phone b');
    await phone.lyrics('c', plain: 'only c');
    await pc.lyrics('b', plain: 'PC b');
    await phone.play(
      'a',
      1000,
      context: PlayContextKind.playlist.index,
      contextName: 'Mix',
      ms: 5000,
    );
    await phone.play('a', 2000);
    await phone.play(
      'b',
      3000,
      context: 77,
    ); // a kind this version does not know
    await phone.play('c', 4000);
    await pc.play('a', 1000); // the same listen as the phone's first
    await pc.play('b', 5000);
    await phone.tag('rock', color: 3, on: ['a', 'b']);
    await phone.tag('sera');
    await pc.tag('ROCK', on: ['b']);
    await pc.tag('pc-only', on: ['a']);
  });
  tearDown(() async {
    await phone.db.close();
    await pc.db.close();
  });

  test('the plan keeps only what is new here: a text for an empty field, listens and tags not here, nothing for a track this library lacks', () async {
    final plan = await pc.planFrom(phone);
    final t = plan.collections.tables;
    expect(
      [for (final e in t.texts) e.ref.title],
      ['a'],
      reason: 'b has its text here, c is not here',
    );
    expect(
      {for (final p in t.plays) (p.ref.title, p.playedAt)},
      {('a', 2000), ('b', 3000)},
    );
    expect([for (final e in t.tags) e.name], ['sera'], reason: 'ROCK is rock');
    expect(
      [for (final e in t.tagged) '${e.ref.title}:${e.tags.join(',')}'],
      ['a:rock'],
    );
    expect(plan.isEmpty, isFalse);
  });

  test('a confirmed sync merges them without loss and without duplicates; a second one adds nothing', () async {
    await pc.apply(await pc.planFrom(phone));

    final a = await pc.track('a');
    expect(
      (a.lyricsPlain, a.lyricsSynced, a.curiosities),
      ('La la', '[00:01]La', 'Fun'),
    );
    expect(
      (await pc.track('b')).lyricsPlain,
      'PC b',
      reason: 'a text here is never replaced',
    );
    expect(await pc.plays(), {
      ('a', 1000),
      ('a', 2000),
      ('b', 3000),
      ('b', 5000),
    });
    expect(await pc.db.select(pc.db.plays).get(), hasLength(4));
    expect(await pc.tagged(), {('b', 'ROCK'), ('a', 'pc-only'), ('a', 'ROCK')});
    expect(
      [for (final t in await pc.db.select(pc.db.userTags).get()) t.name]
        ..sort(),
      ['ROCK', 'pc-only', 'sera'],
    );
    final unknown = (await pc.db.select(pc.db.plays).get()).firstWhere(
      (p) => p.playedAt == 3000,
    );
    expect(
      PlayContextKind.fromIndex(unknown.context),
      PlayContextKind.library,
      reason: 'an unknown kind reads as the library',
    );

    final again = await pc.planFrom(phone);
    expect(again.collections.tables.isEmpty, isTrue);
    expect(again.isEmpty, isTrue);
    await pc.apply(again);
    expect(await pc.db.select(pc.db.plays).get(), hasLength(4));
    expect(await pc.db.select(pc.db.trackTags).get(), hasLength(3));
  });

  test('both directions: each device ends with the union of the two, none loses anything', () async {
    await pc.apply(await pc.planFrom(phone));
    await phone.apply(await phone.planFrom(pc));
    await pc.apply(await pc.planFrom(phone));

    expect(await phone.plays(), {
      ('a', 1000),
      ('a', 2000),
      ('b', 3000),
      ('c', 4000),
      ('b', 5000),
    });
    expect(await pc.plays(), {
      ('a', 1000),
      ('a', 2000),
      ('b', 3000),
      ('b', 5000),
    }, reason: 'the listen of «c» waits for «c»');
    expect(await phone.tagged(), {
      ('a', 'rock'),
      ('b', 'rock'),
      ('a', 'pc-only'),
    });
    expect(
      {
        for (final t in await phone.db.select(phone.db.userTags).get())
          t.name.toLowerCase(),
      },
      {'rock', 'sera', 'pc-only'},
    );
    expect((await phone.track('b')).lyricsPlain, 'Phone b');
    expect((await phone.planFrom(pc)).isEmpty, isTrue);
    expect((await pc.planFrom(phone)).isEmpty, isTrue);
  });

  test('a device that is not «mine» changes nothing here: no setting, no text, no listen, no tag', () async {
    final plan = await pc.planFrom(
      phone,
      mine: false,
      mySettings: {'theme': 'notte'},
      theirSettings: {'theme': 'oled'},
    );
    expect(plan.collections.tables.isEmpty, isTrue);
    expect(plan.collections.settings, isEmpty);
    expect(plan.isEmpty, isTrue);
    await pc.apply(plan);
    expect(await pc.db.select(pc.db.plays).get(), hasLength(2));
    expect((await pc.track('a')).lyricsPlain, isNull);
  });

  test('the settings enter the plan as differences for the user to confirm, from an own device only', () async {
    final plan = await pc.planFrom(
      phone,
      mySettings: {'theme': 'notte', 'fontScale': 1.0},
      theirSettings: {'theme': 'oled', 'fontScale': 1.0, 'deviceName': 'evil'},
    );
    expect(
      [for (final c in plan.collections.settings) (c.key, c.local, c.remote)],
      [('theme', 'notte', 'oled')],
    );
  });

  test('texts come in pages: a full page names where to continue, the last one ends the list', () async {
    final big = _Device('/m', [
      for (var i = 0; i < kTextsPerPage + 5; i++) 't$i',
    ]);
    addTearDown(big.db.close);
    await big.seed();
    for (var i = 0; i < kTextsPerPage + 5; i++) {
      await big.lyrics('t$i', plain: 'w$i');
    }
    final first = await big.sync.texts(0);
    expect(first.texts, hasLength(kTextsPerPage));
    expect(first.next, isNotNull);
    final second = await big.sync.texts(first.next!);
    expect(second.texts, hasLength(5));
    expect(second.next, isNull);
    expect({
      ...first.texts.map((t) => t.ref.title),
      ...second.texts.map((t) => t.ref.title),
    }, hasLength(kTextsPerPage + 5));
  });
}

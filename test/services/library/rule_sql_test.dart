import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_kinds.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:codecore/services/library/rules/rule_sql.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = 86400000;

class _T {
  _T(this.n, {this.artist, this.album, this.genre, this.year, this.sec = 200, this.format = 'mp3',
      this.ageDays = 100, this.plays = 0, this.fav = false, this.folder = 'Rock', this.missing = false,
      String? title}) : title = title ?? 'Song $n';
  final int n;
  final String title;
  final String? artist, album, genre;
  final int? year;
  final int sec, ageDays, plays;
  final String format, folder;
  final bool fav, missing;
  int id = 0;
}

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  late List<_T> data;
  final now = DateTime(2026, 10, 16, 12);

  _T byTitle(String t) => data.firstWhere((x) => x.title == t);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    data = [
      for (var i = 0; i < 24; i++)
        _T(i,
            artist: ['Pink Floyd', 'Daft Punk', 'Lucio Dalla', 'Nina Simone', null, 'daft punk '][i % 6],
            album: i % 4 == 3 ? null : ['The Wall', 'Discovery', 'Canzoni'][i % 3],
            genre: i % 5 == 0 ? null : ['Rock', 'Electronic', 'Jazz', 'Pop'][i % 4],
            year: i % 7 == 0 ? null : 1965 + i * 2,
            sec: 60 + i * 20,
            format: i % 3 == 0 ? 'flac' : 'mp3',
            ageDays: i * 4,
            plays: i % 3 == 0 ? 0 : i,
            fav: i % 4 == 0,
            folder: i % 2 == 0 ? 'Rock' : 'Jazz'),
      _T(24, title: "100% pure_love's \\ test", artist: 'Special'),
      _T(25, title: 'Gone', artist: 'Pink Floyd', missing: true),
      _T(26, title: 'Another one', artist: 'Pink Floyd', genre: 'Rock', year: 1973, ageDays: 2),
      _T(27, title: 'Quoted "name"', artist: 'X'),
    ];
    for (final t in data) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
            path: '/music/${t.folder}/${t.n}.${t.format}',
            title: t.title,
            albumKey: '${t.artist}|${t.album}',
            format: t.format,
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: now.millisecondsSinceEpoch - t.ageDays * _day - 1000,
            artist: Value(t.artist),
            album: Value(t.album),
            genre: Value(t.genre),
            year: Value(t.year),
            durationMs: Value(t.sec * 1000),
            playCount: Value(t.plays),
            isFavorite: Value(t.fav),
            missing: Value(t.missing),
          ));
      t.id = (await repo.idForPath('/music/${t.folder}/${t.n}.${t.format}'))!;
    }
  });
  tearDown(() => db.close());

  /// Ids of the tracks the rules select, as a set.
  Future<Set<int>> run(String rules, {DateTime? at}) async =>
      {for (final t in await repo.watchByRules(parseRules(rules).expr, now: at ?? now).first) t.id};

  Set<int> expected(bool Function(_T) test) =>
      {for (final t in data) if (!t.missing && test(t)) t.id};

  bool has(String? v, String needle) => (v ?? '').toLowerCase().contains(needle.toLowerCase());

  test('free words look in title, artist and album, ignoring case', () async {
    expect(await run('floyd'), expected((t) => has(t.artist, 'floyd') || has(t.title, 'floyd') || has(t.album, 'floyd')));
    expect(await run('wall'), expected((t) => has(t.album, 'wall') || has(t.title, 'wall')));
    expect(await run('song 1'), expected((t) => (has(t.title, 'song') || has(t.artist, 'song') || has(t.album, 'song')) &&
        (has(t.title, '1') || has(t.artist, '1') || has(t.album, '1'))));
  });

  test('an empty rule is every available track; missing tracks never show', () async {
    final all = await run('');
    expect(all, expected((_) => true));
    expect(all, isNot(contains(byTitle('Gone').id)));
    expect(await run('artista:floyd'), isNot(contains(byTitle('Gone').id)));
  });

  test('text fields', () async {
    expect(await run('artista:daft'), expected((t) => has(t.artist, 'daft')));
    expect(await run('artist:"daft punk"'), expected((t) => has(t.artist, 'daft punk')));
    expect(await run('album:discovery'), expected((t) => has(t.album, 'discovery')));
    expect(await run('genere:jazz'), expected((t) => has(t.genre, 'jazz')));
    expect(await run('cartella:jazz'), expected((t) => '/music/${t.folder}/'.toLowerCase().contains('jazz')));
  });

  test('format is matched whole', () async {
    expect(await run('formato:flac'), expected((t) => t.format == 'flac'));
    expect(await run('format:FLAC'), expected((t) => t.format == 'flac'));
    expect(await run('formato:fla'), isEmpty);
  });

  test('numbers: year, ranges, comparisons', () async {
    expect(await run('anno:1973'), expected((t) => t.year == 1973));
    expect(await run('anno:1990..2000'), expected((t) => t.year != null && t.year! >= 1990 && t.year! <= 2000));
    expect(await run('anno:..1975'), expected((t) => t.year != null && t.year! <= 1975));
    expect(await run('anno:2000..'), expected((t) => t.year != null && t.year! >= 2000));
    expect(await run('anno>2005'), expected((t) => t.year != null && t.year! > 2005));
    expect(await run('anno<=1971'), expected((t) => t.year != null && t.year! <= 1971));
  });

  test('numbers: length and plays', () async {
    expect(await run('durata>5m'), expected((t) => t.sec > 300));
    expect(await run('durata<90s'), expected((t) => t.sec < 90));
    expect(await run('durata:2m..3m'), expected((t) => t.sec >= 120 && t.sec <= 180));
    expect(await run('ascolti>10'), expected((t) => t.plays > 10));
    expect(await run('ascolti:0'), expected((t) => t.plays == 0));
  });

  test('«added» counts back from now', () async {
    // Each track was added a second before its whole number of days.
    expect(await run('aggiunto<30g'), expected((t) => t.ageDays < 30));
    expect(await run('aggiunto>60g'), expected((t) => t.ageDays >= 60));
    expect(await run('aggiunto<1sett'), expected((t) => t.ageDays < 7));
    expect(await run('aggiunto:10g..20g'), expected((t) => t.ageDays >= 10 && t.ageDays < 20));
    // The same rule a month later gives fewer tracks: the clock moves.
    final later = await run('aggiunto<30g', at: now.add(const Duration(days: 30)));
    expect(later.length, lessThan((await run('aggiunto<30g')).length));
  });

  test('keywords', () async {
    expect(await run('preferiti'), expected((t) => t.fav));
    expect(await run('mai-ascoltati'), expected((t) => t.plays == 0));
    expect(await run('preferiti mai-ascoltati'), expected((t) => t.fav && t.plays == 0));
  });

  test('negation keeps what has no value at all', () async {
    // 6 tracks have no artist: «-artista:floyd» must keep them.
    expect(await run('-artista:floyd'), expected((t) => !has(t.artist, 'floyd')));
    expect(await run('-genere:jazz'), expected((t) => !has(t.genre, 'jazz')));
    expect(await run('-anno:1990..2000'), expected((t) => !(t.year != null && t.year! >= 1990 && t.year! <= 2000)));
    expect(await run('-preferiti'), expected((t) => !t.fav));
    expect(await run('-floyd'), expected((t) => !(has(t.artist, 'floyd') || has(t.title, 'floyd') || has(t.album, 'floyd'))));
  });

  test('OR and the implicit AND together', () async {
    expect(await run('artista:floyd OR artista:dalla'), expected((t) => has(t.artist, 'floyd') || has(t.artist, 'dalla')));
    expect(await run('formato:flac artista:floyd OR artista:dalla'),
        expected((t) => t.format == 'flac' && (has(t.artist, 'floyd') || has(t.artist, 'dalla'))));
    expect(await run('preferiti -genere:rock'), expected((t) => t.fav && !has(t.genre, 'rock')));
  });

  test('tags: matched by name ignoring case, and a removed tag stops matching', () async {
    final live = await db.into(db.userTags).insert(UserTagsCompanion.insert(name: 'Live'));
    final calm = await db.into(db.userTags).insert(UserTagsCompanion.insert(name: 'Calm'));
    for (final t in [data[1], data[2], data[7]]) {
      await db.into(db.trackTags).insert(TrackTagsCompanion.insert(trackId: t.id, tagId: live));
    }
    await db.into(db.trackTags).insert(TrackTagsCompanion.insert(trackId: data[1].id, tagId: calm));
    expect(await run('tag:live'), {data[1].id, data[2].id, data[7].id});
    expect(await run('tag:LIVE tag:calm'), {data[1].id});
    expect(await run('tag:liv'), isEmpty, reason: 'whole name');
    expect(await run('-tag:live'), expected((t) => ![1, 2, 7].contains(t.n)));
    await (db.delete(db.userTags)..where((x) => x.id.equals(live))).go();
    expect(await run('tag:live'), isEmpty);
  });

  test('the special characters of LIKE and of SQL are only text', () async {
    final special = byTitle("100% pure_love's \\ test").id;
    expect(await run('"100%"'), {special});
    expect(await run('"pure_love"'), {special}, reason: '_ is not a wildcard');
    expect(await run('"p_r"'), isEmpty, reason: 'would match «pur» if _ were a wildcard');
    expect(await run('%'), {special}, reason: 'a lone % is a literal percent');
    expect(await run("love's"), {special});
    expect(await run(r'"\"'), {special});
    expect(await run('"a%"'), isEmpty);
    expect(await run('titolo:"x"'), expected((t) => has(t.title, 'titolo:x') || has(t.artist, 'titolo:x') || has(t.album, 'titolo:x')));
  });

  test('a hostile value is only text: nothing runs, nothing breaks', () async {
    for (final evil in [
      r"""artista:"x'; DROP TABLE tracks; --" """,
      r"""album:"' OR '1'='1" """,
      "tag:\"'); DELETE FROM tracks; --\"",
      r"""'; DROP TABLE tracks; --""",
      r"""anno:1990' OR 1=1 --""",
    ]) {
      final got = await run(evil);
      expect(got.length, lessThan(data.length - 1), reason: evil);
    }
    expect(await db.select(db.tracks).get(), hasLength(data.length), reason: 'every track is still there');
  });

  test('order, limit and a shuffle that holds for a seed', () async {
    final rules = parseRules('preferiti').expr;
    final byTitleOrder = await repo.watchByRules(rules, sort: SortOption.title).first;
    final titles = byTitleOrder.map((t) => t.title.toLowerCase()).toList();
    expect(titles, [...titles]..sort());
    final newest = await repo.watchByRules(rules, sort: SortOption.addedAt, limit: 3).first;
    expect(newest, hasLength(3));
    expect(newest.map((t) => t.addedAt), [...newest.map((t) => t.addedAt)]..sort((a, b) => b.compareTo(a)));
    final a = await repo.watchByRules(rules, randomSeed: 7).first;
    final b = await repo.watchByRules(rules, randomSeed: 7).first;
    final c = await repo.watchByRules(rules, randomSeed: 8).first;
    expect(a.map((t) => t.id), b.map((t) => t.id), reason: 'same seed, same order');
    expect(a.map((t) => t.id), isNot(c.map((t) => t.id)));
    expect(a.map((t) => t.id).toSet(), byTitleOrder.map((t) => t.id).toSet());
  });

  test('countByRules agrees with the list', () async {
    for (final r in ['floyd', 'preferiti', 'anno:1990..2000', 'tag:nothing', '']) {
      expect(await repo.countByRules(parseRules(r).expr, now: now), (await run(r)).length, reason: r);
    }
  });

  test('toSql only carries the text in variables', () {
    final q = toSql(parseRules(r"""artista:"a'b" floyd""").expr, nowMs: 0);
    expect(q.where.contains("a'b"), isFalse);
    expect(q.where.contains('floyd'), isFalse);
    expect(RegExp(r'\?').allMatches(q.where).length, q.vars.length);
    expect(q.where, startsWith('missing = 0 AND ignored = 0 AND ${libraryRowSql()} AND ('));
  });

  test('a rule on tags updates when a tag is assigned', () async {
    // A change to `tracks` is covered by the smart playlist test; this one is
    // about the tag tables being watched too.
    final tag = await db.into(db.userTags).insert(UserTagsCompanion.insert(name: 'Mood'));
    final counts = StreamIterator(repo.watchByRules(parseRules('tag:mood').expr, now: now).map((l) => l.length));
    addTearDown(counts.cancel);
    expect(await counts.moveNext(), isTrue);
    expect(counts.current, 0);
    await db.into(db.trackTags).insert(TrackTagsCompanion.insert(trackId: data[3].id, tagId: tag));
    expect(await counts.moveNext(), isTrue);
    expect(counts.current, 1);
  });
}

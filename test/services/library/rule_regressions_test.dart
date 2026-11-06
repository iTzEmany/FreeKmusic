import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/filter_counts_repository.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_ast.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _day = 86400000;

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  final now = DateTime(2026, 10, 16, 12);
  final nowMs = now.millisecondsSinceEpoch;

  Future<int> add(int id, String artist, {int? addedAt, int? lastPlayed, String? genre}) async {
    await db.into(db.tracks).insert(TracksCompanion.insert(
        id: Value(id), path: '/$id.mp3', title: 't$id', albumKey: 'k', format: 'mp3', sizeBytes: 1,
        mtimeMs: 1, addedAt: addedAt ?? nowMs, artist: Value(artist), lastPlayedAt: Value(lastPlayed),
        genre: Value(genre)));
    return id;
  }

  Future<int> count(String rule) => repo.countByRules(parseRules(rule).expr, now: now);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
  });
  tearDown(() => db.close());

  test('RuleIn keeps quotes and backslashes: canonical -> parse -> same values, finds the track', () async {
    await add(1, 'He said "hi"');
    await add(2, r'AC\DC');
    const e = RuleIn(RuleField.artist, ['He said "hi"']);
    expect((parseRules(e.canonical).expr as RuleIn).values, ['He said "hi"']);
    expect(await repo.countByRules(e), 1);
    const f = RuleIn(RuleField.artist, [r'AC\DC', 'He said "hi"']);
    expect((parseRules(f.canonical).expr as RuleIn).values, [r'AC\DC', 'He said "hi"']);
    expect(await repo.countByRules(f), 2);
  });

  test('escapes only apply inside lists: a folder path ending in a backslash reads as before', () {
    final f = parseRules(r'cartella:"D:\Mia Musica\"').expr;
    expect(f, isA<RuleContains>());
    expect((f as RuleContains).value, r'D:\Mia Musica\');
    expect((parseRules(r'artista:"C:\",').expr as RuleIn).values, [r'C:\']);
    expect((parseRules(r'artista:"AC\\DC",').expr as RuleIn).values, [r'AC\DC']);
    expect((parseRules(r'artista:"He said \"hi\"",').expr as RuleIn).values, ['He said "hi"']);
    expect((parseRules(r'artista:"x\\","y"').expr as RuleIn).values, [r'x\', 'y']);
  });

  test('cleanRuleText empties a value made only of quotes and spaces', () {
    expect(cleanRuleText(' "" '), isEmpty);
    expect(cleanRuleText(' a"b '), 'ab');
  });

  test('numbers out of range are text with a warning and never throw', () {
    final p = parseRules('ascolti:${'9' * 400}');
    expect(p.expr, isA<RuleText>());
    expect(p.warnings.single.kind, RuleWarningKind.badNumber);
    expect(RuleNumber(RuleField.plays, NumOp.eq, double.infinity).canonical, isNotEmpty);
    expect(isValidRuleNumber(double.infinity), isFalse);
    expect(isValidRuleNumber(-1), isFalse);
    expect(isValidRuleNumber(120), isTrue);
    expect(
      () => repo.countByRules(RuleNumber(RuleField.added, NumOp.lt, double.infinity)),
      returnsNormally,
    );
  });

  test('genre counts group with TRIM like the rule', () async {
    await add(1, 'a');
    await add(2, 'b');
    await db.customStatement("UPDATE tracks SET genre = ' Rock ' WHERE id = 1");
    await db.customStatement("UPDATE tracks SET genre = 'rock' WHERE id = 2");
    final g = await FilterCountsRepository(db).counts(FilterList.genres);
    expect(g.map((v) => v.count), [2]);
    expect(await count('genere:"${g.single.value}",'), 2);
  });

  test('huge lists run as one variable (genre, country, artist)', () async {
    await add(1, 'a', genre: 'Rock');
    final many = [for (var i = 0; i < 20000; i++) 'x$i'];
    expect(await repo.countByRules(RuleIn(RuleField.genre, [...many, 'rock'])), 1);
    expect(await repo.countByRules(RuleIn(RuleField.artist, [...many, 'A'])), 1);
    expect(await repo.countByRules(RuleIn(RuleField.country, many)), 0);
  });

  test('ultimoascolto>=30g includes never played; aggiunto<Ng boundary is exclusive', () async {
    await add(1, 'a', lastPlayed: null);
    await add(2, 'b', lastPlayed: nowMs - 40 * _day);
    await add(3, 'c', lastPlayed: nowMs - 5 * _day);
    expect(await count('ultimoascolto>=30g'), 2);
    await db.customStatement('DELETE FROM tracks');
    await add(1, 'a', addedAt: nowMs - 30 * _day); // exactly 30 days: not newer
    await add(2, 'b', addedAt: nowMs - 30 * _day + 1);
    expect(await count('aggiunto<30g'), 1);
    expect(await count('aggiunto<=30g'), 2);
  });

  test('nazionalita lower case with several values; two spellings are summed', () async {
    await add(1, 'Queen');
    await add(2, 'queen feat. Bowie');
    await add(3, 'Abba');
    await add(4, 'Other');
    for (final (k, c) in [('queen', 'GB'), ('abba', 'SE'), ('other', 'US')]) {
      await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: k, country: Value(c), checkedAt: 1));
    }
    expect(await count('nazionalita:"gb","se"'), 3);
    expect(await FilterCountsRepository(db).counts(FilterList.countries),
        [const ValueCount('GB', 2), const ValueCount('SE', 1), const ValueCount('US', 1)]);
  });
}

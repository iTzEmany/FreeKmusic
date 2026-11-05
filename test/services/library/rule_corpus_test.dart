import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// Characterization of the smart-playlist rule language (phase 87.1): every
// canonical string below must keep selecting exactly these track ids.

const _day = 86400000;

// id, title, artist, album, genre, year, seconds, format, folder, ageDays, plays, favourite
const _tracks = <(int, String, String?, String?, String?, int?, int, String, String, int, int, bool)>[
  (1, 'Bohemian Rhapsody', 'Queen', 'A Night at the Opera', 'Rock', 1975, 355, 'mp3', 'Rock', 10, 50, true),
  (2, 'Another One Bites the Dust', 'Queen', 'The Game', 'Rock', 1980, 215, 'flac', 'Rock', 400, 20, false),
  (3, 'No One Knows', 'Queens of the Stone Age', 'Songs for the Deaf', 'Rock', 2002, 253, 'mp3', 'Rock', 3, 0, false),
  (4, 'Go with the Flow', 'Queens of the Stone Age', 'Songs for the Deaf', 'Rock', 2002, 188, 'mp3', 'Rock', 3, 7, true),
  (5, 'One More Time', 'Daft Punk', 'Discovery', 'Electronic', 2001, 320, 'flac', 'Electro', 30, 12, false),
  (6, 'Around the World', 'Daft Punk', 'Homework', 'Electronic', 1997, 429, 'mp3', 'Electro', 800, 0, false),
  (7, 'Time', 'Pink Floyd', 'The Dark Side of the Moon', 'Rock', 1973, 413, 'flac', 'Rock', 200, 33, true),
  (8, 'Wish You Were Here', 'Pink Floyd', 'Wish You Were Here', 'Rock', 1975, 334, 'mp3', 'Rock', 90, 4, false),
  (9, 'Felicità', 'Al Bano', null, 'Pop', 1982, 225, 'mp3', 'Italia', 5, 0, false),
  (10, 'Piazza Grande', 'Lucio Dalla', 'Lucio Dalla', 'Pop', 1972, 240, 'mp3', 'Italia', 60, 9, false),
  (11, 'Caruso', 'Lucio Dalla', 'Caruso', 'Pop', 1986, 307, 'mp3', 'Italia', 14, 0, false),
  (12, "Round Midnight", 'Thelonious Monk', 'Misterioso', 'Jazz', 1948, 380, 'flac', 'Jazz', 500, 1, false),
  (13, 'So What', 'Miles Davis', 'Kind of Blue', 'Jazz', 1959, 562, 'flac', 'Jazz', 120, 15, true),
  (14, 'Untitled', null, null, null, null, 60, 'mp3', 'Rock', 1, 0, false),
  (15, 'Hurt', 'Johnny Cash', 'American IV', 'Country', 2002, 218, 'mp3', 'Country', 45, 6, false),
  // On the range bounds: 1970 and exactly 3:00 / 7 days / 20 plays; 1979 and exactly 4:00.
  (17, 'Edge One', 'Edge Band', 'Edges', 'Pop', 1970, 180, 'mp3', 'Edge', 7, 20, false),
  (18, 'Edge Two', 'Edge Band', 'Edges', 'Pop', 1979, 240, 'mp3', 'Edge', 6, 19, false),
];

/// canonical rule -> ids it selects today.
const _corpus = <String, Set<int>>{
  '': {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18},
  'time': {5, 7},
  '"one more"': {5},
  'queen': {1, 2, 3, 4},
  'artista:Queen': {1, 2, 3, 4},
  'artista:"daft punk"': {5, 6},
  'album:wish': {8},
  'genere:jazz': {12, 13},
  'cartella:Italia': {9, 10, 11},
  'formato:flac': {2, 5, 7, 12, 13},
  'tag:chill': {7, 8, 13},
  'preferiti': {1, 4, 7, 13},
  'mai-ascoltati': {3, 6, 9, 11, 14},
  'anno:1975': {1, 8},
  'anno>2000': {3, 4, 5, 15},
  'anno>=2002': {3, 4, 15},
  'anno<1960': {12, 13},
  'anno<=1973': {7, 10, 12, 13, 17},
  'anno:1970..1979': {1, 7, 8, 10, 17, 18},
  'anno:1990..': {3, 4, 5, 6, 15},
  'durata>6m': {6, 7, 12, 13},
  'durata:3m..4m': {2, 4, 9, 10, 15, 17, 18},
  'aggiunto<7g': {3, 4, 9, 14, 18},
  'ascolti>=20': {1, 2, 7, 17},
  'ascolti:0': {3, 6, 9, 11, 14},
  '-genere:rock': {5, 6, 9, 10, 11, 12, 13, 14, 15, 17, 18},
  'genere:jazz OR genere:country': {12, 13, 15},
  'genere:rock -tag:chill': {1, 2, 3, 4},
  'preferiti formato:flac durata>5m': {7, 13},
};

/// Strings stored by older versions (aliases, other case, units, open ranges)
/// -> ids they select and the canonical form they are rewritten to.
const _legacy = <String, (Set<int>, String)>{
  'artist:Queen': ({1, 2, 3, 4}, 'artista:Queen'),
  'ARTISTA:queen': ({1, 2, 3, 4}, 'artista:queen'),
  'genre:jazz': ({12, 13}, 'genere:jazz'),
  'year>2000': ({3, 4, 5, 15}, 'anno>2000'),
  'plays>=20': ({1, 2, 7, 17}, 'ascolti>=20'),
  'format:FLAC': ({2, 5, 7, 12, 13}, 'formato:FLAC'),
  'folder:italia': ({9, 10, 11}, 'cartella:italia'),
  'favorites': ({1, 4, 7, 13}, 'preferiti'),
  'never-played': ({3, 6, 9, 11, 14}, 'mai-ascoltati'),
  'durata>=360s': ({6, 7, 12, 13}, 'durata>=6m'),
  'durata>6': ({6, 7, 12, 13}, 'durata>6m'),
  'duration:3min..4min': ({2, 4, 9, 10, 15, 17, 18}, 'durata:3m..4m'),
  'durata:180s': ({17}, 'durata:3m'),
  'aggiunto<2sett': ({1, 3, 4, 9, 14, 17, 18}, 'aggiunto<14g'),
  'added<1mese': ({1, 3, 4, 9, 11, 14, 17, 18}, 'aggiunto<30g'),
  'anno:..1980': ({1, 2, 7, 8, 10, 12, 13, 17, 18}, 'anno:..1980'),
  '-"one more"': ({1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 17, 18}, '-"one more"'),
};

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  final now = DateTime(2026, 10, 16, 12);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    for (final t in _tracks) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
            id: Value(t.$1),
            path: '/music/${t.$9}/${t.$1}.${t.$8}',
            title: t.$2,
            albumKey: '${t.$3}|${t.$4}',
            format: t.$8,
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: now.millisecondsSinceEpoch - t.$10 * _day - 1000,
            artist: Value(t.$3),
            album: Value(t.$4),
            genre: Value(t.$5),
            year: Value(t.$6),
            durationMs: Value(t.$7 * 1000),
            playCount: Value(t.$11),
            isFavorite: Value(t.$12),
          ));
    }
    // A missing track never shows, whatever the rule.
    await db.into(db.tracks).insert(TracksCompanion.insert(
        id: const Value(16), path: '/music/Rock/16.mp3', title: 'Gone', albumKey: 'k', format: 'mp3',
        sizeBytes: 1, mtimeMs: 1, addedAt: 1, artist: const Value('Queen'), missing: const Value(true)));
    final tag = await db.into(db.userTags).insert(UserTagsCompanion.insert(name: 'chill'));
    for (final id in [7, 8, 13]) {
      await db.into(db.trackTags).insert(TrackTagsCompanion.insert(trackId: id, tagId: tag));
    }
  });
  tearDown(() => db.close());

  Future<Set<int>> run(String rules) async =>
      {for (final t in await repo.watchByRules(parseRules(rules).expr, now: now).first) t.id};

  test('every rule of the corpus selects the same tracks as today', () async {
    final actual = {for (final r in _corpus.keys) r: await run(r)};
    expect(actual, _corpus);
  });

  test('every rule of the corpus is already in canonical form', () {
    for (final r in _corpus.keys) {
      expect(formatRules(parseRules(r).expr), r);
    }
  });

  test('strings saved by older versions select the same tracks and are rewritten to the canonical form', () async {
    final actual = {for (final r in _legacy.keys) r: await run(r)};
    expect(actual, {for (final e in _legacy.entries) e.key: e.value.$1});
    for (final e in _legacy.entries) {
      expect(formatRules(parseRules(e.key).expr), e.value.$2, reason: e.key);
    }
  });

  test('artista:Queen also matches «Queens of the Stone Age» (contains, not whole word)', () async {
    final names = [for (final t in await repo.watchByRules(parseRules('artista:Queen').expr, now: now).first) t.artist];
    expect(names, contains('Queens of the Stone Age'));
  });
}

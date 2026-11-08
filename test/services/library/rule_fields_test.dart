import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_ast.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

// 94.1 (RuleIn) and 94.2 (new fields) on a fixed DB.

const _day = 86400000;

void main() {
  late AppDatabase db;
  late TrackRepository repo;
  final now = DateTime(2026, 10, 16, 12);
  final nowMs = now.millisecondsSinceEpoch;

  Future<void> add(
    int id,
    String title, {
    String? artist,
    String? albumArtist,
    String? genre,
    int? bitrate,
    String? lyrics,
    String? synced,
    int plays = 0,
    int? lastDaysAgo,
  }) =>
      db.into(db.tracks).insert(TracksCompanion.insert(
            id: Value(id),
            path: '/m/$id.mp3',
            title: title,
            albumKey: 'k$id',
            format: 'mp3',
            sizeBytes: 1,
            mtimeMs: 1,
            addedAt: 1,
            artist: Value(artist),
            albumArtist: Value(albumArtist),
            genre: Value(genre),
            bitrateKbps: Value(bitrate),
            lyricsPlain: Value(lyrics),
            lyricsSynced: Value(synced),
            playCount: Value(plays),
            lastPlayedAt: Value(lastDaysAgo == null ? null : nowMs - lastDaysAgo * _day),
          ));

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TrackRepository(db);
    await add(1, 'a', artist: 'Queen', albumArtist: 'Queen', genre: 'Rock', bitrate: 320, lyrics: 'la', plays: 3, lastDaysAgo: 2);
    await add(2, 'b', artist: 'Queens of the Stone Age', genre: 'Rock', bitrate: 128, synced: '[00:01]la', plays: 1, lastDaysAgo: 40);
    await add(3, 'c', artist: 'Édith Piaf, Jr', albumArtist: 'Various Artists', genre: 'Pop', bitrate: 256, lyrics: '');
    await add(4, 'd', artist: 'Nina Simone feat. X', genre: 'Jazz');
    await add(5, 'e', artist: 'Daft Punk'); // no genre, no data at all
    // Genres of the 93: track 3 has a second genre.
    for (final (id, pos, g) in [(1, 0, 'Rock'), (3, 0, 'Pop'), (3, 1, 'Soul'), (4, 0, 'Jazz')]) {
      await db.into(db.trackGenres).insert(TrackGenresCompanion.insert(trackId: id, genre: g, position: pos));
    }
    await db.into(db.trackEnrich).insert(TrackEnrichCompanion(trackId: const Value(1), details: const Value('{"bpm": 120.5, "label": "EMI"}')));
    await db.into(db.trackEnrich).insert(TrackEnrichCompanion(trackId: const Value(2), details: const Value('{"bpm": 90, "label": "Interscope"}')));
    await db.into(db.trackEnrich).insert(TrackEnrichCompanion(trackId: const Value(3), details: const Value('not json')));
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'queen', country: const Value('GB'), checkedAt: 1));
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'edith piaf', country: const Value('FR'), checkedAt: 1));
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'nina simone', country: const Value('US'), checkedAt: 1));
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'daft punk', checkedAt: 1)); // not found
  });
  tearDown(() => db.close());

  Future<Set<int>> run(String rules) async =>
      {for (final t in await repo.watchByRules(parseRules(rules).expr, now: now).first) t.id};

  group('RuleIn', () {
    test('exact, not substring; commas and accents live inside the quotes', () async {
      expect(await run('artista:"Queen","Daft Punk"'), {1, 5});
      expect(await run('artista:"Édith Piaf, Jr","Queen"'), {1, 3});
      expect(await run('artista:Queen'), {1, 2}); // still a substring
      expect(await run('artista:"queen","DAFT PUNK"'), {1, 5}); // case ignored
    });

    test('with NOT, and with one value', () async {
      expect(await run('-artista:"Queen","Daft Punk"'), {2, 3, 4});
      expect(await run('artista:"Queen",'), {1});
      expect(await run('genere:"Soul","Jazz"'), {3, 4});
    });

    test('parses and prints canonically', () {
      for (final s in ['artista:"A","B"', 'artista:"A",', 'artista:"Édith, Piaf","B c"', '-tag:"x","y"']) {
        final e = parseRules(s);
        expect(e.warnings, isEmpty, reason: s);
        expect(formatRules(e.expr), s);
      }
      expect(parseRules('artista:"A","B"').expr, const RuleIn(RuleField.artist, ['A', 'B']));
      expect(parseRules('artista:"pink floyd"').expr, const RuleContains(RuleField.artist, 'pink floyd'));
      expect(parseRules('artista:"A",b').expr, isA<RuleContains>());
    });

    test('spaces after the comma of a quoted list are allowed; canonical has none', () async {
      final p = parseRules('artista:"Queen", "Daft Punk"');
      expect(p.warnings, isEmpty);
      expect(formatRules(p.expr), 'artista:"Queen","Daft Punk"');
      expect(await run('artista:"Queen", "Daft Punk"'), {1, 5});
      expect(formatRules(parseRules('artista:"Queen", preferiti').expr), 'artista:"Queen", preferiti');
    });

    test('cartella stays a substring, never a list', () {
      expect(parseRules('cartella:"a","b"').expr, isNot(isA<RuleIn>()));
    });

    test('an empty value is reported and skipped', () {
      final p = parseRules('artista:"A",""');
      expect(p.warnings.single.kind, RuleWarningKind.emptyValue);
      expect(formatRules(p.expr), '');
    });
  });

  group('new fields', () {
    test('ultimoascolto counts days back; never played is out', () async {
      expect(await run('ultimoascolto<7g'), {1});
      expect(await run('ultimoascolto>30g'), {2, 3, 4, 5}); // never played = long ago
      expect(await run('-ultimoascolto<7g'), {2, 3, 4, 5});
      expect(await run('ultimoascolto:30..'), {2, 3, 4, 5});
      expect(await run('ultimoascolto:0..60d'), {1, 2});
      expect(formatRules(parseRules('ultimoascolto>30d').expr), 'ultimoascolto>30g');
    });

    test('mai-ascoltati', () async => expect(await run('mai-ascoltati'), {3, 4, 5}));

    test('artistaalbum', () async {
      expect(await run('artistaalbum:queen'), {1});
      expect(await run('artistaalbum:"Various Artists","Queen"'), {1, 3});
    });

    test('nazionalita uses the main artist key; unknown country is out', () async {
      expect(await run('nazionalita:GB'), {1}); // not «Queens of the Stone Age»
      expect(await run('nazionalita:fr'), {3});
      expect(await run('nazionalita:"GB","US"'), {1, 4});
      expect(await run('-nazionalita:GB'), {2, 3, 4, 5});
      expect(await repo.countByRules(parseRules('nazionalita:"GB","FR"').expr, now: now), 2);
    });

    test('etichetta and bpm come from the enrichment; bad JSON is out', () async {
      expect(await run('etichetta:emi'), {1});
      expect(await run('etichetta:"Interscope",'), {2});
      expect(await run('bpm>100'), {1});
      expect(await run('bpm:80..100'), {2});
      expect(await run('bpm:120.5'), {1});
      expect(await run('-bpm>100'), {2, 3, 4, 5});
      expect(await run('bpm:121'), {1}); // equality rounds: 120.5 -> 121
      expect(await run('bpm:90'), {2});
    });

    test('bitrate, con-testo', () async {
      expect(await run('bitrate>=256'), {1, 3});
      expect(await run('bitrate:..200'), {2});
      expect(await run('con-testo'), {1, 2});
      expect(await run('-con-testo'), {3, 4, 5});
    });

    test('genere looks at every genre; old single-column tracks still match', () async {
      expect(await run('genere:soul'), {3});
      expect(await run('genere:rock'), {1, 2}); // 2 has no track_genres row
      expect(await run('-genere:pop'), {1, 2, 4, 5});
    });

    test('rules read only the tables they use', () async {
      var n = 0;
      final sub = repo.watchByRules(parseRules('artista:queen').expr, now: now).listen((_) => n++);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final before = n;
      await db.into(db.trackEnrich).insert(TrackEnrichCompanion(trackId: const Value(4), details: const Value('{}')));
      await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'zz', checkedAt: 1));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(n, before);
      await sub.cancel();
    });

    test('a nazionalita rule follows new countries without reopening', () async {
      final lists = <Set<int>>[];
      final sub = repo.watchByRules(parseRules('nazionalita:IT').expr, now: now).listen((r) => lists.add({for (final t in r) t.id}));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(lists.last, isEmpty);
      // > debounce of 300 ms of _watchWithCountries
      await db.into(db.artistCountries).insertOnConflictUpdate(ArtistCountriesCompanion.insert(artistKey: 'daft punk', country: const Value('IT'), checkedAt: 1));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(lists.last, {5});
      await add(6, 'f', artist: 'Daft Punk');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(lists.last, {5, 6});
      await sub.cancel();
    });

    test('sort and limit are unchanged', () async {
      final r = await repo
          .watchByRules(parseRules('bitrate>0').expr, sort: SortOption.defaultOrder, limit: 2, now: now)
          .first;
      expect(r.length, 2);
    });
  });
}

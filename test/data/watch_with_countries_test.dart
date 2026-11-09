import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:drift/drift.dart'
    show ApplyInterceptor, QueryExecutor, QueryInterceptor, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts the queries the stream runs and can hold the answer of the next main one.
class _Spy extends QueryInterceptor {
  int countryReads = 0; // reads of artist_countries
  int mainRuns = 0; // the tracks query of the rule itself
  Completer<void>? hold; // the next main query waits for this after reading
  final reached = Completer<void>();

  @override
  Future<List<Map<String, Object?>>> runSelect(
    QueryExecutor e,
    String sql,
    List<Object?> args,
  ) async {
    final rows = await super.runSelect(e, sql, args);
    if (sql.contains('FROM artist_countries')) countryReads++;
    if (sql.contains('FROM tracks') &&
        !sql.contains('DISTINCT') &&
        !sql.contains('artist_countries')) {
      mainRuns++;
      final h = hold;
      hold = null;
      if (h != null) {
        reached.complete();
        await h.future;
      }
    }
    return rows;
  }
}

/// Characterizes the stream behind `watchByRules` for «nazionalita» rules (F-118):
/// only the latest value matters, so a later debounce keeps these valid.
void main() {
  late AppDatabase db;
  late _Spy spy;
  late TrackRepository repo;
  late List<List<String>> seen;
  late StreamSubscription<List<Track>> sub;

  Future<void> add(int id, String artist) => db
      .into(db.tracks)
      .insert(
        TracksCompanion.insert(
          id: Value(id),
          path: '/$id.mp3',
          title: 't$id',
          albumKey: 'k',
          format: 'mp3',
          sizeBytes: 1,
          mtimeMs: 1,
          addedAt: 1,
          artist: Value(artist),
        ),
      );

  // Real async, not fakeAsync: drift's stream queries and the debounce-to-be run on real timers.
  Future<void> latestIs(List<String> titles) async {
    final end = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(end)) {
      if (seen.isNotEmpty && seen.last.toString() == titles.toString()) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(seen.isEmpty ? null : seen.last, titles);
  }

  setUp(() async {
    spy = _Spy();
    db = AppDatabase(NativeDatabase.memory().interceptWith(spy));
    repo = TrackRepository(db);
    seen = [];
    await db
        .into(db.artistCountries)
        .insert(
          ArtistCountriesCompanion.insert(
            artistKey: 'queen',
            country: const Value('GB'),
            checkedAt: 1,
          ),
        );
    await db
        .into(db.artistCountries)
        .insert(
          ArtistCountriesCompanion.insert(
            artistKey: 'abba',
            country: const Value('SE'),
            checkedAt: 1,
          ),
        );
    await add(1, 'Queen');
    sub = repo
        .watchByRules(
          parseRules('nazionalita:GB').expr,
          sort: SortOption.defaultOrder,
        )
        .listen((l) => seen.add([for (final t in l) t.title]));
  });
  tearDown(() async {
    await sub.cancel();
    await db.close();
  });

  test('a burst of writes on tracks ends on the correct latest list', () async {
    await latestIs(['t1']);
    for (var i = 2; i <= 6; i++) {
      await add(i, i.isEven ? 'Queen' : 'Abba');
    }
    await latestIs(['t1', 't2', 't4', 't6']);
  });

  test('a new artist inserted in tracks, with its country known, appears in the per-country result', () async {
    await latestIs(['t1']);
    await db
        .into(db.artistCountries)
        .insert(
          ArtistCountriesCompanion.insert(
            artistKey: 'muse',
            country: const Value('GB'),
            checkedAt: 1,
          ),
        );
    await add(2, 'Muse');
    await latestIs(['t1', 't2']);
  });

  test('a country that arrives (or changes) after the track makes the result follow', () async {
    await add(2, 'Muse');
    await latestIs(['t1']);
    await db
        .into(db.artistCountries)
        .insert(
          ArtistCountriesCompanion.insert(
            artistKey: 'muse',
            country: const Value('GB'),
            checkedAt: 1,
          ),
        );
    await latestIs(['t1', 't2']);
    await (db.update(db.artistCountries)
          ..where((c) => c.artistKey.equals('muse')))
        .write(const ArtistCountriesCompanion(country: Value('FR')));
    await latestIs(['t1']);
  });

  test(
    'writes on tracks that add no artist do not re-read the countries',
    () async {
      await latestIs(['t1']);
      final before = spy.countryReads;
      await add(2, 'Queen');
      await add(3, 'Queen');
      await latestIs(['t1', 't2', 't3']);
      expect(spy.countryReads, before);
    },
  );

  test('a burst of writes within 300 ms runs the query once', () async {
    await latestIs(['t1']);
    final before = spy.mainRuns;
    for (var i = 2; i <= 6; i++) {
      await add(i, 'Queen');
    }
    await latestIs(['t1', 't2', 't3', 't4', 't5', 't6']);
    expect(spy.mainRuns, before + 1);
  });

  test(
    'a write on artist_countries recomputes the map even with the same artists',
    () async {
      await latestIs(['t1']);
      final before = spy.countryReads;
      await (db.update(db.artistCountries)
            ..where((c) => c.artistKey.equals('queen')))
          .write(const ArtistCountriesCompanion(country: Value('FR')));
      await latestIs([]);
      expect(spy.countryReads, before + 1);
    },
  );

  test('an old answer that arrives after a newer one is not emitted', () async {
    await latestIs(['t1']);
    final hold = spy.hold = Completer<void>();
    await add(2, 'Queen');
    await spy.reached.future; // the first re-run read t1,t2 and waits
    await add(3, 'Queen');
    await latestIs(['t1', 't2', 't3']);
    final n = seen.length;
    hold.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen.length, n);
  });

  test('a stream cancelled with a query in flight emits nothing', () async {
    await latestIs(['t1']);
    final hold = spy.hold = Completer<void>();
    await add(2, 'Queen');
    await spy.reached.future;
    final n = seen.length;
    await sub.cancel();
    hold.complete();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(seen.length, n);
  });

  test('an artist renamed to another with a known country (same artist count) appears', () async {
    await db
        .into(db.artistCountries)
        .insert(
          ArtistCountriesCompanion.insert(
            artistKey: 'muse',
            country: const Value('GB'),
            checkedAt: 1,
          ),
        );
    await add(2, 'Zed');
    await Future<void>.delayed(
      const Duration(milliseconds: 600),
    ); // let the re-run (and its cache) settle
    await (db.update(db.tracks)..where((t) => t.id.equals(2))).write(
      const TracksCompanion(artist: Value('Muse')),
    );
    await latestIs(['t1', 't2']);
  });

  test(
    'cancelled while the debounce timer waits: no query runs afterwards',
    () async {
      await latestIs(['t1']);
      final before = spy.mainRuns;
      await add(2, 'Queen');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(spy.mainRuns, before);
    },
  );

  test(
    'one transaction writing tracks and artist_countries together is followed',
    () async {
      await latestIs(['t1']);
      await db.transaction(() async {
        await add(2, 'Muse');
        await db
            .into(db.artistCountries)
            .insert(
              ArtistCountriesCompanion.insert(
                artistKey: 'muse',
                country: const Value('GB'),
                checkedAt: 1,
              ),
            );
      });
      await latestIs(['t1', 't2']);
      await db.transaction(() async {
        await (db.update(db.artistCountries)
              ..where((c) => c.artistKey.equals('muse')))
            .write(const ArtistCountriesCompanion(country: Value('FR')));
        await (db.update(db.tracks)..where((t) => t.id.equals(1))).write(
          const TracksCompanion(title: Value('t1b')),
        );
      });
      await latestIs(['t1b']);
    },
  );

  test('writes spread inside the first 300 ms window run the query once (the timer is not restarted)', () async {
    await latestIs(['t1']);
    final before = spy.mainRuns;
    for (var i = 2; i <= 4; i++) {
      await add(i, 'Queen');
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    await latestIs(['t1', 't2', 't3', 't4']);
    expect(spy.mainRuns, before + 1);
  });
}

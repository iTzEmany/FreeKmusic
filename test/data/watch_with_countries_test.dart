import 'dart:async';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/library/rules/rule_parser.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Characterizes the stream behind `watchByRules` for «nazionalita» rules (F-118):
/// only the latest value matters, so a later debounce keeps these valid.
void main() {
  late AppDatabase db;
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
    db = AppDatabase(NativeDatabase.memory());
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
    await db.into(db.artistCountries).insert(ArtistCountriesCompanion.insert(artistKey: 'muse', country: const Value('GB'), checkedAt: 1));
    await latestIs(['t1', 't2']);
    await (db.update(db.artistCountries)..where((c) => c.artistKey.equals('muse'))).write(const ArtistCountriesCompanion(country: Value('FR')));
    await latestIs(['t1']);
  });
}

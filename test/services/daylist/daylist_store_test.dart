import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/daylist/daylist_builder.dart';
import 'package:codecore/services/daylist/daylist_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'daylist_builder_test.dart' show cand, track;

void main() {
  late Directory dir;
  late DaylistStore store;
  final until = DateTime(2026, 11, 10);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('daylist_store');
    store = DaylistStore(() async => File(p.join(dir.path, 'daylist.json')));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  final library = [for (var i = 1; i <= 20; i++) track(i, 'Soul')];

  Future<void> save() => store.save(
    key: 'k',
    until: until,
    result: DaylistResult(
      slotIndex: 5,
      items: [
        for (final t in library) DaylistItem.own(t),
        DaylistItem.suggested(cand('yt1', 'Song 1')),
      ],
      genres: const ['Soul'],
      tooFew: false,
    ),
  );

  /// The library as the database now has it: [change] applied to the tracks it names.
  Future<DaylistResult?> load({
    Map<int, Track Function(Track)> change = const {},
    String key = 'k',
    DateTime? at,
  }) => store.load(
    key: key,
    until: at ?? until,
    tracksOf: (ids) async => [
      for (final id in ids)
        if (id <= 20) (change[id] ?? (t) => t)(library[id - 1]),
    ],
  );

  test(
    'what was saved comes back, in order, suggested songs included',
    () async {
      await save();
      final r = (await load())!;
      expect(r.items, hasLength(21));
      expect(r.items.last.suggestion?.result.id, 'yt1');
      expect(
        [for (final i in r.items.take(20)) i.track!.id],
        [for (var i = 1; i <= 20; i++) i],
      );
      expect(r.genres, ['Soul']);
    },
  );

  test(
    'a song that became missing, hidden or not music is gone at load',
    () async {
      await save();
      final r = (await load(
        change: {
          1: (t) => t.copyWith(missing: true),
          2: (t) => t.copyWith(ignored: true),
          3: (t) => t.copyWith(kind: 2),
        },
      ))!;
      expect(r.items, hasLength(18));
      expect(
        r.items.where((i) => i.track != null && i.track!.id <= 3),
        isEmpty,
      );
    },
  );

  test(
    'too many songs gone (under 15 left): no daylist, it is made again',
    () async {
      await save();
      expect(
        await load(
          change: {
            for (var i = 1; i <= 7; i++) i: (t) => t.copyWith(missing: true),
          },
        ),
        isNull,
      ); // 14 left
      expect(
        await load(
          change: {
            for (var i = 1; i <= 6; i++) i: (t) => t.copyWith(missing: true),
          },
        ),
        isNotNull,
      ); // 15 left
    },
  );

  test('another key or another end of slot: stale', () async {
    await save();
    expect(await load(key: 'other'), isNull);
    expect(await load(at: DateTime(2026, 11, 11)), isNull);
  });
}

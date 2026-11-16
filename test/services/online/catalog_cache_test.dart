import 'dart:io';

import 'package:codecore/services/online/catalog_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late File file;
  var clock = DateTime(2026, 10, 1);

  final made = <CatalogCache>[];

  CatalogCache make({int max = 60}) {
    final c = CatalogCache(
        file: () async => file, max: max, now: () => clock, writeDelay: Duration.zero);
    made.add(c);
    return c;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cc_catalog');
    file = File('${dir.path}/catalog_cache.json');
    clock = DateTime(2026, 10, 1);
  });
  tearDown(() async {
    // A write still running keeps the file open, which Windows cannot delete.
    for (final c in made) {
      await c.dispose();
    }
    made.clear();
    dir.deleteSync(recursive: true);
  });

  test('a page is fresh for its kind\'s time, then expired but still there', () async {
    final c = make();
    await c.put(CatalogKind.artist, 'a', {'n': 1});
    await c.put(CatalogKind.album, 'b', {'n': 2});
    clock = clock.add(const Duration(days: 3));
    final artist = (await c.get(CatalogKind.artist, 'a'))!;
    expect(artist.expired, isTrue, reason: 'artists last 2 days');
    expect(artist.json, {'n': 1}, reason: 'the old copy is kept for offline use');
    expect((await c.get(CatalogKind.album, 'b'))!.expired, isFalse, reason: 'albums last 14 days');
    expect(await c.get(CatalogKind.album, 'a'), isNull, reason: 'the kind is part of the key');
  });

  test('a chart is fresh at 23 h, expired at 25 h and still readable with its date', () async {
    final c = make();
    await c.put(CatalogKind.chart, 'pop:it', {'n': 1});
    final stored = clock;
    clock = stored.add(const Duration(hours: 23));
    expect((await c.get(CatalogKind.chart, 'pop:it'))!.expired, isFalse);
    clock = stored.add(const Duration(hours: 25));
    final e = (await c.get(CatalogKind.chart, 'pop:it'))!;
    expect(e.expired, isTrue);
    expect(e.json, {'n': 1});
    expect(e.storedAt, stored);
  });

  test('keepDate adds to a copy without renewing it', () async {
    final c = make();
    await c.put(CatalogKind.chart, 'pop:it', {'n': 1});
    final stored = clock;
    clock = stored.add(const Duration(hours: 5));
    await c.put(CatalogKind.chart, 'pop:it', {'n': 2}, keepDate: true);
    final e = (await c.get(CatalogKind.chart, 'pop:it'))!;
    expect(e.json, {'n': 2});
    expect(e.storedAt, stored);
  });

  test('beyond the limit the least recently used page goes', () async {
    final c = make(max: 2);
    for (final k in ['a', 'b']) {
      clock = clock.add(const Duration(minutes: 1));
      await c.put(CatalogKind.album, k, k);
    }
    clock = clock.add(const Duration(minutes: 1));
    await c.get(CatalogKind.album, 'a');
    clock = clock.add(const Duration(minutes: 1));
    await c.put(CatalogKind.album, 'c', 'c');
    expect(await c.get(CatalogKind.album, 'b'), isNull);
    expect(await c.get(CatalogKind.album, 'a'), isNotNull);
    expect(await c.get(CatalogKind.album, 'c'), isNotNull);
  });

  test('pages survive a restart, sizeBytes counts them and clear empties the file', () async {
    final c = make();
    expect(await c.sizeBytes(), 0);
    await c.put(CatalogKind.songs, 'k', ['x']);
    expect(await c.sizeBytes(), greaterThan(0));
    final again = make();
    expect((await again.get(CatalogKind.songs, 'k'))!.json, ['x']);
    await again.clear();
    expect(await make().count(), 0);
    expect(await again.sizeBytes(), lessThan(5));
  });
}

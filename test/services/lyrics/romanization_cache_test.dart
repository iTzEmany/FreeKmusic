import 'dart:io';

import 'package:codecore/services/lyrics/romanization_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;
  late File file;
  var now = DateTime(2026, 11, 8);

  RomanizationCache open() =>
      RomanizationCache(file: () async => file, now: () => now);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('romcache');
    file = File(p.join(dir.path, 'sub', 'cache.json'));
    now = DateTime(2026, 11, 8);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'a text and a «none» are written and read back by a new instance',
    () async {
      final c = open();
      await c.put(1, '[00:01.00]konnichiwa');
      await c.put(2, null);
      expect(File('${file.path}.tmp').existsSync(), isFalse);

      final again = open();
      expect((await again.get(1))!.lrc, '[00:01.00]konnichiwa');
      expect((await again.get(2))!.lrc, isNull);
      expect(await again.get(3), isNull);
    },
  );

  test(
    'a «none» is asked again after 30 days, a saved text never expires',
    () async {
      final c = open();
      await c.put(1, 'text');
      await c.put(2, null);
      now = now.add(const Duration(days: 29));
      expect(await c.get(2), isNotNull);
      now = now.add(const Duration(days: 2));
      expect(await c.get(2), isNull);
      expect((await c.get(1))!.lrc, 'text');
    },
  );

  test(
    'an unreadable file starts empty and the next write replaces it',
    () async {
      file.parent.createSync(recursive: true);
      file.writeAsStringSync('{not json');
      final c = open();
      expect(await c.get(1), isNull);
      await c.put(1, 'ok');
      expect((await open().get(1))!.lrc, 'ok');
    },
  );

  test(
    'an entry asked with another title or artist counts as unknown',
    () async {
      final c = open();
      await c.put(1, 'text', key: 'T\u0000A');
      expect((await c.get(1, key: 'T\u0000A'))!.lrc, 'text');
      expect(await c.get(1, key: 'T2\u0000A'), isNull);
      expect(await c.get(1), isNull);
    },
  );

  test('an entry reports its age', () async {
    final c = open();
    await c.put(1, 'text');
    now = now.add(const Duration(days: 40));
    expect((await c.get(1))!.age, const Duration(days: 40));
  });

  test('entries of tracks that no longer exist are dropped on the first load, and the file follows', () async {
    await open().put(1, 'a');
    await open().put(2, 'b');
    final c = RomanizationCache(
      file: () async => file,
      now: () => now,
      liveIds: () async => {2},
    );
    expect(await c.get(1), isNull);
    expect((await c.get(2))!.lrc, 'b');
    await c.put(3, 'c'); // waits for the file to be written
    final again = open();
    expect(await again.get(1), isNull);
    expect((await again.get(2))!.lrc, 'b');
  });

  test('a failing liveIds keeps everything', () async {
    await open().put(1, 'a');
    final c = RomanizationCache(
      file: () async => file,
      now: () => now,
      liveIds: () async => throw StateError('db'),
    );
    expect((await c.get(1))!.lrc, 'a');
  });

  test('a key written by one instance is read by another', () async {
    await open().put(1, 'text', key: 'T\u0000A');
    expect((await open().get(1, key: 'T\u0000A'))!.lrc, 'text');
    expect(await open().get(1, key: 'T\u0000B'), isNull);
  });

  test('a broken entry does not throw away the good ones', () async {
    file.parent.createSync(recursive: true);
    final at = now.millisecondsSinceEpoch;
    file.writeAsStringSync(
      '{"1":{"lrc":"a","at":$at},"2":5,"x":{"at":1},"3":{"lrc":"c"},'
      '"4":{"lrc":"d","at":$at}}',
    );
    final c = open();
    expect((await c.get(1))!.lrc, 'a');
    expect((await c.get(4))!.lrc, 'd');
    expect(await c.get(2), isNull);
    expect(await c.get(3), isNull);
  });

  test('pruning is written to the file', () async {
    await open().put(1, 'a');
    await open().put(2, 'b');
    final c = RomanizationCache(
      file: () async => file,
      now: () => now,
      liveIds: () async => {2},
    );
    await c.get(2); // the first load prunes and writes
    final raw = file.readAsStringSync();
    expect(raw.contains('"1"'), isFalse);
    expect(raw.contains('"2"'), isTrue);
  });

  test('an empty set of live ids prunes nothing', () async {
    await open().put(1, 'a');
    final c = RomanizationCache(
      file: () async => file,
      now: () => now,
      liveIds: () async => <int>{},
    );
    expect((await c.get(1))!.lrc, 'a');
  });

  test('an entry stamped in the future counts as expired', () async {
    final c = open();
    await c.put(1, 'text');
    await c.put(2, null);
    now = now.subtract(const Duration(days: 2));
    expect(await c.get(1), isNull);
    expect(await c.get(2), isNull);
  });
}

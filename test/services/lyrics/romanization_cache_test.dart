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
}

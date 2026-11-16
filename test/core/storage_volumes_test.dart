import 'dart:io';

import 'package:codecore/core/storage_volumes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('writableDirs drops the card folders that are missing or not writable', () async {
    final root = await Directory.systemTemp.createTemp('sdvol');
    addTearDown(() => root.delete(recursive: true));
    final file = File(p.join(root.path, 'f'))..writeAsStringSync('x');
    final good = Directory(p.join(root.path, 'good'))..createSync();
    expect(
      await writableDirs([p.join(root.path, 'gone'), good.path, p.join(file.path, 'x')]),
      [good.path],
    );
  });
}

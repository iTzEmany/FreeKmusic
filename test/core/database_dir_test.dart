import 'dart:io';

import 'package:codecore/core/paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root, docs, support;
  setUp(() {
    root = Directory.systemTemp.createTempSync('dbdir');
    docs = Directory(p.join(root.path, 'docs'))..createSync();
    support = Directory(p.join(root.path, 'support'))..createSync();
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<String> run({bool desktop = true, String? supportPath}) => resolveDatabaseDir(
    desktop: desktop,
    documentsDir: () async => docs.path,
    supportDir: () async => supportPath ?? support.path,
  );

  test('copies the old database and its sidecar, leaving the old ones', () async {
    File(p.join(docs.path, 'codecore.sqlite')).writeAsStringSync('db');
    File(p.join(docs.path, 'codecore.sqlite-wal')).writeAsStringSync('wal');
    expect(await run(), support.path);
    expect(File(p.join(support.path, 'codecore.sqlite')).readAsStringSync(), 'db');
    expect(File(p.join(support.path, 'codecore.sqlite-wal')).readAsStringSync(), 'wal');
    expect(File(p.join(docs.path, 'codecore.sqlite')).existsSync(), isTrue);
  });

  test('does nothing when the new database exists', () async {
    File(p.join(docs.path, 'codecore.sqlite')).writeAsStringSync('old');
    File(p.join(support.path, 'codecore.sqlite')).writeAsStringSync('new');
    expect(await run(), support.path);
    expect(File(p.join(support.path, 'codecore.sqlite')).readAsStringSync(), 'new');
  });

  test('phones keep Documents and copy nothing', () async {
    File(p.join(docs.path, 'codecore.sqlite')).writeAsStringSync('db');
    expect(await run(desktop: false), docs.path);
    expect(File(p.join(support.path, 'codecore.sqlite')).existsSync(), isFalse);
  });

  test('a failed copy keeps the old folder', () async {
    File(p.join(docs.path, 'codecore.sqlite')).writeAsStringSync('db');
    // A file where the support folder should be makes the copy fail.
    final bad = File(p.join(root.path, 'file'))..writeAsStringSync('x');
    expect(await run(supportPath: bad.path), docs.path);
  });
}

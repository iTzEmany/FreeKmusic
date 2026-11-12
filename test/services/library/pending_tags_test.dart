import 'dart:convert';
import 'dart:io';

import 'package:codecore/services/library/pending_tags.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('concurrent adds and removes leave a valid file with every expected path', () async {
    final dir = Directory.systemTemp.createTempSync('pending');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File(p.join(dir.path, 'pending.json'));
    final pending = PendingTags(() async => file);
    await Future.wait([
      for (var i = 0; i < 40; i++) pending.add('/m/$i.mp3'),
      for (var i = 0; i < 40; i += 2) pending.remove('/m/$i.mp3'),
    ]);
    final saved = (jsonDecode(file.readAsStringSync()) as List).cast<String>().toSet();
    expect(saved, {for (var i = 1; i < 40; i += 2) '/m/$i.mp3'});
    expect(dir.listSync().map((e) => p.basename(e.path)), ['pending.json']);
  });
}

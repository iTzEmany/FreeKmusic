import 'dart:io';

import 'package:codecore/providers/backup_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('androidBackupFolder: showing the folder does not create it; a backup does', () async {
    final root = await Directory.systemTemp.createTemp('bkfolder');
    addTearDown(() => root.delete(recursive: true));
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => root.path);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
    final dir = p.join(root.path, 'Documents', 'FreeKmusic');
    expect(await androidBackupFolder(create: false, dir: dir), dir);
    expect(Directory(dir).existsSync(), isFalse);
    expect(await androidBackupFolder(dir: dir), dir);
    expect(Directory(dir).existsSync(), isTrue);
  });
}

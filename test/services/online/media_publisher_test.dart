import 'dart:io';

import 'package:codecore/core/platform.dart';
import 'package:codecore/services/online/media_publisher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('codecore/publish');
  late File work;
  setUp(() async {
    final d = await Directory.systemTemp.createTemp('publisher');
    addTearDown(() => d.delete(recursive: true));
    work = File('${d.path}/a.m4a')..writeAsStringSync('x');
  });
  tearDown(() => debugIsAndroidOverride = null);

  test('off Android the path is returned untouched', () async {
    debugIsAndroidOverride = false;
    expect(await MediaPublisher(channel: channel).publish(work.path), work.path);
    expect(work.existsSync(), isTrue);
  });

  test('Android: the channel answer is the final path and the work copy goes away', () async {
    debugIsAndroidOverride = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async => '/storage/emulated/0/Music/FreeKmusic/a.m4a');
    expect(await MediaPublisher(channel: channel).publish(work.path), '/storage/emulated/0/Music/FreeKmusic/a.m4a');
    expect(work.existsSync(), isFalse);
  });

  test('Android: a refused publish throws and keeps the work copy', () async {
    debugIsAndroidOverride = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async => throw PlatformException(code: 'publish'));
    await expectLater(MediaPublisher(channel: channel).publish(work.path), throwsA(isA<PlatformException>()));
    expect(work.existsSync(), isTrue);
  });
}

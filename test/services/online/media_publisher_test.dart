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
  tearDown(() {
    debugIsAndroidOverride = null;
    debugAndroidSdk = null;
  });

  test('off Android the path is returned untouched', () async {
    debugIsAndroidOverride = false;
    expect(await MediaPublisher(channel: channel).publish(work.path), work.path);
    expect(work.existsSync(), isTrue);
  });

  test('Android: the channel answer is the final path and the work copy goes away', () async {
    debugIsAndroidOverride = true;
    debugAndroidSdk = 33;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async => '/storage/emulated/0/Music/FreeKmusic/a.m4a');
    expect(await MediaPublisher(channel: channel).publish(work.path), '/storage/emulated/0/Music/FreeKmusic/a.m4a');
    expect(work.existsSync(), isFalse);
  });

  test('Android: a refused publish throws and keeps the work copy', () async {
    debugIsAndroidOverride = true;
    debugAndroidSdk = 33;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async => throw PlatformException(code: 'publish'));
    await expectLater(MediaPublisher(channel: channel).publish(work.path), throwsA(isA<PlatformException>()));
    expect(work.existsSync(), isTrue);
  });

  test('D-567: Android 10 and older publish nothing', () async {
    debugIsAndroidOverride = true;
    debugAndroidSdk = 29;
    expect(await MediaPublisher(channel: channel).publish(work.path), work.path);
    expect(work.existsSync(), isTrue);
  });

  test('D-567: the boundary is API 30', () async {
    debugIsAndroidOverride = true;
    for (final (sdk, publishes) in [(29, false), (30, true), (31, true)]) {
      debugAndroidSdk = sdk;
      expect(await publishesToMediaStore(channel: channel), publishes, reason: 'API $sdk');
    }
  });

  test('Android: the subfolder under download-work travels with the path', () async {
    debugIsAndroidOverride = true;
    debugAndroidSdk = 33;
    Object? args;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async => (args = c.arguments) == null ? null : '/x/a.m4a');
    final sub = File('${work.parent.path}/download-work/My Import/a.m4a')..createSync(recursive: true);
    await MediaPublisher(channel: channel).publish(sub.path);
    expect((args as Map)['subdir'], 'My Import');
  });

  group('installTagged', () {
    const dest = '/storage/emulated/0/Music/FreeKmusic/a.m4a';
    late List<String> calls;
    void answer(Object? Function(MethodCall) f) =>
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (c) async {
          calls.add(c.method);
          return f(c);
        });
    setUp(() => calls = []);

    test('MediaStore file: replace is called, no rename or side file', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 33;
      answer((_) => true);
      await installTagged(work.path, dest, publisher: MediaPublisher(channel: channel));
      expect(calls, ['replace']);
      expect(work.existsSync(), isTrue);
    });

    test('a failing replace surfaces as FileSystemException', () async {
      debugIsAndroidOverride = true;
      debugAndroidSdk = 33;
      answer((_) => throw PlatformException(code: 'replace'));
      await expectLater(
        installTagged(work.path, dest, publisher: MediaPublisher(channel: channel)),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('desktop: plain rename, the channel is never asked', () async {
      debugIsAndroidOverride = false;
      answer((_) => true);
      final target = '${work.parent.path}/b.m4a';
      await installTagged(work.path, target, publisher: MediaPublisher(channel: channel));
      expect(calls, isEmpty);
      expect(File(target).existsSync(), isTrue);
    });
  });
}

import 'dart:async';

import 'package:codecore/services/android/incoming_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('codecore/incoming');
  String? path;
  List<String> text = [];

  setUp(() {
    path = null;
    text = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (c) async {
          if (c.method == 'takeIncoming') {
            final v = path;
            path = null;
            return v;
          }
          final v = text;
          text = [];
          return v;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> push(String method) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method)),
        (_) {},
      );

  test('a pending text at start comes from texts()', () async {
    text = ['https://youtu.be/x'];
    final files = IncomingFiles(channel: channel);
    expect(await files.texts().first, 'https://youtu.be/x');
    expect(text, isEmpty);
  });

  test('a pending file at start comes from paths()', () async {
    path = '/cache/a.zip';
    final files = IncomingFiles(channel: channel);
    expect(await files.paths().first, '/cache/a.zip');
  });

  test('texts shared in a row all arrive, in order', () async {
    final files = IncomingFiles(channel: channel);
    final texts = <String>[];
    final a = files.texts().listen(texts.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    text = ['one', 'two', 'three'];
    await push('incomingText');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(texts, ['one', 'two', 'three']);
    unawaited(a.cancel());
  });

  test('pushes are routed: incomingText to texts, incoming to paths', () async {
    final files = IncomingFiles(channel: channel);
    final texts = <String>[];
    final paths = <String>[];
    final a = files.texts().listen(texts.add);
    final b = files.paths().listen(paths.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    text = ['hello'];
    await push('incomingText');
    path = '/cache/b.csv';
    await push('incoming');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(texts, ['hello']);
    expect(paths, ['/cache/b.csv']);
    unawaited(a.cancel());
    unawaited(b.cancel());
  });
}

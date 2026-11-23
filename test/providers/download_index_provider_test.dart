import 'dart:convert';
import 'dart:io';

import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late String gone;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    root = Directory.systemTemp.createTempSync('dl_prov');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (_) async => root.path);
    gone = p.join(root.path, 'gone.m4a'); // its folder exists, the file does not
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      root.deleteSync(recursive: true);
    });
  });

  void writeIndex() => File(DownloadIndex.defaultFile(root.path).path).writeAsStringSync(jsonEncode({'youtube:a': gone}));

  test('the index is pruned once per process, not at every reload', () async {
    writeIndex();
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect((await c.read(downloadIndexProvider.future)).contains('a'), isFalse);
    writeIndex();
    c.invalidate(downloadIndexProvider);
    expect((await c.read(downloadIndexProvider.future)).contains('a'), isTrue);
  });

  test('containsOnDisk forgetting an entry invalidates the provider', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.listen(downloadIndexProvider, (_, _) {});
    final first = await c.read(downloadIndexProvider.future);
    await first.add('a', gone);
    expect(await first.containsOnDisk('a'), isFalse);
    expect(await c.read(downloadIndexProvider.future), isNot(same(first)));
  });
}

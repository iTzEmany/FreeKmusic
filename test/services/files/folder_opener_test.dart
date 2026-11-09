import 'dart:io';

import 'package:codecore/services/files/folder_opener.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/storage');

  String uriOf(String id) =>
      'content://com.android.externalstorage.documents/document/$id';

  test('internal storage path becomes a primary: document URI, never file://', () {
    expect(
      FolderOpener.documentUri('/storage/emulated/0/Music/Rock'),
      uriOf('primary%3AMusic%2FRock'),
    );
    expect(FolderOpener.documentUri('/sdcard/Music/'), uriOf('primary%3AMusic'));
    expect(FolderOpener.documentUri('/storage/emulated/0'), uriOf('primary%3A'));
  });

  test('spaces and accents are percent-encoded', () {
    expect(
      FolderOpener.documentUri('/storage/emulated/0/Musica/Città di sera'),
      uriOf('primary%3AMusica%2FCitt%C3%A0%20di%20sera'),
    );
  });

  test('an SD card keeps its volume id; unknown paths have no URI', () {
    expect(FolderOpener.documentUri('/storage/ABCD-1234/Music'), uriOf('ABCD-1234%3AMusic'));
    expect(FolderOpener.documentUri('/data/user/0/app/files'), isNull);
  });

  test('only /storage/emulated/0, /sdcard and self/primary are primary', () {
    expect(FolderOpener.documentUri('/storage/self/primary/Music'), uriOf('primary%3AMusic'));
    expect(FolderOpener.documentUri('/storage/emulated/0abc/Music'), isNull);
    expect(FolderOpener.documentUri('/storage/emulated/10/Music'), isNull);
    expect(FolderOpener.documentUri('/storage/emulated'), isNull);
    expect(FolderOpener.documentUri('/storage/self/other'), isNull);
  });

  test('double slashes are cleaned; .. and the app folders have no URI', () {
    expect(FolderOpener.documentUri('/storage//emulated/0//Music//Rock/'), uriOf('primary%3AMusic%2FRock'));
    expect(FolderOpener.documentUri('/storage/emulated/0/Music/../Android'), isNull);
    expect(FolderOpener.documentUri('/storage/emulated/0/Android/data/x'), isNull);
    expect(FolderOpener.documentUri('/storage/ABCD-1234/Android/obb'), isNull);
    expect(FolderOpener.documentUri('/storage/emulated/0/Android'), uriOf('primary%3AAndroid'));
  });

  test('a channel that answers null counts as a failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    expect(await FolderOpener(channel: channel, android: true).open('/storage/emulated/0/M'), isFalse);
  });

  test('xdg-open with a non-zero exit code is a failure, zero is a success', () async {
    final dir = Directory.systemTemp.path;
    Future<Process> exits(int code) => Process.start('sh', ['-c', 'exit $code']);
    expect(await FolderOpener(start: (_, _) => exits(3), android: false, windows: false).open(dir), isFalse);
    expect(await FolderOpener(start: (_, _) => exits(0), android: false, windows: false).open(dir), isTrue);
    // explorer reports 1 even when it worked.
    expect(await FolderOpener(start: (_, _) => exits(1), android: false, windows: true).open(dir), isTrue);
  });

  test('Android sends the URI over the channel; a failing channel or odd path gives false', () async {
    final sent = <Object?>[];
    var fail = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      sent.add(call.arguments);
      if (fail) throw PlatformException(code: 'no_app');
      return true;
    });
    final o = FolderOpener(channel: channel, android: true);
    expect(await o.open('/storage/emulated/0/Music'), isTrue);
    expect((sent.single as Map)['uri'], startsWith('content://'));
    fail = true;
    expect(await o.open('/storage/emulated/0/Music'), isFalse);
    sent.clear();
    expect(await o.open('/data/x'), isFalse);
    expect(sent, isEmpty);
  });

  test('desktop starts xdg-open or explorer with the path; a missing program gives false', () async {
    final calls = <String>[];
    Future<Process> ok(String exe, List<String> a) async {
      calls.add('$exe ${a.single}');
      return Process.start('true', []);
    }

    final dir = Directory.systemTemp.path;
    expect(await FolderOpener(start: ok, android: false, windows: false).open(dir), isTrue);
    expect(await FolderOpener(start: ok, android: false, windows: true).open(dir), isTrue);
    expect(calls, ['xdg-open $dir', 'explorer $dir']);
    // A folder that is gone never reaches the program.
    calls.clear();
    expect(await FolderOpener(start: ok, android: false, windows: true).open('$dir/nope-gone'), isFalse);
    expect(calls, isEmpty);
    final bad = FolderOpener(
      start: (_, _) => throw const ProcessException('xdg-open', []),
      android: false,
      windows: false,
    );
    expect(await bad.open(dir), isFalse);
  });
}

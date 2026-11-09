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

    expect(await FolderOpener(start: ok, android: false, windows: false).open('/m/a b'), isTrue);
    expect(await FolderOpener(start: ok, android: false, windows: true).open(r'C:\m'), isTrue);
    expect(calls, ['xdg-open /m/a b', r'explorer C:\m']);
    final bad = FolderOpener(
      start: (_, _) => throw const ProcessException('xdg-open', []),
      android: false,
      windows: false,
    );
    expect(await bad.open('/m'), isFalse);
  });
}

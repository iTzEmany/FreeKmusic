import 'dart:io';

import 'package:codecore/services/online/update_checker.dart';
import 'package:codecore/services/update/update_installer.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final body = List<int>.generate(200000, (i) => i % 251);
  late HttpServer server;
  late Directory tmp;
  late UpdateInstaller installer;
  var cutShort = false;

  setUp(() async {
    cutShort = false;
    tmp = await Directory.systemTemp.createTemp('upd');
    installer = UpdateInstaller(dir: () async => Directory('${tmp.path}/updates'));
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen((r) async {
      if (cutShort) {
        final s = await r.response.detachSocket(writeHeaders: false);
        s.add('HTTP/1.1 200 OK\r\ncontent-length: ${body.length}\r\n\r\n'.codeUnits + body.sublist(0, 1000));
        await s.flush();
        s.destroy();
        return;
      }
      r.response.contentLength = body.length;
      r.response.add(body);
      await r.response.close();
    });
  });
  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  UpdateAsset asset(String? sha) => UpdateAsset(
    name: 'a.apk',
    url: Uri.parse('http://127.0.0.1:${server.port}/a.apk'),
    size: body.length,
    sha256: sha,
  );

  test('right digest: the last event carries the file', () async {
    final events = await installer.download(asset(sha256.convert(body).toString()), CancelToken()).toList();
    expect(events.last.file!.lengthSync(), body.length);
    expect(events.length, greaterThan(1));
  });

  test('wrong digest: error and no file', () async {
    final s = installer.download(asset('00' * 32), CancelToken());
    await expectLater(s, emitsThrough(emitsError(isA<UpdateException>().having((e) => e.kind, 'kind', UpdateFailure.corrupt))));
    expect(File('${tmp.path}/updates/a.apk').existsSync(), isFalse);
  });

  test('connection cut short: interrupted, and it can be tried again', () async {
    cutShort = true;
    final sha = sha256.convert(body).toString();
    await expectLater(
      installer.download(asset(sha), CancelToken()),
      emitsThrough(emitsError(isA<UpdateException>().having((e) => e.kind, 'kind', UpdateFailure.interrupted))),
    );
    cutShort = false;
    expect((await installer.download(asset(sha), CancelToken()).toList()).last.file, isNotNull);
  });

  test('cancel: cancelled and no file', () async {
    final token = CancelToken()..cancel();
    await expectLater(
      installer.download(asset(sha256.convert(body).toString()), token),
      emitsThrough(emitsError(isA<UpdateException>().having((e) => e.kind, 'kind', UpdateFailure.cancelled))),
    );
    expect(File('${tmp.path}/updates/a.apk').existsSync(), isFalse);
  });

  test('cancelled while downloading: cancelled and no file', () async {
    final token = CancelToken();
    final s = installer.download(asset(sha256.convert(body).toString()), token);
    await expectLater(
      s.map((e) {
        token.cancel();
        return e;
      }),
      emitsThrough(emitsError(isA<UpdateException>().having((e) => e.kind, 'kind', UpdateFailure.cancelled))),
    );
    expect(File('${tmp.path}/updates/a.apk').existsSync(), isFalse);
  });

  test('clearUpdatesDir empties the folder', () async {
    final d = Directory('${tmp.path}/updates')..createSync();
    File('${d.path}/x').writeAsStringSync('1');
    await clearUpdatesDir(() async => d);
    expect(d.existsSync(), isFalse);
  });
}

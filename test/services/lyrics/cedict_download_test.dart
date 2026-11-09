import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:codecore/services/lyrics/cedict_download.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake implements HttpClientAdapter {
  _Fake(this.status, this.body);
  final int status;
  final List<int> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(body, status);

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late String target;
  final body = utf8.encode('fake gzip');

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cedict_dl');
    target = '${dir.path}/sub/cedict.txt.gz';
  });
  tearDown(() => dir.delete(recursive: true));

  Dio dio(int status) => Dio()..httpClientAdapter = _Fake(status, body);

  test('download ok: final file, no .tmp, size and delete', () async {
    await downloadCedict(
      dio: dio(200),
      target: target,
      sha256Hex: sha256.convert(body).toString(),
    );
    expect(File(target).readAsBytesSync(), body);
    expect(File('$target.tmp').existsSync(), isFalse);
    expect(await cedictInstalledSize(target), body.length);
    await deleteCedict(target);
    expect(await cedictInstalledSize(target), 0);
  });

  test('HTTP error: no final file, no .tmp', () async {
    await expectLater(
      downloadCedict(dio: dio(404), target: target, sha256Hex: 'x'),
      throwsA(isA<DioException>()),
    );
    expect(File(target).existsSync(), isFalse);
    expect(File('$target.tmp').existsSync(), isFalse);
  });

  test('wrong hash: no final file, no .tmp', () async {
    await expectLater(
      downloadCedict(dio: dio(200), target: target, sha256Hex: 'bad'),
      throwsA(isA<StateError>()),
    );
    expect(File(target).existsSync(), isFalse);
    expect(File('$target.tmp').existsSync(), isFalse);
  });
}

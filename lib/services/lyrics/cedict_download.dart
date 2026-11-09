import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../core/app_log.dart';

const cedictUrl =
    'https://github.com/iTzEmany/codecore-music-player/releases/download/'
    'data-cedict-2026-11-08/cedict_1_0_ts_utf-8_mdbg.txt.gz';
const cedictSha256 =
    '85a742880b294197546c5c48b716a2811d7790367d98cc3ef814df8095fe991e';

/// Downloads the CC-CEDICT copy (D-479) to [target]. Network rules are the
/// caller's. Throws when it fails, the hash differs or [cancel] fires; the
/// `.tmp` is always removed and [target] is only written by a verified file.
Future<void> downloadCedict({
  required Dio dio,
  required String target,
  CancelToken? cancel,
  void Function(int received, int total)? onProgress,
  String url = cedictUrl,
  String sha256Hex = cedictSha256,
}) async {
  final tmp = File('$target.tmp');
  try {
    await Directory(File(target).parent.path).create(recursive: true);
    await dio.download(
      url,
      tmp.path,
      cancelToken: cancel,
      onReceiveProgress: onProgress,
    );
    final got = (await sha256.bind(tmp.openRead()).first).toString();
    if (got != sha256Hex) {
      throw StateError('CC-CEDICT hash mismatch: $got');
    }
    await tmp.rename(target);
  } on Object catch (e, st) {
    if (!(e is DioException && CancelToken.isCancel(e))) {
      AppLog.w('CC-CEDICT download failed', e, st);
    }
    try {
      if (await tmp.exists()) await tmp.delete();
    } on FileSystemException catch (err, st2) {
      AppLog.w('could not delete ${tmp.path}', err, st2);
    }
    rethrow;
  }
}

/// Size of the installed dictionary in bytes, 0 when it is not there.
Future<int> cedictInstalledSize(String path) async {
  final f = File(path);
  return await f.exists() ? await f.length() : 0;
}

Future<void> deleteCedict(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } on FileSystemException catch (e, st) {
    AppLog.w('could not delete $path', e, st);
  }
}

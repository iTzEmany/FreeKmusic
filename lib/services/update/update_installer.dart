import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_log.dart';
import '../online/update_checker.dart' show UpdateAsset;

enum UpdateFailure { interrupted, corrupt, cancelled, installFailed }

class UpdateException implements Exception {
  const UpdateException(this.kind);

  final UpdateFailure kind;

  @override
  String toString() => 'UpdateException($kind)';
}

/// [file] is set on the last event only: downloaded and verified.
class UpdateProgress {
  const UpdateProgress(this.received, this.total, {this.file});

  final int received;
  final int total;
  final File? file;
}

/// In the Flatpak sandbox the temporary folder is a private /tmp the host cannot see; the cache
/// folder maps to `~/.var/app/ID/cache/ID` there, so the pasted `flatpak install` finds the file.
Future<Directory> updatesDir({Map<String, String>? env, Future<Directory> Function()? tmp, Future<Directory> Function()? cache}) async {
  final flatpak = ((env ?? Platform.environment)['FLATPAK_ID'] ?? '').isNotEmpty;
  final base = flatpak ? await (cache ?? getApplicationCacheDirectory)() : await (tmp ?? getTemporaryDirectory)();
  return Directory(p.join(base.path, 'updates'));
}

/// Empties the downloads folder (what is left of an earlier update).
Future<void> clearUpdatesDir([Future<Directory> Function()? dir]) async {
  try {
    final d = await (dir ?? updatesDir)();
    if (await d.exists()) await d.delete(recursive: true);
  } on Object catch (e, st) {
    AppLog.w('could not clear the updates folder', e, st);
  }
}

// Top level so the isolate closure captures the path only; streamed, the file is ~100 MB.
Future<String> _hashInIsolate(String path) =>
    Isolate.run(() async => (await crypto.sha256.bind(File(path).openRead()).first).toString());

class UpdateInstaller {
  UpdateInstaller({Dio? dio, Future<Directory> Function()? dir})
    : _dio = dio ?? Dio(BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30))),
      _dir = dir ?? updatesDir;

  final Dio _dio;
  final Future<Directory> Function() _dir;

  /// Downloads [asset] and checks its SHA-256 (in an isolate). Errors on the
  /// stream are [UpdateException]; the file is deleted on any of them.
  Stream<UpdateProgress> download(UpdateAsset asset, CancelToken cancel) {
    final out = StreamController<UpdateProgress>();
    unawaited(() async {
      File? file;
      try {
        final d = await _dir();
        await d.create(recursive: true);
        file = File(p.join(d.path, p.basename(asset.name)));
        await _dio.download(
          asset.url.toString(),
          file.path,
          cancelToken: cancel,
          onReceiveProgress: (got, total) => out.add(UpdateProgress(got, total > 0 ? total : asset.size)),
        );
        // A release without a digest cannot be verified: not installed.
        final want = asset.sha256;
        if (want == null || await _hashInIsolate(file.path) != want.trim().toLowerCase()) {
          throw const UpdateException(UpdateFailure.corrupt);
        }
        if (cancel.isCancelled) throw const UpdateException(UpdateFailure.cancelled);
        out.add(UpdateProgress(asset.size, asset.size, file: file));
      } on Object catch (e, st) {
        if (file != null && await file.exists()) await file.delete();
        final kind = e is UpdateException
            ? e.kind
            : e is DioException && CancelToken.isCancel(e)
            ? UpdateFailure.cancelled
            : UpdateFailure.interrupted;
        if (kind == UpdateFailure.interrupted) AppLog.w('update download failed', e, st);
        out.addError(UpdateException(kind), st);
      } finally {
        await out.close();
      }
    }());
    return out.stream;
  }
}

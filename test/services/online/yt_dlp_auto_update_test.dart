import 'dart:io';

import 'package:codecore/providers/yt_dlp_update_providers.dart';
import 'package:codecore/core/file_portal.dart';
import 'package:codecore/services/online/yt_dlp_process_service.dart';
import 'package:codecore/services/online/yt_dlp_updater.dart';
import 'package:codecore/services/online/yt_dlp_version.dart';
import 'package:codecore/services/online/retry_policy.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Updater extends YtDlpUpdater {
  _Updater({this.fail}) : super(dio: Dio(), binDir: '/nowhere');
  final YtDlpUpdateError? fail;
  int calls = 0;
  @override
  Future<String> update({void Function(double)? onProgress}) async {
    calls++;
    if (fail != null) throw YtDlpUpdateException(fail!);
    return '2026.11.01';
  }
}

void main() {
  final now = DateTime(2026, 11, 11);

  test('impossible dates in a version are left alone', () {
    expect(ytDlpNeedsDownload('2026.00.01', now), isFalse);
    expect(ytDlpNeedsDownload('0000.01.01', now), isFalse);
    expect(ytDlpNeedsDownload('2026.02.31', now), isFalse);
  });

  test('missing, or older than 90 days, calls for a download; recent does not', () {
    expect(ytDlpNeedsDownload(null, now), isTrue);
    expect(ytDlpNeedsDownload('2026.06.01', now), isTrue);
    expect(ytDlpNeedsDownload('2026.10.01', now), isFalse);
    expect(ytDlpNeedsDownload('garbage', now), isFalse);
  });

  test('autoUpdate downloads when yt-dlp is missing, once, and not when recent', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final u = _Updater();
    await c.read(ytDlpUpdateProvider.notifier).autoUpdate('2026.10.30', now: now, updater: u);
    expect(u.calls, 0);
    await c.read(ytDlpUpdateProvider.notifier).autoUpdate(null, now: now, updater: u);
    expect(u.calls, 1);
    expect(c.read(ytDlpUpdateProvider).phase, YtDlpUpdatePhase.done);
    await c.read(ytDlpUpdateProvider.notifier).autoUpdate(null, now: now, updater: u);
    expect(u.calls, 1);
  });

  test('a network error leaves a failed state to retry from', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(ytDlpUpdateProvider.notifier).autoUpdate(null,
        now: now, updater: _Updater(fail: YtDlpUpdateError.network));
    final s = c.read(ytDlpUpdateProvider);
    expect(s.phase, YtDlpUpdatePhase.failed);
    expect(s.error, YtDlpUpdateError.network);
  });

  test('internal channel errors get their own kind and are never retried', () {
    final e = ytExceptionFromStderr(
        '${PlatformException(code: 'YTDLP', message: 'java.lang.NoClassDefFoundError: il0 | root: java.lang.NoClassDefFoundError: il0').message}');
    expect(e.kind, YtErrorKind.internal);
    expect(ytExceptionFromStderr('java.lang.ExceptionInInitializerError').kind,
        YtErrorKind.internal);
    expect(RetryPolicy().nextDelay(0, YtErrorKind.internal), isNull);
    expect(ytExceptionFromStderr("ERROR: Sign in to confirm you're not a bot").kind,
        YtErrorKind.rateLimited);
  });

  // The Kotlin channel appends " | root: <class>: <msg>" to every Throwable.
  for (final (msg, kind) in [
    ('ERROR: [youtube] abc: HTTP Error 429: Too Many Requests', YtErrorKind.rateLimited),
    ('ERROR: [youtube] abc: Video unavailable', YtErrorKind.unavailable),
    ('ERROR: Temporary failure in name resolution', YtErrorKind.network),
  ]) {
    test('a real yt-dlp error through the channel keeps its kind: ${kind.name}', () {
      expect(
          ytExceptionFromStderr('$msg | root: com.yausername.youtubedl_android.YoutubeDLException: $msg').kind,
          kind);
    });
  }

  test('the file portal check: missing portal is reported, a present one is not', () async {
    ProcessResult res(int code, String out) => ProcessResult(0, code, out, '');
    expect(await filePortalMissing(run: (_, _) async => res(1, '')), isTrue);
    expect(await filePortalMissing(run: (_, _) async => res(0, 'interface org.freedesktop.portal.Settings')), isTrue);
    expect(await filePortalMissing(run: (_, _) async => res(0, 'interface org.freedesktop.portal.FileChooser')), isFalse);
    expect(await filePortalMissing(run: (_, _) => throw const ProcessException('gdbus', [])), isFalse);
  });
}

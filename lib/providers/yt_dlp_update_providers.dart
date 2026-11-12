import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../core/app_log.dart';
import '../core/paths.dart';
import '../services/online/http_client.dart';
import '../services/online/yt_dlp_process_service.dart';
import '../services/online/yt_dlp_updater.dart';
import '../services/online/yt_dlp_version.dart';
import 'youtube_providers.dart';

Future<String> ytDlpBinDir() async => p.join(await appSupportDir(), 'bin');

/// The yt-dlp to run: the one the app downloaded, then one shipped beside the
/// executable (Windows installer) or in `/app/bin` (Flatpak); else the PATH.
Future<String?> locateYtDlp() async {
  final name = Platform.isWindows ? 'yt-dlp.exe' : 'yt-dlp';
  final candidates = [
    managedYtDlpPath(await ytDlpBinDir()),
    p.join(p.dirname(Platform.resolvedExecutable), name),
    if (Platform.isLinux) '/app/bin/yt-dlp',
  ];
  for (final c in candidates) {
    if (await File(c).exists()) return c;
  }
  return null;
}

enum YtDlpUpdatePhase { idle, working, done, failed }

class YtDlpUpdateState {
  const YtDlpUpdateState(this.phase, {this.progress = 0, this.tag, this.error});

  final YtDlpUpdatePhase phase;
  final double progress;
  final String? tag;
  final YtDlpUpdateError? error;
}

/// Runs when the user taps «Aggiorna», and by itself (desktop) when yt-dlp is
/// missing or too old, see [autoUpdate].
class YtDlpUpdateNotifier extends Notifier<YtDlpUpdateState> {
  @override
  YtDlpUpdateState build() => const YtDlpUpdateState(YtDlpUpdatePhase.idle);

  /// Downloads the managed copy when [version] (null = no yt-dlp) calls for
  /// it. Tried once per session: after a failure the user taps «Riprova».
  Future<void> autoUpdate(String? version,
      {DateTime? now, YtDlpUpdater? updater}) async {
    if (state.phase != YtDlpUpdatePhase.idle ||
        !ytDlpNeedsDownload(version, now ?? DateTime.now())) {
      return;
    }
    await run(updater: updater);
  }

  Future<void> run({YtDlpUpdater? updater}) async {
    if (state.phase == YtDlpUpdatePhase.working) return;
    state = const YtDlpUpdateState(YtDlpUpdatePhase.working);
    try {
      updater ??= YtDlpUpdater(
        dio: Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
          headers: {'User-Agent': DioWebClient.userAgent},
        )),
        binDir: await ytDlpBinDir(),
      );
      final tag = await updater.update(
        onProgress: (f) => state =
            YtDlpUpdateState(YtDlpUpdatePhase.working, progress: f),
      );
      final service = ref.read(ytDlpServiceProvider);
      if (service is YtDlpProcessService) service.refresh();
      ref.invalidate(ytDlpStatusProvider);
      state = YtDlpUpdateState(YtDlpUpdatePhase.done, tag: tag);
    } on YtDlpUpdateException catch (e, st) {
      AppLog.e('yt-dlp update failed', e, st);
      state = YtDlpUpdateState(YtDlpUpdatePhase.failed, error: e.kind);
    }
  }
}

final ytDlpUpdateProvider =
    NotifierProvider<YtDlpUpdateNotifier, YtDlpUpdateState>(
        YtDlpUpdateNotifier.new);

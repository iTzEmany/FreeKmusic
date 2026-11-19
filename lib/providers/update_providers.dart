import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_info.dart';
import '../core/app_log.dart';
import '../services/online/update_checker.dart';
import '../services/update/android_update.dart';
import '../services/update/desktop_update.dart';
import '../services/update/update_installer.dart';
import '../services/update/update_target.dart';
import 'online_providers.dart';
import 'settings_providers.dart';
import 'shuffle_plus_providers.dart' show networkProbeProvider;
import 'startup_providers.dart';

/// The repository to ask; overridden in tests.
final releaseRepoProvider = Provider<String>((ref) => kReleaseRepo);

final updateCheckerProvider = Provider<UpdateChecker?>((ref) {
  final repo = ref.watch(releaseRepoProvider);
  if (repo.isEmpty) return null;
  return UpdateChecker(ref.watch(webClientProvider), repo: repo, current: kAppVersion);
});

/// «Controlla all'avvio»: off by default.
class CheckUpdatesOnStartNotifier extends Notifier<bool> {
  @override
  bool build() => ref.read(settingsStoreProvider).readCheckUpdatesOnStart();

  void set(bool on) {
    state = on;
    ref.read(settingsStoreProvider).writeCheckUpdatesOnStart(on).catchError((Object e, StackTrace st) {
      AppLog.w('could not save the update setting', e, st);
    });
  }
}

final checkUpdatesOnStartProvider =
    NotifierProvider<CheckUpdatesOnStartNotifier, bool>(CheckUpdatesOnStartNotifier.new);

int _epochDay(DateTime now) => now.toUtc().millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

/// The check made once at start-up (when enabled): at most one a day, a
/// failure is silent. The new release, or null.
final updateOnStartProvider = FutureProvider<UpdateInfo?>(
  (ref) async {
    final checker = ref.watch(updateCheckerProvider);
    if (checker == null || !ref.read(checkUpdatesOnStartProvider)) return null;
    await ref.watch(startupSettledProvider.future);
    final store = ref.read(settingsStoreProvider);
    final today = _epochDay(DateTime.now());
    if (store.readLastUpdateCheckDay() == today) return null;
    await store.writeLastUpdateCheckDay(today);
    final r = await checker.check();
    return r.status == UpdateStatus.newer ? r.info : null;
  },
  retry: (_, _) => null,
);

final androidUpdateProvider = Provider<AndroidUpdate>((ref) => AndroidUpdate());
final desktopUpdateProvider = Provider<DesktopUpdate>((ref) => DesktopUpdate());
final updateInstallerProvider = Provider<UpdateInstaller>((ref) => UpdateInstaller());
final updatesDirProvider = Provider<Future<Directory> Function()>((ref) => updatesDir);

/// What this install updates to; null when there is no file for it.
final updateTargetProvider = FutureProvider<UpdateTarget?>((ref) async {
  try {
    return await detectUpdateTarget(androidAbi: ref.read(androidUpdateProvider).abi);
  } on Object catch (e, st) {
    AppLog.w('could not tell which update file fits', e, st);
    return null;
  }
});

/// Empties the updates folder once the app has settled. Watch it from the app root.
final updatesCleanupProvider = Provider<void>((ref) {
  ref.read(startupSettledProvider.future).then((_) {
    if (ref.mounted) unawaited(clearUpdatesDir(ref.read(updatesDirProvider)));
  });
});

enum UpdatePhase { idle, confirmSize, downloading, ready, error, differentSigner, needsPermission }

class UpdateDownloadState {
  const UpdateDownloadState(this.phase, {this.asset, this.received = 0, this.failure});

  final UpdatePhase phase;
  final UpdateAsset? asset;
  final int received;

  /// With [UpdatePhase.error].
  final UpdateFailure? failure;
}

/// The update flow: pick the file, ask on a metered network (D-656), download,
/// verify, install. Files that do not install themselves open in the browser.
class UpdateDownloadNotifier extends Notifier<UpdateDownloadState> {
  UpdateInfo? _info;
  UpdateTarget? _target;
  CancelToken? _cancel;

  @override
  UpdateDownloadState build() => const UpdateDownloadState(UpdatePhase.idle);

  Future<void> start(UpdateInfo info) async {
    if (state.phase == UpdatePhase.downloading) return;
    _info = info;
    final target = _target = await ref.read(updateTargetProvider.future);
    final asset = target == null ? null : pickUpdateAsset(info.assets, target);
    final desktop = ref.read(desktopUpdateProvider);
    if (asset == null) return desktop.openBrowser(Uri.parse(info.url));
    if (!selfInstalls(target!.kind)) return desktop.openBrowser(asset.url);
    if ((await ref.read(networkProbeProvider).current()).metered) {
      state = UpdateDownloadState(UpdatePhase.confirmSize, asset: asset);
      return;
    }
    await _download(asset);
  }

  /// After [UpdatePhase.confirmSize].
  Future<void> confirm() async {
    final a = state.asset;
    if (state.phase == UpdatePhase.confirmSize && a != null) await _download(a);
  }

  void cancel() {
    _cancel?.cancel();
    if (state.phase == UpdatePhase.confirmSize) state = const UpdateDownloadState(UpdatePhase.idle);
  }

  Future<void> retry() async {
    final i = _info;
    if (i != null) await start(i);
  }

  Future<void> _download(UpdateAsset asset) async {
    final cancel = _cancel = CancelToken();
    state = UpdateDownloadState(UpdatePhase.downloading, asset: asset);
    File? file;
    try {
      await for (final e in ref.read(updateInstallerProvider).download(asset, cancel)) {
        if (!ref.mounted) return;
        file = e.file;
        if (file == null) state = UpdateDownloadState(UpdatePhase.downloading, asset: asset, received: e.received);
      }
    } on UpdateException catch (e) {
      if (!ref.mounted) return;
      state = e.kind == UpdateFailure.cancelled
          ? const UpdateDownloadState(UpdatePhase.idle)
          : UpdateDownloadState(UpdatePhase.error, asset: asset, failure: e.kind);
      return;
    }
    if (file != null && ref.mounted) await _install(asset, file);
  }

  Future<void> _install(UpdateAsset asset, File file) async {
    final target = _target!;
    UpdateDownloadState done(UpdatePhase p, [UpdateFailure? f]) => UpdateDownloadState(p, asset: asset, failure: f);
    try {
      if (target.kind == UpdateKind.androidFull || target.kind == UpdateKind.androidLite) {
        final android = ref.read(androidUpdateProvider);
        state = switch (await android.install(file.path)) {
          AndroidInstallResult.started => done(UpdatePhase.ready),
          AndroidInstallResult.needsPermission => done(UpdatePhase.needsPermission),
          AndroidInstallResult.differentSigner => done(UpdatePhase.differentSigner),
          AndroidInstallResult.failed => done(UpdatePhase.error, UpdateFailure.installFailed),
        };
        if (state.phase == UpdatePhase.needsPermission) await android.openInstallSettings();
      } else {
        await ref.read(desktopUpdateProvider).install(file, target, fallback: asset.url);
        state = done(UpdatePhase.ready);
      }
    } on Object catch (e, st) {
      AppLog.w('update install failed', e, st);
      state = done(UpdatePhase.error, UpdateFailure.installFailed);
    }
  }
}

final updateDownloadProvider = NotifierProvider<UpdateDownloadNotifier, UpdateDownloadState>(
  UpdateDownloadNotifier.new,
);

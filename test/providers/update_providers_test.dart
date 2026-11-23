import 'dart:async';
import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/providers/issue_providers.dart' show linkOpenerProvider;
import 'package:codecore/services/issue/link_opener.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart' show networkProbeProvider;
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/startup_providers.dart';
import 'package:codecore/providers/update_providers.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/update_checker.dart';
import 'package:codecore/services/update/android_update.dart';
import 'package:codecore/services/update/desktop_update.dart';
import 'package:codecore/services/update/update_installer.dart';
import 'package:codecore/services/update/update_target.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoWeb implements WebClient {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Checker extends UpdateChecker {
  _Checker(this.status) : super(_NoWeb(), repo: 'x/y', current: '1.0.0');
  final UpdateStatus status;
  @override
  Future<UpdateResult> check() async => UpdateResult(status);
}

class _Probe extends NetworkProbe {
  _Probe(this.metered, {this.boom = false});
  final bool metered;
  final bool boom;
  @override
  Future<NetworkKind> current() async {
    if (boom) throw StateError('probe');
    return NetworkKind(metered: metered);
  }
}

class _Installer extends UpdateInstaller {
  _Installer(this.file);
  final File file;
  int downloads = 0;
  CancelToken? token;

  /// Replaces the normal two events; may throw an [UpdateException].
  Stream<UpdateProgress> Function()? script;
  @override
  Stream<UpdateProgress> download(UpdateAsset asset, CancelToken cancel) async* {
    downloads++;
    token = cancel;
    if (script != null) {
      yield* script!();
      return;
    }
    yield const UpdateProgress(5, 10);
    yield UpdateProgress(10, 10, file: file);
  }
}

class _Android implements AndroidUpdate {
  _Android(this.result);
  AndroidInstallResult result;
  final calls = <String>[];
  bool allowed = true;
  bool boom = false;
  Completer<bool>? gate;
  @override
  Future<String> abi() async => 'arm64-v8a';
  @override
  Future<bool> canInstall() async {
    return gate == null ? allowed : gate!.future;
  }
  @override
  Future<bool> openInstallSettings() async {
    calls.add('settings');
    return true;
  }
  @override
  Future<AndroidInstallResult> install(String path) async {
    calls.add('install:$path');
    if (boom) throw StateError('install');
    return result;
  }
}

class _Desktop implements DesktopUpdate {
  final calls = <String>[];
  bool ok = true;
  Uri? fallback;
  @override
  Future<bool> install(File f, UpdateTarget t, {Uri? fallback}) async {
    calls.add('install:${f.path}');
    this.fallback = fallback;
    return ok;
  }
  @override
  Future<bool> openBrowser(Uri url) async {
    calls.add('browser:$url');
    return true;
  }
}

class _Link extends LinkOpener {
  _Link(this.ok);
  final bool ok;
  bool boom = false;
  final opened = <String>[];
  @override
  Future<bool> open(String url) async {
    opened.add(url);
    if (boom) throw StateError('link');
    return ok;
  }
}

void main() {
  const apk = 'freekmusic-full-arm64-v8a-release.apk';
  final info = UpdateInfo(version: '9.9.9', url: 'https://x/rel', assets: [
    UpdateAsset(name: apk, url: Uri.parse('https://x/$apk'), size: 10, sha256: 'ab'),
    UpdateAsset(name: 'freekmusic_9.9.9_amd64.deb', url: Uri.parse('https://x/d.deb'), size: 10, sha256: 'ab'),
  ]);

  late _Installer installer;
  late _Desktop desktop;
  late _Android android;
  late _Link link;

  ProviderContainer make(UpdateKind kind, {bool metered = false, AndroidInstallResult r = AndroidInstallResult.started, File? file, bool linkOk = true, bool probeBoom = false}) {
    link = _Link(linkOk);
    installer = _Installer(file ?? File('/tmp/$apk'));
    desktop = _Desktop();
    android = _Android(r);
    final c = ProviderContainer(overrides: [
      updateTargetProvider.overrideWith((_) => UpdateTarget(kind: kind, abi: 'arm64-v8a')),
      updateInstallerProvider.overrideWithValue(installer),
      networkProbeProvider.overrideWithValue(_Probe(metered, boom: probeBoom)),
      androidUpdateProvider.overrideWithValue(android),
      desktopUpdateProvider.overrideWithValue(desktop),
      linkOpenerProvider.overrideWithValue(link),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('metered network: asks with the size, downloads only after confirm', () async {
    final c = make(UpdateKind.androidFull, metered: true);
    final n = c.read(updateDownloadProvider.notifier);
    await n.start(info);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.confirmSize);
    expect(c.read(updateDownloadProvider).asset!.size, 10);
    expect(installer.downloads, 0);
    await n.confirm();
    expect(installer.downloads, 1);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.ready);
  });

  test('Android: downloaded file goes to the system installer', () async {
    final c = make(UpdateKind.androidFull);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(android.calls, ['install:/tmp/$apk']);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.ready);
  });

  test('Android: missing permission opens the settings; other signer is reported', () async {
    var c = make(UpdateKind.androidFull, r: AndroidInstallResult.needsPermission);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.needsPermission);
    expect(android.calls, ['install:/tmp/$apk', 'settings']);
    c = make(UpdateKind.androidFull, r: AndroidInstallResult.differentSigner);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.differentSigner);
    expect(android.calls, ['install:/tmp/$apk']);
  });

  test('back from the permission setting: installs the same file once allowed, no new download', () async {
    final tmp = await Directory.systemTemp.createTemp('updr');
    addTearDown(() => tmp.delete(recursive: true));
    final file = File('${tmp.path}/$apk')..writeAsStringSync('x');
    final c = make(UpdateKind.androidFull, r: AndroidInstallResult.needsPermission, file: file);
    final n = c.read(updateDownloadProvider.notifier);
    android.allowed = false;
    await n.start(info);
    android.calls.clear();
    await n.resumeInstall();
    expect(android.calls, isEmpty, reason: 'still not allowed: nothing happens');
    android.allowed = true;
    android.result = AndroidInstallResult.started;
    await n.resumeInstall();
    expect(android.calls, ['install:${file.path}']);
    expect(installer.downloads, 1);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.ready);
  });

  test('desktop self-install: the installer is handed the file', () async {
    final c = make(UpdateKind.windows);
    final w = UpdateAsset(name: 'FreeKmusic-Setup-9.9.9.exe', url: Uri.parse('https://x/s.exe'), size: 10, sha256: 'ab');
    await c.read(updateDownloadProvider.notifier).start(UpdateInfo(version: '9.9.9', url: 'u', assets: [w]));
    expect(desktop.calls, ['install:/tmp/$apk']);
  });

  test('.deb opens the browser on the file, with no download', () async {
    final c = make(UpdateKind.deb);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(link.opened, ['https://x/d.deb']);
    expect(installer.downloads, 0);
  });

  test('no file in the release: the release page opens', () async {
    final c = make(UpdateKind.macos);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(link.opened, ['https://x/rel']);
  });

  test('the browser cannot open: error state', () async {
    final c = make(UpdateKind.deb, linkOk: false);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.error);
  });

  test('two taps at once download once', () async {
    final c = make(UpdateKind.androidFull);
    final n = c.read(updateDownloadProvider.notifier);
    await Future.wait([n.start(info), n.start(info)]);
    expect(installer.downloads, 1);
  });

  test('no digest: the browser opens on the file, nothing is downloaded', () async {
    final c = make(UpdateKind.androidFull);
    final nd = UpdateInfo(version: '9', url: 'u', assets: [UpdateAsset(name: apk, url: Uri.parse('https://x/$apk'), size: 10)]);
    await c.read(updateDownloadProvider.notifier).start(nd);
    expect(link.opened, ['https://x/$apk']);
    expect(installer.downloads, 0);
  });

  test('the updates folder is emptied once the app has settled', () async {
    final tmp = await Directory.systemTemp.createTemp('updc');
    final d = Directory('${tmp.path}/updates')..createSync();
    File('${d.path}/old.apk').writeAsStringSync('1');
    final c = ProviderContainer(overrides: [
      startupSettledProvider.overrideWith((_) async {}),
      updatesDirProvider.overrideWithValue(() async => d),
    ]);
    addTearDown(() async {
      c.dispose();
      await tmp.delete(recursive: true);
    });
    c.read(updatesCleanupProvider);
    await c.read(startupSettledProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(d.existsSync(), isFalse);
  });

  File tmpFile(String name) {
    final d = Directory.systemTemp.createTempSync('updp');
    addTearDown(() => d.deleteSync(recursive: true));
    return File('${d.path}/$name')..writeAsStringSync('x');
  }

  test('cancel at the size question goes back to idle', () async {
    final c = make(UpdateKind.androidFull, metered: true);
    final n = c.read(updateDownloadProvider.notifier);
    await n.start(info);
    n.cancel();
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.idle);
  });

  test('confirm outside the size question downloads nothing', () async {
    final c = make(UpdateKind.androidFull);
    await c.read(updateDownloadProvider.notifier).confirm();
    expect(installer.downloads, 0);
  });

  test('cancel while downloading cancels the token', () async {
    final c = make(UpdateKind.androidFull);
    final gate = Completer<void>();
    installer.script = () async* {
      yield const UpdateProgress(1, 10);
      await gate.future;
    };
    final run = c.read(updateDownloadProvider.notifier).start(info);
    await Future<void>.delayed(Duration.zero);
    c.read(updateDownloadProvider.notifier).cancel();
    expect(installer.token!.isCancelled, isTrue);
    gate.complete();
    await run;
  });

  test('download failures: corrupt and interrupted are errors, cancelled is idle', () async {
    final expected = {
      UpdateFailure.corrupt: UpdatePhase.error,
      UpdateFailure.interrupted: UpdatePhase.error,
      UpdateFailure.cancelled: UpdatePhase.idle,
    };
    for (final e in expected.entries) {
      final c = make(UpdateKind.androidFull);
      installer.script = () => Stream.error(UpdateException(e.key));
      await c.read(updateDownloadProvider.notifier).start(info);
      final s = c.read(updateDownloadProvider);
      expect(s.phase, e.value, reason: '${e.key}');
      if (e.value == UpdatePhase.error) expect(s.failure, e.key);
    }
  });

  test('the install fails or throws: error installFailed', () async {
    var c = make(UpdateKind.androidFull, r: AndroidInstallResult.failed);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(c.read(updateDownloadProvider).failure, UpdateFailure.installFailed);
    c = make(UpdateKind.androidFull);
    android.boom = true;
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.error);
  });

  test('desktop install false: error; the fallback is the file URL', () async {
    final c = make(UpdateKind.windows);
    desktop.ok = false;
    final w = UpdateAsset(name: 'FreeKmusic-Setup-9.9.9.exe', url: Uri.parse('https://x/s.exe'), size: 10, sha256: 'ab');
    await c.read(updateDownloadProvider.notifier).start(UpdateInfo(version: '9.9.9', url: 'u', assets: [w]));
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.error);
    expect(desktop.fallback, w.url);
  });

  test('the network probe or the browser throw: error, nothing escapes', () async {
    var c = make(UpdateKind.androidFull, probeBoom: true);
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.error);
    c = make(UpdateKind.deb);
    link.boom = true;
    await c.read(updateDownloadProvider.notifier).start(info);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.error);
  });

  test('retry after an error downloads again', () async {
    final c = make(UpdateKind.androidFull);
    installer.script = () => Stream.error(const UpdateException(UpdateFailure.interrupted));
    final n = c.read(updateDownloadProvider.notifier);
    await n.start(info);
    installer.script = null;
    await n.retry();
    expect(installer.downloads, 2);
    expect(c.read(updateDownloadProvider).phase, UpdatePhase.ready);
  });

  test('resumeInstall from idle does nothing', () async {
    final c = make(UpdateKind.androidFull);
    await c.read(updateDownloadProvider.notifier).resumeInstall();
    expect(android.calls, isEmpty);
    expect(installer.downloads, 0);
  });

  test('resumeInstall with the file gone downloads again', () async {
    final file = tmpFile(apk);
    final c = make(UpdateKind.androidFull, r: AndroidInstallResult.needsPermission, file: file);
    final n = c.read(updateDownloadProvider.notifier);
    await n.start(info);
    file.deleteSync();
    await n.resumeInstall();
    expect(installer.downloads, 2);
  });

  test('two resumeInstall at once install once', () async {
    final file = tmpFile(apk);
    final c = make(UpdateKind.androidFull, r: AndroidInstallResult.needsPermission, file: file);
    final n = c.read(updateDownloadProvider.notifier);
    await n.start(info);
    android.calls.clear();
    android.result = AndroidInstallResult.started;
    final gate = android.gate = Completer<bool>();
    final both = Future.wait([n.resumeInstall(), n.resumeInstall()]);
    gate.complete(true);
    await both;
    expect(android.calls.where((x) => x.startsWith('install')), hasLength(1));
  });

  test('the notifier disposed during a download cancels it and stays quiet', () async {
    final c = make(UpdateKind.androidFull);
    final gate = Completer<void>();
    installer.script = () async* {
      yield const UpdateProgress(1, 10);
      await gate.future;
    };
    final run = c.read(updateDownloadProvider.notifier).start(info);
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    expect(installer.token!.isCancelled, isTrue);
    gate.complete();
    await run;
    expect(android.calls, isEmpty);
  });

  test('the updates folder is left alone while a start is in progress', () async {
    final tmp = await Directory.systemTemp.createTemp('updc2');
    final d = Directory('${tmp.path}/updates')..createSync();
    final settled = Completer<void>();
    final gate = Completer<void>();
    final c = make(UpdateKind.androidFull);
    final c2 = ProviderContainer(overrides: [
      startupSettledProvider.overrideWith((_) => settled.future),
      updatesDirProvider.overrideWithValue(() async => d),
      updateTargetProvider.overrideWith((_) async {
        await gate.future;
        return null;
      }),
      linkOpenerProvider.overrideWithValue(_Link(true)),
    ]);
    c.dispose();
    addTearDown(() async {
      c2.dispose();
      await tmp.delete(recursive: true);
    });
    c2.read(updatesCleanupProvider);
    final run = c2.read(updateDownloadProvider.notifier).start(info);
    settled.complete();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(d.existsSync(), isTrue);
    gate.complete();
    await run;
  });

  for (final (status, written) in [
    (UpdateStatus.failed, false),
    (UpdateStatus.rateLimited, false),
    (UpdateStatus.upToDate, true),
    (UpdateStatus.newer, true),
  ]) {
    test('start-up check $status: the day is ${written ? '' : 'not '}recorded', () async {
      SharedPreferences.setMockInitialValues({'checkUpdatesOnStart': true});
      final store = SettingsStore(await SharedPreferences.getInstance());
      final c = ProviderContainer(overrides: [
        settingsStoreProvider.overrideWithValue(store),
        startupSettledProvider.overrideWith((_) async {}),
        updateCheckerProvider.overrideWithValue(_Checker(status)),
      ]);
      addTearDown(c.dispose);
      await c.read(updateOnStartProvider.future);
      expect(store.readLastUpdateCheckDay() != 0, written);
    });
  }
}

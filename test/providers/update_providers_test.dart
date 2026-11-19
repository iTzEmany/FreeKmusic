import 'dart:async';
import 'dart:io';

import 'package:codecore/core/network_kind.dart';
import 'package:codecore/providers/issue_providers.dart' show linkOpenerProvider;
import 'package:codecore/services/issue/link_opener.dart';
import 'package:codecore/providers/shuffle_plus_providers.dart' show networkProbeProvider;
import 'package:codecore/providers/startup_providers.dart';
import 'package:codecore/providers/update_providers.dart';
import 'package:codecore/services/online/update_checker.dart';
import 'package:codecore/services/update/android_update.dart';
import 'package:codecore/services/update/desktop_update.dart';
import 'package:codecore/services/update/update_installer.dart';
import 'package:codecore/services/update/update_target.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends NetworkProbe {
  _Probe(this.metered);
  final bool metered;
  @override
  Future<NetworkKind> current() async => NetworkKind(metered: metered);
}

class _Installer extends UpdateInstaller {
  _Installer(this.file);
  final File file;
  int downloads = 0;
  @override
  Stream<UpdateProgress> download(UpdateAsset asset, CancelToken cancel) async* {
    downloads++;
    yield const UpdateProgress(5, 10);
    yield UpdateProgress(10, 10, file: file);
  }
}

class _Android implements AndroidUpdate {
  _Android(this.result);
  AndroidInstallResult result;
  final calls = <String>[];
  bool allowed = true;
  @override
  Future<String> abi() async => 'arm64-v8a';
  @override
  Future<bool> canInstall() async => allowed;
  @override
  Future<bool> openInstallSettings() async {
    calls.add('settings');
    return true;
  }
  @override
  Future<AndroidInstallResult> install(String path) async {
    calls.add('install:$path');
    return result;
  }
}

class _Desktop implements DesktopUpdate {
  final calls = <String>[];
  @override
  Future<bool> install(File f, UpdateTarget t, {Uri? fallback}) async {
    calls.add('install:${f.path}');
    return true;
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
  final opened = <String>[];
  @override
  Future<bool> open(String url) async {
    opened.add(url);
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

  ProviderContainer make(UpdateKind kind, {bool metered = false, AndroidInstallResult r = AndroidInstallResult.started, File? file, bool linkOk = true}) {
    link = _Link(linkOk);
    installer = _Installer(file ?? File('/tmp/$apk'));
    desktop = _Desktop();
    android = _Android(r);
    final c = ProviderContainer(overrides: [
      updateTargetProvider.overrideWith((_) => UpdateTarget(kind: kind, abi: 'arm64-v8a')),
      updateInstallerProvider.overrideWithValue(installer),
      networkProbeProvider.overrideWithValue(_Probe(metered)),
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
}

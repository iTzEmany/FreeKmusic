import 'dart:io';

import 'package:codecore/services/online/update_checker.dart';
import 'package:codecore/services/update/update_target.dart';
import 'package:flutter_test/flutter_test.dart';

List<UpdateAsset> _release(String v) => [
  for (final n in [
    'FreeKmusic-$v-macos.zip',
    'freekmusic-$v-x86_64.AppImage',
    'freekmusic-full-arm64-v8a-release.apk',
    'freekmusic-full-armeabi-v7a-release.apk',
    'freekmusic-linux-x64.zip',
    'freekmusic-lite-arm64-v8a-release.apk',
    'freekmusic-lite-armeabi-v7a-release.apk',
    'FreeKmusic-Setup-$v.exe',
    'freekmusic-$v.flatpak',
    'freekmusic.flatpak',
    'freekmusic_${v}_amd64.deb',
  ])
    UpdateAsset(name: n, url: Uri.parse('https://x/$n'), size: 1),
];

void main() {
  final cases = <(UpdateTarget, String Function(String))>[
    (const UpdateTarget(kind: UpdateKind.androidFull, abi: 'arm64-v8a'), (v) => 'freekmusic-full-arm64-v8a-release.apk'),
    (const UpdateTarget(kind: UpdateKind.androidFull, abi: 'armeabi-v7a'), (v) => 'freekmusic-full-armeabi-v7a-release.apk'),
    (const UpdateTarget(kind: UpdateKind.androidLite, abi: 'arm64-v8a'), (v) => 'freekmusic-lite-arm64-v8a-release.apk'),
    (const UpdateTarget(kind: UpdateKind.androidLite, abi: 'armeabi-v7a'), (v) => 'freekmusic-lite-armeabi-v7a-release.apk'),
    (const UpdateTarget(kind: UpdateKind.windows), (v) => 'FreeKmusic-Setup-$v.exe'),
    (const UpdateTarget(kind: UpdateKind.appImage), (v) => 'freekmusic-$v-x86_64.AppImage'),
    (const UpdateTarget(kind: UpdateKind.deb), (v) => 'freekmusic_${v}_amd64.deb'),
    (const UpdateTarget(kind: UpdateKind.flatpak), (v) => 'freekmusic-$v.flatpak'),
    (const UpdateTarget(kind: UpdateKind.linuxZip), (v) => 'freekmusic-linux-x64.zip'),
    (const UpdateTarget(kind: UpdateKind.macos), (v) => 'FreeKmusic-$v-macos.zip'),
  ];

  for (final v in ['1.6.2', '2.10.0']) {
    for (final (t, name) in cases) {
      test('${t.kind} ${t.abi ?? ''} picks its file in $v', () {
        expect(pickUpdateAsset(_release(v), t)?.name, name(v));
      });
    }
  }

  test('an ABI the release does not carry gives null', () {
    expect(pickUpdateAsset(_release('1.6.2'), const UpdateTarget(kind: UpdateKind.androidFull, abi: 'x86_64')), isNull);
  });

  test('a release without the file gives null', () {
    expect(pickUpdateAsset(_release('1.6.2').where((a) => !a.name.endsWith('.deb')).toList(), const UpdateTarget(kind: UpdateKind.deb)), isNull);
  });

  test('the flatpak command quotes a path with spaces or quotes', () {
    expect(flatpakInstallCommand('/home/u/updates/freekmusic-1.8.0.flatpak'), 'flatpak install --user /home/u/updates/freekmusic-1.8.0.flatpak');
    expect(flatpakInstallCommand("/home/u/my dir/it's.flatpak"), "flatpak install --user '/home/u/my dir/it'\\''s.flatpak'");
  });

  test('only Android, Windows and AppImage install by themselves', () {
    expect([for (final k in UpdateKind.values) if (selfInstalls(k)) k], [
      UpdateKind.androidFull,
      UpdateKind.androidLite,
      UpdateKind.windows,
      UpdateKind.appImage,
    ]);
  });

  test('on Linux: AppImage, Flatpak, system path, otherwise the zip', () async {
    Future<UpdateKind?> kind(Map<String, String> env, String exe) async =>
        (await detectUpdateTarget(env: env, executable: exe))?.kind;
    expect(await kind({'APPIMAGE': '/x/a.AppImage'}, '/tmp/.mount_freekAbc/usr/bin/freekmusic'), UpdateKind.appImage);
    expect(await kind({'APPIMAGE': '/x/vscode.AppImage'}, '/home/u/freekmusic/freekmusic'), UpdateKind.linuxZip);
    expect(await kind({'FLATPAK_ID': 'com.freekmusic.player'}, '/app/freekmusic'), UpdateKind.flatpak);
    expect(await kind({}, '/usr/lib/freekmusic/freekmusic'), UpdateKind.deb);
    expect(await kind({}, '/opt/freekmusic/freekmusic'), UpdateKind.deb);
    expect(await kind({}, '/usr/local/bin/other'), UpdateKind.linuxZip);
    expect(await kind({}, '/home/u/freekmusic/freekmusic'), UpdateKind.linuxZip);
    expect(await kind({}, '/usr/bin/freekmusic'), UpdateKind.deb);
    expect(await kind({}, '/usr/bin/firefox'), UpdateKind.linuxZip);
    expect(await kind({}, '/usr/lib/firefox/firefox'), UpdateKind.linuxZip);
    expect(await kind({'FLATPAK_ID': '', 'APPIMAGE': ''}, '/home/u/f/freekmusic'), UpdateKind.linuxZip);
    expect(await kind({'APPIMAGE': '/x/a.AppImage', 'FLATPAK_ID': 'com.freekmusic.player'}, '/app/freekmusic'), UpdateKind.flatpak);
  }, skip: !Platform.isLinux);

  test('APPDIR is matched as a folder: a sibling prefix, "/" or empty do not count', () async {
    Future<UpdateKind?> kind(String appDir, String exe) async =>
        (await detectUpdateTarget(env: {'APPIMAGE': '/x/a.AppImage', 'APPDIR': appDir}, executable: exe))?.kind;
    expect(await kind('/home/u/app', '/home/u/app/usr/bin/freekmusic'), UpdateKind.appImage);
    expect(await kind('/home/u/app', '/home/u/app-other/freekmusic'), UpdateKind.linuxZip);
    expect(await kind('/', '/home/u/freekmusic'), UpdateKind.linuxZip);
    expect(await kind('', '/home/u/freekmusic'), UpdateKind.linuxZip);
  }, skip: !Platform.isLinux);

  test('side files of a release are not picked', () {
    final extra = [
      for (final n in ['freekmusic.flatpak.sha256', 'FreeKmusic-Setup-1.exe.blockmap', 'freekmusic_1_amd64.deb.asc'])
        UpdateAsset(name: n, url: Uri.parse('https://x/$n'), size: 1),
    ];
    for (final k in [UpdateKind.flatpak, UpdateKind.windows, UpdateKind.deb]) {
      expect(pickUpdateAsset(extra, UpdateTarget(kind: k)), isNull);
    }
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/services/update/desktop_update.dart';
import 'package:codecore/services/update/update_target.dart';

void main() {
  late Directory dir;
  late List<List<String>> started;
  late List<int> exits;
  final url = Uri.parse('https://example.com/a');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('desktop_update');
    started = [];
    exits = [];
  });
  tearDown(() => dir.deleteSync(recursive: true));

  DesktopUpdate make({Map<String, String> env = const {}, String? browser}) =>
      DesktopUpdate(
        start: (exe, args) async => started.add([exe, ...args]),
        run: (exe, args) => Process.run(exe, args),
        exitApp: exits.add,
        env: env,
        browserCommand: browser ?? 'xdg-open',
      );

  UpdateTarget target(UpdateKind k) => UpdateTarget(kind: k);

  test('windows starts the silent setup and exits', () async {
    final setup = File('${dir.path}/setup.exe')..writeAsStringSync('x');
    expect(await make().install(setup, target(UpdateKind.windows)), isTrue);
    expect(started.single, [
      setup.path,
      '/SILENT',
      '/SUPPRESSMSGBOXES',
      '/NORESTART',
      '/CLOSEAPPLICATIONS',
    ]);
    expect(exits, [0]);
  });

  test(
    'appImage replaces the old file, makes it executable and restarts',
    () async {
      final old = File('${dir.path}/App.AppImage')..writeAsStringSync('old');
      final fresh = File('${dir.path}/dl/new')
        ..createSync(recursive: true)
        ..writeAsStringSync('new');
      await make(env: {'APPIMAGE': old.path})
          .install(fresh, target(UpdateKind.appImage), fallback: url);
      expect(old.readAsStringSync(), 'new');
      expect(old.statSync().mode & 0x49, 0x49); // executable bits
      expect(File('${old.path}.new').existsSync(), isFalse);
      expect(started.single, [old.path]);
      expect(exits, [0]);
    },
  );

  test('appImage in a read-only folder opens the browser', () async {
    final ro = Directory('${dir.path}/ro')..createSync();
    final old = File('${ro.path}/App.AppImage')..writeAsStringSync('old');
    final fresh = File('${dir.path}/new')..writeAsStringSync('new');
    await Process.run('chmod', ['555', ro.path]);
    try {
      final ok = await make(env: {'APPIMAGE': old.path})
          .install(fresh, target(UpdateKind.appImage), fallback: url);
      expect(ok, isFalse);
    } finally {
      await Process.run('chmod', ['755', ro.path]);
    }
    expect(old.readAsStringSync(), 'old');
    expect(started.single, ['xdg-open', url.toString()]);
    expect(exits, isEmpty);
  });

  test('deb, flatpak and zip open the browser', () async {
    final f = File('${dir.path}/x')..writeAsStringSync('x');
    for (final k in [UpdateKind.deb, UpdateKind.flatpak, UpdateKind.linuxZip]) {
      await make().install(f, target(k), fallback: url);
    }
    expect(started, everyElement(['xdg-open', url.toString()]));
    expect(started, hasLength(3));
  });

  test('macOS opens the browser with open', () async {
    await make(
      browser: 'open',
    ).install(File('${dir.path}/x'), target(UpdateKind.macos), fallback: url);
    expect(started.single, ['open', url.toString()]);
  });

  test('openBrowser returns false when the process cannot start', () async {
    final d = DesktopUpdate(
      start: (exe, args) => throw const ProcessException('xdg-open', []),
      exitApp: exits.add,
      env: const {},
      browserCommand: 'xdg-open',
    );
    expect(await d.openBrowser(url), isFalse);
  });
}

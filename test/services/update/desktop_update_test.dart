import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/services/update/desktop_update.dart';
import 'package:codecore/services/update/update_target.dart';

// File modes and read-only folders are POSIX: the AppImage path runs on Linux only.
final Object _posixOnly = Platform.isWindows ? 'POSIX file modes' : false;

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

  DesktopUpdate make({Map<String, String> env = const {}, String? browser, ProcessRunner? run}) =>
      DesktopUpdate(
        start: (exe, args) async => started.add([exe, ...args]),
        run: run ?? (exe, args) => Process.run(exe, args),
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
    skip: _posixOnly,
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
  }, skip: _posixOnly);
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

  test('chmod fails: old AppImage untouched, no .new left, browser opens', () async {
    final old = File('${dir.path}/App.AppImage')..writeAsStringSync('old');
    final fresh = File('${dir.path}/new')..writeAsStringSync('new');
    final ok = await make(env: {'APPIMAGE': old.path}, run: (e, a) async => ProcessResult(0, 1, '', 'no'))
        .install(fresh, target(UpdateKind.appImage), fallback: url);
    expect(ok, isFalse);
    expect(old.readAsStringSync(), 'old');
    expect(File('${old.path}.new').existsSync(), isFalse);
    expect(started.single, ['xdg-open', url.toString()]);
    expect(exits, isEmpty);
  });

  test('APPIMAGE missing or empty: browser, nothing written next to the cwd', () async {
    final fresh = File('${dir.path}/new')..writeAsStringSync('new');
    for (final env in [<String, String>{}, {'APPIMAGE': ''}]) {
      expect(await make(env: env).install(fresh, target(UpdateKind.appImage), fallback: url), isFalse);
    }
    expect(started, everyElement(['xdg-open', url.toString()]));
    expect(started, hasLength(2));
    expect(File('.new').existsSync(), isFalse);
  });

  test('Windows browser is rundll32 with the file protocol handler', () async {
    await make(browser: 'rundll32').openBrowser(url);
    expect(started.single, ['rundll32', 'url.dll,FileProtocolHandler', url.toString()]);
  });
}

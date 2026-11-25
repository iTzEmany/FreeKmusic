import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/platform/open_files.dart';
import 'package:path/path.dart' as p;

class _FakeTrack implements Track {
  _FakeTrack(this.path);
  @override
  final String path;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Track _t(String path) => _FakeTrack(path);

/// The path as OpenFiles normalizes it on this system (D:\\music\\a.mp3 on Windows).
String abs(String path) => p.normalize(p.absolute(path));

void main() {
  late List<List<Track>> played;
  late List<List<String>> outside, portal;
  late List<String> scanned, addedDirs;
  late Set<String> known;
  late OpenFiles open;
  late Set<String> missingOnDisk;
  late Folder folder;


  setUp(() {
    folder = Folder(id: 1, path: abs('/music'), addedAt: 0);
    played = [];
    outside = [];
    portal = [];
    scanned = [];
    addedDirs = [];
    known = {abs('/music/a.mp3')};
    missingOnDisk = {};
    open = OpenFiles(
      channel: const MethodChannel('test/open'),
      folders: () async => [folder],
      trackAt: (path) async => known.contains(path) ? _t(path) : null,
      scan: (f, path) async {
        scanned.add(path);
        known.add(path);
      },
      play: (t) async => played.add(t),
      addFolder: (d) async {
        addedDirs.add(d);
        known.add(abs('/other/x.mp3'));
      },
      onOutside: outside.add,
      onPortal: portal.add,
      exists: (path) async => !missingOnDisk.contains(path),
    );
  });

  test('several files play in the order given, scanning the new one', () async {
    await open.handle([abs('/music/b.flac'), '--flag', abs('/music/a.mp3')]);
    expect(played.single.map((t) => t.path), [abs('/music/b.flac'), abs('/music/a.mp3')]);
    expect(scanned, [abs('/music/b.flac')]);
    expect(outside, isEmpty);
  });

  test('a file outside the library folders warns instead of playing, and joins on request', () async {
    await open.handle([Uri.file(abs('/other/x.mp3')).toString()]);
    expect(played, isEmpty);
    expect(outside.single, [abs('/other/x.mp3')]);

    await open.addToLibrary(outside.single);
    expect(addedDirs, [abs('/other')]);
    expect(played.single.single.path, abs('/other/x.mp3'));
  });

  test('relative paths become absolute and missing files are dropped', () async {
    missingOnDisk = {abs('/music/gone.mp3')};
    await open.handle([abs('/music/../music/a.mp3'), abs('/music/gone.mp3'), 'rel.mp3']);
    expect(played.single.map((t) => t.path), [abs('/music/a.mp3')]);
    expect(outside.single.single, endsWith('rel.mp3'));
    expect(outside.single.single, predicate<String>(p.isAbsolute));
  });

  test('a documents-portal file is not played nor written: the user is told', () async {
    await open.handle(['/run/user/1000/doc/ab12/song.mp3']);
    expect(outside, isEmpty);
    expect(scanned, isEmpty);
    expect(played, isEmpty);
    expect(portal.single, ['/run/user/1000/doc/ab12/song.mp3']);
  }, skip: Platform.isLinux ? false : 'documents portal is Flatpak-only');

  test('the runner channel delivers files after start', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('test/open'), (call) async {
      return call.method == 'takeFiles' ? [abs('/music/a.mp3')] : null;
    });
    await open.start([]);
    expect(played.single.single.path, abs('/music/a.mp3'));
    messenger.setMockMethodCallHandler(const MethodChannel('test/open'), null);
  });
}

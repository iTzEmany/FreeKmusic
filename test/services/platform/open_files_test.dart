import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/platform/open_files.dart';

class _FakeTrack implements Track {
  _FakeTrack(this.path);
  @override
  final String path;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Track _t(String path) => _FakeTrack(path);

void main() {
  late List<List<Track>> played;
  late List<List<String>> outside, portal;
  late List<String> scanned, addedDirs;
  late Set<String> known;
  late OpenFiles open;
  late Set<String> missingOnDisk;
  const folder = Folder(id: 1, path: '/music', addedAt: 0);

  setUp(() {
    played = [];
    outside = [];
    portal = [];
    scanned = [];
    addedDirs = [];
    known = {'/music/a.mp3'};
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
        known.add('/other/x.mp3');
      },
      onOutside: outside.add,
      onPortal: portal.add,
      exists: (path) async => !missingOnDisk.contains(path),
    );
  });

  test('several files play in the order given, scanning the new one', () async {
    await open.handle(['/music/b.flac', '--flag', '/music/a.mp3']);
    expect(played.single.map((t) => t.path), ['/music/b.flac', '/music/a.mp3']);
    expect(scanned, ['/music/b.flac']);
    expect(outside, isEmpty);
  });

  test('a file outside the library folders warns instead of playing, and joins on request', () async {
    await open.handle(['file:///other/x.mp3']);
    expect(played, isEmpty);
    expect(outside.single, ['/other/x.mp3']);

    await open.addToLibrary(outside.single);
    expect(addedDirs, ['/other']);
    expect(played.single.single.path, '/other/x.mp3');
  });

  test('relative paths become absolute and missing files are dropped', () async {
    missingOnDisk = {'/music/gone.mp3'};
    await open.handle(['/music/../music/a.mp3', '/music/gone.mp3', 'rel.mp3']);
    expect(played.single.map((t) => t.path), ['/music/a.mp3']);
    expect(outside.single.single, endsWith('rel.mp3'));
    expect(outside.single.single, startsWith('/'));
  });

  test('a documents-portal file is not played nor written: the user is told', () async {
    await open.handle(['/run/user/1000/doc/ab12/song.mp3']);
    expect(outside, isEmpty);
    expect(scanned, isEmpty);
    expect(played, isEmpty);
    expect(portal.single, ['/run/user/1000/doc/ab12/song.mp3']);
  });

  test('the runner channel delivers files after start', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('test/open'), (call) async {
      return call.method == 'takeFiles' ? ['/music/a.mp3'] : null;
    });
    await open.start([]);
    expect(played.single.single.path, '/music/a.mp3');
    messenger.setMockMethodCallHandler(const MethodChannel('test/open'), null);
  });
}

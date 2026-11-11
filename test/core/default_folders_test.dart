import 'dart:io';

import 'package:codecore/core/platform.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory home;
  setUp(() async {
    home = await Directory.systemTemp.createTemp('folders');
    addTearDown(() => home.delete(recursive: true));
  });

  Future<DefaultFolders> resolve(String os, [Map<String, String> env = const {}]) =>
      resolveDefaultFolders(platform: os, env: {'HOME': home.path, ...env}, create: false);

  test('Android: library Music, downloads Music/FreeKmusic', () async {
    final f = await resolve('android');
    expect(f.library, '/storage/emulated/0/Music');
    expect(f.downloads, '/storage/emulated/0/Music/FreeKmusic');
  });

  test('Windows: %USERPROFILE%\\Music', () async {
    final f = await resolve('windows', {r'USERPROFILE': r'C:\Users\me'});
    expect(f.library, r'C:\Users\me\Music');
    expect(f.downloads, r'C:\Users\me\Music\FreeKmusic');
  });

  test('macOS: ~/Music', () async {
    final f = await resolve('macos');
    expect(f.library, p.join(home.path, 'Music'));
    expect(f.downloads, p.join(home.path, 'Music', 'FreeKmusic'));
  });

  test('iOS: the app documents folder for both', () async {
    final f = await resolveDefaultFolders(platform: 'ios', documentsDir: () async => '/docs');
    expect((f.library, f.downloads), ('/docs', '/docs'));
  });

  test('Linux: XDG_MUSIC_DIR from the environment', () async {
    final f = await resolve('linux', {'XDG_MUSIC_DIR': r'$HOME/Musica'});
    expect(f.library, '${home.path}/Musica');
  });

  test('Linux: XDG_MUSIC_DIR from user-dirs.dirs', () async {
    final conf = Directory(p.join(home.path, '.config'))..createSync();
    File(p.join(conf.path, 'user-dirs.dirs'))
        .writeAsStringSync('XDG_DOCUMENTS_DIR="\$HOME/Doc"\nXDG_MUSIC_DIR="\$HOME/Musica"\n');
    final f = await resolve('linux');
    expect(f.library, '${home.path}/Musica');
    expect(f.downloads, '${home.path}/Musica/FreeKmusic');
  });

  test('Linux: XDG_MUSIC_DIR = \$HOME (disabled) is ignored, in the environment and in user-dirs.dirs', () async {
    expect((await resolve('linux', {'XDG_MUSIC_DIR': home.path})).library, '${home.path}/Music');
    final conf = Directory(p.join(home.path, '.config'))..createSync();
    File(p.join(conf.path, 'user-dirs.dirs')).writeAsStringSync('XDG_MUSIC_DIR="\$HOME/"\n');
    expect((await resolve('linux')).library, '${home.path}/Music');
  });

  test('Linux: no configuration falls back to ~/Music', () async {
    final f = await resolve('linux');
    expect(f.library, '${home.path}/Music');
  });

  test('the folders are created when missing', () async {
    final f = await resolveDefaultFolders(platform: 'macos', env: {'HOME': home.path});
    expect(Directory(f.library).existsSync(), isTrue);
    expect(Directory(f.downloads).existsSync(), isTrue);
  });
}

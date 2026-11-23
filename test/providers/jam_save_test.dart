import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/jam_providers.dart';
import 'package:codecore/providers/jam_save.dart';
import 'package:codecore/providers/library_providers.dart';
import 'package:codecore/providers/library_add_providers.dart' show savedStreamKeysProvider;
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/youtube_providers.dart' show downloadIndexProvider;
import 'package:codecore/services/jam/jam_cache.dart';
import 'package:codecore/services/jam/jam_models.dart';
import 'package:codecore/services/online/download_index.dart';
import 'package:codecore/services/tags/tag_reader.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _Tags implements TagReader {
  @override
  Future<TagInfo> read(String path, {bool withCover = true}) async => TagInfo(title: p.basenameWithoutExtension(path));
}

class _Jam extends JamController {
  _Jam(this._cache);
  final JamCache? _cache;
  @override
  JamCache? get cache => _cache;
  @override
  JamUiState build() => const JamUiState(jam: JamState(hostDeviceId: 'host', outputDeviceId: 'host'));
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  setUp(() => tmp = Directory.systemTemp.createTempSync('jamsave'));
  tearDown(() async {
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<ProviderContainer> make(JamCache? cache) async {
    SharedPreferences.setMockInitialValues({'downloadLocation': p.join(tmp.path, 'dl')});
    db = AppDatabase(NativeDatabase.memory());
    final c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      settingsStoreProvider.overrideWithValue(await SettingsStore.open()),
      tagReaderProvider.overrideWithValue(_Tags()),
      coversDirProvider.overrideWithValue(Directory(p.join(tmp.path, 'covers'))),
      downloadIndexProvider.overrideWith((ref) async => DownloadIndex(File(p.join(tmp.path, 'idx.json')))),
      jamProvider.overrideWith(() => _Jam(cache)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  const online = JamItem(
      id: 1, ownerDeviceId: 'host', title: 'On', ext: 'm4a', ref: 'yt:youtube:abcdefghijk', videoId: 'abcdefghijk');
  const local = JamItem(id: 2, ownerDeviceId: 'host', title: 'Loc', ext: 'mp3');

  test('an online item is saved as a stream row', () async {
    final c = await make(null);
    final s = c.read(jamSaverProvider);
    expect(s.canSave(online, 'me'), isTrue);
    expect(await s.save(online), isTrue);
    expect((await db.select(db.tracks).get()).single.path, 'stream:youtube:abcdefghijk');
  });

  test('a local item in the cache is copied to the downloads folder and scanned', () async {
    final cache = JamCache(Directory(p.join(tmp.path, 'cache')))..dir.createSync(recursive: true);
    File(p.join(cache.dir.path, '2.mp3')).writeAsBytesSync([1, 2, 3]);
    final c = await make(cache);
    final s = c.read(jamSaverProvider);
    expect(s.canSave(local, 'me'), isTrue);
    expect(await s.save(local), isTrue);
    expect(File(p.join(tmp.path, 'dl', 'Loc.mp3')).readAsBytesSync(), [1, 2, 3]);
    expect((await db.select(db.tracks).get()).single.path, p.join(tmp.path, 'dl', 'Loc.mp3'));
  });

  test('without the cache a local item has no action; our own items neither', () async {
    final c = await make(JamCache(Directory(p.join(tmp.path, 'cache'))));
    final s = c.read(jamSaverProvider);
    expect(s.canSave(local, 'me'), isFalse);
    expect(s.canSave(online, 'host'), isFalse);
  });

  JamItem loc(String title, {int id = 2, String owner = 'host'}) =>
      JamItem(id: id, ownerDeviceId: owner, title: title, ext: 'mp3');
  Future<ProviderContainer> withFile(int id) async {
    final cache = JamCache(Directory(p.join(tmp.path, 'cache')))..dir.createSync(recursive: true);
    File(p.join(cache.dir.path, '$id.mp3')).writeAsBytesSync([1, 2, 3]);
    return make(cache);
  }

  test('long CJK and emoji titles stay under 200 bytes and are saved', () async {
    for (final t in ['漢' * 100, '😀' * 70]) {
      final name = jamFileName(t, 'mp3');
      expect(utf8.encode(name).length, lessThanOrEqualTo(200));
      expect(name.endsWith('.mp3'), isTrue);
      expect(name.runes.every((r) => r == 0x6F22 || r == 0x1F600 || '.mp3'.runes.contains(r)), isTrue);
    }
    final c = await withFile(2);
    expect(await c.read(jamSaverProvider).save(loc('漢' * 100)), isTrue);
    File(p.join(tmp.path, 'cache', '3.mp3')).writeAsBytesSync([4]);
    expect(await c.read(jamSaverProvider).save(loc('😀' * 70, id: 3)), isTrue);
  });

  test('the file name: suffix, sanitizing and the extension', () {
    expect(jamFileName('A/B:C', 'mp3'), 'ABC.mp3');
    expect(jamFileName('Song', 'mp3', 2), 'Song (2).mp3');
    expect(jamFileName('Song', 'm/p3'), 'Song.mp3');
    expect(utf8.encode(jamFileName('漢' * 100, 'mp3', 12)).length, lessThanOrEqualTo(200));
  });

  test('saving twice makes one row and the action goes away', () async {
    final c = await withFile(2);
    final s = c.read(jamSaverProvider);
    expect(await s.save(local), isTrue);
    expect(s.canSave(local, 'me'), isFalse);
    expect(await s.save(local), isFalse);
    expect((await db.select(db.tracks).get()).length, 1);
    expect(Directory(p.join(tmp.path, 'dl')).listSync().whereType<File>().any((f) => f.path.endsWith('.part')), isFalse);
  });

  test('a song of another guest has no action', () async {
    final c = await withFile(2);
    expect(c.read(jamSaverProvider).canSave(loc('X', owner: 'guest2'), 'me'), isFalse);
  });

  test('a name already taken gets (2)', () async {
    final c = await withFile(2);
    File(p.join(tmp.path, 'cache', '5.mp3')).writeAsBytesSync([9]);
    final s = c.read(jamSaverProvider);
    expect(await s.save(local), isTrue);
    expect(await s.save(loc('Loc', id: 5)), isTrue);
    expect(File(p.join(tmp.path, 'dl', 'Loc (2).mp3')).readAsBytesSync(), [9]);
  });

  test('an online song already in the library has no action', () async {
    final c = await make(null);
    c.listen(savedStreamKeysProvider, (_, _) {});
    c.listen(downloadIndexProvider, (_, _) {});
    final s = c.read(jamSaverProvider);
    expect(await s.save(online), isTrue);
    await c.read(downloadIndexProvider.future);
    await pumpEventQueue();
    expect(c.read(savedStreamKeysProvider).value, contains('youtube:abcdefghijk'));
    expect(s.canSave(online.copyWith(id: 9), 'me'), isFalse);
  });
}

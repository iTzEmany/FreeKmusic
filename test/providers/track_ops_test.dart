import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/settings/settings_store.dart';
import 'package:codecore/providers/database_providers.dart';
import 'package:codecore/providers/folder_ops.dart';
import 'package:codecore/providers/playlist_ops.dart';
import 'package:codecore/providers/radio_providers.dart';
import 'package:codecore/providers/radio_ops.dart';
import 'package:codecore/providers/settings_providers.dart';
import 'package:codecore/providers/tag_ops.dart';
import 'package:codecore/providers/track_ops.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer c;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    for (var i = 0; i < 3; i++) {
      await db.into(db.tracks).insert(TracksCompanion.insert(
          path: '/m/t$i.mp3', title: 'T$i', albumKey: 'a', format: 'mp3', sizeBytes: 1, mtimeMs: 1, addedAt: 1));
    }
    SharedPreferences.setMockInitialValues({});
    c = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      settingsStoreProvider.overrideWithValue(await SettingsStore.open()),
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<List<Track>> rows() => (db.select(db.tracks)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  TrackOps ops() => c.read(trackOpsProvider);

  group('TrackOps', () {
    test('toggleFavorites on a mixed pick favourites only the ones that were not; undo reverts those', () async {
      await db.update(db.tracks).replace(
          (await rows()).first.copyWith(isFavorite: true));
      final r = await ops().toggleFavorites(await rows());
      expect((r.count, r.added), (2, true));
      expect([for (final t in await rows()) t.isFavorite], [true, true, true]);
      await r.undo();
      expect([for (final t in await rows()) t.isFavorite], [true, false, false]);
    });

    test('toggleFavorites on all-favourites removes them', () async {
      await ops().addFavorites([for (final t in await rows()) t.id]);
      final r = await ops().toggleFavorites(await rows());
      expect((r.count, r.added), (3, false));
      expect([for (final t in await rows()) t.isFavorite], [false, false, false]);
    });

    test('addFavorites counts only the changed rows', () async {
      final ids = [for (final t in await rows()) t.id];
      expect(await ops().addFavorites(ids.take(1).toList()), 1);
      expect(await ops().addFavorites(ids), 2);
    });

    test('toggleFavorite flips from the stored state, undoes it, and gives null for a gone row', () async {
      final id = (await rows()).first.id;
      final r = (await ops().toggleFavorite(id))!;
      expect(r.added, isTrue);
      await r.undo();
      expect((await rows()).first.isFavorite, isFalse);
      expect(await ops().toggleFavorite(9999), isNull);
    });

    test('setLyrics with plain only writes null into synced', () async {
      final id = (await rows()).first.id;
      await ops().setLyrics(id, plain: 'p', synced: '[00:01.00]p');
      await ops().setLyrics(id, plain: 'only');
      final t = (await rows()).first;
      expect((t.lyricsPlain, t.lyricsSynced), ('only', null));
    });

    test('the hand-written mark: set by the editor, cleared by a search or a delete, put back by the undo', () async {
      final id = (await rows()).first.id;
      bool marked() => c.read(handWrittenLyricsProvider).contains(id);
      await ops().saveLyricsText(id, 'my own words');
      expect(marked(), isTrue);
      expect((await SettingsStore.open()).readHandWrittenLyrics(), {id});
      await ops().setLyrics(id, plain: 'from a search', byUser: true);
      expect(marked(), isFalse);
      await ops().saveLyricsText(id, 'again');
      final undo = await ops().deleteLyrics(id);
      expect(marked(), isFalse);
      await undo();
      expect(marked(), isTrue);
      expect((await rows()).first.lyricsPlain, 'again');
    });

    test('undoing a delete of a text not typed by hand does not mark it as typed', () async {
      final id = (await rows()).first.id;
      await ops().setLyrics(id, plain: 'from a search', byUser: true);
      final undo = await ops().deleteLyrics(id);
      await undo();
      expect(c.read(handWrittenLyricsProvider).contains(id), isFalse);
      expect((await rows()).first.lyricsPlain, 'from a search');
    });

    test('a typed transliteration goes with the old text: new text or delete drops it, the undo brings it back', () async {
      final id = (await rows()).first.id;
      final rom = c.read(manualRomanizationProvider.notifier);
      Map<int, String> typed() => c.read(manualRomanizationProvider);
      await ops().saveLyricsText(id, 'old');
      await rom.setText(id, 'old rom');
      await ops().saveLyricsText(id, 'new');
      expect(typed(), isEmpty);

      await rom.setText(id, 'rom 2');
      await ops().setLyrics(id, plain: 'from a search');
      expect(typed(), isEmpty);

      await rom.setText(id, 'rom 3');
      final undo = await ops().deleteLyrics(id);
      expect(typed(), isEmpty);
      await undo();
      expect(typed(), {id: 'rom 3'});
    });

    test('FolderOps.paths maps folder id to its root path', () async {
      final a = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/m', addedAt: 1));
      final b = await db.into(db.folders).insert(FoldersCompanion.insert(path: '/n', addedAt: 1));
      expect(await c.read(folderOpsProvider).paths(), {a: '/m', b: '/n'});
    });
  });

  group('PlaylistOps', () {
    test('createWith makes a playlist holding the tracks', () async {
      final ids = [for (final t in await rows()) t.id];
      final id = await c.read(playlistOpsProvider).createWith('Mix', ids);
      expect([for (final t in await c.read(playlistOpsProvider).tracksOf(id)) t.id], ids);
    });

    test('removeTracks undo restores the original order', () async {
      final ids = [for (final t in await rows()) t.id];
      final o = c.read(playlistOpsProvider);
      final id = await o.createWith('Mix', ids);
      final undo = await o.removeTracks(id, [ids[0]]);
      expect([for (final t in await o.tracksOf(id)) t.id], [ids[1], ids[2]]);
      await undo();
      expect([for (final t in await o.tracksOf(id)) t.id], ids);
    });
  });

  group('TagOps', () {
    test('create with assignTo gives the new tag to the tracks and returns it', () async {
      final ids = [for (final t in await rows()) t.id];
      final tag = await c.read(tagOpsProvider).create('rock', assignTo: ids);
      expect(tag?.name, 'rock');
      expect(await c.read(tagOpsProvider).countsAmong(ids), {tag!.id: 3});
    });
  });

  group('RadioOps', () {
    test('toggleSaved saves, then removes, and undo reverts', () async {
      final sub = c.listen(savedRadiosProvider, (_, _) {});
      addTearDown(sub.close);
      const s = RadioStation(id: 'r1', name: 'One', streamUrl: 'http://x/1');
      final o = c.read(radioOpsProvider);
      Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));
      final undo = await o.toggleSaved(s);
      await settle();
      expect(c.read(savedRadioIdsProvider), {'r1'});
      await undo();
      await settle();
      expect(c.read(savedRadioIdsProvider), isEmpty);
    });
  });
}

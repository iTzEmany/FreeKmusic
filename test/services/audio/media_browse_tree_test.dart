import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:codecore/data/repositories/radio_repository.dart';
import 'package:codecore/services/radio/radio_station.dart';
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/services/audio/media_browse_tree.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MediaBrowseTree tree;
  late PlaylistRepository playlists;
  late TrackRepository tracks;
  late RadioRepository radios;

  Future<void> seed(int n, {String album = 'k1', String prefix = 'T', bool fav = false}) =>
      tracks.upsertBatch([
        for (var i = 0; i < n; i++)
          TracksCompanion.insert(
            path: '/m/$prefix$i.mp3', title: '$prefix$i', albumKey: album, format: 'mp3',
            sizeBytes: 1, mtimeMs: 1, addedAt: 1000 + i,
            artist: const Value('Art'), album: Value('Album $album'),
            durationMs: const Value(60000), trackNumber: Value(i + 1),
            isFavorite: Value(fav),
          ),
      ]);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tracks = TrackRepository(db);
    playlists = PlaylistRepository(db);
    radios = RadioRepository(db);
    tree = MediaBrowseTree(
      DbBrowseSource(tracks, LibraryQueries(db), playlists, radios),
      coverUri: (k) => Uri.file('/covers/$k'),
    );
  });
  tearDown(() => db.close());

  test('the root has five folders, none playable', () async {
    final root = await tree.children('root');
    expect(root.map((i) => i.id), ['fav', 'playlists', 'albums', 'top', 'recent']);
    expect(root.every((i) => i.playable == false), isTrue);
  });

  test('a playlist lists its tracks in playlist order, as playable items of that folder', () async {
    await seed(3);
    final ids = [for (final p in ['T2', 'T0', 'T1']) (await tracks.idForPath('/m/$p.mp3'))!];
    final list = await playlists.create('Road');
    await playlists.addTracks(list, ids);

    final folders = await tree.children('playlists');
    expect(folders.single.id, 'playlist:$list');
    expect(folders.single.title, 'Road');
    final items = await tree.children('playlist:$list');
    expect(items.map((i) => i.title), ['T2', 'T0', 'T1']);
    expect(items.every((i) => i.playable == true), isTrue);
    expect(items.first.id, 'track:${ids.first}@playlist:$list');
  });

  test('a playlist with a streamed row counts and lists only the library tracks', () async {
    await seed(2);
    final ids = [for (final p in ['T0', 'T1']) (await tracks.idForPath('/m/$p.mp3'))!];
    final shadow = await tracks.ensureStreamRow(YtResult(id: 'v1', title: 'S', channel: 'Ch', duration: Duration.zero));
    final list = await playlists.create('Road');
    await playlists.addStreamTracks(list, [ids[0], shadow, ids[1]]);

    expect((await tree.children('playlists')).single.artist, '2');
    expect((await tree.children('playlist:$list')).map((i) => i.title), ['T0', 'T1']);
  });

  test('choosing a track of an album queues the album from that track', () async {
    await seed(4, album: 'alb');
    final albums = await tree.children('albums');
    expect(albums.single.id, 'album:alb');
    final items = await tree.children('album:alb');
    expect(items.map((i) => i.title), ['T0', 'T1', 'T2', 'T3']);

    final r = (await tree.resolve(items[2].id))!;
    expect(r.ids, [for (final i in items) MediaBrowseTree.parseTrackId(i.id)!.id]);
    expect(r.index, 2);
  });

  test('favourites, recent and most played are folders of tracks', () async {
    await seed(2, prefix: 'F', fav: true);
    await seed(2, prefix: 'N', album: 'k2');
    expect((await tree.children('fav')).map((i) => i.title), ['F0', 'F1']);
    expect((await tree.children('recent')).first.title, anyOf('N1', 'F1'), reason: 'newest first');
    expect(await tree.children('top'), isEmpty, reason: 'nothing played yet');
  });

  test('lists stop at 200 entries and the queue is the same 200', () async {
    await seed(230);
    final items = await tree.children('recent');
    expect(items, hasLength(kBrowseLimit));
    final r = (await tree.resolve(items.last.id))!;
    expect(r.ids, hasLength(kBrowseLimit));
    expect(r.index, kBrowseLimit - 1);
  });

  test('unknown ids give nothing; a track gone from its folder plays alone', () async {
    await seed(2);
    expect(await tree.children('nope'), isEmpty);
    expect(await tree.children('playlist:abc'), isEmpty);
    expect(await tree.resolve('root'), isNull);
    expect(await tree.resolve('track:x@fav'), isNull);
    final id = (await tracks.idForPath('/m/T0.mp3'))!;
    final r = (await tree.resolve('track:$id@fav'))!; // T0 is not a favourite
    expect(r.ids, [id]);
    expect(r.index, 0);
  });

  test('item() finds folders and tracks; search is capped and needs text', () async {
    await seed(3);
    expect((await tree.item('fav'))!.title, 'Preferiti');
    expect(await tree.item('wat'), isNull);
    final id = (await tracks.idForPath('/m/T1.mp3'))!;
    final it = (await tree.item('track:$id@recent'))!;
    expect(it.title, 'T1');
    expect(it.duration, const Duration(minutes: 1));

    expect(await tree.search('  '), isEmpty);
    final found = await tree.search('T1');
    expect(found.map((i) => i.title), ['T1']);
    final r = (await tree.resolve(found.single.id))!;
    expect(r.ids, [id]);
  });

  test('labels follow the language', () {
    expect(BrowseLabels.forLanguage('en').favorites, 'Favourites');
    expect(BrowseLabels.forLanguage('xx').favorites, 'Preferiti');
  });

  RadioStation station(String id) =>
      RadioStation(id: id, name: 'Radio $id', streamUrl: 'http://s/$id', tags: const ['pop']);

  test('the Radio folder shows only with saved stations, which list in the saved order', () async {
    expect((await tree.children('root')).map((i) => i.id), isNot(contains('radio')));
    for (final id in ['a', 'b', 'c']) {
      await radios.save(station(id));
    }
    await radios.reorder(['c', 'a', 'b']);
    final root = await tree.children('root');
    expect(root.last.id, 'radio');
    expect(root.last.playable, isFalse);
    final items = await tree.children('radio');
    expect(items.map((i) => i.id), ['radio:c', 'radio:a', 'radio:b']);
    expect(items.every((i) => i.playable == true), isTrue);
    expect((await tree.item('radio:a'))!.title, 'Radio a');
    expect(await tree.item('radio:zzz'), isNull);
  });

  test('choosing a station resolves to the saved list from it; track ids are not radios', () async {
    await radios.save(station('a'));
    await radios.save(station('manual:m'));
    await radios.save(station('c'));
    final r = (await tree.resolveRadio('radio:manual:m'))!;
    expect(r.stations.map((s) => s.id), ['a', 'manual:m', 'c']);
    expect(r.index, 1);
    expect(await tree.resolveRadio('radio:gone'), isNull);
    expect(await tree.resolveRadio('track:1@fav'), isNull);
    expect(await tree.resolve('radio:a'), isNull);
  });

  test('the Radio label is localized', () {
    expect(BrowseLabels.forLanguage('pt').radio, 'Rádio');
    expect(BrowseLabels.forLanguage('it').radio, 'Radio');
  });
}

import 'package:dio/dio.dart' show CancelToken;
import 'package:codecore/data/repositories/track_repository.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/ytm_catalog.dart' show CatalogResult;
import 'package:codecore/services/online/youtube_service.dart' show YtResult;
import 'package:codecore/services/online/ytm_album_search.dart' show YtmAlbumHit;
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_ytm.dart';

YtResult _song(String id, String title) => YtResult(
      id: id,
      title: title,
      channel: 'Artist',
      duration: const Duration(minutes: 3),
      artists: const ['Artist'],
      album: 'Album 0',
      albumId: 'MPREb_x',
    );

class _AlbumCatalog extends FakeCatalog {
  _AlbumCatalog(this.titles, {this.hit = true}) : super((_) async => null);

  final List<String> titles;
  final bool hit;
  final asked = <String>[];

  @override
  Future<List<YtmAlbumHit>> searchAlbums(String query, String hl, {CancelToken? cancel}) async => hit
      ? [
          (
            release: const YtmRelease(browseId: 'MPREb_x', title: 'Album 0', subtitle: 'Album'),
            artist: const YtmArtistRef(id: 'UC1', name: 'Artist'),
          ),
        ]
      : const [];

  @override
  Future<CatalogResult<YtmAlbum>> album(String browseId, String hl, {bool refresh = false}) async {
    asked.add(browseId);
    return CatalogResult(
      YtmAlbum(
        browseId: browseId,
        title: 'Album 0',
        tracks: [for (var i = 0; i < titles.length; i++) YtmAlbumTrack(i + 1, _song('v$i', titles[i]))],
      ),
      DateTime(2026),
    );
  }
}

void main() {
  // The harness album 'artist|album 0' holds Song 0, Song 2 and Song 4.
  final ten = ['Song 0', 'Song 2', 'Song 4', for (var i = 3; i < 10; i++) 'Other $i'];

  testWidgets('an album with 3 songs of 10 in the library lists the 7 missing (found by search)', (tester) async {
    final h = await Harness.create(tester, tracks: 6);
    final catalog = _AlbumCatalog(ten);
    final c = ProviderContainer(overrides: h.overridesWith([ytmCatalogProvider.overrideWithValue(catalog)]));
    addTearDown(c.dispose);
    c.listen(albumMissingTracksProvider('artist|album 0'), (_, _) {});
    await tester.runAsync(() async {
      final missing = await c.read(albumMissingTracksProvider('artist|album 0').future);
      expect(missing.map((r) => r.title), [for (var i = 3; i < 10; i++) 'Other $i']);
    });
    await h.dispose(tester);
  });

  testWidgets('a hit with another title is not taken: no missing songs', (tester) async {
    final h = await Harness.create(tester, tracks: 6);
    final catalog = _AlbumCatalog(ten, hit: false);
    final c = ProviderContainer(overrides: h.overridesWith([ytmCatalogProvider.overrideWithValue(catalog)]));
    addTearDown(c.dispose);
    c.listen(albumMissingTracksProvider('artist|album 0'), (_, _) {});
    await tester.runAsync(() async {
      expect(await c.read(albumMissingTracksProvider('artist|album 0').future), isEmpty);
    });
    expect(catalog.asked, isEmpty);
    await h.dispose(tester);
  });

  testWidgets('saveStream keeps the album browseId and never overwrites a known one', (tester) async {
    final h = await Harness.create(tester);
    final repo = TrackRepository(h.db);
    await tester.runAsync(() async {
      final id = (await repo.saveStream(_song('v1', 'A')))!;
      expect((await repo.getById(id))!.albumBrowseId, 'MPREb_x');
      final other = YtResult(
          id: 'v1', title: 'A', channel: 'c', duration: null, albumId: 'MPREb_other');
      await repo.saveStream(other);
      expect((await repo.getById(id))!.albumBrowseId, 'MPREb_x');
      final none = (await repo.saveStream(
          const YtResult(id: 'v2', title: 'B', channel: 'c', duration: null)))!;
      expect((await repo.getById(none))!.albumBrowseId, isNull);
    });
    await h.dispose(tester);
  });
}

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

YtResult _song(String id, String title, {Duration duration = const Duration(minutes: 3)}) => YtResult(
      id: id,
      title: title,
      channel: 'Artist',
      duration: duration,
      artists: const ['Artist'],
      album: 'Album 0',
      albumId: 'MPREb_x',
    );

class _AlbumCatalog extends FakeCatalog {
  _AlbumCatalog(this.titles, {this.hitTitle = 'Album 0', this.hitArtist = 'Artist', this.durations = const {}}) : super((_) async => null);

  final List<String> titles;
  final String hitTitle;
  final String hitArtist;
  final Map<int, Duration> durations;
  final asked = <String>[];
  var searches = 0;

  @override
  Future<List<YtmAlbumHit>> searchAlbums(String query, String hl, {CancelToken? cancel}) async {
    searches++;
    return [
      (
        release: YtmRelease(browseId: 'MPREb_x', title: hitTitle, subtitle: 'Album'),
        artist: YtmArtistRef(id: 'UC1', name: hitArtist),
      ),
    ];
  }

  @override
  Future<CatalogResult<YtmAlbum>> album(String browseId, String hl, {bool refresh = false}) async {
    asked.add(browseId);
    return CatalogResult(
      YtmAlbum(
        browseId: browseId,
        title: 'Album 0',
        tracks: [for (var i = 0; i < titles.length; i++) YtmAlbumTrack(i + 1, _song('v$i', titles[i], duration: durations[i] ?? const Duration(minutes: 3)))],
      ),
      DateTime(2026),
    );
  }
}

void main() {
  // The harness album 'artist|album 0' holds Song 0, Song 2 and Song 4.
  final ten = ['Song 0', 'Song 2', 'Song 4', for (var i = 3; i < 10; i++) 'Other $i'];

  testWidgets('an album with 3 songs of 10 in the library lists the 7 missing (found by search)', (tester) async {
    final h = await Harness.create(tester, tracks: 6)..realAlbumMissing = true;
    final catalog = _AlbumCatalog(ten);
    final c = ProviderContainer(overrides: h.overridesWith([ytmCatalogProvider.overrideWithValue(catalog)]));
    addTearDown(c.dispose);
    c.listen(albumMissingTracksProvider('artist|album 0'), (_, _) {});
    await tester.runAsync(() async {
      final missing = await c.read(albumMissingTracksProvider('artist|album 0').future);
      expect(missing.map((r) => r.result.title), [for (var i = 3; i < 10; i++) 'Other $i']);
    });
    await h.dispose(tester);
  });

  for (final (why, title, artist) in [('title', 'Another Album', 'Artist'), ('artist', 'Album 0', 'Someone Else')]) {
  testWidgets('a search hit with another $why is not taken: no missing songs', (tester) async {
    final h = await Harness.create(tester, tracks: 6)..realAlbumMissing = true;
    final catalog = _AlbumCatalog(ten, hitTitle: title, hitArtist: artist);
    final c = ProviderContainer(overrides: h.overridesWith([ytmCatalogProvider.overrideWithValue(catalog)]));
    addTearDown(c.dispose);
    c.listen(albumMissingTracksProvider('artist|album 0'), (_, _) {});
    await tester.runAsync(() async {
      expect(await c.read(albumMissingTracksProvider('artist|album 0').future), isEmpty);
    });
    expect(catalog.asked, isEmpty);
    await h.dispose(tester);
  });
  }

  testWidgets('a saved browseId is used without any search', (tester) async {
    final h = await Harness.create(tester, tracks: 6)..realAlbumMissing = true;
    await tester.runAsync(() => h.db.customStatement("UPDATE tracks SET album_browse_id = 'MPREb_saved' WHERE title = 'Song 0'"));
    final catalog = _AlbumCatalog(ten);
    final c = ProviderContainer(overrides: h.overridesWith([ytmCatalogProvider.overrideWithValue(catalog)]));
    addTearDown(c.dispose);
    c.listen(albumMissingTracksProvider('artist|album 0'), (_, _) {});
    await tester.runAsync(() async {
      expect(await c.read(albumMissingTracksProvider('artist|album 0').future), hasLength(7));
    });
    expect(catalog.searches, 0);
    expect(catalog.asked, ['MPREb_saved']);
    await h.dispose(tester);
  });

  testWidgets('the same place on the record with about the same length is owned, whatever the title', (tester) async {
    final h = await Harness.create(tester, tracks: 6)..realAlbumMissing = true;
    await tester.runAsync(() => h.db.customStatement("UPDATE tracks SET track_number = 1 WHERE title = 'Song 0'"));
    // Own length 185 s: 2 s off is the same song, a whole minute off is not.
    final catalog = _AlbumCatalog(['Song Zero', 'Song Two'], durations: {0: const Duration(seconds: 187), 1: const Duration(seconds: 245)});
    final c = ProviderContainer(overrides: h.overridesWith([ytmCatalogProvider.overrideWithValue(catalog)]));
    addTearDown(c.dispose);
    c.listen(albumMissingTracksProvider('artist|album 0'), (_, _) {});
    await tester.runAsync(() async {
      final missing = await c.read(albumMissingTracksProvider('artist|album 0').future);
      expect(missing.map((r) => r.result.title), ['Song Two']);
    });
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
      // A row edited by hand (album renamed) keeps no page of the old album.
      final edited = (await repo.saveStream(const YtResult(id: 'v3', title: 'C', channel: 'c', duration: null)))!;
      await h.db.customStatement('UPDATE tracks SET user_edited = 1 WHERE id = $edited');
      await repo.saveStream(const YtResult(id: 'v3', title: 'C', channel: 'c', duration: null, albumId: 'MPREb_old'));
      expect((await repo.getById(edited))!.albumBrowseId, isNull);
    });
    await h.dispose(tester);
  });
}

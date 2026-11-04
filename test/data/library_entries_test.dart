import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_entries.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

AlbumSummary album(String t, {int? played, int added = 0}) => AlbumSummary(
      albumKey: t,
      title: t,
      artist: 'X',
      variousArtists: false,
      trackCount: 3,
      durationMs: 1,
      year: null,
      coverKey: null,
      lastPlayedAt: played,
      addedAt: added,
    );

PlaylistSummary list(int id, String name, {int? played, int added = 0}) =>
    PlaylistSummary(Playlist(id: id, name: name, createdAt: 0, updatedAt: 0), 2, null,
        played, added);

ArtistSummary artist(String n, {int? played, int added = 0}) => ArtistSummary(
    key: n.toLowerCase(),
    name: n,
    trackCount: 4,
    albumCount: 1,
    lastPlayedAt: played,
    addedAt: added);

void main() {
  final playlists = [list(1, 'Notte', played: 50), list(2, 'In macchina')];
  final albums = [album('Zeta', played: 90, added: 5), album('Alfa', added: 30)];
  final artists = [artist('Mina', played: 70, added: 1)];

  List<String?> titles(List<LibraryEntry> e) => [for (final x in e) x.title];

  test('alphabetical mixes every kind', () {
    final e = buildLibraryEntries(
        playlists: playlists,
        albums: albums,
        artists: artists,
        sort: LibrarySort.alpha);
    expect(titles(e), ['Alfa', 'In macchina', 'Mina', 'Notte', 'Zeta']);
  });

  test('alphabetical: digits and symbols first, accents fold', () {
    final e = buildLibraryEntries(
        playlists: [list(1, 'Zeta'), list(2, '#1'), list(3, '😀'), list(4, 'Àlfa')],
        albums: [],
        artists: [],
        sort: LibrarySort.alpha);
    expect(titles(e), ['#1', '😀', 'Àlfa', 'Zeta']);
  });

  test('recent: played first by latest play, then the rest alphabetically',
      () {
    final e = buildLibraryEntries(
        playlists: playlists, albums: albums, artists: artists);
    expect(titles(e), ['Zeta', 'Mina', 'Notte', 'Alfa', 'In macchina']);
  });

  test('added: latest added first', () {
    final e = buildLibraryEntries(
        playlists: playlists,
        albums: albums,
        artists: artists,
        sort: LibrarySort.added);
    expect(e.first.title, 'Alfa');
    expect(titles(e).sublist(1, 3), ['Zeta', 'Mina']);
  });

  test('a kind filter keeps only that kind', () {
    final e = buildLibraryEntries(
        playlists: playlists,
        albums: albums,
        artists: artists,
        kind: LibraryKind.artist);
    expect(titles(e), ['Mina']);
    expect(e.single.kind, LibraryKind.artist);
  });
}

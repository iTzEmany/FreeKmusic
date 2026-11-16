import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/library_queries.dart';
import 'package:codecore/data/repositories/library_search.dart';
import 'package:codecore/data/repositories/playlist_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Track track(int id, String title) => Track(saved: false, 
  coverSource: 0,
  id: id,
  path: '/$id',
  title: title,
  albumKey: 'k',
  format: 'mp3',
  sizeBytes: 1,
  mtimeMs: 1,
  addedAt: 1,
  durationMs: 1000,
  playCount: 0,
  isFavorite: false,
  missing: false,
  ignored: false,
  kind: 0,
  enrichStatus: 0,
  hasCover: false,
  userEdited: false,
);

AlbumSummary album(String t, String artist) => AlbumSummary(
  albumKey: t,
  title: t,
  artist: artist,
  variousArtists: false,
  trackCount: 1,
  durationMs: 1,
  year: null,
  coverKey: null,
);

ArtistSummary artist(String n) =>
    ArtistSummary(key: n.toLowerCase(), name: n, trackCount: 2, albumCount: 1);

void main() {
  final artists = [artist('Queen'), artist('Mina'), artist('Blue Öyster')];
  final albums = [
    album('A Night At The Opera', 'Queen'),
    album('Queenie', 'X'),
  ];
  final playlists = [
    PlaylistSummary(
      Playlist(id: 1, name: 'Queen e amici', createdAt: 0, updatedAt: 0),
      3,
    ),
  ];

  test('ranked by name, and totals count past the section limit', () {
    final r = searchLibrary(
      text: 'que',
      tracks: [track(1, 'Bohemian Rhapsody')],
      artists: [
        ...artists,
        artist('Queens'),
        artist('Queenie'),
        artist('Quebec'),
      ],
      albums: albums,
      playlists: playlists,
      sectionLimit: 2,
    );
    expect(r.artists.map((a) => a.name), ['Queen', 'Queens']);
    expect(r.artistTotal, 4);
    expect(r.albums.length, 2);
    expect(r.albumTotal, 2);
    expect(r.playlistTotal, 1);
    expect(r.playlists.single.playlist.name, 'Queen e amici');
  });

  test('diacritics and case are ignored; tracks limited to 4 with a total', () {
    final r = searchLibrary(
      text: 'OYSTER',
      tracks: [for (var i = 0; i < 6; i++) track(i, 't$i')],
      artists: artists,
      albums: albums,
      playlists: playlists,
    );
    expect(r.artists.single.name, 'Blue Öyster');
    expect(r.tracks.length, 4);
    expect(r.trackTotal, 6);
  });

  test('blank text gives nothing', () {
    final r = searchLibrary(
      text: '  ',
      tracks: [track(1, 'x')],
      artists: artists,
      albums: albums,
      playlists: playlists,
    );
    expect(r.isEmpty, isTrue);
  });

  group('with operators', () {
    test('the tracks are the rules\' matches and the other sections need plain words', () {
      final r = searchLibrary(
        text: 'artista:queen anno:1970..1979',
        tracks: [track(1, 'Bohemian Rhapsody'), track(2, 'Somebody to Love')],
        artists: artists,
        albums: albums,
        playlists: playlists,
      );
      expect(r.tracks.map((t) => t.title), [
        'Bohemian Rhapsody',
        'Somebody to Love',
      ]);
      expect(r.trackTotal, 2);
      expect(
        r.artists,
        isEmpty,
        reason: 'no plain word: the artist is not filtered on «artista:queen»',
      );
      expect(r.albums, isEmpty);
      expect(r.playlists, isEmpty);
    });

    test('plain words next to operators still filter the other sections', () {
      final r = searchLibrary(
        text: 'queen anno:1975..',
        tracks: [track(1, 'Bohemian Rhapsody')],
        artists: artists,
        albums: albums,
        playlists: playlists,
      );
      expect(r.artists.single.name, 'Queen');
      expect(r.albums.length, 2);
      expect(r.tracks, hasLength(1));
    });

    test('a negation alone is an operator with no plain word', () {
      final r = searchLibrary(
        text: '-live',
        tracks: [track(1, 'Studio')],
        artists: artists,
        albums: albums,
        playlists: playlists,
      );
      expect(r.tracks, hasLength(1));
      expect(r.artists, isEmpty);
    });

    test('an operator with nothing after it is not one yet (typing)', () {
      final r = searchLibrary(
        text: 'artista:',
        tracks: const [],
        artists: artists,
        albums: albums,
        playlists: playlists,
      );
      expect(r.isEmpty, isTrue);
    });
  });
}

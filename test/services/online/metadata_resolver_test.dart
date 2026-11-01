import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/services/online/deezer_client.dart';
import 'package:codecore/services/online/itunes_client.dart';
import 'package:codecore/services/online/metadata_resolver.dart';
import 'package:codecore/services/online/query_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

import 'online_clients_test.dart' show FakeWeb, song;

void main() {
  test('when the uploader split finds nothing, iTunes is asked again as tagged', () async {
    final web = FakeWeb((_, q) => {
          'results': [if (q['term']!.contains('Beethoven')) song('Symphony No. 5 - I. Allegro', 'Beethoven')]
        });
    final t = Track(
      coverSource: 0,
      id: 1,
      path: '/m/x.mp3',
      title: 'Symphony No. 5 - I. Allegro',
      artist: 'Beethoven',
      albumKey: 'k',
      durationMs: 0,
      format: 'mp3',
      sizeBytes: 1,
      mtimeMs: 1,
      hasCover: false,
      isFavorite: false,
      enrichStatus: 0,
      userEdited: false,
      missing: false,
      ignored: false,
      kind: 0,
      addedAt: 1,
      playCount: 0,
    );
    final c = cleanSearchQuery(t.title, t.artist!);
    expect(c.tagged, isNotNull, reason: 'the split happened');
    final r = await MetadataResolver(itunes: ItunesClient(web)).resolve(t, c, null, false);
    expect(r!.match.title, 'Symphony No. 5 - I. Allegro');
  });

  Track track(String title, String artist) => Track(
        coverSource: 0, id: 1, path: '/m/x.mp3', title: title, artist: artist,
        albumKey: 'k', durationMs: 200000, format: 'mp3', sizeBytes: 1, mtimeMs: 1,
        hasCover: false, isFavorite: false, enrichStatus: 0, userEdited: false,
        missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
      );
  Map<String, Object> dz(String title, String artist) => {
        'data': [
          {'id': 7, 'title': title, 'artist': {'name': artist}, 'duration': 200}
        ]
      };

  test('Deezer is searched and scored with the cleaned text', () async {
    final web = FakeWeb((_, q) => dz('Skyfall', 'Adele'));
    final hit = await MetadataResolver(itunes: ItunesClient(web), deezer: DeezerClient(web))
        .deezerHit(track('Adele - Skyfall (Lyrics) [sZrTJesvJeo]', '7clouds Rock'), null);
    expect(web.calls.single, contains('{q: Adele Skyfall,'));
    expect(hit!.id, 7);
  });

  test('Deezer is asked again as tagged when the split finds nothing', () async {
    final web = FakeWeb((_, q) =>
        q['q']!.contains('Beethoven') ? dz('Symphony No. 5 - I. Allegro', 'Beethoven') : {'data': []});
    final hit = await MetadataResolver(itunes: ItunesClient(web), deezer: DeezerClient(web))
        .deezerHit(track('Symphony No. 5 - I. Allegro', 'Beethoven'), null);
    expect(web.calls, hasLength(2));
    expect(hit!.id, 7);
  });
}

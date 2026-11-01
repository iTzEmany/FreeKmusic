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

  test('Deezer is searched with the cleaned query, not the raw file name', () async {
    final web = FakeWeb((_, _) => {'data': []});
    final t = Track(
      coverSource: 0, id: 1, path: '/m/x.mp3', title: 'Adele - Skyfall (Lyrics) [sZrTJesvJeo]',
      artist: '7clouds Rock', albumKey: 'k', durationMs: 0, format: 'mp3', sizeBytes: 1,
      mtimeMs: 1, hasCover: false, isFavorite: false, enrichStatus: 0, userEdited: false,
      missing: false, ignored: false, kind: 0, addedAt: 1, playCount: 0,
    );
    await MetadataResolver(itunes: ItunesClient(web), deezer: DeezerClient(web))
        .deezerHit(t, null);
    expect(web.calls.single, contains('{q: Adele Skyfall,'));
  });
}

import 'package:codecore/services/online/merge_results.dart';
import 'package:codecore/services/online/query_match.dart';
import 'package:codecore/services/online/ytm_artist_parser.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:flutter_test/flutter_test.dart';

import 'merge_results_test.dart' show song, video, ytm, yt;

// Characterization of phase 87: what the online results are today.
Map _card(String title, String pageType, String browseId) => {
      'musicCardShelfRenderer': {
        'title': {'runs': [{'text': title}]},
        'onTap': {
          'browseEndpoint': {
            'browseId': browseId,
            'browseEndpointContextSupportedConfigs': {
              'browseEndpointContextMusicConfig': {'pageType': pageType},
            },
          },
        },
      },
    };

void main() {
  // Local tracks never enter mergeResults (92.1): a song the library has is
  // taken out afterwards, by withoutOwned.
  test('every merged row is online: sources and primary come from the input', () {
    final input = [
      ytm(song('s1', 'Sigarette', secs: 180)),
      yt(video('v1', 'Altra canzone', secs: 200), 0.7),
    ];
    final rows = mergeResults(input);
    final given = {for (final i in input) i.result.id};
    expect(rows, isNotEmpty);
    for (final r in rows) {
      expect(r.sources, isNotEmpty);
      expect({MediaKind.ytmSong, MediaKind.ytVideo}.containsAll(r.sources), isTrue);
      expect(given, contains(r.primary.id));
    }
  });

  test('only the first card of the answer is read: one artist, no album', () {
    final data = {
      'contents': [
        _card('Pink Floyd', 'MUSIC_PAGE_TYPE_ARTIST', 'UC1'),
        _card('The Wall', 'MUSIC_PAGE_TYPE_ALBUM', 'MPREb_1'),
      ],
    };
    final top = parseTopCard(data);
    expect(top, isA<TopArtist>());
    expect((top as TopArtist).artist.name, 'Pink Floyd');
  });

  test('only the first card of the answer is read: one album, no artist', () {
    final data = {
      'contents': [
        _card('The Wall', 'MUSIC_PAGE_TYPE_ALBUM', 'MPREb_1'),
        _card('Pink Floyd', 'MUSIC_PAGE_TYPE_ARTIST', 'UC1'),
      ],
    };
    expect(parseTopCard(data), isA<TopAlbum>());
  });
}

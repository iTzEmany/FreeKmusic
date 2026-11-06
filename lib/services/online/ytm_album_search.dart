import '../../core/text_utils.dart';
import 'innertube_client.dart' show InnerTubeChanged;
import 'innertube_json.dart';
import 'ytm_artist.dart';

const _artistType = 'MUSIC_PAGE_TYPE_ARTIST';
const _albumType = 'MUSIC_PAGE_TYPE_ALBUM';

/// An album, single or EP found by the albums filter of the search: the
/// release (subtitle «Album • 1973») and its artist when YouTube links one.
typedef YtmAlbumHit = ({YtmRelease release, YtmArtistRef? artist});

/// The albums of a YouTube Music search filtered on albums, best first.
/// Second column: `Album • Pink Floyd • 1973`, the artist being a link.
List<YtmAlbumHit> parseAlbumSearch(Map data) {
  final contents = data['contents'];
  if (contents is! Map || !contents.containsKey('tabbedSearchResultsRenderer')) {
    throw const InnerTubeChanged('no tabbedSearchResultsRenderer');
  }
  final out = <YtmAlbumHit>[];
  for (final item in collectRenderers(contents, 'musicResponsiveListItemRenderer')) {
    final nav = {'navigationEndpoint': item['navigationEndpoint']};
    final id = browseIdOf(nav);
    if (pageTypeOf(nav) != _albumType || id == null) continue;
    final columns = [
      for (final c in item['flexColumns'] is List ? item['flexColumns'] as List : const [])
        if (c is Map && c['musicResponsiveListItemFlexColumnRenderer'] is Map)
          (c['musicResponsiveListItemFlexColumnRenderer'] as Map)['text'],
    ];
    final title = columns.isEmpty ? '' : htmlUnescape(runsText(columns[0]));
    if (title.isEmpty) continue;
    YtmArtistRef? artist;
    final rest = <String>[];
    for (final g in bulletGroups(columns.length > 1 ? columns[1] : null)) {
      final linked = g.where((r) => pageTypeOf(r) == _artistType && browseIdOf(r) != null);
      if (linked.isEmpty) {
        rest.add(htmlUnescape(groupText(g)));
      } else {
        artist ??= YtmArtistRef(
            id: browseIdOf(linked.first)!,
            name: htmlUnescape('${linked.first['text']}'.trim()));
      }
    }
    out.add((
      release: YtmRelease(
        browseId: id,
        title: title,
        subtitle: rest.join(' • '),
        thumbnailUrl: pickThumbnail(item['thumbnail'], minWidth: 120),
      ),
      artist: artist,
    ));
  }
  return out;
}

import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/online/ytm_album_search.dart';
import '../../../services/online/ytm_artist.dart';
import '../../theme/tokens.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/section_header.dart';
import '../online/artist_page_sections.dart' show releaseLine, thumbAt;

const _gap = 12.0;
const _artistWidth = 96.0;
const _albumWidth = 124.0;

/// «Artisti» (D-401): more artists than the main card, in a row that scrolls
/// sideways. Nothing when [artists] is empty.
class ArtistsRow extends StatelessWidget {
  const ArtistsRow({super.key, required this.artists, required this.onOpen});

  final List<YtmArtistRef> artists;
  final void Function(YtmArtistRef) onOpen;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return _Shelf(
      shelfKey: const ValueKey('online-artists'),
      title: l.artists,
      width: _artistWidth,
      lines: 1,
      count: artists.length,
      tile: (context, i) {
        final a = artists[i];
        return _ShelfTile(
          key: ValueKey('artist-hit-${a.id}'),
          width: _artistWidth,
          cover: NetThumbnail(
            url: thumbAt(context, a.thumbnailUrl, _artistWidth),
            width: _artistWidth,
            height: _artistWidth,
            icon: Icons.person_rounded,
            circle: true,
          ),
          title: a.name,
          subtitle: l.kindArtist,
          centered: true,
          onTap: () => onOpen(a),
        );
      },
    );
  }
}

/// «Album» (D-401): albums, singles and EPs found by the search, in a row that
/// scrolls sideways. Nothing when [albums] is empty.
class AlbumsRow extends StatelessWidget {
  const AlbumsRow({super.key, required this.albums, required this.onOpen});

  final List<YtmAlbumHit> albums;
  final void Function(YtmRelease) onOpen;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();
    final l = context.l10n;
    return _Shelf(
      shelfKey: const ValueKey('online-albums'),
      title: l.albums,
      width: _albumWidth,
      lines: 2,
      count: albums.length,
      tile: (context, i) {
        final (:release, :artist) = albums[i];
        final line = [
          if (artist != null) artist.name,
          releaseLine(release.subtitle),
        ].where((p) => p.isNotEmpty).join(', ');
        return _ShelfTile(
          key: ValueKey('album-hit-${release.browseId}'),
          width: _albumWidth,
          cover: NetThumbnail(
            url: thumbAt(context, release.thumbnailUrl, _albumWidth),
            width: _albumWidth,
            height: _albumWidth,
            radius: CcDims.rGrid,
            icon: Icons.album_rounded,
          ),
          title: release.title,
          subtitle: line,
          lines: 2,
          onTap: () => onOpen(release),
        );
      },
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.shelfKey,
    required this.title,
    required this.width,
    required this.lines,
    required this.count,
    required this.tile,
  });

  final Key shelfKey;
  final String title;
  final double width;

  /// Lines of the text under the title.
  final int lines;
  final int count;
  final Widget Function(BuildContext, int) tile;

  @override
  Widget build(BuildContext context) {
    // The text under the cover (a title of two lines and [lines] more) grows
    // with the text size.
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);
    return Column(
      key: shelfKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title),
        SizedBox(
          height: width + CcDims.gap8 + (44 + 28 * lines) * scale,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
            // One fixed step: sideways scrolling needs no measuring.
            itemExtent: width + _gap,
            itemCount: count,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: tile(context, i),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({
    super.key,
    required this.width,
    required this.cover,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.lines = 1,
    this.centered = false,
  });

  final double width;
  final Widget cover;
  final String title, subtitle;
  final bool centered;
  final int lines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final align = centered ? TextAlign.center : TextAlign.start;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CcDims.rGrid),
      child: Semantics(
        button: true,
        label: [title, if (subtitle.isNotEmpty) subtitle].join(', '),
        excludeSemantics: true,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              cover,
              const SizedBox(height: 6),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: align,
                style: theme.titleSmall,
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: align,
                  style: theme.bodySmall?.copyWith(color: cc.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

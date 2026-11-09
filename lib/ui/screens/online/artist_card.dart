import 'package:flutter/material.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../services/online/google_thumb.dart';
import '../../../services/online/ytm_artist.dart';
import '../../theme/tokens.dart';
import '../../widgets/dislike_sheet.dart' show BlockedArtistMark;
import '../../widgets/net_thumbnail.dart';

/// The artist on top of the online results: round photo, name and «Artista ·
/// monthly audience»; a tap opens the artist's page. [large] is the card of a
/// search that is just the artist's name.
class ArtistCard extends StatelessWidget {
  const ArtistCard({
    super.key,
    required this.artist,
    required this.onTap,
    this.large = false,
  });

  final YtmArtistRef artist;
  final VoidCallback onTap;
  final bool large;

  static const photo = 64.0;
  static const largePhoto = 96.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final thumb = artist.thumbnailUrl;
    final audience = artist.audience;
    final size = large ? largePhoto : photo;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CcDims.margin,
        CcDims.gap4,
        CcDims.margin,
        CcDims.gap8,
      ),
      child: Material(
        key: const ValueKey('artist-card'),
        color: cc.surface1,
        borderRadius: BorderRadius.circular(CcDims.rCard),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(large ? CcDims.gap16 : CcDims.gap12),
            child: Row(
              children: [
                NetThumbnail(
                  url: thumb == null
                      ? null
                      : googleThumbAt(thumb, (size * dpr).round()),
                  width: size,
                  height: size,
                  icon: Icons.person_rounded,
                  circle: true,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              artist.name,
                              maxLines: large ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: large
                                  ? theme.headlineSmall
                                  : theme.titleMedium,
                            ),
                          ),
                          BlockedArtistMark(artist.name),
                        ],
                      ),
                      Text(
                        audience == null || audience.isEmpty
                            ? l.kindArtist
                            : l.ytmArtistWithAudience(audience),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodyMedium?.copyWith(color: cc.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cc.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

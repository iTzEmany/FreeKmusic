import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../l10n/l10n_ext.dart';
import '../../providers/library_providers.dart' show artistsProvider;
import '../../providers/player_providers.dart';
import '../../services/online/artist_link_resolver.dart';
import 'artist_link_open.dart';

/// The credited artists of [track], one tappable zone per name; separators are
/// plain text. Streamed tracks use the artists of their YouTube Music result.
class ArtistLinks extends ConsumerWidget {
  const ArtistLinks(this.track, {super.key, this.style, this.minHeight = 48});

  final Track track;
  final TextStyle? style;

  /// Height of each tap target.
  final double minHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(onlineEntriesProvider)?[track.id]?.result;
    final inLibrary =
        isLibraryArtistIn(ref.watch(artistsProvider).value ?? const []);
    final artists = artistsOfTrack(track, online, isLibraryArtist: inLibrary);
    if (artists.isEmpty) {
      return Text(context.l10n.unknownArtist, maxLines: 1, style: style);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in artists) ...[
          // flex ~ text length: each part gets what it needs whenever the total fits.
          Flexible(
            flex: a.name.length,
            child: Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              label: a.name,
              onTap: () => openArtistLink(context, ref, a),
              child: InkWell(
                onTap: () => openArtistLink(context, ref, a),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: Text(
                      a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (a.sep.isNotEmpty)
            Flexible(flex: a.sep.length, child: Text(a.sep, maxLines: 1, overflow: TextOverflow.clip, style: style)),
        ],
      ],
    );
  }
}

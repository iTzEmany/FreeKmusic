import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n_ext.dart';
import '../../../providers/ytm_catalog_providers.dart' show artistPageProvider;
import '../../../services/import/track_matcher.dart' show matchKey;
import '../../../services/online/google_thumb.dart';
import '../../../services/online/ytm_artist.dart';
import '../../theme/tokens.dart';
import '../../widgets/collection_header.dart';
import '../../widgets/motion.dart';
import '../../widgets/net_thumbnail.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';

/// A picture of [url] at [size] dp, asked of Google at the right step.
String? thumbAt(BuildContext context, String? url, double size) => url == null
    ? null
    : googleThumbAt(
        url,
        (size * MediaQuery.devicePixelRatioOf(context)).round(),
      );

/// Photo, name and monthly audience at the top of an artist page. Built from
/// the reference the page was opened from, so it is there while the page loads.
class ArtistHeader extends StatelessWidget {
  const ArtistHeader({
    super.key,
    required this.artist,
    this.audience,
    this.action,
  });

  final YtmArtistRef artist;

  /// «25.9M monthly audience» once the page is read.
  final String? audience;

  /// A button under the name («Segui»).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = audience ?? artist.audience;
    return CollectionHeader(
      cover: (s) => NetThumbnail(
        url: thumbAt(context, artist.thumbnailUrl, s.round().toDouble()),
        width: s,
        height: s,
        icon: Icons.person_rounded,
        circle: true,
      ),
      name: artist.name,
      meta: text == null || text.isEmpty ? null : text,
      actions: [?action],
    );
  }
}

/// «Non in linea · dati del 21/10/2026» over an old copy of the page.
class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key, required this.fetchedAt});

  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final date = MaterialLocalizations.of(context).formatShortDate(fetchedAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap4, CcDims.margin, CcDims.gap4),
      child: Container(
        key: const ValueKey('offline-notice'),
        padding: const EdgeInsets.symmetric(horizontal: CcDims.gap12, vertical: CcDims.gap8),
        decoration: BoxDecoration(
          color: cc.surface1,
          borderRadius: BorderRadius.circular(CcDims.rCard),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 18, color: cc.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.ytmOffline(date),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows where the songs will be, while the page loads.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, this.rows = 5});

  final int rows;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('page-skeleton'),
    padding: const EdgeInsets.symmetric(vertical: CcDims.gap12),
    child: Skeleton.list(rows: rows),
  );
}

/// A shelf of albums, singles or EPs: the first few as rows.
class ReleaseList extends StatelessWidget {
  const ReleaseList({
    super.key,
    required this.shelf,
    required this.onOpen,
    this.onMore,
  });

  final YtmReleaseShelf shelf;
  final void Function(YtmRelease) onOpen;

  /// Null hides «Tutti» (the page gave no link).
  final VoidCallback? onMore;

  static const maxRows = 5;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          shelf.title,
          actionLabel: onMore == null ? null : l.showAll,
          onAction: onMore,
        ),
        for (final r in shelf.releases.take(maxRows))
          ReleaseRow(release: r, onTap: onOpen),
      ],
    );
  }
}

/// «EP • 2025» as «EP, 2025»; empty when the page gave nothing.
String releaseLine(String subtitle) =>
    subtitle.replaceAll(RegExp(r' [\u2022\u00b7] '), ', ');

/// One row: a square cover, the title and a line like «EP, 2025».
class ReleaseRow extends StatelessWidget {
  const ReleaseRow({super.key, required this.release, required this.onTap});

  final YtmRelease release;
  final void Function(YtmRelease) onTap;

  @override
  Widget build(BuildContext context) {
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    final line = releaseLine(release.subtitle);
    return PressScale(
      child: InkWell(
        key: ValueKey('release-${release.browseId}'),
        onTap: () => onTap(release),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CcDims.margin,
            vertical: CcDims.gap8,
          ),
          child: Row(
            children: [
              NetThumbnail(
                url: thumbAt(context, release.thumbnailUrl, 56),
                width: 56,
                height: 56,
                radius: CcDims.rGrid,
                icon: Icons.album_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      release.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleSmall,
                    ),
                    if (line.isNotEmpty)
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(color: cc.textMuted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Fans might also like»: three rows with a round photo.
class ArtistList extends StatelessWidget {
  const ArtistList({super.key, required this.shelf, required this.onOpen});

  final YtmArtistShelf shelf;
  final void Function(YtmArtistRef) onOpen;

  static const maxRows = 3;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    final theme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(shelf.title),
        for (final a in shelf.artists.take(maxRows))
          PressScale(
            child: InkWell(
              key: ValueKey('similar-${a.id}'),
              onTap: () => onOpen(a),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CcDims.margin,
                  vertical: CcDims.gap8,
                ),
                child: Row(
                  children: [
                    NetThumbnail(
                      url: thumbAt(context, a.thumbnailUrl, 56),
                      width: 56,
                      height: 56,
                      icon: Icons.person_rounded,
                      circle: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.titleSmall,
                          ),
                          if (a.audience != null && a.audience!.isNotEmpty)
                            Text(
                              l.ytmArtistWithAudience(a.audience!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.bodySmall?.copyWith(
                                color: cc.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The biography: four lines, «Altro» opens the rest.
class AboutSection extends StatefulWidget {
  const AboutSection({super.key, required this.text});

  final String text;

  @override
  State<AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<AboutSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l.ytmAbout),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
          child: Text(
            widget.text,
            key: const ValueKey('about-text'),
            maxLines: _open ? null : 4,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: cc.textMuted),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CcDims.margin - CcDims.gap8),
          child: TextButton(
            key: const ValueKey('about-toggle'),
            onPressed: () => setState(() => _open = !_open),
            child: Text(_open ? l.ytmLess : l.ytmMore),
          ),
        ),
      ],
    );
  }
}

final _year = RegExp(r'\b(?:19|20)\d{2}\b');

/// The shelves of the merged profiles as one page (D-402): the main profile's
/// shelves, plus the releases of the other profiles it does not have yet (same
/// normalised title and year in any release shelf, so a «Singolo» on one profile
/// and an «Album» on the other count once). Each release shelf is then newest
/// first. «Show all» stays the main profile's. Other shelf kinds stay the main's.
List<YtmShelf> mergeArtistShelves(YtmArtistPage main, List<YtmArtistPage> others) {
  if (others.isEmpty) return main.shelves;
  String key(YtmRelease r) {
    final k = matchKey(r.title);
    return '${k.isEmpty ? r.title.trim().toLowerCase() : k}|${_yearOf(r)}';
  }
  final shelves = [...main.shelves];
  final seen = {
    for (final x in shelves)
      if (x is YtmReleaseShelf) for (final r in x.releases) key(r),
  };
  for (final other in others) {
    for (final shelf in other.shelves) {
      if (shelf is! YtmReleaseShelf) continue;
      final added = [for (final r in shelf.releases) if (seen.add(key(r))) r];
      if (added.isEmpty) continue;
      final at = shelves.indexWhere((x) => x is YtmReleaseShelf && x.title == shelf.title);
      if (at < 0) {
        shelves.add(YtmReleaseShelf(shelf.title, added));
      } else {
        final mine = shelves[at] as YtmReleaseShelf;
        shelves[at] = YtmReleaseShelf(mine.title, [...mine.releases, ...added], more: mine.more);
      }
    }
  }
  return [
    for (final x in shelves)
      if (x is YtmReleaseShelf) YtmReleaseShelf(x.title, _newestFirst(x.releases), more: x.more) else x,
  ];
}

String _yearOf(YtmRelease r) => _year.firstMatch(r.subtitle)?.group(0) ?? '';

/// Stable: releases of the same year (or without one) keep their order.
List<YtmRelease> _newestFirst(List<YtmRelease> l) {
  final at = {for (var i = 0; i < l.length; i++) l[i]: i};
  return [...l]..sort((a, b) {
      final c = _yearOf(b).compareTo(_yearOf(a));
      return c != 0 ? c : at[a]!.compareTo(at[b]!);
    });
}

/// The merged shelves of a group, computed once per change of its pages instead
/// of at every rebuild. [key] is the ids of the group joined by «|», main first;
/// null while the main page is not there.
final groupShelvesProvider = Provider.autoDispose.family<List<YtmShelf>?, String>((ref, key) {
  final ids = key.split('|');
  final main = ref.watch(artistPageProvider(ids.first)).value?.value;
  if (main == null) return null;
  return mergeArtistShelves(main, [
    for (final id in ids.skip(1)) ?ref.watch(artistPageProvider(id)).value?.value,
  ]);
});

/// «2 profili uniti» under the header of a merged page; a tap lists them.
class MergedProfilesNote extends StatelessWidget {
  const MergedProfilesNote({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          button: true,
          child: InkWell(
            key: const ValueKey('merged-note'),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: CcDims.margin),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1,
                  child: Text(
                    context.l10n.artistMergedNote(count),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.cc.textMuted),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// «Sembra lo stesso artista…»: merge the two profiles or say they are different.
class MergeWarning extends StatelessWidget {
  const MergeWarning({super.key, required this.other, required this.onMerge, required this.onDifferent});

  /// What names the other profile («Marco Castello · 38 mila iscritti»).
  final String other;
  final VoidCallback onMerge, onDifferent;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cc = context.cc;
    return Container(
      key: const ValueKey('merge-warning'),
      margin: const EdgeInsets.fromLTRB(CcDims.margin, CcDims.gap8, CcDims.margin, 0),
      padding: const EdgeInsets.fromLTRB(CcDims.gap12, CcDims.gap12, CcDims.gap8, CcDims.gap4),
      decoration: BoxDecoration(color: cc.surface2, borderRadius: BorderRadius.circular(CcDims.rCard)),
      child: Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.artistSameWarn(other), style: Theme.of(context).textTheme.bodyLarge),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                children: [
                  TextButton(
                    key: const ValueKey('merge-different'),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: onDifferent,
                    child: Text(l.artistNotSame),
                  ),
                  TextButton(
                    key: const ValueKey('merge-yes'),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    onPressed: onMerge,
                    child: Text(l.artistMergeYes),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

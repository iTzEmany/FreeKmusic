import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/online/ytm_artist.dart';
import 'ytm_catalog_providers.dart' show artistPageProvider;
import '../core/artist_key.dart';

final _year = RegExp(r'\b(?:19|20)\d{2}\b');

/// The shelves of the merged profiles as one page (D-402): the main profile's
/// shelves, plus the releases of the other profiles it does not have yet (same
/// normalised title and year in any release shelf, so a «Singolo» on one profile
/// and an «Album» on the other count once). Each release shelf is then newest
/// first. «Show all» stays the main profile's. Other shelf kinds stay the main's.
List<YtmShelf> mergeArtistShelves(
  YtmArtistPage main,
  List<YtmArtistPage> others,
) {
  if (others.isEmpty) return main.shelves;
  String key(YtmRelease r) {
    final k = matchKey(r.title);
    return '${k.isEmpty ? r.title.trim().toLowerCase() : k}|${_yearOf(r)}';
  }

  final shelves = [...main.shelves];
  final seen = {
    for (final x in shelves)
      if (x is YtmReleaseShelf)
        for (final r in x.releases) key(r),
  };
  for (final other in others) {
    for (final shelf in other.shelves) {
      if (shelf is! YtmReleaseShelf) continue;
      final added = [
        for (final r in shelf.releases)
          if (seen.add(key(r))) r,
      ];
      if (added.isEmpty) continue;
      final at = shelves.indexWhere(
        (x) => x is YtmReleaseShelf && x.title == shelf.title,
      );
      if (at < 0) {
        shelves.add(YtmReleaseShelf(shelf.title, added));
      } else {
        final mine = shelves[at] as YtmReleaseShelf;
        shelves[at] = YtmReleaseShelf(mine.title, [
          ...mine.releases,
          ...added,
        ], more: mine.more);
      }
    }
  }
  return [
    for (final x in shelves)
      if (x is YtmReleaseShelf)
        YtmReleaseShelf(x.title, _newestFirst(x.releases), more: x.more)
      else
        x,
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
final groupShelvesProvider = Provider.autoDispose
    .family<List<YtmShelf>?, String>((ref, key) {
      final ids = key.split('|');
      final main = ref.watch(artistPageProvider(ids.first)).value?.value;
      if (main == null) return null;
      return mergeArtistShelves(main, [
        for (final id in ids.skip(1))
          ?ref.watch(artistPageProvider(id)).value?.value,
      ]);
    });

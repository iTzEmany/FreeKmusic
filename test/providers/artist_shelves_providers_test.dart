import 'package:codecore/providers/artist_shelves_providers.dart';
import 'package:codecore/providers/ytm_catalog_providers.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_catalog.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const a = YtmArtistRef(id: 'UCa', name: 'Marco Castello');
const b = YtmArtistRef(id: 'UCb', name: 'Marco Castello', audience: '38 mila');

void main() {
  test('merged shelves: one release per title and year across shelves, newest first', () {
    const old = YtmRelease(browseId: 'o', title: 'Old', subtitle: '2010');
    final main = YtmArtistPage(
      ref: a,
      shelves: const [
        YtmReleaseShelf('Album', [
          old,
          YtmRelease(browseId: 'n', title: 'New', subtitle: '2024'),
        ], more: YtmBrowseLink('M', null)),
      ],
    );
    final other = YtmArtistPage(
      ref: b,
      shelves: const [
        YtmReleaseShelf('Singoli', [
          YtmRelease(browseId: 'x', title: 'new', subtitle: 'Singolo • 2024'),
        ]),
        YtmReleaseShelf('Album', [
          YtmRelease(browseId: 'm', title: 'Mid', subtitle: '2018'),
        ]),
      ],
    );
    final shelves = mergeArtistShelves(main, [other]).cast<YtmReleaseShelf>();
    expect(
      shelves.length,
      1,
      reason: 'the single is the main profile\'s album: not a new shelf',
    );
    expect(
      [for (final r in shelves.single.releases) r.title],
      ['New', 'Mid', 'Old'],
    );
    expect(shelves.single.more, isNotNull);
  });

  test('merged shelves: same title in different years stays two releases; symbol-only titles do not collapse', () {
    final main = YtmArtistPage(
      ref: a,
      shelves: const [
        YtmReleaseShelf('Album', [
          YtmRelease(browseId: 'l1', title: 'Live', subtitle: '2010'),
          YtmRelease(browseId: 'h', title: '\u2665', subtitle: '2020'),
        ]),
      ],
    );
    final other = YtmArtistPage(
      ref: b,
      shelves: const [
        YtmReleaseShelf('Album', [
          YtmRelease(browseId: 'l2', title: 'Live', subtitle: '2015'),
          YtmRelease(browseId: 's', title: '\u2606', subtitle: '2020'),
        ]),
      ],
    );
    final shelf = mergeArtistShelves(main, [other]).single as YtmReleaseShelf;
    expect(shelf.releases.length, 4);
  });

  test('groupShelvesProvider groups like mergeArtistShelves, and is null while the main page is missing', () async {
    final main = YtmArtistPage(
      ref: a,
      shelves: const [
        YtmReleaseShelf('Album', [
          YtmRelease(browseId: 'n', title: 'New', subtitle: '2024'),
        ]),
      ],
    );
    final other = YtmArtistPage(
      ref: b,
      shelves: const [
        YtmReleaseShelf('Album', [
          YtmRelease(browseId: 'm', title: 'Mid', subtitle: '2018'),
        ]),
      ],
    );
    ProviderContainer make(Map<String, YtmArtistPage> pages) =>
        ProviderContainer(
          overrides: [
            artistPageProvider.overrideWith((ref, id) async {
              final p = pages[id];
              if (p == null) throw StateError('missing $id');
              return CatalogResult(p, DateTime(2026, 10, 22));
            }),
          ],
        );
    List<List<String>> titles(List<YtmShelf>? l) => [
      for (final s in l!.cast<YtmReleaseShelf>())
        [for (final r in s.releases) r.title],
    ];

    final both = make({a.id: main, b.id: other});
    addTearDown(both.dispose);
    final sub = both.listen(groupShelvesProvider('${a.id}|${b.id}'), (_, _) {});
    await both.read(artistPageProvider(a.id).future);
    await both.read(artistPageProvider(b.id).future);
    expect(titles(sub.read()), [
      ['New', 'Mid'],
    ]);
    expect([for (final s in sub.read()!) s.title], ['Album']);

    final none = make({b.id: other});
    addTearDown(none.dispose);
    final sub2 = none.listen(
      groupShelvesProvider('${a.id}|${b.id}'),
      (_, _) {},
    );
    await none.read(artistPageProvider(b.id).future);
    await Future<void>.delayed(Duration.zero);
    expect(sub2.read(), isNull);
  });
}

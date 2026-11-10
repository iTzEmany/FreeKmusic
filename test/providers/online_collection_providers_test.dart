import 'package:codecore/providers/online_collection_providers.dart';
import 'package:codecore/providers/youtube_providers.dart';
import 'package:codecore/services/online/external_collection.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_ytm.dart';

void main() {
  test('a YouTube listing becomes a collection with every row ready', () async {
    final listing = PlaylistListing(
      title: 'Mix',
      owner: 'Chan',
      truncated: true,
      entries: [ytmSong('a', 'One', seconds: 10), ytmSong('b', 'Two', seconds: 20)],
    );
    final c = ProviderContainer(overrides: [
      playlistListingProvider.overrideWith((ref, url) async => listing),
    ]);
    addTearDown(c.dispose);
    final page = await c.read(
        onlineCollectionProvider(const OnlineCollectionRef.youtubeListing('u')).future);
    expect(page.collection.title, 'Mix');
    expect(page.collection.owner, 'Chan');
    expect(page.collection.truncated, isTrue);
    expect(page.collection.tracks.map((t) => t.key), ['a', 'b']);
    expect(page.matches.every((m) => m is TrackReady), isTrue);
    expect([for (final m in page.matches) (m as TrackReady).result.id], ['a', 'b']);
  });
}

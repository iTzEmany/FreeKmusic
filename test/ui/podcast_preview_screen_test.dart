import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/providers/podcast_discover_providers.dart';
import 'package:codecore/ui/screens/podcast/podcast_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

void main() {
  testWidgets('«Segui» follows the show and turns into «Segui già»; touched again it unfollows', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    const listing = PodcastListing(origin: PodcastOrigin.apple, title: 'Show', feedUrl: 'https://x/feed');
    const preview = PodcastPreview(
      feedUrl: 'https://x/feed',
      feed: PodcastFeed(title: 'Show', episodes: [PodcastEpisodeInfo(guid: 'e1', title: 'One', audioUrl: 'https://x/1.mp3')]),
    );
    await h.pump(tester, const PodcastPreviewScreen(listing: listing), extraOverrides: [
      podcastPreviewProvider.overrideWith((ref, key) async => preview),
      podcastCoverSaverProvider.overrideWithValue((id, url) async => null),
    ]);
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await settle();
    expect(find.text('Segui'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('follow')));
    await settle();
    expect(find.text('Segui già'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('follow')));
    await settle();
    expect(find.text('Segui'), findsOneWidget);
    // Let drift's stream timers go before the test ends.
    await tester.pumpWidget(const SizedBox());
    await settle();
  });
}

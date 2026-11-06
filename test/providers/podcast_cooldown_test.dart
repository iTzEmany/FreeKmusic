import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/providers/smart_search_providers.dart';
import 'package:codecore/services/online/query_match.dart' show MediaKind;
import 'package:codecore/services/online/youtube_service.dart' show YtErrorKind, YtException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the YouTube Music podcasts rest with the same source cooldown as Search', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(sourceCooldownProvider).trip(MediaKind.ytmSong);
    await expectLater(
      c.read(ytmPodcastsProvider).searchShows('x'),
      throwsA(isA<YtException>().having((e) => e.kind, 'kind', YtErrorKind.rateLimited)),
    );
  });
}

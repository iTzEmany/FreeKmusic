import 'package:codecore/core/constants.dart' show kEnableYoutube;
import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/podcast_repository.dart';
import 'package:codecore/providers/podcast_discover_providers.dart';
import 'package:codecore/providers/podcast_providers.dart';
import 'package:codecore/services/online/http_client.dart';
import 'package:codecore/services/online/ytm_podcasts.dart';
import 'package:codecore/services/podcast/apple_podcasts.dart';
import 'package:codecore/services/podcast/podcast_models.dart';
import 'package:codecore/services/podcast/podcast_service.dart';
import 'package:dio/dio.dart' show CancelToken;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Apple implements ApplePodcasts {
  bool fail = false;
  @override
  Future<List<PodcastSearchHit>> search(String term, {int limit = 10, String? country, String? genreId}) async {
    if (fail) throw const PodcastException(PodcastErrorKind.network, 'down');
    return const [PodcastSearchHit(name: 'Apple Show', feedUrl: 'https://x/f')];
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Ytm implements YtmPodcasts {
  bool fail = false;
  var hits = const <YtmShowHit>[YtmShowHit(id: 'MPSPa', title: 'Ytm Show')];
  @override
  Future<List<YtmShowHit>> searchShows(String query, {String hl = 'en', CancelToken? cancel}) async {
    if (fail) throw StateError('down');
    return hits;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

PodcastListing _l(String title, String? author, {PodcastOrigin o = PodcastOrigin.apple, String? feed, String? ytm}) =>
    PodcastListing(origin: o, title: title, author: author, feedUrl: feed, ytmId: ytm);

void main() {
  late AppDatabase db;
  late _Apple apple;
  late _Ytm ytm;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    apple = _Apple();
    ytm = _Ytm();
    c = ProviderContainer(overrides: [
      podcastServiceProvider.overrideWithValue(PodcastService(
        repo: PodcastRepository(db),
        fetch: (u) async => u,
        parse: (t) async => throw const FormatException('x'),
        web: DioWebClient(),
        apple: apple,
      )),
      ytmPodcastsProvider.overrideWithValue(ytm),
    ]);
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<List<String>> titles() async =>
      [for (final l in await c.read(podcastSearchProvider((query: 'x', hl: 'en')).future)) l.title];

  group('search with one source down', () {
    test('Apple down, YouTube Music answers', () async {
      apple.fail = true;
      expect(await titles(), ['Ytm Show']);
    }, skip: !kEnableYoutube);

    test('YouTube Music down, Apple answers', () async {
      ytm.fail = true;
      expect(await titles(), ['Apple Show']);
    }, skip: !kEnableYoutube);
  });

  group('the same show on two sources', () {
    PodcastSubscriptions none() => PodcastSubscriptions(const []);

    test('accents, case, decomposed accents and punctuation do not tell shows apart', () {
      final merged = mergeListings([
        _l('Caffè Corretto!', 'Radio Uno'),
        _l('CAFFÈ corretto', 'radio uno', o: PodcastOrigin.ytm, ytm: 'a'),
      ], none());
      expect(merged, hasLength(1));
    });

    test('titles with no letters (emoji) are kept apart by their raw text', () {
      expect(mergeListings([_l('🎧', 'a'), _l('🎵', 'a')], none()), hasLength(2));
      expect(mergeListings([_l('🎧', 'a'), _l('🎧', 'a')], none()), hasLength(1));
    });

    test('a missing author on one side still matches the same title; two different authors do not', () {
      expect(mergeListings([_l('Tintoria', 'OnePodcast'), _l('Tintoria', null)], none()), hasLength(1));
      expect(mergeListings([_l('Tintoria', 'A'), _l('Tintoria', 'B')], none()), hasLength(2));
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_alias_repository.dart';
import 'package:codecore/data/repositories/follow_repository.dart';
import 'package:codecore/data/repositories/release_repository.dart';
import 'package:codecore/services/online/innertube_client.dart';
import 'package:codecore/services/online/youtube_service.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/online/ytm_artist_parser.dart';
import 'package:codecore/services/releases/release_checker.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The page of an artist: release ids are unique per artist, so they carry its id.
YtmArtistPage page(String fixture, String artist) {
  final p = parseArtistPage(
      jsonDecode(File('test/fixtures/innertube/$fixture.json').readAsStringSync()) as Map, artist);
  return YtmArtistPage(ref: p.ref, shelves: [
    for (final s in p.shelves.whereType<YtmReleaseShelf>())
      YtmReleaseShelf(s.title, [
        for (final r in s.releases)
          YtmRelease(browseId: '${r.browseId}_$artist', title: r.title, subtitle: r.subtitle),
      ]),
  ]);
}

void main() {
  late AppDatabase db;
  late FollowRepository follows;
  late ReleaseRepository releases;
  late List<String> asked;
  late List<Duration> waits;
  var now = DateTime(2026, 10, 22, 9);
  // What each artist's page answers (a function so a test can change it).
  late Object Function(String id) answer;

  ReleaseChecker checker() => ReleaseChecker(
        (id) async {
          asked.add(id);
          final a = answer(id);
          if (a is YtmArtistPage) return a;
          throw a;
        },
        follows,
        releases,
        now: () => now,
        wait: (d) async => waits.add(d),
      );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    follows = FollowRepository(db, now: () => now.millisecondsSinceEpoch);
    releases = ReleaseRepository(db, now: () => now.millisecondsSinceEpoch);
    asked = [];
    waits = [];
    answer = (id) => page('ytm_artist_releases', id);
    for (final id in ['UC1', 'UC2', 'UC3']) {
      await follows.follow(YtmArtistRef(id: id, name: 'Artist $id'));
    }
  });
  tearDown(() => db.close());

  test('the first round of an artist marks everything as seen; a later release is news', () async {
    final first = await checker().run();
    expect((first.checked, first.failed, first.stoppedBy), (3, 0, null));
    expect(first.fresh, isEmpty);
    expect(await releases.countNew(), 0);
    expect((await follows.get('UC1'))!.lastCheckedAt, isNotNull);

    // The same pages again: still nothing. Then the page of UC2 has one more.
    await db.customStatement("DELETE FROM artist_releases WHERE artist_id = 'UC2' AND title = 'Patient Zero'");
    final second = await checker().run();
    expect(second.fresh.map((f) => (f.artist.ytmId, f.release.release.title)), [('UC2', 'Patient Zero')]);
    expect(await releases.countNew(), 1);
    final third = await checker().run();
    expect(third.fresh, isEmpty); // seen now
  });

  test('one request at a time with 1.5 s between two artists', () async {
    await checker().run();
    expect(asked, ['UC1', 'UC2', 'UC3']);
    expect(waits, [const Duration(milliseconds: 1500), const Duration(milliseconds: 1500)]);
  });

  test('a 429 on the second artist stops the round: the third is not asked, retry in 6 hours', () async {
    answer = (id) => id == 'UC2' ? const YtException(YtErrorKind.rateLimited, 'HTTP 429') : page('ytm_artist_releases', id);
    final out = await checker().run();
    expect(asked, ['UC1', 'UC2']);
    expect(out.stoppedBy, CheckStop.rateLimited);
    expect(out.retryAt, now.add(const Duration(hours: 6)));
    expect(out.checked, 1);
    expect((await follows.get('UC2'))!.lastCheckedAt, isNull);
  });

  test('offline or an unreadable page also stops the round without blaming the artist', () async {
    answer = (_) => const YtException(YtErrorKind.network);
    expect((await checker().run()).stoppedBy, CheckStop.offline);
    answer = (_) => const InnerTubeChanged('no header');
    expect((await checker().run()).stoppedBy, CheckStop.changed);
    expect((await follows.get('UC1'))!.checksFailed, 0);
  });

  test('an artist not found three rounds in a row is marked and no longer asked', () async {
    answer = (id) => id == 'UC3' ? ArtistNotFound(id) : page('ytm_artist_releases', id);
    for (var i = 0; i < 3; i++) {
      final out = await checker().run();
      expect(out.failed, 1);
    }
    expect((await follows.get('UC3'))!.notFound, isTrue);
    asked.clear();
    await checker().run();
    expect(asked, ['UC1', 'UC2']);
  });

  test('a cancelled round stops before the next artist', () async {
    final cancel = CheckCancel();
    final c = ReleaseChecker(
      (id) async {
        asked.add(id);
        cancel.cancel();
        return page('ytm_artist_releases', id);
      },
      follows,
      releases,
      now: () => now,
      wait: (_) async {},
    );
    final out = await c.run(cancel: cancel);
    expect(asked, ['UC1']);
    expect(out.stoppedBy, CheckStop.cancelled);
  });

  test('a round with nobody to check asks nothing', () async {
    for (final id in ['UC1', 'UC2', 'UC3']) {
      await follows.unfollow(id);
    }
    final out = await checker().run();
    expect(asked, isEmpty);
    expect((out.checked, out.stoppedBy), (0, null));
  });

  test('the merged profiles are fetched with the followed one and their news count for it', () async {
    await ArtistAliasRepository(db).merge('UC1', 'UC9', createdAt: 0);
    await checker().run(only: 'UC1');
    expect(asked, ['UC1', 'UC9']);
    expect((await follows.all()).length, 3);
    answer = (id) => id != 'UC9'
        ? page('ytm_artist_releases', id)
        : YtmArtistPage(ref: YtmArtistRef(id: id, name: id), shelves: const [
            YtmReleaseShelf('Album', [YtmRelease(browseId: 'z', title: 'Zeta', subtitle: '2026')]),
          ]);
    final out = await checker().run(only: 'UC1');
    expect(out.fresh.map((f) => (f.artist.ytmId, f.release.release.title)), [('UC1', 'Zeta')]);
  });

  test('a profile merged after the last check adds its releases as known, not as news', () async {
    await checker().run(only: 'UC1');
    now = now.add(const Duration(hours: 1));
    await ArtistAliasRepository(db).merge('UC1', 'UC9', createdAt: now.millisecondsSinceEpoch);
    now = now.add(const Duration(hours: 1));
    YtmArtistPage alias(List<String> titles) => YtmArtistPage(
        ref: YtmArtistRef(id: 'UC9', name: 'UC9'),
        shelves: [YtmReleaseShelf('Album', [for (final t in titles) YtmRelease(browseId: t, title: t, subtitle: '2026')])]);
    var titles = ['Zeta'];
    answer = (id) => id == 'UC9' ? alias(titles) : page('ytm_artist_releases', id);
    expect((await checker().run(only: 'UC1')).fresh, isEmpty);
    titles = ['Zeta', 'Omega'];
    now = now.add(const Duration(hours: 1));
    final out = await checker().run(only: 'UC1');
    expect(out.fresh.map((f) => f.release.release.title), ['Omega']);
  });
}

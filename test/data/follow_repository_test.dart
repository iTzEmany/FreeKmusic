import 'package:codecore/data/db/app_database.dart';
import 'package:codecore/data/repositories/artist_alias_repository.dart';
import 'package:codecore/data/repositories/follow_repository.dart';
import 'package:codecore/data/repositories/release_repository.dart';
import 'package:codecore/services/online/ytm_artist.dart';
import 'package:codecore/services/releases/release_diff.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

YtmArtistRef artist(String id) => YtmArtistRef(id: id, name: 'Artist $id');

SeenRelease seen(String id, String title, {int year = 2026, ReleaseKind kind = ReleaseKind.album}) =>
    SeenRelease(
      release: YtmRelease(browseId: id, title: title, subtitle: '$year'),
      kind: kind,
      year: year,
      groupKey: releaseGroupKey(title),
    );

void main() {
  late AppDatabase db;
  late FollowRepository follows;
  late ReleaseRepository releases;
  var clock = 1000000000000;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    follows = FollowRepository(db, now: () => clock);
    releases = ReleaseRepository(db, now: () => clock);
  });
  tearDown(() => db.close());

  test('following twice is one row', () async {
    await follows.follow(artist('UC1'));
    await follows.follow(artist('UC1'));
    expect((await follows.all()).length, 1);
    expect(await follows.watchIsFollowed('UC1').first, isTrue);
  });

  test('unfollowing a followed artist removes it; an automatic one is excluded for good', () async {
    await follows.follow(artist('UC1'));
    await follows.followAuto(artist('UC2'));
    await follows.unfollow('UC1');
    await follows.unfollow('UC2');
    final rows = await follows.all();
    expect(rows.map((r) => (r.ytmId, r.excluded)), [('UC2', true)]);
    expect(await follows.followAuto(artist('UC2')), isFalse);
    expect(await follows.toCheck(), isEmpty);
    expect(await follows.watchFollowed().first, isEmpty);
    expect(await follows.watchIsFollowed('UC2').first, isFalse);
    // The user can follow it again by hand.
    await follows.follow(artist('UC2'));
    expect((await follows.toCheck()).single.isAuto, isFalse);
  });

  test('toCheck gives never-checked artists first, then the oldest check', () async {
    for (final id in ['UC1', 'UC2', 'UC3']) {
      await follows.follow(artist(id));
    }
    clock += 10;
    await follows.markChecked('UC2');
    clock += 10;
    await follows.markChecked('UC1');
    expect((await follows.toCheck()).map((a) => a.ytmId), ['UC3', 'UC2', 'UC1']);
    expect((await follows.toCheck(limit: 1)).length, 1);
  });

  test('three misses in a row mark the artist not found until «Riprova»', () async {
    await follows.follow(artist('UC1'));
    for (var i = 0; i < kMaxNotFound; i++) {
      await follows.markChecked('UC1', error: kArtistNotFound);
    }
    expect((await follows.get('UC1'))!.notFound, isTrue);
    expect(await follows.toCheck(), isEmpty);
    await follows.retry('UC1');
    expect((await follows.toCheck()).single.ytmId, 'UC1');
    // A success resets the count; another error does not add to it.
    await follows.markChecked('UC1', error: kArtistNotFound);
    await follows.markChecked('UC1', error: 'unavailable');
    expect((await follows.get('UC1'))!.checksFailed, 1);
    await follows.markChecked('UC1');
    expect((await follows.get('UC1'))!.checksFailed, 0);
  });

  test('removing an artist deletes its releases', () async {
    await follows.follow(artist('UC1'));
    await follows.follow(artist('UC2'));
    await releases.store('UC1', ReleaseDiff([seen('MPREb_1', 'One')], const []));
    await releases.store('UC2', ReleaseDiff([seen('MPREb_2', 'Two')], const []));
    await follows.unfollow('UC1');
    expect(await releases.knownIds('UC1'), isEmpty);
    expect(await releases.knownIds('UC2'), {'MPREb_2'});
  });

  test('storing a first check creates no news; fresh ones are flagged until opened', () async {
    await follows.follow(artist('UC1'));
    await releases.store('UC1', ReleaseDiff([seen('MPREb_1', 'One'), seen('MPREb_2', 'Two')], const []));
    expect(await releases.countNew(), 0);
    expect(await releases.watchRecent().first, isEmpty);

    clock += 1000;
    final s3 = seen('MPREb_3', 'Three'), v3 = seen('MPREb_4', 'Three (Deluxe)');
    await releases.store(
        'UC1',
        ReleaseDiff([s3, v3], [
          NewRelease(release: s3.release, kind: s3.kind, year: 2026, groupKey: s3.groupKey, variants: [v3.release]),
        ]));
    expect(await releases.countNew(), 1);
    final recent = await releases.watchRecent().first;
    expect(recent.single.release.browseId, 'MPREb_3');
    expect(recent.single.artistName, 'Artist UC1');
    expect(recent.single.variants, 1);
    expect(await releases.watchRecent(onlyNew: true).first, hasLength(1));

    await releases.markOpened('MPREb_3');
    expect(await releases.countNew(), 0);
    expect(await releases.watchRecent(onlyNew: true).first, isEmpty);
    expect(await releases.watchRecent().first, hasLength(1)); // still listed
    expect(await releases.knownIds('UC1'), {'MPREb_1', 'MPREb_2', 'MPREb_3', 'MPREb_4'});
    expect(await releases.knownGroups('UC1'), contains(releaseGroupId(ReleaseKind.album, 'three')));
  });

  test('storing twice keeps what is already there', () async {
    await follows.follow(artist('UC1'));
    final d = ReleaseDiff([seen('MPREb_1', 'One')], const []);
    await releases.store('UC1', d);
    await releases.markOpened('MPREb_1');
    await releases.store('UC1', d);
    expect((await db.select(db.artistReleases).get()).length, 1);
  });

  test('recent releases leave out what was seen too long ago', () async {
    await follows.follow(artist('UC1'));
    final s = seen('MPREb_1', 'One');
    await releases.store('UC1', ReleaseDiff([s], [
      NewRelease(release: s.release, kind: s.kind, year: 2026, groupKey: s.groupKey),
    ]));
    clock += const Duration(days: 40).inMilliseconds;
    expect(await releases.watchRecent(days: 30).first, isEmpty);
    expect(await releases.watchRecent(days: 90).first, hasLength(1));
  });

  test('lookups are remembered for 30 days', () async {
    await follows.saveLookup('daft punk', 'Daft Punk', artist: artist('UC1'));
    await follows.saveLookup('x', 'X');
    expect((await follows.lookups()).keys, {'daft punk', 'x'});
    clock += const Duration(days: 31).inMilliseconds;
    expect(await follows.lookups(), isEmpty);
  });


  test('following the main profile makes the alias followed too; unfollowing the alias stops both', () async {
    await ArtistAliasRepository(db).merge('UC1', 'UC2');
    await follows.follow(artist('UC1'));
    expect(await follows.watchIsFollowed('UC2').first, isTrue);
    expect(await follows.watchIsFollowed('UC3').first, isFalse);
    await follows.unfollow('UC2');
    expect(await follows.all(), isEmpty);
    expect(await follows.watchIsFollowed('UC2').first, isFalse);
  });

  test('excluding an automatic profile excludes the whole group', () async {
    await ArtistAliasRepository(db).merge('UC1', 'UC2');
    await follows.followAuto(artist('UC1'));
    await follows.followAuto(artist('UC2'));
    await follows.unfollow('UC1');
    expect((await follows.all()).map((r) => r.excluded), [true, true]);
    expect(await follows.watchIsFollowed('UC2').first, isFalse);
  });

  test('the group of a followed main is checked with it, with no row of its own; split frees the alias', () async {
    final repo = ArtistAliasRepository(db);
    await repo.merge('UC1', 'UC2');
    await follows.follow(artist('UC1'));
    expect((await follows.toCheck()).map((r) => r.ytmId), ['UC1']);
    expect(await follows.checkIds('UC1'), ['UC1', 'UC2']);
    expect((await follows.all()).length, 1);
    expect((await follows.watchFollowed().first).length, 1);
    await repo.split('UC2');
    expect(await follows.watchIsFollowed('UC2').first, isFalse);
    expect(await follows.checkIds('UC1'), ['UC1']);
  });

  test('an excluded main leaves its aliases unchecked', () async {
    await ArtistAliasRepository(db).merge('UC1', 'UC2');
    await follows.follow(artist('UC1'));
    await follows.unfollow('UC1');
    expect(await follows.toCheck(), isEmpty);
  });

  test('a followed alias whose main is followed too is checked once', () async {
    await ArtistAliasRepository(db).merge('UC1', 'UC2');
    await follows.follow(artist('UC1'));
    await follows.follow(artist('UC2'));
    expect((await follows.toCheck()).map((r) => r.ytmId), ['UC1']);
  });

  test('following an alias makes its main profile followed', () async {
    await ArtistAliasRepository(db).merge('UC1', 'UC2');
    await follows.follow(artist('UC2'));
    expect(await follows.watchIsFollowed('UC1').first, isTrue);
  });
}

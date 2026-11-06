import 'package:drift/drift.dart';

import '../../core/clock.dart';
import '../../services/online/ytm_artist.dart';
import '../db/app_database.dart';
import 'artist_alias_repository.dart';

/// `last_error` of an artist whose page YouTube did not find.
const kArtistNotFound = 'not_found';

/// Checks in a row that did not find the page before the artist is left alone.
const kMaxNotFound = 3;

/// 0 followed by hand, 1 followed automatically.
const kOriginManual = 0, kOriginAuto = 1;

extension FollowedArtistState on FollowedArtist {
  bool get isAuto => origin == kOriginAuto;
  bool get notFound => checksFailed >= kMaxNotFound;
}

/// The artists whose new releases are checked. Rows with `excluded` are
/// automatic artists the user stopped following: kept so they do not come back.
class FollowRepository {
  FollowRepository(this._db, {int Function()? now}) : _now = now ?? nowMs;

  final AppDatabase _db;
  final int Function() _now;

  /// Follows [artist] by hand. Following twice is one row; an automatic or
  /// excluded artist becomes a followed one.
  Future<void> follow(YtmArtistRef artist) => _db.transaction(() async {
        final row = await _get(artist.id);
        if (row == null) {
          await _db.into(_db.followedArtists).insert(FollowedArtistsCompanion.insert(
                ytmId: artist.id,
                name: artist.name,
                thumbUrl: Value(artist.thumbnailUrl),
                followedAt: Value(_now()),
              ));
          return;
        }
        await (_db.update(_db.followedArtists)..where((a) => a.ytmId.equals(artist.id)))
            .write(FollowedArtistsCompanion(
          origin: const Value(kOriginManual),
          excluded: const Value(false),
          name: Value(artist.name),
          thumbUrl: artist.thumbnailUrl == null
              ? const Value.absent()
              : Value(artist.thumbnailUrl),
        ));
      });

  /// Follows [artist] automatically (most listened); never overrides a row
  /// that exists, excluded ones included. Returns whether it was added.
  Future<bool> followAuto(YtmArtistRef artist) async {
    if (await _get(artist.id) != null) return false;
    await _db.into(_db.followedArtists).insert(FollowedArtistsCompanion.insert(
          ytmId: artist.id,
          name: artist.name,
          origin: const Value(kOriginAuto),
          thumbUrl: Value(artist.thumbnailUrl),
          followedAt: Value(_now()),
        ));
    return true;
  }

  /// A followed artist leaves the list (and its releases); an automatic one is
  /// excluded, so it does not come back while it stays among the most listened.
  /// It applies to every profile of the group of [id] (D-402).
  Future<void> unfollow(String id) => _db.transaction(() async {
        for (final member in await ArtistAliasRepository(_db).groupOf(id)) {
          final row = await _get(member);
          if (row == null) continue;
          if (row.isAuto) {
            await (_db.update(_db.followedArtists)..where((a) => a.ytmId.equals(member)))
                .write(const FollowedArtistsCompanion(excluded: Value(true)));
          } else {
            await (_db.delete(_db.followedArtists)..where((a) => a.ytmId.equals(member))).go();
          }
        }
      });

  /// Takes an automatic artist off the list when it left the most listened.
  Future<void> removeAuto(String id) => (_db.delete(_db.followedArtists)
        ..where((a) => a.ytmId.equals(id) & a.origin.equals(kOriginAuto) & a.excluded.equals(false)))
      .go();

  Future<void> setMuted(String id, bool muted) =>
      (_db.update(_db.followedArtists)..where((a) => a.ytmId.equals(id)))
          .write(FollowedArtistsCompanion(muted: Value(muted)));

  /// «Riprova» on an artist marked not found.
  Future<void> retry(String id) =>
      (_db.update(_db.followedArtists)..where((a) => a.ytmId.equals(id))).write(
          const FollowedArtistsCompanion(checksFailed: Value(0), lastError: Value(null)));

  Future<FollowedArtist?> get(String id) => _get(id);

  Future<FollowedArtist?> _get(String id) =>
      (_db.select(_db.followedArtists)..where((a) => a.ytmId.equals(id))).getSingleOrNull();

  /// Whether [id] or any profile merged with it is followed.
  Stream<bool> watchIsFollowed(String id) => _db
      .customSelect(
        'WITH m(id) AS (SELECT COALESCE((SELECT main_id FROM artist_aliases WHERE alias_id = ?1), ?1)) '
        'SELECT 1 FROM followed_artists f, m WHERE f.excluded = 0 AND '
        '(f.ytm_id = m.id OR f.ytm_id IN (SELECT alias_id FROM artist_aliases WHERE main_id = m.id)) LIMIT 1',
        variables: [Variable<String>(id)],
        readsFrom: {_db.followedArtists, _db.artistAliases},
      )
      .watch()
      .map((l) => l.isNotEmpty);

  /// Followed and automatic artists (not the excluded), by name.
  Stream<List<FollowedArtist>> watchFollowed() => (_db.select(_db.followedArtists)
        ..where((a) => a.excluded.equals(false))
        ..orderBy([(a) => OrderingTerm.asc(a.name.collate(Collate.noCase))]))
      .watch();

  /// Names by `UC…` id from what is stored locally: the lookups of most-listened names, then the
  /// followed artists (also the excluded), which win. No request.
  Stream<Map<String, String>> watchNames() => _db
          .customSelect(
            'SELECT ytm_id AS id, ytm_name AS name, 0 AS pri FROM artist_lookups '
            'WHERE ytm_id IS NOT NULL AND ytm_name IS NOT NULL '
            'UNION ALL SELECT ytm_id, name, 1 FROM followed_artists ORDER BY pri',
            readsFrom: {_db.artistLookups, _db.followedArtists},
          )
          .watch()
          .map((rows) => {for (final r in rows) r.read<String>('id'): r.read<String>('name')});

  Future<List<FollowedArtist>> all() => _db.select(_db.followedArtists).get();

  /// Artists to check, the least recently checked first (never checked ones
  /// before any other); not the excluded nor the not found.
  /// The profiles merged with a followed one are checked with it ([checkIds]),
  /// so they have no row of their own; a followed alias whose main is followed
  /// too is left out (the main covers it).
  Future<List<FollowedArtist>> toCheck({int limit = 115}) async {
    final aliases = await ArtistAliasRepository(_db).allAliases();
    final rows = await _toCheck(1 << 30);
    final ids = {for (final r in rows) r.ytmId};
    return [for (final r in rows) if (!ids.contains(aliases[r.ytmId])) r].take(limit).toList();
  }

  /// The aliases of [id]'s group that joined it after [since] (ms).
  Future<Set<String>> joinedAfter(String id, int since) async {
    final main = await ArtistAliasRepository(_db).mainOf(id);
    return {
      for (final r in await (_db.select(_db.artistAliases)
            ..where((x) => x.mainId.equals(main) & x.createdAt.isBiggerThanValue(since)))
          .get())
        r.aliasId,
    };
  }

  /// Every profile to fetch for the followed row [id]: its whole group.
  Future<List<String>> checkIds(String id) => ArtistAliasRepository(_db).groupOf(id);

  Future<List<FollowedArtist>> _toCheck(int limit) => (_db.select(_db.followedArtists)
        ..where((a) => a.excluded.equals(false) & a.checksFailed.isSmallerThanValue(kMaxNotFound))
        ..orderBy([
          (a) => OrderingTerm.asc(a.lastCheckedAt),
          (a) => OrderingTerm.asc(a.followedAt),
        ])
        ..limit(limit))
      .get();

  /// A check finished. No [error]: all fine. [kArtistNotFound] counts toward
  /// «not found»; any other text is kept as the last error only.
  Future<void> markChecked(String id, {String? error}) async {
    final row = await _get(id);
    if (row == null) return;
    await (_db.update(_db.followedArtists)..where((a) => a.ytmId.equals(id)))
        .write(FollowedArtistsCompanion(
      lastCheckedAt: Value(_now()),
      lastError: Value(error),
      checksFailed: Value(switch (error) {
        null => 0,
        kArtistNotFound => row.checksFailed + 1,
        _ => row.checksFailed,
      }),
    ));
  }

  /// Lookups of most-listened names saved less than [maxAge] ago, by key.
  Future<Map<String, ArtistLookup>> lookups({Duration maxAge = const Duration(days: 30)}) async {
    final since = _now() - maxAge.inMilliseconds;
    return {
      for (final l in await (_db.select(_db.artistLookups)
            ..where((l) => l.checkedAt.isBiggerOrEqualValue(since)))
          .get())
        l.artistKey: l,
    };
  }

  /// Most listened names that matched more than one artist, saved less than
  /// [maxAge] ago: the user still has to pick one («Da confermare»).
  Future<List<ArtistLookup>> pendingLookups({Duration maxAge = const Duration(days: 30)}) async {
    final all = await lookups(maxAge: maxAge);
    return [for (final l in all.values) if (l.status == 2) l]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Remembers what YouTube Music answered for [key]: [artist] when one exact
  /// artist, null with [ambiguous] false for nobody.
  Future<void> saveLookup(String key, String name,
      {YtmArtistRef? artist, bool ambiguous = false}) =>
      _db.into(_db.artistLookups).insertOnConflictUpdate(ArtistLookupsCompanion.insert(
        artistKey: key,
        name: name,
        status: artist != null ? 0 : (ambiguous ? 2 : 1),
        ytmId: Value(artist?.id),
        ytmName: Value(artist?.name),
        thumbUrl: Value(artist?.thumbnailUrl),
        checkedAt: _now(),
      ));
}

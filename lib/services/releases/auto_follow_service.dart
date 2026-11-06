import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show FollowedArtist, ArtistLookup;
import '../../data/repositories/artist_alias_repository.dart' show ArtistAliasRepository;
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/stats_queries.dart';
import '../online/youtube_service.dart';
import '../online/ytm_artist.dart';
import '../online/ytm_artist_resolver.dart';
import 'auto_follow.dart';

/// Looks for artists on YouTube Music by name.
typedef ArtistSearch = Future<List<YtmArtistRef>> Function(String name);

/// Keeps the automatic follows equal to the most listened artists of the last
/// 90 days: at most [maxLookups] searches a round, [gap] apart, each answer
/// remembered 30 days.
class AutoFollowService {
  AutoFollowService({
    required this.stats,
    required this.follows,
    required this.search,
    this.aliases,
    DateTime Function()? now,
    this.gap = const Duration(milliseconds: 1500),
    this.maxLookups = 5,
    this.wait = _delay,
  }) : _now = now ?? DateTime.now;

  final StatsQueries stats;
  final FollowRepository follows;
  final ArtistSearch search;

  /// Merged artists: a group's main profile counts as the one match.
  final ArtistAliasRepository? aliases;
  final DateTime Function() _now;
  final Duration gap;
  final int maxLookups;
  final Future<void> Function(Duration) wait;

  static Future<void> _delay(Duration d) => Future<void>.delayed(d);

  /// One round: looks names up, then follows and unfollows. Returns the plan
  /// applied (its [AutoFollowPlan.toConfirm] is what the user still has to settle).
  Future<AutoFollowPlan> run() async {
    final now = _now();
    final top = await stats.topArtistsSince(
        now.subtract(const Duration(days: 90)), limit: kAutoFollowCount);
    if (top.isEmpty) return const AutoFollowPlan();
    final names = {for (final t in top) t.key: t.name};
    final lookups = await follows.lookups();

    var plan = _plan(top, await follows.all(), lookups);
    var asked = 0;
    for (final key in plan.toResolve) {
      if (asked >= maxLookups) break;
      if (asked > 0) await wait(gap);
      asked++;
      try {
        final found = await search(names[key]!);
        switch (await pickYtmArtistWithAliases(aliases, names[key]!, found)) {
          case ExactArtist(:final artist):
            await follows.saveLookup(key, names[key]!, artist: artist);
          case ChooseArtist():
            await follows.saveLookup(key, names[key]!, ambiguous: true);
          case NoArtist():
            await follows.saveLookup(key, names[key]!);
        }
      } on YtException catch (e) {
        // Offline or paused by YouTube: the rest waits for the next round.
        AppLog.w('auto-follow lookup stopped: $e');
        break;
      }
    }
    if (asked > 0) {
      plan = _plan(top, await follows.all(), await follows.lookups());
    }
    for (final a in plan.toAdd) {
      await follows.followAuto(a);
    }
    for (final id in plan.toRemove) {
      await follows.removeAuto(id);
    }
    return plan;
  }

  AutoFollowPlan _plan(List<ListenedArtist> top, List<FollowedArtist> rows,
      Map<String, ArtistLookup> lookups) {
    return planAutoFollow(
      top: [for (final t in top) (key: t.key, name: t.name)],
      followedIds: {for (final r in rows) if (!r.excluded) r.ytmId},
      autoIds: {for (final r in rows) if (r.isAuto && !r.excluded) r.ytmId},
      excludedIds: {for (final r in rows) if (r.excluded) r.ytmId},
      resolved: {
        for (final l in lookups.values) l.artistKey: _resolution(l),
      },
    );
  }

  AutoResolution _resolution(ArtistLookup l) => switch (l.status) {
        0 when l.ytmId != null => ResolvedArtist(YtmArtistRef(
            id: l.ytmId!, name: l.ytmName ?? l.name, thumbnailUrl: l.thumbUrl)),
        2 => const Ambiguous(),
        _ => const NoMatch(),
      };
}


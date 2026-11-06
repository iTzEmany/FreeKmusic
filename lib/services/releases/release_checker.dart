import '../../core/app_log.dart';
import '../../data/db/app_database.dart' show FollowedArtist;
import '../../data/repositories/follow_repository.dart';
import '../../data/repositories/release_repository.dart';
import '../online/innertube_client.dart' show ArtistNotFound, InnerTubeChanged;
import '../online/youtube_service.dart' show YtErrorKind, YtException;
import '../online/ytm_artist.dart';
import 'release_diff.dart';

/// Reads the releases page of an artist (`YtmCatalog.releases`).
typedef ReleasesFetch = Future<YtmArtistPage> Function(String artistId);

/// Why a round stopped before the last artist.
enum CheckStop { rateLimited, offline, changed, cancelled }

/// A new release with the artist it belongs to.
class FreshRelease {
  const FreshRelease(this.artist, this.release);

  final FollowedArtist artist;
  final NewRelease release;
}

class CheckOutcome {
  const CheckOutcome({
    this.fresh = const [],
    this.checked = 0,
    this.failed = 0,
    this.stoppedBy,
    this.retryAt,
  });

  final List<FreshRelease> fresh;
  final int checked, failed;
  final CheckStop? stoppedBy;

  /// Set after a 429: the earliest time for another round.
  final DateTime? retryAt;
}

/// Lets the caller stop a round (network gone, option switched off).
class CheckCancel {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}

/// One round of checks: the artists to check, one at a time, [gap] apart.
/// The first check of an artist stores everything as seen.
class ReleaseChecker {
  ReleaseChecker(
    this.fetch,
    this.follows,
    this.releases, {
    DateTime Function()? now,
    this.gap = const Duration(milliseconds: 1500),
    this.pause = const Duration(hours: 6),
    this.limit = 115,
    Future<void> Function(Duration)? wait,
  })  : _now = now ?? DateTime.now,
        _wait = wait ?? ((d) => Future<void>.delayed(d));

  final ReleasesFetch fetch;
  final FollowRepository follows;
  final ReleaseRepository releases;
  final Duration gap, pause;
  final int limit;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _wait;

  /// With [only] just that artist is checked (the first check after «Segui»).
  Future<CheckOutcome> run({CheckCancel? cancel, String? only}) async {
    final List<FollowedArtist> artists;
    if (only == null) {
      artists = await follows.toCheck(limit: limit);
    } else {
      final a = await follows.get(only);
      artists = [if (a != null && !a.excluded && !a.notFound) a];
    }
    final fresh = <FreshRelease>[];
    var checked = 0, failed = 0;
    CheckOutcome stop(CheckStop why, {DateTime? retryAt}) => CheckOutcome(
        fresh: fresh, checked: checked, failed: failed, stoppedBy: why, retryAt: retryAt);

    for (var i = 0; i < artists.length; i++) {
      final artist = artists[i];
      if (i > 0) await _wait(gap);
      if (cancel?.isCancelled ?? false) return stop(CheckStop.cancelled);
      try {
        // The merged profiles' releases are stored under the followed row.
        final shelves = <YtmReleaseShelf>[], late = <YtmReleaseShelf>[];
        final first = artist.lastCheckedAt == null;
        final joined = first ? const <String>{} : await follows.joinedAfter(artist.ytmId, artist.lastCheckedAt!);
        for (final id in await follows.checkIds(artist.ytmId)) {
          if (id != artist.ytmId) await _wait(gap);
          final page = id == artist.ytmId ? await fetch(id) : await _fetchAlias(id);
          (joined.contains(id) ? late : shelves).addAll(page?.shelves.whereType<YtmReleaseShelf>() ?? const []);
        }
        final diff = diffReleases(
          known: first ? const {} : await releases.knownIds(artist.ytmId),
          knownGroups: first ? const {} : await releases.knownGroups(artist.ytmId),
          fetched: shelves,
          firstCheck: first,
          now: _now(),
        );
        await releases.store(artist.ytmId, diff);
        fresh.addAll([for (final n in diff.fresh) FreshRelease(artist, n)]);
        // A profile merged since the last check: its whole discography is the base, not news.
        if (late.isNotEmpty) {
          await releases.store(
              artist.ytmId, diffReleases(known: const {}, fetched: late, firstCheck: true, now: _now()));
        }
        await follows.markChecked(artist.ytmId);
        checked++;
      } on ArtistNotFound {
        await follows.markChecked(artist.ytmId, error: kArtistNotFound);
        failed++;
      } on YtException catch (e) {
        switch (e.kind) {
          case YtErrorKind.rateLimited:
            AppLog.w('release check paused by YouTube (429)');
            return stop(CheckStop.rateLimited, retryAt: _now().add(pause));
          case YtErrorKind.network:
            return stop(CheckStop.offline);
          default:
            AppLog.w('release check of ${artist.name} failed: $e');
            await follows.markChecked(artist.ytmId, error: e.kind.name);
            failed++;
        }
      } on InnerTubeChanged catch (e) {
        AppLog.w('release check stopped, page not readable: $e');
        return stop(CheckStop.changed);
      }
    }
    return CheckOutcome(fresh: fresh, checked: checked, failed: failed);
  }

  /// An alias page YouTube does not find is skipped: the main profile's check goes on.
  Future<YtmArtistPage?> _fetchAlias(String id) async {
    try {
      return await fetch(id);
    } on ArtistNotFound {
      AppLog.w('release check: merged profile $id not found');
      return null;
    }
  }
}

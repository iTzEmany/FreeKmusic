import 'package:drift/drift.dart';

import '../../services/podcast/podcast_models.dart';
import '../db/app_database.dart';

/// A podcast with what the list shows next to it.
class PodcastSummary {
  const PodcastSummary(this.podcast, this.episodeCount, this.toListen);

  final Podcast podcast;
  final int episodeCount;

  /// Downloaded episodes not played yet.
  final int toListen;
}

/// An episode and, when it is downloaded, its track (with the bookmark).
class EpisodeRow {
  const EpisodeRow(this.episode, this.track);

  final PodcastEpisode episode;
  final Track? track;

  bool get downloaded => track != null;
}

/// Subscriptions and their episodes. Downloaded episodes also live in
/// `tracks` (kind 1); this class never touches music.
class PodcastRepository {
  PodcastRepository(this._db);

  final AppDatabase _db;

  /// Saves a podcast (or refreshes the one with the same address) and its
  /// episodes. Returns the podcast's id. [source] and [sourceId] say where it
  /// comes from (see [Podcasts.source]); a podcast already there keeps its own. [followed] false saves it for listening only.
  Future<int> subscribe(String feedUrl, PodcastFeed feed,
      {required int now, int source = 0, String? sourceId, bool followed = true}) {
    return _db.transaction(() async {
      final existing = await (_db.select(_db.podcasts)
            ..where((p) => p.feedUrl.equals(feedUrl)))
          .getSingleOrNull();
      final int id;
      if (existing == null) {
        id = await _db.into(_db.podcasts).insert(PodcastsCompanion.insert(
              feedUrl: feedUrl,
              title: feed.title,
              author: Value(feed.author),
              imageUrl: Value(feed.imageUrl),
              language: Value(feed.language),
              addedAt: now,
              lastCheckedAt: Value(now),
              source: Value(source),
              sourceId: Value(sourceId),
              followed: Value(followed),
            ));
      } else {
        id = existing.id;
        await (_db.update(_db.podcasts)..where((p) => p.id.equals(id))).write(
          PodcastsCompanion(
            title: Value(feed.title),
            author: Value(feed.author),
            imageUrl: Value(feed.imageUrl),
            language: Value(feed.language),
            lastCheckedAt: Value(now),
            // Saving without following never unfollows or follows an existing podcast.
            followed: followed ? const Value(true) : const Value.absent(),
          ),
        );
      }
      await upsertEpisodes(id, feed.episodes);
      return id;
    });
  }

  /// Adds the episodes the podcast does not have yet (by `guid`) and brings the
  /// listed details of the others up to date. `played` and the download are
  /// never touched. Returns how many are new.
  Future<int> upsertEpisodes(int podcastId, List<PodcastEpisodeInfo> list) {
    return _db.transaction(() async {
      final have = {
        for (final e in await (_db.select(_db.podcastEpisodes)
              ..where((e) => e.podcastId.equals(podcastId)))
            .get())
          e.guid: e,
      };
      final fresh = <PodcastEpisodesCompanion>[];
      final seen = <String>{};
      for (final info in list) {
        if (!seen.add(info.guid)) continue; // a feed that repeats an item
        final old = have[info.guid];
        if (old == null) {
          fresh.add(PodcastEpisodesCompanion.insert(
            podcastId: podcastId,
            guid: info.guid,
            title: info.title,
            audioUrl: info.audioUrl,
            publishedAt: Value(info.publishedAt?.millisecondsSinceEpoch),
            durationMs: Value(info.duration?.inMilliseconds),
            mimeType: Value(info.mimeType),
            sizeBytes: Value(info.sizeBytes),
            description: Value(info.description),
          ));
        } else if (_changed(old, info)) {
          await (_db.update(_db.podcastEpisodes)
                ..where((e) => e.id.equals(old.id)))
              .write(PodcastEpisodesCompanion(
            title: Value(info.title),
            audioUrl: Value(info.audioUrl),
            publishedAt: Value(info.publishedAt?.millisecondsSinceEpoch),
            durationMs: Value(info.duration?.inMilliseconds),
            mimeType: Value(info.mimeType),
            sizeBytes: Value(info.sizeBytes),
            description: Value(info.description),
          ));
        }
      }
      if (fresh.isNotEmpty) {
        await _db.batch((b) => b.insertAll(_db.podcastEpisodes, fresh));
      }
      return fresh.length;
    });
  }

  /// The `guid` of every episode the podcast has.
  Future<Set<String>> episodeGuids(int podcastId) async => {
        for (final e in await (_db.select(_db.podcastEpisodes)..where((e) => e.podcastId.equals(podcastId))).get())
          e.guid,
      };

  bool _changed(PodcastEpisode e, PodcastEpisodeInfo i) =>
      e.title != i.title ||
      e.audioUrl != i.audioUrl ||
      e.publishedAt != i.publishedAt?.millisecondsSinceEpoch ||
      e.durationMs != i.duration?.inMilliseconds ||
      e.mimeType != i.mimeType ||
      e.sizeBytes != i.sizeBytes ||
      e.description != i.description;

  /// Removes the podcast, its episodes and the library rows of the ones that
  /// were downloaded. Returns those episodes' file paths: the caller deletes
  /// them (and only from the app's own folder).
  Future<List<String>> unsubscribe(int podcastId) {
    return _db.transaction(() async {
      final trackIds = [
        for (final e in await (_db.select(_db.podcastEpisodes)
              ..where((e) => e.podcastId.equals(podcastId)))
            .get())
          if (e.trackId != null) e.trackId!,
      ];
      final paths = <String>[];
      if (trackIds.isNotEmpty) {
        final rows = await (_db.select(_db.tracks)
              ..where((t) => t.id.isIn(trackIds) & t.kind.equals(1)))
            .get();
        paths.addAll(rows.map((t) => t.path));
        await (_db.delete(_db.tracks)
              ..where((t) => t.id.isIn(trackIds) & t.kind.equals(1)))
            .go();
      }
      await (_db.delete(_db.podcasts)..where((p) => p.id.equals(podcastId))).go();
      return paths;
    });
  }

  /// Podcast tracks (kind 1) that no episode points to.
  Future<List<Track>> orphanEpisodeTracks() async {
    final linked = {
      for (final e in await _db.select(_db.podcastEpisodes).get())
        if (e.trackId != null) e.trackId!,
    };
    final rows = await (_db.select(_db.tracks)..where((t) => t.kind.equals(1))).get();
    return [for (final t in rows) if (!linked.contains(t.id)) t];
  }

  Future<Podcast?> byId(int id) =>
      (_db.select(_db.podcasts)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<Podcast?> byFeedUrl(String feedUrl) =>
      (_db.select(_db.podcasts)..where((p) => p.feedUrl.equals(feedUrl))).getSingleOrNull();

  Stream<Podcast?> watchById(int id) =>
      (_db.select(_db.podcasts)..where((p) => p.id.equals(id)))
          .watchSingleOrNull();

  Future<List<Podcast>> all() =>
      (_db.select(_db.podcasts)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();

  /// Only the subscribed podcasts: the ones the app refreshes on its own.
  Future<List<Podcast>> allFollowed() => (_db.select(_db.podcasts)
        ..where((p) => p.followed.equals(true))
        ..orderBy([(p) => OrderingTerm.asc(p.id)]))
      .get();

  Future<void> setFollowed(int podcastId, bool followed) =>
      (_db.update(_db.podcasts)..where((p) => p.id.equals(podcastId)))
          .write(PodcastsCompanion(followed: Value(followed)));

  Stream<List<PodcastSummary>> watchPodcasts() {
    return _db
        .customSelect(
          'SELECT p.*, '
          '(SELECT COUNT(*) FROM podcast_episodes e WHERE e.podcast_id = p.id) '
          'AS episode_count, '
          '(SELECT COUNT(*) FROM podcast_episodes e WHERE e.podcast_id = p.id '
          'AND e.track_id IS NOT NULL AND e.played = 0) AS to_listen '
          'FROM podcasts p WHERE p.followed = 1 ORDER BY lower(p.title), p.id',
          readsFrom: {_db.podcasts, _db.podcastEpisodes},
        )
        .watch()
        .map((rows) => [
              for (final r in rows)
                PodcastSummary(
                  _db.podcasts.map(r.data),
                  r.read<int>('episode_count'),
                  r.read<int>('to_listen'),
                ),
            ]);
  }

  /// Newest first (episodes without a date after the dated ones).
  Stream<List<EpisodeRow>> watchEpisodes(int podcastId) {
    final q = _db.select(_db.podcastEpisodes).join([
      leftOuterJoin(
          _db.tracks, _db.tracks.id.equalsExp(_db.podcastEpisodes.trackId)),
    ])
      ..where(_db.podcastEpisodes.podcastId.equals(podcastId))
      ..orderBy([
        OrderingTerm(
            expression: _db.podcastEpisodes.publishedAt,
            mode: OrderingMode.desc,
            nulls: NullsOrder.last),
        OrderingTerm.desc(_db.podcastEpisodes.id),
      ]);
    return q.watch().map((rows) => [
          for (final r in rows)
            EpisodeRow(r.readTable(_db.podcastEpisodes), r.readTableOrNull(_db.tracks)),
        ]);
  }

  Future<PodcastEpisode?> episodeById(int id) => (_db.select(_db.podcastEpisodes)
        ..where((e) => e.id.equals(id)))
      .getSingleOrNull();

  Future<void> markPlayed(int episodeId, bool played, {required int now}) =>
      (_db.update(_db.podcastEpisodes)..where((e) => e.id.equals(episodeId)))
          .write(PodcastEpisodesCompanion(
        played: Value(played),
        playedAt: Value(played ? now : null),
      ));

  /// For the player: marks the episode that this track is.
  Future<void> markPlayedByTrack(int trackId, bool played, {required int now}) =>
      (_db.update(_db.podcastEpisodes)..where((e) => e.trackId.equals(trackId)))
          .write(PodcastEpisodesCompanion(
        played: Value(played),
        playedAt: Value(played ? now : null),
      ));

  /// Links an episode to its downloaded track (null = no longer downloaded).
  Future<void> setTrackId(int episodeId, int? trackId) =>
      (_db.update(_db.podcastEpisodes)..where((e) => e.id.equals(episodeId)))
          .write(PodcastEpisodesCompanion(trackId: Value(trackId)));

  /// Every episode that has a downloaded track, with that track.
  Future<List<EpisodeRow>> downloadedEpisodes({int? podcastId}) async {
    final q = _db.select(_db.podcastEpisodes).join([
      innerJoin(_db.tracks, _db.tracks.id.equalsExp(_db.podcastEpisodes.trackId)),
    ]);
    if (podcastId != null) {
      q.where(_db.podcastEpisodes.podcastId.equals(podcastId));
    }
    return [
      for (final r in await q.get())
        EpisodeRow(r.readTable(_db.podcastEpisodes), r.readTable(_db.tracks)),
    ];
  }

  Future<void> setAutoDeleteDays(int podcastId, int? days) =>
      (_db.update(_db.podcasts)..where((p) => p.id.equals(podcastId)))
          .write(PodcastsCompanion(autoDeleteDays: Value(days)));

  Future<void> markChecked(int podcastId, int now) =>
      (_db.update(_db.podcasts)..where((p) => p.id.equals(podcastId)))
          .write(PodcastsCompanion(lastCheckedAt: Value(now)));

  Future<void> setCoverKey(int podcastId, String? key) =>
      (_db.update(_db.podcasts)..where((p) => p.id.equals(podcastId)))
          .write(PodcastsCompanion(coverKey: Value(key)));
}

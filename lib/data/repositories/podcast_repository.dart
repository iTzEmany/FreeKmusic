import 'package:drift/drift.dart';

import '../../services/podcast/podcast_models.dart';
import '../../services/stream/stream_key.dart';
import '../db/app_database.dart';
import 'track_kinds.dart';

/// A podcast with what the list shows next to it.
class PodcastSummary {
  const PodcastSummary(this.podcast, this.episodeCount, this.toListen);

  final Podcast podcast;
  final int episodeCount;

  /// Downloaded episodes not played yet.
  final int toListen;
}

/// An episode and its track (with the bookmark): a file when downloaded, else a
/// streaming row made the first time it was played.
class EpisodeRow {
  const EpisodeRow(this.episode, this.track);

  final PodcastEpisode episode;
  final Track? track;

  bool get downloaded => track != null && !isRemoteEpisodePath(track!.path);
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
          if (old.trackId != null && old.audioUrl != info.audioUrl) {
            await _followAddress(old.id, old.trackId!, info.audioUrl);
          }
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
        // A streaming row has an address, not a file: nothing to delete.
        paths.addAll(rows.map((t) => t.path).where((p) => !isRemoteEpisodePath(p)));
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

  /// The saved podcast of [feedUrl], followed or not, as it changes.
  Stream<Podcast?> watchByFeedUrl(String feedUrl) =>
      (_db.select(_db.podcasts)..where((p) => p.feedUrl.equals(feedUrl))).watchSingleOrNull();

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
          'AND e.played = 0 AND EXISTS (SELECT 1 FROM tracks t WHERE t.id = e.track_id '
          "AND t.path NOT LIKE 'http%' AND t.path NOT LIKE 'stream:%')) AS to_listen "
          'FROM podcasts p WHERE p.followed = 1 ORDER BY lower(p.title), p.id',
          readsFrom: {_db.podcasts, _db.podcastEpisodes, _db.tracks},
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

  /// Every episode that has a downloaded track (a file, not a streaming row), with that track.
  Future<List<EpisodeRow>> downloadedEpisodes({int? podcastId}) async {
    final q = _db.select(_db.podcastEpisodes).join([
      innerJoin(
        _db.tracks,
        _db.tracks.id.equalsExp(_db.podcastEpisodes.trackId) &
            _db.tracks.path.like('http%').not() &
            _db.tracks.path.like('stream:%').not(),
      ),
    ]);
    if (podcastId != null) {
      q.where(_db.podcastEpisodes.podcastId.equals(podcastId));
    }
    return [
      for (final r in await q.get())
        EpisodeRow(r.readTable(_db.podcastEpisodes), r.readTable(_db.tracks)),
    ];
  }

  Future<PodcastEpisode?> episodeByGuid(int podcastId, String guid) =>
      (_db.select(_db.podcastEpisodes)..where((e) => e.podcastId.equals(podcastId) & e.guid.equals(guid)))
          .getSingleOrNull();

  /// Runs [body] as one transaction (a download and a first play must not interleave).
  Future<T> atomically<T>(Future<T> Function() body) => _db.transaction(body);

  /// Where a not downloaded episode streams from: the audio address, or the stream key of
  /// a YouTube Music one; null when there is none (not an http(s) address).
  String? remotePathOf(Podcast podcast, PodcastEpisode e) {
    if (podcast.source == kPodcastSourceYtm) return streamPathOf('youtube:${e.guid}');
    return isHttpAddress(e.audioUrl) ? e.audioUrl : null;
  }

  Future<Track?> _trackByPath(String path) =>
      (_db.select(_db.tracks)..where((t) => t.path.equals(path))).getSingleOrNull();

  Future<Track?> _trackById(int id) =>
      (_db.select(_db.tracks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The path (and the row on it, if any) a streaming row of [episodeId] can have: [base], or when
  /// another episode has the row on it (two episodes, one address) its own `#cc-ep=<id>` variant.
  /// The player drops the fragment, so the server never sees it.
  Future<({String path, Track? row})> _slot(String base, int episodeId) async {
    final row = await _trackByPath(base);
    if (row == null) return (path: base, row: null);
    final others = await (_db.select(_db.podcastEpisodes)
          ..where((e) => e.trackId.equals(row.id) & e.id.isNotValue(episodeId)))
        .get();
    if (others.isEmpty) return (path: base, row: row);
    final own = '$base#cc-ep=$episodeId';
    return (path: own, row: await _trackByPath(own));
  }

  /// The track the episode plays from: its file when downloaded, else a kind-1 row
  /// with a remote path, made on first play and kept so the bookmark has a place
  /// (and the episode shows in «Riprendi»). Null when there is nothing to stream from.
  Future<Track?> playableTrack(int episodeId) {
    return _db.transaction(() async {
      final e = await episodeById(episodeId);
      final podcast = e == null ? null : await byId(e.podcastId);
      if (e == null || podcast == null) return null;
      final linked = e.trackId == null ? null : await _trackById(e.trackId!);
      if (linked != null) return linked;
      final base = remotePathOf(podcast, e);
      if (base == null) return null;
      final slot = await _slot(base, episodeId);
      var row = slot.row;
      final albumKey = podcastAlbumKeyOf(podcast.id);
      if (row == null) {
        final id = await _db.into(_db.tracks).insert(TracksCompanion.insert(
              path: slot.path,
              title: e.title,
              albumKey: albumKey,
              format: episodeExtension(url: e.audioUrl, mime: e.mimeType) ??
                  (podcast.source == kPodcastSourceYtm ? 'm4a' : 'mp3'),
              sizeBytes: 0,
              mtimeMs: 0,
              addedAt: DateTime.now().millisecondsSinceEpoch,
              artist: Value(podcast.title),
              albumArtist: Value(podcast.title),
              album: Value(podcast.title),
              genre: const Value('Podcast'),
              durationMs: Value(e.durationMs ?? 0),
              hasCover: Value(podcast.coverKey != null),
              coverKey: Value(podcast.coverKey),
              kind: const Value(kEpisodeKind),
            ));
        row = await _trackById(id);
      } else if (row.kind == kStreamKind) {
        // The shadow row of the same video (a stream played from Search): it becomes the episode's.
        await (_db.update(_db.tracks)..where((t) => t.id.equals(row!.id))).write(TracksCompanion(
          kind: const Value(kEpisodeKind),
          albumKey: Value(albumKey),
          title: Value(e.title),
          artist: Value(podcast.title),
          albumArtist: Value(podcast.title),
          album: Value(podcast.title),
          genre: const Value('Podcast'),
          hasCover: Value(podcast.coverKey != null),
          coverKey: Value(podcast.coverKey),
        ));
        row = await _trackById(row.id);
      }
      await setTrackId(episodeId, row!.id);
      return row;
    });
  }

  /// A feed that moved the audio of [episodeId]: its streaming row (an address, not a file or
  /// a stream key) follows, when the new address is free.
  Future<void> _followAddress(int episodeId, int trackId, String url) async {
    final row = await _trackById(trackId);
    if (row == null || row.kind != kEpisodeKind) return;
    if (!isHttpAddress(row.path)) return;
    final slot = await _slot(url, episodeId);
    if (slot.row != null || slot.path == row.path) return;
    await (_db.update(_db.tracks)..where((t) => t.id.equals(trackId)))
        .write(TracksCompanion(path: Value(slot.path)));
  }

  /// A downloaded episode whose file goes (the download is deleted) streams again: its row keeps
  /// the bookmark and the plays and goes back to the address. False when it has none to go to
  /// (or it is taken): the caller then drops the row.
  Future<bool> backToRemote(int episodeId) {
    return _db.transaction(() async {
      final e = await episodeById(episodeId);
      final podcast = e == null ? null : await byId(e.podcastId);
      final row = e?.trackId == null ? null : await _trackById(e!.trackId!);
      final base = podcast == null || e == null ? null : remotePathOf(podcast, e);
      if (row == null || row.kind != kEpisodeKind || base == null) return false;
      final slot = await _slot(base, episodeId);
      if (slot.row != null && slot.row!.id != row.id) return false;
      await (_db.update(_db.tracks)..where((t) => t.id.equals(row.id))).write(
          TracksCompanion(path: Value(slot.path), sizeBytes: const Value(0), mtimeMs: const Value(0), missing: const Value(false)));
      return true;
    });
  }

  /// A downloaded file takes the place of the streaming row [trackId] (same row, same bookmark).
  Future<void> attachFile(int trackId, TracksCompanion file) =>
      (_db.update(_db.tracks)..where((t) => t.id.equals(trackId))).write(file);

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

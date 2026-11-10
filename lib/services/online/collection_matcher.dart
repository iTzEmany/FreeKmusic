import 'dart:async';
import 'dart:io' show Directory;

import 'package:dio/dio.dart' show CancelToken;

import '../../core/app_log.dart';
import '../../core/import_row.dart';
import '../../data/db/app_database.dart' show Track;
import '../import/row_search.dart';
import '../import/track_matcher.dart';
import 'budgeted_call.dart';
import 'external_collection.dart';
import 'query_match.dart' show MediaKind;
import 'request_budget.dart';
import 'source_cooldown.dart';
import 'youtube_service.dart';

/// Resolves the songs of an [ExternalCollection] one at a time, in page order:
/// the library first (no network), then YouTube Music with the Exportify rules
/// ([searchRow]). Every YouTube Music request goes through [budgetedYtm] with
/// the link-match [limiter]; a 429 pauses the shared [cooldown] and the matcher
/// waits for its end (R-194..R-196, D-525, D-526).
class CollectionMatcher {
  CollectionMatcher({
    required YoutubeService youtube,
    required this.cooldown,
    required this.limiter,
    required this.library,
    required this.trackById,
    required this.thresholds,
    this.gap = const Duration(milliseconds: 1500),
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed {
    _youtube = _BudgetedYoutube(youtube, this);
  }

  final SourceCooldown cooldown;
  final WindowLimiter limiter;
  final LibraryIndex? Function() library;
  final Future<Track?> Function(int id) trackById;
  final MatchThresholds Function() thresholds;
  final Duration gap;
  final Future<void> Function(Duration) _wait;
  late final YoutubeService _youtube;
  bool _cancelled = false;

  /// Stops the matching: no further request is made, the stream ends.
  void cancel() => _cancelled = true;

  Stream<(int, TrackMatch)> match(List<ExternalTrack> tracks) async* {
    for (var i = 0; i < tracks.length && !_cancelled; i++) {
      try {
        final result = await _one(tracks[i].toImportRow(i));
        if (_cancelled) return;
        yield (i, result);
      } on _Cancelled {
        return;
      } on Object catch (e, st) {
        // The page was closed while the search ran: the Ref may be gone too.
        if (_cancelled) return;
        AppLog.e('link match failed for ${tracks[i].title}', e, st);
        // Offline or no yt-dlp: not final, a reopened page asks again.
        final transient = e is YtException &&
            (e.kind == YtErrorKind.network || e.kind == YtErrorKind.toolMissing);
        yield (i, TrackNotFound(transient: transient));
      }
    }
  }

  Future<TrackMatch> _one(ImportRow row) async {
    final hit = library()?.find(row);
    if (hit != null) {
      final t = await trackById(hit.id);
      if (t != null) return TrackReady.library(t);
    }
    final d = await searchRow(row, _youtube, thresholds: thresholds, gap: gap);
    final best = d.kind == MatchKind.notFound ? null : d.best;
    return best == null ? const TrackNotFound() : TrackReady.online(best.result);
  }

  /// [run] under the budget: waits (pause end, or a free slot) and retries when
  /// there is no budget or YouTube answers 429.
  Future<T> _budgeted<T>(Future<T> Function() run) async {
    while (true) {
      if (_cancelled) throw const _Cancelled();
      final call = budgetedYtm(cooldown, limiter, run);
      if (call == null) {
        await _wait(_pauseLeft());
        continue;
      }
      try {
        return await call;
      } on YtException catch (e) {
        if (e.kind != YtErrorKind.rateLimited) rethrow;
        // budgetedYtm tripped the shared pause; the loop waits for its end.
      }
    }
  }

  Duration _pauseLeft() {
    if (cooldown.isPaused(MediaKind.ytmSong)) return const Duration(seconds: 1);
    final free = limiter.untilFree;
    return free > Duration.zero ? free : const Duration(milliseconds: 50);
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Sends the YouTube Music searches of [searchRow] through the matcher's budget.
class _BudgetedYoutube implements YoutubeService {
  _BudgetedYoutube(this._inner, this._m);
  final YoutubeService _inner;
  final CollectionMatcher _m;

  @override
  Future<List<YtResult>> search(String query) =>
      _m._budgeted(() => _inner.search(query));

  @override
  Future<List<YtResult>> searchSongs(String query, {int limit = 5}) =>
      _m._budgeted(() => _inner.searchSongs(query, limit: limit));

  @override
  Future<List<YtResult>> searchAlbums(String query, {int limit = 3}) =>
      _m._budgeted(() => _inner.searchAlbums(query, limit: limit));

  @override
  Future<List<YtResult>> albumTracks(String albumLink) =>
      _m._budgeted(() => _inner.albumTracks(albumLink));

  @override
  Future<PlaylistListing> listPlaylist(String url, {int limit = 500}) =>
      throw UnsupportedError('not used by the matcher');

  @override
  Stream<DownloadProgress> download(YtResult r, Directory outDir,
          {CancelToken? cancel, DownloadOptions options = const DownloadOptions()}) =>
      throw UnsupportedError('not used by the matcher');

  @override
  Future<String?> toolVersion() => _inner.toolVersion();

  @override
  void close() {}
}

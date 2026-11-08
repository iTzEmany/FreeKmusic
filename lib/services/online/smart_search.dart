import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;

import '../../core/app_log.dart';
import '../import/track_matcher.dart' show matchKey;
import 'budgeted_call.dart';
import 'merge_results.dart';
import 'query_intent.dart';
import 'query_match.dart';
import 'request_budget.dart';
import 'source_cooldown.dart';
import 'youtube_service.dart';
import 'ytm_album_search.dart' show YtmAlbumHit;
import 'ytm_artist.dart';
import 'ytm_catalog.dart';

enum NoticeKind { rateLimited, offline, failed }

/// Why a source gave nothing, for the line above the results.
class SearchNotice {
  const SearchNotice(this.source, this.kind);

  final MediaKind source;
  final NoticeKind kind;

  @override
  bool operator ==(Object other) =>
      other is SearchNotice && other.source == source && other.kind == kind;

  @override
  int get hashCode => Object.hash(source, kind);
}

/// What the page shows at one moment of a search. Rows already shown keep
/// their place in the next state: late answers are merged into their row or
/// added at the end.
class SmartSearchState {
  const SmartSearchState({
    required this.query,
    this.queryKind = QueryKind.text,
    this.listingUrl,
    this.intent = SearchIntent.songs,
    this.intentKnown = true,
    this.card,
    this.best = const [],
    this.others = const [],
    this.noneSure = false,
    this.pending = const {},
    this.notices = const [],
    this.artists = const [],
    this.albums = const [],
    this.error,
  });

  final String query;
  final QueryKind queryKind;

  /// For [QueryKind.listing]: the playlist or channel to list; nothing is searched.
  final String? listingUrl;
  final SearchIntent intent;

  /// [intent] is a real answer (the top card came, or the rows told what the
  /// card could not), not the default of a page still waiting for it.
  final bool intentKnown;
  final TopCard? card;

  /// «Migliori risultati» and «Altri risultati».
  final List<SmartResult> best, others;

  /// Nothing was sure: [best] holds the top few anyway.
  final bool noneSure;

  /// Sources that have not answered yet.
  final Set<MediaKind> pending;
  final List<SearchNotice> notices;

  /// The «Artisti» and «Album» rows (at most [_rowLimit] each). A bonus: empty
  /// when their request failed or the budget was used up, never an error.
  final List<YtmArtistRef> artists;
  final List<YtmAlbumHit> albums;

  /// Every source failed: the first error ([YtException] for the known ones).
  final Object? error;

  bool get loading => pending.isNotEmpty;

  /// «Nella tua libreria» and the duplicate filter (D-399, D-400) apply: text
  /// for a song, and only once the intent is known, so they never come and go.
  bool get showsLibrary =>
      queryKind == QueryKind.text && intentKnown && libraryAppliesTo(intent);

  SmartSearchState copyWith({
    TopCard? card,
    SearchIntent? intent,
    bool? intentKnown,
    List<SmartResult>? best,
    List<SmartResult>? others,
    bool? noneSure,
    Set<MediaKind>? pending,
    List<SearchNotice>? notices,
    List<YtmArtistRef>? artists,
    List<YtmAlbumHit>? albums,
    Object? error,
  }) =>
      SmartSearchState(
        query: query,
        queryKind: queryKind,
        listingUrl: listingUrl,
        intent: intent ?? this.intent,
        intentKnown: intentKnown ?? this.intentKnown,
        card: card ?? this.card,
        best: best ?? this.best,
        others: others ?? this.others,
        noneSure: noneSure ?? this.noneSure,
        pending: pending ?? this.pending,
        notices: notices ?? this.notices,
        artists: artists ?? this.artists,
        albums: albums ?? this.albums,
        error: error ?? this.error,
      );
}

const _resultsPerSource = 10;
const _rowLimit = 10;
const _cacheLife = Duration(minutes: 10);
const _cacheSize = 30;
const _maxBest = 15;

class _Cached {
  _Cached(this.state, this.storedAt, {required this.rowsMissing});

  final SmartSearchState state;
  final DateTime storedAt;

  /// The rows were asked for but not all came (budget used up, or a failure):
  /// [state] holds none, and the next read of the copy asks for them again.
  final bool rowsMissing;
}

/// The online search: YouTube Music songs, YouTube videos and the top card
/// asked together, scored, merged and shown as one stable list. See
/// `docs/fase-32-ricerca-intelligente.md`.
class SmartSearch {
  SmartSearch({
    required this.youtube,
    required this.catalog,
    SourceCooldown? cooldown,
    DateTime Function()? now,
    this.cap = const Duration(milliseconds: 1500),
    this.libraryArtists,
    WindowLimiter? rowsLimiter,
  })  : _now = now ?? DateTime.now,
        cooldown = cooldown ?? SourceCooldown(now: now),
        rowsLimiter = rowsLimiter ?? WindowLimiter(perMinute: kSearchRowsPerMinute, now: now);

  final YoutubeService youtube;
  final YtmCatalog catalog;
  final SourceCooldown cooldown;

  /// The requests of the «Artisti» and «Album» rows; none left, no rows.
  final WindowLimiter rowsLimiter;

  /// [libraryArtistKey] of the artists in the library, read at each search: a
  /// phrase with no artist favours their results.
  final Set<String> Function()? libraryArtists;

  /// How long after the first answer the page waits for the others.
  final Duration cap;
  final DateTime Function() _now;
  final _cache = <String, _Cached>{};

  /// States of the search for [query]: first the waiting one, then the first
  /// block (when both sources answered, or [cap] after the first), then one
  /// per late answer. Cancelling the subscription drops what is still coming.
  /// [refresh] skips the saved copy.
  Stream<SmartSearchState> run(String query, String hl, {bool refresh = false}) {
    late final StreamController<SmartSearchState> out;
    final search = _Run(this, query.trim(), hl, refresh);
    out = StreamController<SmartSearchState>(
      onListen: () => unawaited(search.start(out)),
      onCancel: search.cancel,
    );
    return out.stream;
  }

  _Cached? _fromCache(String key) {
    final hit = _cache[key];
    if (hit == null) return null;
    if (_now().difference(hit.storedAt) >= _cacheLife) {
      _cache.remove(key);
      return null;
    }
    return hit;
  }

  void _store(String key, SmartSearchState state,
      {bool rowsMissing = false, DateTime? storedAt}) {
    _cache.remove(key);
    _cache[key] = _Cached(state, storedAt ?? _now(), rowsMissing: rowsMissing);
    while (_cache.length > _cacheSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class _Answer<T> {
  _Answer.ok(this.value) : error = null;
  _Answer.failed(this.error) : value = null;

  final T? value;
  final Object? error;
}

/// One search in progress.
class _Run {
  _Run(this.engine, this.query, this.hl, this.refresh);

  final SmartSearch engine;
  final String query, hl;
  final bool refresh;
  final _token = CancelToken();
  late StreamController<SmartSearchState> _out;
  bool _cancelled = false;

  _Answer<List<YtResult>>? _songs, _videos;
  _Answer<TopCard?>? _card;
  final _asked = <MediaKind>{};
  var _cardAsked = false;
  final _notices = <SearchNotice>[];
  var _artists = const <YtmArtistRef>[];
  var _albums = const <YtmAlbumHit>[];
  var _rowsOpen = 0;
  var _rowsFailed = false;
  SmartSearchState? _shown;
  Timer? _capTimer;

  void cancel() {
    _cancelled = true;
    _capTimer?.cancel();
    if (!_token.isCancelled) _token.cancel('new search');
  }

  void _emit(SmartSearchState s) {
    if (_cancelled || _out.isClosed) return;
    _out.add(s);
  }

  Future<void> start(StreamController<SmartSearchState> out) async {
    _out = out;
    try {
      await _run();
    } on Object catch (e, st) {
      AppLog.e('smart search failed', e, st);
      _emit(SmartSearchState(query: query, error: e));
    } finally {
      if (!_out.isClosed) unawaited(_out.close());
    }
  }

  Future<void> _run() async {
    final kind = classifyQuery(query);
    if (query.isEmpty) return;
    if (kind.kind == QueryKind.listing) {
      _emit(SmartSearchState(
          query: query, queryKind: QueryKind.listing, listingUrl: kind.url));
      return;
    }
    final isVideoUrl = kind.kind == QueryKind.video;
    final key = '${matchKey(query)}|$hl';
    if (!refresh) {
      final hit = engine._fromCache(key);
      if (hit != null) {
        _emit(hit.state);
        if (hit.rowsMissing) await _lateRows(key, hit);
        return;
      }
    }

    final cooldown = engine.cooldown;
    for (final source in MediaKind.values) {
      if (isVideoUrl && source == MediaKind.ytmSong) continue;
      if (cooldown.isPaused(source)) {
        _notices.add(SearchNotice(source, NoticeKind.rateLimited));
      } else {
        _asked.add(source);
      }
    }
    if (_asked.isEmpty) {
      _emit(SmartSearchState(
          query: query,
          queryKind: kind.kind,
          notices: _notices,
          error: const YtException(YtErrorKind.rateLimited, 'sources paused')));
      return;
    }
    _cardAsked = !isVideoUrl && _asked.contains(MediaKind.ytmSong);
    _emit(SmartSearchState(
        query: query,
        queryKind: kind.kind,
        intentKnown: false,
        pending: {..._asked},
        notices: [..._notices]));

    final done = Completer<void>(), rowsDone = Completer<void>();
    void settled() {
      if (_cancelled) return;
      _onAnswer(kind.kind);
      if (_everythingIn && !done.isCompleted) done.complete();
    }

    // Rows come after the page: they never delay it (nor its error), they are
    // folded in while the stream stays open.
    void rowIn() {
      if (_cancelled) return;
      if (_shown != null) _showLate();
      if (_rowsOpen == 0 && !rowsDone.isCompleted) rowsDone.complete();
    }

    if (_asked.contains(MediaKind.ytmSong)) {
      unawaited(_ask(() => engine.youtube.searchSongs(query, limit: _resultsPerSource),
              MediaKind.ytmSong)
          .then((a) {
        _songs = a;
        settled();
      }));
    }
    if (_asked.contains(MediaKind.ytVideo)) {
      unawaited(_ask(() async {
        final all = await engine.youtube.search(query);
        return all.take(_resultsPerSource).toList();
      }, MediaKind.ytVideo)
          .then((a) {
        _videos = a;
        settled();
      }));
    }
    if (_cardAsked) {
      unawaited(_askCard().then((a) {
        _card = a;
        settled();
      }));
    }
    // Both rows or none: artists without albums would look like a result.
    if (_cardAsked && engine.rowsLimiter.tryAcquire(2)) {
      _rowsOpen = 2;
      unawaited(_row(() => engine.catalog.searchArtists(query, hl, cancel: _token),
              (v) => _artists = v)
          .then((_) => rowIn()));
      unawaited(_row(() => engine.catalog.searchAlbums(query, hl, cancel: _token),
              (v) => _albums = v)
          .then((_) => rowIn()));
    } else {
      if (_cardAsked) {
        AppLog.d('search rows: request budget used up, rows left out');
        _rowsFailed = true;
      }
      rowsDone.complete();
    }
    await done.future;
    if (_cancelled) return;
    if (!_finish(key)) return;
    await rowsDone.future;
    // The page is already saved; the copy with its rows replaces it unless a
    // row failed (then the page alone stays, and the next read asks again).
    if (!_cancelled && !_rowsFailed) _store(key);
  }

  /// A saved page that has no rows: asked again when the budget allows, the
  /// main requests are not repeated.
  Future<void> _lateRows(String key, _Cached hit) async {
    // The two rows are one budgeted call of cost 2; each row still handles its own failure.
    final rows = budgetedYtm(engine.cooldown, engine.rowsLimiter, () {
      _rowsOpen = 2;
      return Future.wait([
        _row(() => engine.catalog.searchArtists(query, hl, cancel: _token), (v) => _artists = v),
        _row(() => engine.catalog.searchAlbums(query, hl, cancel: _token), (v) => _albums = v),
      ]);
    }, cost: 2);
    if (rows == null) return;
    await rows;
    if (_cancelled) return;
    final state = hit.state.copyWith(artists: _artists, albums: _albums);
    _emit(state);
    if (!_rowsFailed) engine._store(key, state, storedAt: hit.storedAt);
  }

  bool get _everythingIn =>
      (!_asked.contains(MediaKind.ytmSong) || _songs != null) &&
      (!_asked.contains(MediaKind.ytVideo) || _videos != null) &&
      (!_cardAsked || _card != null);

  Future<_Answer<List<YtResult>>> _ask(
      Future<List<YtResult>> Function() call, MediaKind source) async {
    try {
      return _Answer.ok(await call());
    } on Object catch (e) {
      if (_cancelled) return _Answer.failed(e);
      _fail(source, e);
      return _Answer.failed(e);
    }
  }

  Future<_Answer<TopCard?>> _askCard() async {
    try {
      return _Answer.ok(await engine.catalog.topCard(query, hl, cancel: _token));
    } on Object catch (e) {
      if (_cancelled) return _Answer.failed(e);
      // The card is a bonus: its failure is not shown, but a 429 is remembered.
      AppLog.w('top card not read: $e');
      if (e is YtException && e.kind == YtErrorKind.rateLimited) {
        engine.cooldown.trip(MediaKind.ytmSong);
      }
      return _Answer.failed(e);
    }
  }

  /// One row's request. Its failure is not shown (the row is a bonus), but a
  /// 429 is remembered and a failed row keeps the rows out of the saved copy.
  Future<void> _row<T>(Future<List<T>> Function() call, void Function(List<T>) put) async {
    try {
      put((await call()).take(_rowLimit).toList());
    } on Object catch (e) {
      if (_cancelled) return;
      AppLog.w('search row not read: $e');
      _rowsFailed = true;
      // On purpose also the main source: a 429 is YouTube Music's as a whole.
      if (e is YtException && e.kind == YtErrorKind.rateLimited) {
        engine.cooldown.trip(MediaKind.ytmSong);
      }
    } finally {
      _rowsOpen--;
    }
  }

  void _fail(MediaKind source, Object e) {
    AppLog.w('online search on ${source.name} failed: $e');
    final kind = switch (e) {
      YtException(kind: YtErrorKind.rateLimited) => NoticeKind.rateLimited,
      YtException(kind: YtErrorKind.network) => NoticeKind.offline,
      _ => NoticeKind.failed,
    };
    if (kind == NoticeKind.rateLimited) engine.cooldown.trip(source);
    _notices.add(SearchNotice(source, kind));
  }

  Set<MediaKind> get _pending => {
        if (_asked.contains(MediaKind.ytmSong) && _songs == null) MediaKind.ytmSong,
        if (_asked.contains(MediaKind.ytVideo) && _videos == null) MediaKind.ytVideo,
      };

  bool get _anyResult =>
      _songs?.value != null || _videos?.value != null;

  /// A source answered (or failed): shows the first block when it is time,
  /// else folds the answer into what is on screen.
  void _onAnswer(QueryKind kind) {
    final shown = _shown;
    if (shown == null) {
      if (_everythingIn) {
        _capTimer?.cancel();
        // All failed: `_finish` reports it.
        if (_anyResult) _showFirst(kind);
      } else if (_anyResult && _capTimer == null) {
        _capTimer = Timer(engine.cap, () {
          if (_cancelled || _shown != null) return;
          _showFirst(kind);
        });
      }
      return;
    }
    _showLate();
  }

  List<ScoredResult> _scored({required bool useCard}) {
    final songs = _songs?.value ?? const <YtResult>[];
    final videos = _videos?.value ?? const <YtResult>[];
    if (classifyQuery(query).kind == QueryKind.video) {
      return [for (final (i, r) in videos.indexed) ScoredResult(r, 1, MediaKind.ytVideo, i)];
    }
    return scoreAll(query,
        songs: songs,
        videos: videos,
        card: useCard ? _card?.value : null,
        libraryArtists: engine.libraryArtists?.call() ?? const {});
  }

  /// What the phrase is, and whether that is known yet: from the card once it
  /// answered; when the card failed, from the artists row (the top artist
  /// against the phrase); otherwise not known, and the library stays out.
  (SearchIntent, bool) _intent() {
    final card = _card;
    if (card == null) return (SearchIntent.songs, false);
    if (card.error == null) return (intentOf(query, card.value), true);
    if (_rowsOpen > 0 || _artists.isEmpty) return (SearchIntent.songs, false);
    return (intentOf(query, TopArtist(_artists.first)), true);
  }

  SmartSearchState _base(QueryKind kind) {
    final (intent, known) = _intent();
    return SmartSearchState(
        query: query,
        queryKind: kind,
        card: _card?.value,
        intent: intent,
        intentKnown: known,
        pending: _pending,
        notices: [..._notices],
      );
  }

  void _showFirst(QueryKind kind) {
    final (intent, known) = _intent();
    final split = splitBest(mergeResults(_scored(useCard: true)), kBestThreshold,
        maxBest: _maxBest);
    final state = SmartSearchState(
      query: query,
      queryKind: kind,
      card: _card?.value,
      intent: intent,
      intentKnown: known,
      best: split.best,
      others: split.others,
      noneSure: split.noneSure,
      pending: _pending,
      notices: [..._notices],
      artists: _artists,
      albums: _albums,
    );
    _shown = state;
    _emit(state);
  }

  /// Folds the new answers into the rows on screen: a row of the same song is
  /// replaced where it stands, anything else goes to the end of its block.
  void _showLate() {
    final prev = _shown!;
    final card = prev.card ?? _card?.value;
    final (intent, known) = _intent();
    final full = mergeResults(_scored(useCard: false));
    final claimed = <SmartResult>{};
    SmartResult? latest(SmartResult old) {
      for (final row in full) {
        if (!claimed.contains(row) && row.ids.any(old.ids.toSet().contains)) {
          claimed.add(row);
          return row;
        }
      }
      return null;
    }

    final best = <SmartResult>[];
    final others = <SmartResult>[];
    for (final old in prev.best) {
      best.add(latest(old) ?? old);
    }
    for (final old in prev.others) {
      others.add(latest(old) ?? old);
    }
    var noneSure = prev.noneSure;
    for (final row in full) {
      if (claimed.contains(row)) continue;
      if (row.confidence >= kBestThreshold && best.length < _maxBest) {
        best.add(row);
        noneSure = false;
      } else {
        others.add(row);
      }
    }
    final state = SmartSearchState(
      query: query,
      queryKind: prev.queryKind,
      card: card,
      intent: intent,
      intentKnown: known,
      best: best,
      others: others,
      noneSure: noneSure,
      pending: _pending,
      notices: [..._notices],
      artists: _artists,
      albums: _albums,
    );
    final changed = !identical(state.card, prev.card) ||
        state.intent != prev.intent ||
        state.intentKnown != prev.intentKnown ||
        !_sameRows(state.best, prev.best) ||
        !_sameRows(state.others, prev.others) ||
        state.pending.length != prev.pending.length ||
        state.notices.length != prev.notices.length ||
        state.artists.length != prev.artists.length ||
        state.albums.length != prev.albums.length;
    _shown = state;
    if (changed) _emit(state);
  }

  bool _sameRows(List<SmartResult> a, List<SmartResult> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) =>
          a[i].primary.id == b[i].primary.id &&
          a[i].alternatives.length == b[i].alternatives.length);

  /// The main answers are in: the error at once if every source failed (the
  /// rows are dropped), else the copy kept for ten minutes. False when there is
  /// nothing more to wait for.
  bool _finish(String key) {
    final queryKind = classifyQuery(query).kind;
    if (_shown == null && !_anyResult) {
      // Every source failed.
      final first = [_songs, _videos].whereType<_Answer>().map((a) => a.error).nonNulls;
      _emit(_base(queryKind).copyWith(error: first.isEmpty ? 'no answer' : first.first));
      cancel();
      return false;
    }
    _store(key);
    return true;
  }

  /// A failed row does not stop the page being saved; the rows only join the
  /// copy when none failed (never half of them).
  void _store(String key) {
    if (_notices.isNotEmpty) return;
    final rowsIn = !_cardAsked || (!_rowsFailed && _rowsOpen == 0);
    final shown = _shown!;
    engine._store(
      key,
      rowsIn ? shown : shown.copyWith(artists: const [], albums: const []),
      rowsMissing: !rowsIn,
    );
  }
}
